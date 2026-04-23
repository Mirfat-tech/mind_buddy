import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Restaurants local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'restaurants-local-first-',
      );
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists restaurant entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 17, 11, 0);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'restaurant-entry-1',
        templateId: 'builtin:restaurants',
        templateKey: 'restaurants',
        userId: 'user-1',
        day: '2026-04-17',
        payload: <String, dynamic>{
          'id': 'restaurant-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-17',
          'restaurant_name': 'Dishoom',
          'cuisine_type': 'Indian',
          'location': 'London',
          'rating': 5,
          'notes': 'Great breakfast',
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
        templateId: 'builtin:restaurants',
        templateKey: 'restaurants',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'restaurants',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'restaurant_name',
          'cuisine_type',
          'location',
          'rating',
          'notes',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['restaurant_name'], 'Dishoom');
      expect(entries.single['cuisine_type'], 'Indian');
      expect(entries.single['rating'], 5);
    });
  });
}
