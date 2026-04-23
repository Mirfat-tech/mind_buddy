import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cycle local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cycle-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists cycle entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 10, 0);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'cycle-entry-1',
        templateId: 'builtin:cycle',
        templateKey: 'cycle',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'cycle-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'flow': 'Medium',
          'symptoms': 'Cramps, Fatigue',
          'cramps': 3,
          'libido': 2,
          'energy_level': 4,
          'stress_level': 2,
          'pregnancy_test': 'Not Done',
          'notes': 'Stored locally first',
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
        templateId: 'builtin:cycle',
        templateKey: 'cycle',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'cycle',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'flow',
          'symptoms',
          'cramps',
          'libido',
          'energy_level',
          'stress_level',
          'pregnancy_test',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['flow'], 'Medium');
      expect(entries.single['symptoms'], 'Cramps, Fatigue');
      expect(entries.single['cramps'], 3);
      expect(entries.single['pregnancy_test'], 'Not Done');
    });
  });
}
