import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/bubble_coins/bubble_coin_reward_service.dart';
import 'package:mind_buddy/features/habits/data/local/habit_local_data_source.dart';
import 'package:mind_buddy/features/habits/habit_category_catalog.dart';
import 'package:mind_buddy/features/habits/habit_models.dart';
import 'package:mind_buddy/features/insights/habit_completion_stats.dart';

class HabitMonthGridState {
  const HabitMonthGridState({
    required this.habitsWithMetadata,
    required this.doneByHabitId,
    required this.labelWidth,
  });

  final List<Map<String, dynamic>> habitsWithMetadata;
  final Map<String, Set<String>> doneByHabitId;
  final double labelWidth;
}

class HabitManageState {
  const HabitManageState({
    required this.categories,
    required this.habits,
    required this.streaksByHabitName,
  });

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> habits;
  final Map<String, ({int current, int best})> streaksByHabitName;
}

class HabitStreakRow {
  const HabitStreakRow({
    required this.habit,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastDoneDay,
  });

  final String habit;
  final int currentStreak;
  final int longestStreak;
  final String? lastDoneDay;
}

class HabitLocalRepository {
  HabitLocalRepository({AppDatabase? database, SupabaseClient? supabase})
    : _database = database ?? AppDatabase.shared(),
      _localDataSource = HabitLocalDataSource(database ?? AppDatabase.shared()),
      _bubbleCoinRewardService = BubbleCoinRewardService(
        database: database ?? AppDatabase.shared(),
        supabase: supabase ?? Supabase.instance.client,
      ),
      _supabase = supabase ?? Supabase.instance.client;

  static const _uuid = Uuid();

  final AppDatabase _database;
  final HabitLocalDataSource _localDataSource;
  final BubbleCoinRewardService _bubbleCoinRewardService;
  final SupabaseClient _supabase;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<HabitLocalStateRecord> _ensureState(String userId) async {
    final existing = await _localDataSource.load(userId: userId);
    if (existing != null) return existing;

    final seeded = HabitLocalStateRecord(
      userId: userId,
      categories: <HabitCategoryRecord>[
        for (final preset in HabitCategoryCatalog.builtInCategories)
          HabitCategoryRecord(
            id: 'habit-category-${preset.sortOrder}',
            name: preset.name,
            icon: preset.icon,
            sortOrder: preset.sortOrder,
          ),
      ],
      habits: const <HabitDefinitionRecord>[],
      completions: const <HabitCompletionRecord>[],
      updatedAt: DateTime.now().toUtc(),
    );
    await _saveState(seeded, reason: 'seed_defaults');
    return seeded;
  }

  Future<void> _saveState(
    HabitLocalStateRecord state, {
    required String reason,
  }) async {
    await _localDataSource.save(
      userId: state.userId,
      categories: state.categories,
      habits: state.habits,
      completions: state.completions,
      reason: reason,
    );
    debugPrint('HABIT_QUEUE_SYNC userId=${state.userId} kind=$reason');
    debugPrint(
      'HABIT_REMOTE_SKIPPED_OFFLINE userId=${state.userId} reason=habit_sync_not_enabled',
    );
  }

