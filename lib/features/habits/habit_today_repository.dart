import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/features/habits/habit_home_widget_service.dart';
import 'package:mind_buddy/features/habits/habit_local_repository.dart';
import 'package:mind_buddy/features/habits/habit_models.dart';

class HabitTodayRepository {
  HabitTodayRepository({SupabaseClient? client})
    : _localRepository = HabitLocalRepository(
        supabase: client ?? Supabase.instance.client,
      );

  final HabitLocalRepository _localRepository;

  Future<List<TodayHabitItem>> fetchTodayHabits() async {
    final items = await _localRepository.loadTodayHabits();
    final groupedCounts = <String, int>{};
    for (final item in items) {
      groupedCounts.update(
        item.categoryName,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    _debugLog(
      'load_local count=${items.length} grouped=${groupedCounts.entries.map((e) => '${e.key}:${e.value}').join(', ')}',
    );
    return items;
  }

  Future<bool> setHabitCompletion({
    required String habitId,
    required String habitName,
    required bool isCompleted,
    DateTime? day,
  }) async {
    debugPrint(
      'HABIT_UI_SAVE_TRIGGERED kind=bubble_toggle habitId=$habitId isCompleted=$isCompleted day=${day?.toIso8601String() ?? 'today'}',
    );
    final rewardAwarded = await _localRepository.setHabitCompletion(
      habitId: habitId,
      habitName: habitName,
      isCompleted: isCompleted,
      day: day,
    );
    await HabitHomeWidgetService.syncTodaySnapshot();
    return rewardAwarded;
  }

  static void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[HabitBubble] $message');
    }
  }
}
