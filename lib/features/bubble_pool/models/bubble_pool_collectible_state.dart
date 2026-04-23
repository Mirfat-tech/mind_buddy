import 'package:flutter/foundation.dart';

@immutable
class BubblePoolCollectibleState {
  const BubblePoolCollectibleState({
    required this.userId,
    required this.cooldownEndsAtByItemId,
    required this.updatedAt,
  });

  final String userId;
  final Map<String, DateTime> cooldownEndsAtByItemId;
  final DateTime updatedAt;

  factory BubblePoolCollectibleState.empty({required String userId}) {
    return BubblePoolCollectibleState(
      userId: userId,
      cooldownEndsAtByItemId: const <String, DateTime>{},
      updatedAt: DateTime.now().toUtc(),
    );
  }

  BubblePoolCollectibleState copyWith({
    String? userId,
    Map<String, DateTime>? cooldownEndsAtByItemId,
    DateTime? updatedAt,
  }) {
    return BubblePoolCollectibleState(
      userId: userId ?? this.userId,
      cooldownEndsAtByItemId:
          cooldownEndsAtByItemId ?? this.cooldownEndsAtByItemId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'cooldown_ends_at_by_item_id': cooldownEndsAtByItemId.map(
      (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
    ),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static BubblePoolCollectibleState fromJson(Map<String, dynamic> json) {
    final rawCooldowns = json['cooldown_ends_at_by_item_id'];
    final cooldowns = <String, DateTime>{};
    if (rawCooldowns is Map) {
      rawCooldowns.forEach((key, value) {
        final normalizedKey = key.toString().trim();
        final parsed = DateTime.tryParse((value ?? '').toString())?.toUtc();
        if (normalizedKey.isEmpty || parsed == null) return;
        cooldowns[normalizedKey] = parsed;
      });
    }
    return BubblePoolCollectibleState(
      userId: (json['user_id'] ?? '').toString(),
      cooldownEndsAtByItemId: cooldowns,
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}
