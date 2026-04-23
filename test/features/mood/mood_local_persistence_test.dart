import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mood local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mood-local-first-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists mood entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 16, 8, 30);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'mood-entry-1',
        templateId: 'builtin:mood',
        templateKey: 'mood',
        userId: 'user-1',
        day: '2026-04-16',
        payload: <String, dynamic>{
          'id': 'mood-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-16',
          'feeling': 'Happy',
          'intensity': 4,
          'notes': 'Stored offline first',
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
        templateId: 'builtin:mood',
        templateKey: 'mood',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'mood',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>['feeling', 'intensity', 'notes']),
      );
      expect(entries, hasLength(1));
      expect(entries.single['feeling'], 'Happy');
      expect(entries.single['intensity'], 4);
      expect(entries.single['notes'], 'Stored offline first');
    });
  });
}
