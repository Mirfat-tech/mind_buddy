import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Water local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('water-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists water entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 8, 45);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'water-entry-1',
        templateId: 'builtin:water',
        templateKey: 'water',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'water-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'amount': 500,
          'unit': 'ml',
          'goal_reached': true,
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
        templateId: 'builtin:water',
        templateKey: 'water',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'water',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>['amount', 'unit', 'goal_reached']),
      );
      expect(entries, hasLength(1));
      expect(entries.single['amount'], 500);
      expect(entries.single['unit'], 'ml');
      expect(entries.single['goal_reached'], true);
    });
  });
}
