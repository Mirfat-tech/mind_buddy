import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/bubble_coins/bubble_coin_wallet.dart';
import 'package:mind_buddy/features/bubble_coins/data/local/bubble_coin_local_data_source.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_launch_config.dart';
import 'package:mind_buddy/features/bubble_pool/data/local/bubble_pool_collectible_local_data_source.dart';
import 'package:mind_buddy/features/bubble_pool/models/bubble_pool_collectible_state.dart';

class BubblePoolCollectResult {
  const BubblePoolCollectResult({
    required this.didCollect,
    required this.updatedBalance,
    required this.cooldownEndsAt,
    this.message,
  });

  final bool didCollect;
  final int updatedBalance;
  final DateTime? cooldownEndsAt;
  final String? message;
}

class BubblePoolCollectionService {
  BubblePoolCollectionService({AppDatabase? database, SupabaseClient? supabase})
    : _database = database ?? AppDatabase.shared(),
      _walletLocalDataSource = BubbleCoinLocalDataSource(
        database ?? AppDatabase.shared(),
      ),
      _collectibleLocalDataSource = BubblePoolCollectibleLocalDataSource(
        database ?? AppDatabase.shared(),
      ),
      _supabase = supabase ?? Supabase.instance.client;

  final AppDatabase _database;
  final BubbleCoinLocalDataSource _walletLocalDataSource;
  final BubblePoolCollectibleLocalDataSource _collectibleLocalDataSource;
  final SupabaseClient _supabase;

  static final Set<String> _activeCollectibleIds = <String>{};

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<BubblePoolCollectibleState> loadState() async {
    final userId = currentUserId;
    if (userId == null) {
      return BubblePoolCollectibleState.empty(userId: '');
    }
    return _loadStateForUser(userId);
  }

  Future<BubblePoolCollectResult> collectFromItem({
    required String collectibleId,
    int rewardAmount = 1,
    Duration cooldown = const Duration(minutes: 30),
  }) async {
    if (!bubblePoolEnabledForLaunch) {
      debugPrint('BUBBLE_COIN_DISABLED_FOR_LAUNCH');
      return const BubblePoolCollectResult(
        didCollect: false,
        updatedBalance: 0,
        cooldownEndsAt: null,
        message: 'Bubble Pool rewards are coming soon.',
      );
    }
    final userId = currentUserId;
    if (userId == null) {
      return const BubblePoolCollectResult(
        didCollect: false,
        updatedBalance: 0,
        cooldownEndsAt: null,
        message: 'Sign in to collect Bubble Coins.',
      );
    }

    if (!_activeCollectibleIds.add(collectibleId)) {
      final wallet = await _loadWalletForUser(userId);
      final state = await _loadStateForUser(userId);
      return BubblePoolCollectResult(
        didCollect: false,
        updatedBalance: wallet.balance,
        cooldownEndsAt: state.cooldownEndsAtByItemId[collectibleId],
        message: 'This bubble is already being collected.',
      );
    }

    try {
      return await _database.transaction(() async {
        final now = DateTime.now().toUtc();
        final wallet = await _loadWalletForUser(userId);
        final state = await _loadStateForUser(userId);
        final currentCooldownEnd = state.cooldownEndsAtByItemId[collectibleId];

        if (currentCooldownEnd != null && now.isBefore(currentCooldownEnd)) {
          return BubblePoolCollectResult(
            didCollect: false,
            updatedBalance: wallet.balance,
            cooldownEndsAt: currentCooldownEnd,
            message: 'This item is resting for a little while.',
          );
        }

        final nextCooldownEnd = now.add(cooldown);
        final nextWallet = wallet.copyWith(
          balance: wallet.balance + rewardAmount,
        );
        final nextCooldowns = Map<String, DateTime>.from(
          state.cooldownEndsAtByItemId,
        )..[collectibleId] = nextCooldownEnd;

        await _walletLocalDataSource.save(
          wallet: nextWallet,
          reason: 'bubble_pool_collect_reward',
        );
        await _collectibleLocalDataSource.save(
          state: state.copyWith(cooldownEndsAtByItemId: nextCooldowns),
          reason: 'bubble_pool_collect_reward',
        );

        return BubblePoolCollectResult(
          didCollect: true,
          updatedBalance: nextWallet.balance,
          cooldownEndsAt: nextCooldownEnd,
        );
      });
    } finally {
      _activeCollectibleIds.remove(collectibleId);
    }
  }

  Future<BubbleCoinWallet> _loadWalletForUser(String userId) async {
    return await _walletLocalDataSource.load(userId: userId) ??
        BubbleCoinWallet.empty(userId: userId);
  }

  Future<BubblePoolCollectibleState> _loadStateForUser(String userId) async {
    return await _collectibleLocalDataSource.load(userId: userId) ??
        BubblePoolCollectibleState.empty(userId: userId);
  }
}
