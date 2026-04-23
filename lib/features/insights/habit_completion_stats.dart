import 'package:flutter/foundation.dart';
import 'package:mind_buddy/features/habits/habit_local_repository.dart';

class HabitMonthlyCompletionStats {
  final DateTime monthStart;
  final DateTime monthEndExclusive;
  final int totalCompletedInstances;
  final int uniqueDaysWithCompletion;
  final int activeHabitsCount;
  final int doneTodayCount;
  final Map<int, int> completionsByDay;

  const HabitMonthlyCompletionStats({
    required this.monthStart,
    required this.monthEndExclusive,
    required this.totalCompletedInstances,
    required this.uniqueDaysWithCompletion,
    required this.activeHabitsCount,
    required this.doneTodayCount,
    required this.completionsByDay,
  });
}

String _ymd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

Future<HabitMonthlyCompletionStats> fetchHabitMonthlyCompletionStats({
  required DateTime selectedMonth,
}) async {
  debugPrint('INSIGHTS_LOAD_LOCAL source=habits');
  final stats = await HabitLocalRepository().loadMonthlyStats(selectedMonth);
  if (kDebugMode) {
    debugPrint(
      '📅 [HabitStats] start=${_ymd(stats.monthStart)} end(exclusive)=${_ymd(stats.monthEndExclusive)} '
      'uniqueDays=${stats.uniqueDaysWithCompletion} total=${stats.totalCompletedInstances} doneToday=${stats.doneTodayCount}',
    );
  }
  return stats;
}
