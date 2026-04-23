import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';

int _habitAsInt(Object? value) {
  return switch (value) {
    int number => number,
    double number => number.round(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}

String? _habitNullableString(Object? value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

class HabitCategoryRecord {
  const HabitCategoryRecord({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String icon;
  final int sortOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'icon': icon,
    'sort_order': sortOrder,
  };

  static HabitCategoryRecord fromJson(Map<String, dynamic> json) {
    return HabitCategoryRecord(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      sortOrder: _habitAsInt(json['sort_order']),
    );
  }
}

class HabitDefinitionRecord {
  const HabitDefinitionRecord({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.sortOrder,
    required this.isActive,
    this.startDate,
    this.activeFrom,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? categoryId;
  final int sortOrder;
  final bool isActive;
  final String? startDate;
  final String? activeFrom;
  final String? updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'category_id': categoryId,
    'sort_order': sortOrder,
    'is_active': isActive,
    'start_date': startDate,
    'active_from': activeFrom,
    'updated_at': updatedAt,
  };

  static HabitDefinitionRecord fromJson(Map<String, dynamic> json) {
    return HabitDefinitionRecord(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      categoryId: _habitNullableString(json['category_id']),
      sortOrder: _habitAsInt(json['sort_order']),
      isActive: json['is_active'] == true,
      startDate: _habitNullableString(json['start_date']),
      activeFrom: _habitNullableString(json['active_from']),
      updatedAt: _habitNullableString(json['updated_at']),
    );
  }
}

class HabitCompletionRecord {
  const HabitCompletionRecord({
    required this.habitId,
    required this.habitName,
    required this.day,
    required this.isCompleted,
  });

  final String habitId;
  final String habitName;
  final String day;
  final bool isCompleted;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'habit_id': habitId,
    'habit_name': habitName,
    'day': day,
    'is_completed': isCompleted,
  };

  static HabitCompletionRecord fromJson(Map<String, dynamic> json) {
    return HabitCompletionRecord(
      habitId: (json['habit_id'] ?? '').toString(),
      habitName: (json['habit_name'] ?? '').toString(),
      day: (json['day'] ?? '').toString(),
      isCompleted: json['is_completed'] == true,
    );
  }
}

class HabitLocalStateRecord {
  const HabitLocalStateRecord({
    required this.userId,
    required this.categories,
    required this.habits,
    required this.completions,
    required this.updatedAt,
  });

  final String userId;
  final List<HabitCategoryRecord> categories;
  final List<HabitDefinitionRecord> habits;
  final List<HabitCompletionRecord> completions;
  final DateTime updatedAt;
}

class HabitLocalDataSource {
  HabitLocalDataSource(this._database);

  final AppDatabase _database;

  String _scopeKey(String userId) => 'habit_state:$userId';

  Future<HabitLocalStateRecord?> load({required String userId}) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('HABIT_DB_PATH_RELOAD=$dbPath');
    debugPrint('HABIT_LOAD_FROM_LOCAL_START userId=$userId kind=snapshot');

    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_scopeKey(userId)))).getSingleOrNull();

    if (row == null || row.value == null || row.value!.isEmpty) {
      debugPrint('HABIT_DRIFT_ROW_NOT_FOUND userId=$userId kind=snapshot');
      debugPrint(
        'HABIT_LOAD_FROM_LOCAL_RESULT userId=$userId found=false categoryCount=0 habitCount=0 completionCount=0',
      );
      return null;
    }

    final decoded = jsonDecode(row.value!);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final categories = _decodeList(
      payload['categories'],
      HabitCategoryRecord.fromJson,
    );
    final habits = _decodeList(
      payload['habits'],
      HabitDefinitionRecord.fromJson,
    );
    final completions = _decodeList(
      payload['completions'],
      HabitCompletionRecord.fromJson,
    );
    final record = HabitLocalStateRecord(
      userId: (payload['user_id'] ?? userId).toString(),
      categories: categories,
      habits: habits,
      completions: completions,
      updatedAt:
          DateTime.tryParse(
            (payload['updated_at'] ?? '').toString(),
          )?.toUtc() ??
          row.updatedAt.toUtc(),
    );
    debugPrint(
      'HABIT_DRIFT_ROW_FOUND userId=${record.userId} kind=snapshot categoryCount=${record.categories.length} habitCount=${record.habits.length} completionCount=${record.completions.length}',
    );
    debugPrint(
      'HABIT_LOAD_FROM_LOCAL_RESULT userId=${record.userId} found=true categoryCount=${record.categories.length} habitCount=${record.habits.length} completionCount=${record.completions.length}',
    );
    return record;
  }

  Future<void> save({
    required String userId,
    required List<HabitCategoryRecord> categories,
    required List<HabitDefinitionRecord> habits,
    required List<HabitCompletionRecord> completions,
    required String reason,
  }) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('HABIT_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'HABIT_SAVE_LOCAL_START userId=$userId kind=$reason categoryCount=${categories.length} habitCount=${habits.length} completionCount=${completions.length}',
    );
    debugPrint(
      'HABIT_LOCAL_SAVE_START userId=$userId kind=$reason categoryCount=${categories.length} habitCount=${habits.length} completionCount=${completions.length}',
    );
    final now = DateTime.now().toUtc();
    final payload = jsonEncode(<String, dynamic>{
      'user_id': userId,
      'updated_at': now.toIso8601String(),
      'categories': categories
          .map((item) => item.toJson())
          .toList(growable: false),
      'habits': habits.map((item) => item.toJson()).toList(growable: false),
      'completions': completions
          .map((item) => item.toJson())
          .toList(growable: false),
    });
    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _scopeKey(userId),
            value: drift.Value(payload),
            updatedAt: now,
          ),
        );
    debugPrint(
      'HABIT_SAVE_LOCAL_SUCCESS userId=$userId kind=$reason categoryCount=${categories.length} habitCount=${habits.length} completionCount=${completions.length}',
    );
    debugPrint(
      'HABIT_LOCAL_SAVE_SUCCESS userId=$userId kind=$reason categoryCount=${categories.length} habitCount=${habits.length} completionCount=${completions.length}',
    );
  }

  static List<T> _decodeList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return <T>[];
    return raw
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
