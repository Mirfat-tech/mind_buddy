import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Skin Care local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('skin-care-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists skin care entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 17, 11, 30);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'skin-care-entry-1',
        templateId: 'builtin:skin_care',
        templateKey: 'skin_care',
        userId: 'user-1',
        day: '2026-04-17',
        payload: <String, dynamic>{
          'id': 'skin-care-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-17',
          'routine_type': 'Evening',
          'products': 'Cleanser, serum, moisturiser',
          'skin_condition': 'Balanced',
          'notes': 'Felt gentle and calming',
        },
        syncStatus: SyncStatus.pendingUpsert,
        createdAt: now,
        updatedAt: now,
      );
      await firstDatabase.close();

      final secondDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      addTearDown(secondDatabase.close);
      final secondDataSource = TemplateLogsLocalDataSource(secondDatabase);

      final definition = await secondDataSource.loadTemplateDefinition(
        templateId: 'builtin:skin_care',
        templateKey: 'skin_care',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'skin_care',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'routine_type',
          'products',
          'skin_condition',
          'notes',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['routine_type'], 'Evening');
      expect(entries.single['skin_condition'], 'Balanced');
      expect(entries.single['products'], 'Cleanser, serum, moisturiser');
    });
  });
}
