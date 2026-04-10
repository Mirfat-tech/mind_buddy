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

DateTime? _parseLocalDay(dynamic raw) {
  if (raw == null) return null;
  final parsed = raw is DateTime
      ? raw.toLocal()
      : DateTime.tryParse(raw.toString())?.toLocal();
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _habitActiveFrom(
  Map<String, dynamic> row, {
  DateTime? earliestLoggedDay,
}) {
  return _parseLocalDay(
        row['start_date'] ?? row['active_from'] ?? row['created_at'],
      ) ??
      earliestLoggedDay;
}

DateTime? _habitActiveUntil(Map<String, dynamic> row) {
  return _parseLocalDay(
    row['end_date'] ??
        row['ended_at'] ??
        row['deleted_at'] ??
        row['archived_at'] ??
        row['inactive_at'] ??
        ((row['is_active'] == false) ? row['updated_at'] : null),
  );
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
      .select()
      .eq('user_id', user.id);
  final historyRows = await supabase
      .from('habit_logs')
      .select('habit_id, day')
      .eq('user_id', user.id)
      .lt('day', endExclusiveDay);
  final earliestLoggedDayByHabit = <String, DateTime>{};
  for (final raw in (historyRows as List)) {
    final row = Map<String, dynamic>.from(raw as Map);
    final hid = (row['habit_id'] ?? '').toString().trim();
    if (hid.isEmpty) continue;
    final loggedDay = _parseLocalDay(row['day']);
    if (loggedDay == null) continue;
    final existing = earliestLoggedDayByHabit[hid];
    if (existing == null || loggedDay.isBefore(existing)) {
      earliestLoggedDayByHabit[hid] = loggedDay;
    }
  }
  final activeHabitIds = <String>{};
  for (final raw in (activeRows as List)) {
    final row = Map<String, dynamic>.from(raw as Map);
    final id = (row['id'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    final activeFrom = _habitActiveFrom(
      row,
      earliestLoggedDay: earliestLoggedDayByHabit[id],
    );
    final activeUntil = _habitActiveUntil(row);
    if (activeFrom != null && !activeFrom.isBefore(monthEndExclusive)) {
      continue;
    }
    if (activeUntil != null && activeUntil.isBefore(monthStart)) {
      continue;
    }
    activeHabitIds.add(id);
  }

  final completionRows = await supabase
      .from('habit_logs')
      .select('habit_id, habit_name, day, is_completed')
      .eq('user_id', user.id)
      .gte('day', startDay)
      .lt('day', endExclusiveDay);

  final todayKey = _ymd(DateTime.now().toLocal());
  final entryByHabitDay = <String, bool>{};
  final idSourceByHabitDay = <String, bool>{};

  for (final r in (completionRows as List)) {
    final row = Map<String, dynamic>.from(r as Map);
    final hid = (row['habit_id'] ?? '').toString().trim();
    if (hid.isEmpty || !activeHabitIds.contains(hid)) continue;

    final day = _parseLocalDay(row['day']);
    if (day == null) continue;
    if (day.year != selectedMonth.year || day.month != selectedMonth.month) {
      continue;
    }
    final isIdSource = hid.isNotEmpty;
    final key = '$hid|${_ymd(day)}';
    if (isIdSource) {
      entryByHabitDay[key] = row['is_completed'] == true;
      idSourceByHabitDay[key] = true;
      continue;
    }
    if (idSourceByHabitDay[key] == true) continue;
    entryByHabitDay[key] = row['is_completed'] == true;
  }

  final Map<int, int> countsByDay = {};
  final Set<int> activeDays = {};
  final Set<String> doneTodayHabitIds = {};
  int total = 0;
  for (final entry in entryByHabitDay.entries) {
    if (entry.value != true) continue;
    final parts = entry.key.split('|');
    if (parts.length != 2) continue;
    final hid = parts[0];
    final day = _parseLocalDay(parts[1]);
    if (day == null) continue;
    countsByDay[day.day] = (countsByDay[day.day] ?? 0) + 1;
    activeDays.add(day.day);
    total += 1;
    if (_ymd(day) == todayKey) {
      doneTodayHabitIds.add(hid);
    }
  }

  if (kDebugMode) {
    debugPrint(
      '📅 [HabitStats] start=$startDay end(exclusive)=$endExclusiveDay rows=${(completionRows).length} '
      'uniqueDays=${activeDays.length} total=$total doneToday=${doneTodayHabitIds.length}',
    );
  }

  return HabitMonthlyCompletionStats(
    monthStart: monthStart,
    monthEndExclusive: monthEndExclusive,
    totalCompletedInstances: total,
    uniqueDaysWithCompletion: activeDays.length,
    activeHabitsCount: activeHabitIds.length,
    doneTodayCount: doneTodayHabitIds.length,
    completionsByDay: countsByDay,
  );
}
