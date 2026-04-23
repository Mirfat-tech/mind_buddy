import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/brain_fog/data/local/brain_fog_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Brain fog local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brain-fog-local-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists brain fog state across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = BrainFogLocalDataSource(firstDatabase);

      await firstDataSource.save(
        userId: 'user-1',
        thoughts: const <BrainFogThoughtRecord>[
          BrainFogThoughtRecord(
            id: 'thought-1',
            text: 'Reply to that email',
            dx: 120,
            dy: 240,
          ),
          BrainFogThoughtRecord(
            id: 'thought-2',
            text: 'Book dentist appointment',
            dx: 260,
            dy: 180,
          ),
        ],
        isDeleteMode: false,
        figureOutMode: true,
        figureStep: 2,
        controllableIds: const <String>{'thought-1'},
        focusOrder: const <String>['thought-1'],
        reason: 'test_save',
      );
      await firstDatabase.close();

      final secondDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      addTearDown(secondDatabase.close);
      final secondDataSource = BrainFogLocalDataSource(secondDatabase);

      final restored = await secondDataSource.load(userId: 'user-1');

      expect(restored, isNotNull);
      expect(restored!.thoughts, hasLength(2));
      expect(restored.thoughts.first.id, 'thought-1');
      expect(restored.thoughts.first.text, 'Reply to that email');
      expect(restored.figureOutMode, isTrue);
      expect(restored.figureStep, 2);
      expect(restored.controllableIds, contains('thought-1'));
      expect(restored.focusOrder, orderedEquals(const <String>['thought-1']));
    });
  });
}
