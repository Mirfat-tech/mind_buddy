import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Custom templates local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('custom-template-local-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists custom template definitions and entries across reopen',
      () async {
        final firstDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
        final now = DateTime.utc(2026, 4, 17, 13, 30);

        await firstDataSource.ensureBuiltInDefinitions();
        await firstDataSource.saveTemplateDefinition(
          id: 'custom:template-1',
          templateKey: 'reading_sprints',
          name: 'Reading Sprints',
          userId: 'user-1',
          fields: const <Map<String, dynamic>>[
            {
              'field_key': 'book',
              'label': 'Book',
              'field_type': 'text',
              'sort_order': 0,
            },
            {
              'field_key': 'minutes',
              'label': 'Minutes',
              'field_type': 'number',
              'sort_order': 1,
            },
          ],
        );
        await firstDataSource.saveEntry(
          id: 'custom-entry-1',
          templateId: 'custom:template-1',
          templateKey: 'reading_sprints',
          userId: 'user-1',
          day: '2026-04-17',
          payload: <String, dynamic>{
            'id': 'custom-entry-1',
            'user_id': 'user-1',
            'day': '2026-04-17',
            'book': 'Deep Work',
            'minutes': 25,
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

        final template = await secondDataSource.loadTemplateDefinition(
          templateId: 'custom:template-1',
          templateKey: 'reading_sprints',
        );
        final entries = await secondDataSource.loadEntries(
          templateKey: 'reading_sprints',
          userId: 'user-1',
        );

        expect(template, isNotNull);
        expect(template!.name, 'Reading Sprints');
        expect(template.templateKey, 'reading_sprints');
        expect(
          template.fields.map((field) => field['field_key']),
          containsAll(<String>['book', 'minutes']),
        );
        expect(entries, hasLength(1));
        expect(entries.single['book'], 'Deep Work');
        expect(entries.single['minutes'], 25);
      },
    );
  });
}
