import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Books local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('books-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists books entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 9, 30);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'books-entry-1',
        templateId: 'builtin:books',
        templateKey: 'books',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'books-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'book_title': 'Deep Work',
          'author': 'Cal Newport',
          'category': 'Productivity',
          'current_page': 42,
          'rating': 5,
          'notes': 'Still there after restart',
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
        templateId: 'builtin:books',
        templateKey: 'books',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'books',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'book_title',
          'author',
          'category',
          'current_page',
          'rating',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['book_title'], 'Deep Work');
      expect(entries.single['author'], 'Cal Newport');
      expect(entries.single['category'], 'Productivity');
      expect(entries.single['current_page'], 42);
      expect(entries.single['rating'], 5);
    });
  });
}
