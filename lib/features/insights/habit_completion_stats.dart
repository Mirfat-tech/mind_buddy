import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

String _habitKey(String name) => name.trim().toLowerCase();

DateTime? _parseLocalDay(dynamic raw) {
  if (raw == null) return null;
  final parsed = raw is DateTime
      ? raw.toLocal()
      : DateTime.tryParse(raw.toString())?.toLocal();
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

Future<HabitMonthlyCompletionStats> fetchHabitMonthlyCompletionStats({
  required SupabaseClient supabase,
  required DateTime selectedMonth,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    return HabitMonthlyCompletionStats(
      monthStart: start,
      monthEndExclusive: DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        1,
      ),
      totalCompletedInstances: 0,
      uniqueDaysWithCompletion: 0,
      activeHabitsCount: 0,
      doneTodayCount: 0,
      completionsByDay: const {},
    );
  }

  final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final monthEndExclusive = DateTime(
    selectedMonth.year,
    selectedMonth.month + 1,
    1,
  );
  final startDay = _ymd(monthStart);
  final endExclusiveDay = _ymd(monthEndExclusive);

  final activeRows = await supabase
      .from('user_habits')
      .select('name')
      .eq('user_id', user.id)
      .eq('is_active', true);
  final activeHabitKeys = (activeRows as List)
      .map((r) => (r as Map)['name']?.toString() ?? '')
      .where((name) => name.trim().isNotEmpty)
      .map(_habitKey)
      .toSet();

  final completionRows = await supabase
      .from('habit_logs')
      .select('habit_name, day, is_completed')
      .eq('user_id', user.id)
      .eq('is_completed', true)
      .gte('day', startDay)
      .lt('day', endExclusiveDay);

  final todayKey = _ymd(DateTime.now().toLocal());
  final Map<int, int> countsByDay = {};
  final Set<int> activeDays = {};
  final Set<String> doneTodayHabitKeys = {};
  int total = 0;

  for (final r in (completionRows as List)) {
    final row = Map<String, dynamic>.from(r as Map);
    final habit = (row['habit_name'] ?? '').toString();
    final hk = _habitKey(habit);
    if (!activeHabitKeys.contains(hk)) continue;

    final day = _parseLocalDay(row['day']);
    if (day == null) continue;
    if (day.year != selectedMonth.year || day.month != selectedMonth.month) {
      continue;
    }

    countsByDay[day.day] = (countsByDay[day.day] ?? 0) + 1;
    activeDays.add(day.day);
    total += 1;

    if (_ymd(day) == todayKey) {
      doneTodayHabitKeys.add(hk);
    }
  }

  if (kDebugMode) {
    debugPrint(
      '📅 [HabitStats] start=$startDay end(exclusive)=$endExclusiveDay rows=${(completionRows).length} '
      'uniqueDays=${activeDays.length} total=$total doneToday=${doneTodayHabitKeys.length}',
    );
  }

  return HabitMonthlyCompletionStats(
    monthStart: monthStart,
    monthEndExclusive: monthEndExclusive,
    totalCompletedInstances: total,
    uniqueDaysWithCompletion: activeDays.length,
    activeHabitsCount: activeHabitKeys.length,
    doneTodayCount: doneTodayHabitKeys.length,
    completionsByDay: countsByDay,
  );
}
