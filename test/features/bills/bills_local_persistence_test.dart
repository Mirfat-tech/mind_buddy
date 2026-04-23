import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bills local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bills-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists bills entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 9, 15);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'bills-entry-1',
        templateId: 'builtin:bills',
        templateKey: 'bills',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'bills-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'name': 'Electricity',
          'category': 'Utilities',
          'currency': 'GBP',
          'amount': 89.99,
          'is_paid': true,
          'notes': 'Paid offline',
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
        templateId: 'builtin:bills',
        templateKey: 'bills',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'bills',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'name',
          'category',
          'currency',
          'amount',
          'is_paid',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['name'], 'Electricity');
      expect(entries.single['category'], 'Utilities');
      expect(entries.single['currency'], 'GBP');
      expect(entries.single['amount'], 89.99);
      expect(entries.single['is_paid'], true);
    });

    test('persists bills entries when is_paid is false', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 9, 20);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'bills-entry-2',
        templateId: 'builtin:bills',
        templateKey: 'bills',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'bills-entry-2',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'name': 'Internet',
          'category': 'Utilities',
          'currency': 'GBP',
          'amount': 49.99,
          'is_paid': false,
          'notes': 'Unpaid default preserved',
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

      final entries = await secondDataSource.loadEntries(
        templateKey: 'bills',
        userId: 'user-1',
      );
      final unpaidEntry = entries.singleWhere(
        (entry) => entry['id'] == 'bills-entry-2',
      );

      expect(unpaidEntry['name'], 'Internet');
      expect(unpaidEntry['amount'], 49.99);
      expect(unpaidEntry['is_paid'], false);
    });
  });
}