  Future<List<TodayHabitItem>> loadTodayHabits() async {
    final userId = currentUserId;
    if (userId == null) return const <TodayHabitItem>[];
    debugPrint('HABIT_LOAD_FROM_LOCAL_START userId=$userId kind=today_habits');
    final state = await _ensureState(userId);
    final today = _today();
    final todayKey = _ymd(today);
    final categorySortByName = <String, int>{
      for (final category in state.categories)
        category.name.trim().toLowerCase(): category.sortOrder,
    };
    final completionByHabitId = <String, bool>{};
    for (final completion in state.completions) {
      if (completion.day == todayKey) {
        completionByHabitId[completion.habitId] = completion.isCompleted;
      }
    }
    final items = <TodayHabitItem>[];
    for (final habit in state.habits) {
      if (!habit.isActive) continue;
      final activeFrom = _parseLocalDay(habit.startDate ?? habit.activeFrom);
      if (activeFrom != null && activeFrom.isAfter(today)) {
        continue;
      }
      final categoryName = _resolveCategoryName(
        state.categories,
        habit.categoryId,
      );
      items.add(
        TodayHabitItem(
          id: habit.id,
          name: habit.name,
          categoryName: categoryName,
          categorySortOrder:
              categorySortByName[categoryName.toLowerCase()] ?? 999,
          sortOrder: habit.sortOrder,
          startedAt: activeFrom,
          isCompleted: completionByHabitId[habit.id] == true,
        ),
      );
    }
    items.sort((a, b) {
      final categoryCompare = a.categorySortOrder.compareTo(
        b.categorySortOrder,
      );
      if (categoryCompare != 0) return categoryCompare;
      final nameCompare = a.categoryName.toLowerCase().compareTo(
        b.categoryName.toLowerCase(),
      );
      if (nameCompare != 0) return nameCompare;
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      if (sortCompare != 0) return sortCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_RESULT userId=$userId kind=today_habits count=${items.length}',
    );
    return items;
  }

  Future<bool> setHabitCompletion({
    required String habitId,
    required String habitName,
    required bool isCompleted,
    DateTime? day,
  }) async {
    final userId = currentUserId;
    if (userId == null) return false;
    debugPrint(
      'HABIT_UI_SAVE_TRIGGERED userId=$userId kind=completion_toggle habitId=$habitId day=${_ymd(day ?? DateTime.now())} isCompleted=$isCompleted',
    );
    final dayKey = _ymd(day ?? DateTime.now());
    return _database.transaction(() async {
      final state = await _ensureState(userId);
      final completions = state.completions.toList(growable: true);
      final index = completions.indexWhere(
        (item) => item.habitId == habitId && item.day == dayKey,
      );
      final previousRecord = index == -1 ? null : completions[index];
      final wasCompleted = previousRecord?.isCompleted == true;
      final nextRecord = HabitCompletionRecord(
        habitId: habitId,
        habitName: habitName,
        day: dayKey,
        isCompleted: isCompleted,
      );

      if (previousRecord != null &&
          previousRecord.isCompleted == nextRecord.isCompleted &&
          previousRecord.habitName == nextRecord.habitName) {
        return false;
      }

      if (index == -1) {
        completions.add(nextRecord);
      } else {
        completions[index] = nextRecord;
      }

      await _saveState(
        HabitLocalStateRecord(
          userId: state.userId,
          categories: state.categories,
          habits: state.habits,
          completions: completions,
          updatedAt: DateTime.now().toUtc(),
        ),
        reason: 'completion_toggle',
      );

      if (!wasCompleted && isCompleted) {
        final didAward = await _bubbleCoinRewardService.awardHabitCompletion(
          userId: userId,
          habitId: habitId,
          habitName: habitName,
          day: dayKey,
        );
        debugPrint(
          'BUBBLE_COIN_REWARD_TRIGGERED userId=$userId habitId=$habitId day=$dayKey awarded=$didAward source=HabitLocalRepository.setHabitCompletion',
        );
        return didAward;
      }
      return false;
    });
  }

  Future<HabitMonthGridState> loadMonthGrid(DateTime month) async {
    final userId = currentUserId;
    if (userId == null) {
      return const HabitMonthGridState(
        habitsWithMetadata: <Map<String, dynamic>>[],
        doneByHabitId: <String, Set<String>>{},
        labelWidth: 110,
      );
    }
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_START userId=$userId kind=month_grid month=${month.year}-${month.month.toString().padLeft(2, '0')}',
    );
    final state = await _ensureState(userId);
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEndExclusive = DateTime(month.year, month.month + 1, 1);
    final earliestLoggedDayByHabit = <String, DateTime>{};
    for (final completion in state.completions) {
      final loggedDay = _parseLocalDay(completion.day);
      if (loggedDay == null) continue;
      final existing = earliestLoggedDayByHabit[completion.habitId];
      if (existing == null || loggedDay.isBefore(existing)) {
        earliestLoggedDayByHabit[completion.habitId] = loggedDay;
      }
    }
    final localHabits = <Map<String, dynamic>>[];
    for (final habit in state.habits) {
      final activeFrom = _habitActiveFrom(
        habit,
        earliestLoggedDay: earliestLoggedDayByHabit[habit.id],
      );
      final activeUntil = _habitActiveUntil(habit);
      if (activeFrom != null && !activeFrom.isBefore(monthEndExclusive)) {
        continue;
      }
      if (activeUntil != null && activeUntil.isBefore(monthStart)) {
        continue;
      }
      final categoryName = _resolveCategoryName(
        state.categories,
        habit.categoryId,
      );
      localHabits.add(<String, dynamic>{
        'id': habit.id,
        'name': habit.name,
        'category_id': habit.categoryId,
        'sort_order': habit.sortOrder,
        'is_active': habit.isActive,
        'start_date': habit.startDate,
        'active_from': habit.activeFrom,
        'updated_at': habit.updatedAt,
        'habit_categories': <String, dynamic>{'name': categoryName},
        if (activeFrom != null) '_active_from': _ymd(activeFrom),
        if (activeUntil != null) '_active_until': _ymd(activeUntil),
      });
    }
    final labelWidth = _computeLabelWidth(
      localHabits
          .map((h) => (h['name'] ?? '').toString())
          .toList(growable: false),
    );
    final activeIds = localHabits
        .map((h) => (h['id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final doneByHabitId = <String, Set<String>>{};
    for (final completion in state.completions) {
      final hid = completion.habitId.trim();
      if (!activeIds.contains(hid) || completion.isCompleted != true) continue;
      final day = _parseLocalDay(completion.day);
      if (day == null) continue;
      if (day.year != month.year || day.month != month.month) continue;
      doneByHabitId.putIfAbsent(hid, () => <String>{}).add(_ymd(day));
    }
    final result = HabitMonthGridState(
      habitsWithMetadata: localHabits,
      doneByHabitId: doneByHabitId,
      labelWidth: labelWidth,
    );
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_RESULT userId=$userId kind=month_grid habitCount=${result.habitsWithMetadata.length} doneGroupCount=${result.doneByHabitId.length}',
    );
    return result;
  }

  Future<HabitMonthlyCompletionStats> loadMonthlyStats(
    DateTime selectedMonth,
  ) async {
    final userId = currentUserId;
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthEndExclusive = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );
    if (userId == null) {
      return HabitMonthlyCompletionStats(
        monthStart: monthStart,
        monthEndExclusive: monthEndExclusive,
        totalCompletedInstances: 0,
        uniqueDaysWithCompletion: 0,
        activeHabitsCount: 0,
        doneTodayCount: 0,
        completionsByDay: const {},
      );
    }
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_START userId=$userId kind=monthly_stats month=${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}',
    );
    final state = await _ensureState(userId);
    final earliestLoggedDayByHabit = <String, DateTime>{};
    for (final completion in state.completions) {
      final loggedDay = _parseLocalDay(completion.day);
      if (loggedDay == null) continue;
      final existing = earliestLoggedDayByHabit[completion.habitId];
      if (existing == null || loggedDay.isBefore(existing)) {
        earliestLoggedDayByHabit[completion.habitId] = loggedDay;
      }
    }
    final activeHabitIds = <String>{};
    for (final habit in state.habits) {
      final activeFrom = _habitActiveFrom(
        habit,
        earliestLoggedDay: earliestLoggedDayByHabit[habit.id],
      );
      final activeUntil = _habitActiveUntil(habit);
      if (activeFrom != null && !activeFrom.isBefore(monthEndExclusive)) {
        continue;
      }
      if (activeUntil != null && activeUntil.isBefore(monthStart)) {
        continue;
      }
      activeHabitIds.add(habit.id);
    }
    final todayKey = _ymd(DateTime.now().toLocal());
    final countsByDay = <int, int>{};
    final activeDays = <int>{};
    final doneTodayHabitIds = <String>{};
    int total = 0;
    for (final completion in state.completions) {
      if (!activeHabitIds.contains(completion.habitId)) continue;
      if (completion.isCompleted != true) continue;
      final day = _parseLocalDay(completion.day);
      if (day == null) continue;
      if (day.year != selectedMonth.year || day.month != selectedMonth.month) {
        continue;
      }
      countsByDay[day.day] = (countsByDay[day.day] ?? 0) + 1;
      activeDays.add(day.day);
      total += 1;
      if (_ymd(day) == todayKey) {
        doneTodayHabitIds.add(completion.habitId);
      }
    }
    final stats = HabitMonthlyCompletionStats(
      monthStart: monthStart,
      monthEndExclusive: monthEndExclusive,
      totalCompletedInstances: total,
      uniqueDaysWithCompletion: activeDays.length,
      activeHabitsCount: activeHabitIds.length,
      doneTodayCount: doneTodayHabitIds.length,
      completionsByDay: countsByDay,
    );
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_RESULT userId=$userId kind=monthly_stats activeHabits=${stats.activeHabitsCount} doneToday=${stats.doneTodayCount} totalCompleted=${stats.totalCompletedInstances}',
    );
    return stats;
  }

  Future<HabitManageState> loadManageState() async {
    final userId = currentUserId;
    if (userId == null) {
      return const HabitManageState(
        categories: <Map<String, dynamic>>[],
        habits: <Map<String, dynamic>>[],
        streaksByHabitName: <String, ({int current, int best})>{},
      );
    }
    debugPrint('HABIT_LOAD_FROM_LOCAL_START userId=$userId kind=manage_state');
    final state = await _ensureState(userId);
    final categories = state.categories
        .map((item) => item.toJson())
        .toList(growable: false);
    final habits = state.habits
        .map((item) => item.toJson())
        .toList(growable: false);
    final streaks = _computeStreaks(state.completions, state.habits);
    final result = HabitManageState(
      categories: categories,
      habits: habits,
      streaksByHabitName: streaks,
    );
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_RESULT userId=$userId kind=manage_state categoryCount=${result.categories.length} habitCount=${result.habits.length}',
    );
    return result;
  }

  Future<List<HabitStreakRow>> loadStreakRows() async {
    final userId = currentUserId;
    if (userId == null) return const <HabitStreakRow>[];
    debugPrint('HABIT_LOAD_FROM_LOCAL_START userId=$userId kind=streak_rows');
    final state = await _ensureState(userId);
    final doneDatesByHabitId = <String, Set<DateTime>>{};
    final lastDoneByHabitId = <String, DateTime>{};
    for (final completion in state.completions) {
      if (!completion.isCompleted) continue;
      final day = _parseLocalDay(completion.day);
      if (day == null) continue;
      doneDatesByHabitId
          .putIfAbsent(completion.habitId, () => <DateTime>{})
          .add(day);
      final previous = lastDoneByHabitId[completion.habitId];
      if (previous == null || day.isAfter(previous)) {
        lastDoneByHabitId[completion.habitId] = day;
      }
    }

    final rows =
        state.habits
            .map((habit) {
              final streak = _computeStreak(doneDatesByHabitId[habit.id] ?? {});
              return HabitStreakRow(
                habit: habit.name,
                currentStreak: streak.current,
                longestStreak: streak.best,
                lastDoneDay: lastDoneByHabitId[habit.id] == null
                    ? null
                    : _ymd(lastDoneByHabitId[habit.id]!),
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final currentCompare = b.currentStreak.compareTo(a.currentStreak);
            if (currentCompare != 0) return currentCompare;
            final bestCompare = b.longestStreak.compareTo(a.longestStreak);
            if (bestCompare != 0) return bestCompare;
            return a.habit.toLowerCase().compareTo(b.habit.toLowerCase());
          });
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_RESULT userId=$userId kind=streak_rows count=${rows.length}',
    );
    return rows;
  }

  Future<void> saveCategory({
    String? categoryId,
    required String name,
    required String icon,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;
    debugPrint(
      'HABIT_UI_SAVE_TRIGGERED userId=$userId kind=category_save categoryId=${categoryId ?? 'new'} name=$name',
    );
    final state = await _ensureState(userId);
    final categories = state.categories.toList(growable: true);
    if (categoryId == null) {
      categories.add(
        HabitCategoryRecord(
          id: 'habit-category-${_uuid.v4()}',
          name: name,
          icon: icon,
          sortOrder: categories.length,
        ),
      );
    } else {
      final index = categories.indexWhere((item) => item.id == categoryId);
      if (index != -1) {
        final existing = categories[index];
        categories[index] = HabitCategoryRecord(
          id: existing.id,
          name: name,
          icon: icon,
          sortOrder: existing.sortOrder,
        );
      }
    }
    await _saveState(
      HabitLocalStateRecord(
        userId: state.userId,
        categories: categories,
        habits: state.habits,
        completions: state.completions,
        updatedAt: DateTime.now().toUtc(),
      ),
      reason: 'category_save',
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final userId = currentUserId;
    if (userId == null) return;
    debugPrint(
      'HABIT_UI_SAVE_TRIGGERED userId=$userId kind=category_delete categoryId=$categoryId',
    );
    final state = await _ensureState(userId);
    final categories = state.categories
        .where((item) => item.id != categoryId)
        .toList(growable: false);
    final habits = state.habits
        .map((habit) {
          if (habit.categoryId != categoryId) return habit;
          return HabitDefinitionRecord(
            id: habit.id,
            name: habit.name,
            categoryId: null,
            sortOrder: habit.sortOrder,
            isActive: habit.isActive,
            startDate: habit.startDate,
            activeFrom: habit.activeFrom,
            updatedAt: habit.updatedAt,
          );
        })
        .toList(growable: false);
    await _saveState(
      HabitLocalStateRecord(
        userId: state.userId,
        categories: categories,
        habits: habits,
        completions: state.completions,
        updatedAt: DateTime.now().toUtc(),
      ),
      reason: 'category_delete',
    );
  }

  Future<void> saveHabit({
    String? habitId,
    required String name,
    required String? categoryId,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;
    debugPrint(
      'HABIT_UI_SAVE_TRIGGERED userId=$userId kind=habit_save habitId=${habitId ?? 'new'} name=$name categoryId=${categoryId ?? 'uncategorised'}',
    );
    final state = await _ensureState(userId);
    final habits = state.habits.toList(growable: true);
    final nowIso = DateTime.now().toIso8601String();
    if (habitId == null) {
      habits.add(
        HabitDefinitionRecord(
          id: 'habit-${_uuid.v4()}',
          name: name,
          categoryId: categoryId,
          sortOrder: habits.length,
          isActive: true,
          startDate: nowIso,
          activeFrom: nowIso,
          updatedAt: nowIso,
        ),
      );
    } else {
      final index = habits.indexWhere((item) => item.id == habitId);
      if (index != -1) {
        final existing = habits[index];
        habits[index] = HabitDefinitionRecord(
          id: existing.id,
          name: name,
          categoryId: categoryId,
          sortOrder: existing.sortOrder,
          isActive: existing.isActive,
          startDate: existing.startDate,
          activeFrom: existing.activeFrom,
          updatedAt: nowIso,
        );
      }
    }
    await _saveState(
      HabitLocalStateRecord(
        userId: state.userId,
        categories: state.categories,
        habits: habits,
        completions: state.completions,
        updatedAt: DateTime.now().toUtc(),
      ),
      reason: 'habit_save',
    );
  }

  Future<void> toggleHabitActive({
    required String habitId,
    required bool isActive,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;
    debugPrint(
      'HABIT_UI_SAVE_TRIGGERED userId=$userId kind=habit_toggle_active habitId=$habitId isActive=$isActive',
    );
    final state = await _ensureState(userId);
    final habits = state.habits
        .map((habit) {
          if (habit.id != habitId) return habit;
          return HabitDefinitionRecord(
            id: habit.id,
            name: habit.name,
            categoryId: habit.categoryId,
            sortOrder: habit.sortOrder,
            isActive: isActive,
            startDate: habit.startDate,
            activeFrom: habit.activeFrom,
            updatedAt: DateTime.now().toIso8601String(),
          );
        })
        .toList(growable: false);
    await _saveState(
      HabitLocalStateRecord(
        userId: state.userId,
        categories: state.categories,
        habits: habits,
        completions: state.completions,
        updatedAt: DateTime.now().toUtc(),
      ),
      reason: 'habit_toggle_active',
    );
  }

  Future<void> deleteHabits(Set<String> habitIds) async {
    final userId = currentUserId;
    if (userId == null || habitIds.isEmpty) return;
    debugPrint(
      'HABIT_UI_SAVE_TRIGGERED userId=$userId kind=habit_delete count=${habitIds.length} habitIds=${habitIds.toList()}',
    );
    final state = await _ensureState(userId);
    final habits = state.habits
        .where((habit) => !habitIds.contains(habit.id))
        .toList(growable: false);
    final completions = state.completions
        .where((completion) => !habitIds.contains(completion.habitId))
        .toList(growable: false);
    await _saveState(
      HabitLocalStateRecord(
        userId: state.userId,
        categories: state.categories,
        habits: habits,
        completions: completions,
        updatedAt: DateTime.now().toUtc(),
      ),
      reason: 'habit_delete',
    );
  }

  Future<void> syncNotificationSnapshot() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _ensureState(userId);
  }

  static String _resolveCategoryName(
    List<HabitCategoryRecord> categories,
    String? categoryId,
  ) {
    if (categoryId == null || categoryId.trim().isEmpty) {
      return 'Uncategorised';
    }
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return 'Uncategorised';
  }

  static Map<String, ({int current, int best})> _computeStreaks(
    List<HabitCompletionRecord> completions,
    List<HabitDefinitionRecord> habits,
  ) {
    final doneDatesByHabit = <String, Set<DateTime>>{};
    for (final completion in completions) {
      if (!completion.isCompleted) continue;
      final day = _parseLocalDay(completion.day);
      if (day == null) continue;
      doneDatesByHabit
          .putIfAbsent(completion.habitName, () => <DateTime>{})
          .add(day);
    }
    final result = <String, ({int current, int best})>{};
    for (final habit in habits) {
      result[habit.name] = _computeStreak(doneDatesByHabit[habit.name] ?? {});
    }
    return result;
  }

  static ({int current, int best}) _computeStreak(Set<DateTime> doneDates) {
    if (doneDates.isEmpty) return (current: 0, best: 0);
    final dates = doneDates.toList()..sort();
    var best = 1;
    var run = 1;
    for (var index = 1; index < dates.length; index++) {
      final diff = dates[index].difference(dates[index - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > best) best = run;
      } else if (diff > 1) {
        run = 1;
      }
    }
    final today = _today();
    var current = 0;
    var cursor = today;
    while (doneDates.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return (current: current, best: best);
  }

  static DateTime _today() {
    final now = DateTime.now().toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  static String _ymd(DateTime dt) {
    final local = DateTime(dt.year, dt.month, dt.day);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseLocalDay(Object? raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final parsed = DateTime.tryParse(text)?.toLocal();
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _habitActiveFrom(
    HabitDefinitionRecord habit, {
    DateTime? earliestLoggedDay,
  }) {
    return _parseLocalDay(habit.startDate ?? habit.activeFrom) ??
        earliestLoggedDay;
  }

  static DateTime? _habitActiveUntil(HabitDefinitionRecord habit) {
    if (habit.isActive) return null;
    return _parseLocalDay(habit.updatedAt);
  }

  static double _computeLabelWidth(List<String> habitNames) {
    const style = TextStyle(fontSize: 12);
    var maxWidth = 0.0;
    for (final name in habitNames) {
      final painter = TextPainter(
        text: TextSpan(text: name, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 9999);
      if (painter.width > maxWidth) {
        maxWidth = painter.width;
      }
    }
    return (maxWidth + 18).clamp(110, 180).toDouble();
  }
}
