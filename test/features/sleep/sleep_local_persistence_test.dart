import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sleep local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sleep-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists sleep entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 9, 0);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'sleep-entry-1',
        templateId: 'builtin:sleep',
        templateKey: 'sleep',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'sleep-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'hours_slept': 8.0,
          'quality': 4,
          'bedtime': '23:00',
          'wake_up_time': '07:00',
          'notes': 'Slept well',
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
        templateId: 'builtin:sleep',
        templateKey: 'sleep',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'sleep',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'hours_slept',
          'quality',
          'bedtime',
          'wake_up_time',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['hours_slept'], 8.0);
      expect(entries.single['quality'], 4);
      expect(entries.single['bedtime'], '23:00');
      expect(entries.single['wake_up_time'], '07:00');
    });
  });
}
