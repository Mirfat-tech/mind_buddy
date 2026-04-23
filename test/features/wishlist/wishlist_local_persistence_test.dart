import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wishlist local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wishlist-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists wishlist entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 17, 13, 30);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'wishlist-entry-1',
        templateId: 'builtin:wishlist',
        templateKey: 'wishlist',
        userId: 'user-1',
        day: '2026-04-17',
        payload: <String, dynamic>{
          'id': 'wishlist-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-17',
          'item_name': 'Noise-cancelling headphones',
          'currency': 'GBP',
          'estimated_price': 249.99,
          'priority': 5,
          'status': '🛍️ To Buy',
          'notes': 'Watch for sales',
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
        templateId: 'builtin:wishlist',
        templateKey: 'wishlist',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'wishlist',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'item_name',
          'currency',
          'estimated_price',
          'priority',
          'status',
          'notes',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['item_name'], 'Noise-cancelling headphones');
      expect(entries.single['priority'], 5);
      expect(entries.single['status'], '🛍️ To Buy');
    });
  });
}
