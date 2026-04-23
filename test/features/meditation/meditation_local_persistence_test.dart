import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Meditation local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'meditation-local-first-',
      );
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists meditation entries across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = TemplateLogsLocalDataSource(firstDatabase);
      final now = DateTime.utc(2026, 4, 17, 9, 15);

      await firstDataSource.ensureBuiltInDefinitions();
      await firstDataSource.saveEntry(
        id: 'meditation-entry-1',
        templateId: 'builtin:meditation',
        templateKey: 'meditation',
        userId: 'user-1',
        day: '2026-04-17',
        payload: <String, dynamic>{
          'id': 'meditation-entry-1',
          'user_id': 'user-1',
          'day': '2026-04-17',
          'duration_minutes': 20.0,
          'technique': '🌬️ Breathwork',
          'focus_rating': 4,
          'notes': 'Quiet session offline',
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
        templateId: 'builtin:meditation',
        templateKey: 'meditation',
      );
      final entries = await secondDataSource.loadEntries(
        templateKey: 'meditation',
        userId: 'user-1',
      );

      expect(definition, isNotNull);
      expect(
        definition!.fields.map((field) => field['field_key']),
        containsAll(<String>[
          'duration_minutes',
          'technique',
          'focus_rating',
          'notes',
        ]),
      );
      expect(entries, hasLength(1));
      expect(entries.single['duration_minutes'], 20.0);
      expect(entries.single['technique'], '🌬️ Breathwork');
      expect(entries.single['focus_rating'], 4);
    });
  });
}
