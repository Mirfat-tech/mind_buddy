import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Study local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('study-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists study entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 17, 13, 30);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'study-entry-1',
        templateId: 'builtin:study',
        templateKey: 'study',
        userId: 'user-1',
        day: '2026-04-17',
        payload: <String, dynamic>{
          'id': 'study-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-17',
          'subject': 'Math',
          'duration_hours': 1.5,
          'study_methods': 'flashcards,practice tests',
          'focus_rating': 4,
          'notes': 'Strong revision session',
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
        templateId: 'builtin:study',
        templateKey: 'study',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'study',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'subject',
          'duration_hours',
          'study_methods',
          'focus_rating',
          'notes',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['subject'], 'Math');
      expect(entries.single['duration_hours'], 1.5);
      expect(entries.single['focus_rating'], 4);
    });
  });
}
