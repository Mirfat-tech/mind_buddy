import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/journal/data/local/journal_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Journal local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('journal-local-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists owned journal entries and folders across database reopen',
      () async {
        final firstDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        final firstDataSource = JournalLocalDataSource(firstDatabase);

        await firstDataSource
            .saveFolders('user-1', const <LocalJournalFolderRecord>[
              LocalJournalFolderRecord(
                id: 'folder-1',
                userId: 'user-1',
                name: 'Morning Pages',
                colorKey: 'pink',
                iconStyle: 'bubble_folder',
                createdAt: '2026-04-18T08:00:00.000Z',
                updatedAt: '2026-04-18T08:00:00.000Z',
              ),
            ], reason: 'test_save_folders');
        await firstDataSource
            .saveEntries('user-1', const <LocalJournalEntryRecord>[
              LocalJournalEntryRecord(
                id: 'journal-1',
                userId: 'user-1',
                title: 'A quiet morning',
                text: '[{\"insert\":\"hello\\n\"}]',
                dayId: '2026-04-18',
                folderId: 'folder-1',
                isArchived: false,
                isShared: false,
                createdAt: '2026-04-18T08:05:00.000Z',
                updatedAt: '2026-04-18T08:05:00.000Z',
              ),
            ], reason: 'test_save_entries');
        await firstDatabase.close();

        final secondDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        addTearDown(secondDatabase.close);
        final secondDataSource = JournalLocalDataSource(secondDatabase);

        final folders = await secondDataSource.loadFolders('user-1');
        final entries = await secondDataSource.loadEntries('user-1');

        expect(folders, hasLength(1));
        expect(entries, hasLength(1));
        expect(folders.first.name, 'Morning Pages');
        expect(entries.first.title, 'A quiet morning');
        expect(entries.first.folderId, 'folder-1');
        expect(entries.first.text, '[{\"insert\":\"hello\\n\"}]');
      },
    );
  });
}
