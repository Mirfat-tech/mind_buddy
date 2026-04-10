import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/features/habits/habit_category_catalog.dart';
import 'package:mind_buddy/features/habits/habit_home_widget_service.dart';

@immutable
class TodayHabitItem {
  const TodayHabitItem({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.categorySortOrder,
    required this.sortOrder,
    required this.startedAt,
    required this.isCompleted,
  });

  final String id;
  final String name;
  final String categoryName;
  final int categorySortOrder;
  final int sortOrder;
  final DateTime? startedAt;
  final bool isCompleted;

  TodayHabitItem copyWith({
    String? id,
    String? name,
    String? categoryName,
    int? categorySortOrder,
    int? sortOrder,
    DateTime? startedAt,
    bool? isCompleted,
  }) {
    return TodayHabitItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryName: categoryName ?? this.categoryName,
      categorySortOrder: categorySortOrder ?? this.categorySortOrder,
      sortOrder: sortOrder ?? this.sortOrder,
      startedAt: startedAt ?? this.startedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class HabitTodayRepository {
  HabitTodayRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TodayHabitItem>> fetchTodayHabits() async {
    final user = _client.auth.currentUser;
    if (user == null) return const <TodayHabitItem>[];

    final categorySortByName = <String, int>{
      for (final category in HabitCategoryCatalog.builtInCategories)
        category.name.trim().toLowerCase(): category.sortOrder,
    };

    final habitsResponse = await _client
        .from('user_habits')
        .select('*, habit_categories(name)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .order('sort_order');
    _debugLog(
      'fetch_raw habits=${(habitsResponse as List).length} user=${user.id}',
    );

    final dayKey = _ymd(DateTime.now());
    final logsResponse = await _client
        .from('habit_logs')
        .select('habit_id, is_completed')
        .eq('user_id', user.id)
        .eq('day', dayKey);

    final completedByHabitId = <String, bool>{};
    for (final raw in logsResponse as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final habitId = (row['habit_id'] ?? '').toString().trim();
      if (habitId.isEmpty) continue;
      completedByHabitId[habitId] = row['is_completed'] == true;
    }

    final items = <TodayHabitItem>[];
    for (final raw in habitsResponse) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = (row['id'] ?? '').toString().trim();
      final name = (row['name'] ?? '').toString().trim();
      if (id.isEmpty || name.isEmpty) continue;
      final activeFrom = _habitActiveFrom(row);
      if (activeFrom != null && activeFrom.isAfter(_today())) {
        continue;
      }
      final resolvedCategoryName = _resolveCategoryName(row);
      final startedAt = _habitStartedAt(row);
      items.add(
        TodayHabitItem(
          id: id,
          name: name,
          categoryName: resolvedCategoryName,
          categorySortOrder:
              categorySortByName[resolvedCategoryName.toLowerCase()] ?? 999,
          sortOrder: _asInt(row['sort_order'], fallback: 999),
          startedAt: startedAt,
          isCompleted: completedByHabitId[id] == true,
        ),
      );
    }
    _debugLog('filter_today count=${items.length} day=$dayKey');

    items.sort((a, b) {
      final categoryCompare = a.categorySortOrder.compareTo(b.categorySortOrder);
      if (categoryCompare != 0) return categoryCompare;
      final nameCompare = a.categoryName.toLowerCase().compareTo(
        b.categoryName.toLowerCase(),
      );
      if (nameCompare != 0) return nameCompare;
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      if (sortCompare != 0) return sortCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final groupedCounts = <String, int>{};
    for (final item in items) {
      groupedCounts.update(item.categoryName, (count) => count + 1, ifAbsent: () => 1);
    }
    _debugLog('grouped ${groupedCounts.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
    return items;
  }

  Future<void> setHabitCompletion({
    required String habitId,
    required String habitName,
    required bool isCompleted,
    DateTime? day,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final dayKey = _ymd(day ?? DateTime.now());
    final payload = <String, dynamic>{
      'user_id': user.id,
      'habit_id': habitId,
      'habit_name': habitName,
      'day': dayKey,
      'is_completed': isCompleted,
    };

    try {
      await _client.from('habit_logs').upsert(
        payload,
        onConflict: 'user_id,habit_id,day',
      );
    } catch (_) {
      final existing = await _client
          .from('habit_logs')
          .select('id')
          .eq('user_id', user.id)
          .eq('habit_id', habitId)
          .eq('day', dayKey)
          .maybeSingle();
      if (existing != null) {
        await _client
            .from('habit_logs')
            .update({'is_completed': isCompleted})
            .eq('user_id', user.id)
            .eq('habit_id', habitId)
            .eq('day', dayKey);
      } else {
        await _client.from('habit_logs').insert(payload);
      }
    }

    await HabitHomeWidgetService.syncTodaySnapshot();
  }

  static String _ymd(DateTime dt) {
    final local = DateTime(dt.year, dt.month, dt.day);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static int _asInt(Object? value, {required int fallback}) {
    return switch (value) {
      int number => number,
      double number => number.round(),
      String text => int.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }

  static DateTime? _parseLocalDay(Object? raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _habitActiveFrom(Map<String, dynamic> habit) {
    return _parseLocalDay(habit['start_date'] ?? habit['active_from']);
  }

  static DateTime? _habitStartedAt(Map<String, dynamic> habit) {
    return _parseLocalDay(
      habit['start_date'] ?? habit['active_from'] ?? habit['created_at'],
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _resolveCategoryName(Map<String, dynamic> row) {
    final embedded = row['habit_categories'];
    String? categoryName;

    if (embedded is Map) {
      categoryName = embedded['name']?.toString();
    } else if (embedded is List && embedded.isNotEmpty) {
      final first = embedded.first;
      if (first is Map) {
        categoryName = first['name']?.toString();
      }
    } else if (row['category_name'] != null) {
      categoryName = row['category_name']?.toString();
    }

    final normalized = categoryName?.trim() ?? '';
    if (normalized.isNotEmpty) return normalized;

    final categoryId = row['category_id']?.toString().trim() ?? '';
    return categoryId.isEmpty ? 'Uncategorised' : 'Uncategorised';
  }

  static void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[HabitBubble] $message');
    }
  }
}
