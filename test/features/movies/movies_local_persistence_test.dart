import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Movies local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('movies-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists movie entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 17, 9, 30);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'movies-entry-1',
        templateId: 'builtin:movies',
        templateKey: 'movies',
        userId: 'user-1',
        day: '2026-04-17',
        payload: <String, dynamic>{
          'id': 'movies-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-17',
          'movie_title': 'Arrival',
          'genre': 'Sci-Fi',
          'rating': 5,
          'location': '🏠 Home',
          'status': '✅ Finished',
          'notes': 'Watched offline first',
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
        templateId: 'builtin:movies',
        templateKey: 'movies',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'movies',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'movie_title',
          'genre',
          'rating',
          'location',
          'status',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['movie_title'], 'Arrival');
      expect(entries.single['genre'], 'Sci-Fi');
      expect(entries.single['rating'], 5);
      expect(entries.single['status'], '✅ Finished');
    });
  });
}
