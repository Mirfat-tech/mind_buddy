import 'package:flutter/foundation.dart';

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
