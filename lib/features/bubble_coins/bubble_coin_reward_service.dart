import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/bubble_coins/bubble_coin_wallet.dart';
import 'package:mind_buddy/features/bubble_coins/data/local/bubble_coin_local_data_source.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_launch_config.dart';

class BubbleCoinRewardService {
  BubbleCoinRewardService({AppDatabase? database, SupabaseClient? supabase})
    : _localDataSource = BubbleCoinLocalDataSource(
        database ?? AppDatabase.shared(),
      ),
      _supabase = supabase ?? Supabase.instance.client;

  final BubbleCoinLocalDataSource _localDataSource;
  final SupabaseClient _supabase;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<BubbleCoinWallet> loadWallet() async {
    final userId = currentUserId;
    if (userId == null) {
      return BubbleCoinWallet.empty(userId: '');
    }
    return _loadWalletForUser(userId);
  }

  Future<bool> awardHabitCompletion({
    required String userId,
    required String habitId,
    required String habitName,
    required String day,
  }) async {
    if (!bubbleCoinsEnabledForLaunch) {
      debugPrint('BUBBLE_COIN_DISABLED_FOR_LAUNCH');
      return false;
    }
    final rewardKey = rewardKeyForHabitCompletion(habitId: habitId, day: day);
    final wallet = await _loadWalletForUser(userId);
    if (wallet.rewardedCompletionKeys.contains(rewardKey)) {
      return false;
    }

    final nextRewardedKeys = wallet.rewardedCompletionKeys.toSet()
      ..add(rewardKey);
    await _localDataSource.save(
      wallet: wallet.copyWith(
        balance: wallet.balance + 1,
        rewardedCompletionKeys: nextRewardedKeys,
      ),
      reason: 'habit_completion_reward',
    );
    return true;
  }

  static String rewardKeyForHabitCompletion({
    required String habitId,
    required String day,
  }) {
    return 'habit_completion:$habitId:$day';
  }

  Future<BubbleCoinWallet> _loadWalletForUser(String userId) async {
    return await _localDataSource.load(userId: userId) ??
        BubbleCoinWallet.empty(userId: userId);
  }
}
