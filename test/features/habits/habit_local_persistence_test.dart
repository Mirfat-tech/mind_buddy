import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/habits/data/local/habit_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Habit local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('habit-local-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists habits, categories, and completions across database reopen',
      () async {
        final firstDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        final firstDataSource = HabitLocalDataSource(firstDatabase);

        await firstDataSource.save(
          userId: 'user-1',
          categories: const <HabitCategoryRecord>[
            HabitCategoryRecord(
              id: 'cat-1',
              name: 'Morning',
              icon: '🌅',
              sortOrder: 0,
            ),
          ],
          habits: const <HabitDefinitionRecord>[
            HabitDefinitionRecord(
              id: 'habit-1',
              name: 'Drink water',
              categoryId: 'cat-1',
              sortOrder: 0,
              isActive: true,
              startDate: '2026-04-18T08:00:00.000Z',
              activeFrom: '2026-04-18T08:00:00.000Z',
              updatedAt: '2026-04-18T08:00:00.000Z',
            ),
          ],
          completions: const <HabitCompletionRecord>[
            HabitCompletionRecord(
              habitId: 'habit-1',
              habitName: 'Drink water',
              day: '2026-04-18',
              isCompleted: true,
            ),
          ],
          reason: 'test_save',
        );
        await firstDatabase.close();

        final secondDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        addTearDown(secondDatabase.close);
        final secondDataSource = HabitLocalDataSource(secondDatabase);

        final restored = await secondDataSource.load(userId: 'user-1');

        expect(restored, isNotNull);
        expect(restored!.categories, hasLength(1));
        expect(restored.habits, hasLength(1));
        expect(restored.completions, hasLength(1));
        expect(restored.categories.first.name, 'Morning');
        expect(restored.habits.first.name, 'Drink water');
        expect(restored.completions.first.isCompleted, isTrue);
      },
    );
  });
}
