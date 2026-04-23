import 'package:flutter/foundation.dart';

@immutable
class BubbleCoinWallet {
  const BubbleCoinWallet({
    required this.userId,
    required this.balance,
    required this.rewardedCompletionKeys,
    required this.updatedAt,
  });

  final String userId;
  final int balance;
  final Set<String> rewardedCompletionKeys;
  final DateTime updatedAt;

  factory BubbleCoinWallet.empty({required String userId}) {
    return BubbleCoinWallet(
      userId: userId,
      balance: 0,
      rewardedCompletionKeys: const <String>{},
      updatedAt: DateTime.now().toUtc(),
    );
  }

  BubbleCoinWallet copyWith({
    String? userId,
    int? balance,
    Set<String>? rewardedCompletionKeys,
    DateTime? updatedAt,
  }) {
    return BubbleCoinWallet(
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      rewardedCompletionKeys:
          rewardedCompletionKeys ?? this.rewardedCompletionKeys,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final rewardedKeys = rewardedCompletionKeys.toList(growable: false)..sort();
    return <String, dynamic>{
      'user_id': userId,
      'balance': balance,
      'rewarded_completion_keys': rewardedKeys,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static BubbleCoinWallet fromJson(Map<String, dynamic> json) {
    final rawRewardedKeys = json['rewarded_completion_keys'];
    final rewardedKeys = rawRewardedKeys is List
        ? rawRewardedKeys
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
        : <String>{};
    return BubbleCoinWallet(
      userId: (json['user_id'] ?? '').toString(),
      balance: _asInt(json['balance']),
      rewardedCompletionKeys: rewardedKeys,
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
