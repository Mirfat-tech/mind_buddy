import 'package:flutter/foundation.dart';

@immutable
class BubblePoolInventory {
  const BubblePoolInventory({
    required this.userId,
    required this.itemCountsByKind,
    required this.updatedAt,
  });

  final String userId;
  final Map<String, int> itemCountsByKind;
  final DateTime updatedAt;

  factory BubblePoolInventory.empty({required String userId}) {
    return BubblePoolInventory(
      userId: userId,
      itemCountsByKind: const <String, int>{},
      updatedAt: DateTime.now().toUtc(),
    );
  }

  BubblePoolInventory copyWith({
    String? userId,
    Map<String, int>? itemCountsByKind,
    DateTime? updatedAt,
  }) {
    return BubblePoolInventory(
      userId: userId ?? this.userId,
      itemCountsByKind: itemCountsByKind ?? this.itemCountsByKind,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'item_counts_by_kind': itemCountsByKind,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static BubblePoolInventory fromJson(Map<String, dynamic> json) {
    final rawCounts = json['item_counts_by_kind'];
    final counts = <String, int>{};
    if (rawCounts is Map) {
      rawCounts.forEach((key, value) {
        final normalizedKey = key.toString().trim();
        if (normalizedKey.isEmpty) return;
        counts[normalizedKey] = _asInt(value);
      });
    }
    return BubblePoolInventory(
      userId: (json['user_id'] ?? '').toString(),
      itemCountsByKind: counts,
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  static int _asInt(Object? value) {
    return switch (value) {
      int number => number,
      double number => number.round(),
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };
  }
}
