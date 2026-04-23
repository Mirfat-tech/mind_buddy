import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expenses local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('expenses-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists expenses entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 10, 15);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'expenses-entry-1',
        templateId: 'builtin:expenses',
        templateKey: 'expenses',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'expenses-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'item_service': 'Groceries',
          'category': '🛒 Groceries',
          'currency': 'GBP',
          'cost': 24.50,
          'status': '✅ Paid',
          'notes': 'Saved offline first',
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
        templateId: 'builtin:expenses',
        templateKey: 'expenses',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'expenses',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'item_service',
          'category',
          'currency',
          'cost',
          'status',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['item_service'], 'Groceries');
      expect(entries.single['currency'], 'GBP');
      expect(entries.single['cost'], 24.50);
      expect(entries.single['status'], '✅ Paid');
    });
  });
}
