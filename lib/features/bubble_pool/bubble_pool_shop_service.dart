import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/bubble_coins/bubble_coin_wallet.dart';
import 'package:mind_buddy/features/bubble_coins/data/local/bubble_coin_local_data_source.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_shop_catalog.dart';
import 'package:mind_buddy/features/bubble_pool/data/local/bubble_pool_inventory_local_data_source.dart';
import 'package:mind_buddy/features/bubble_pool/models/bubble_pool_inventory.dart';

class BubblePoolPurchaseResult {
  const BubblePoolPurchaseResult({
    required this.didPurchase,
    required this.updatedBalance,
    required this.updatedItemCount,
    this.message,
  });

  final bool didPurchase;
  final int updatedBalance;
  final int updatedItemCount;
  final String? message;
}

class BubblePoolShopService {
  BubblePoolShopService({AppDatabase? database, SupabaseClient? supabase})
    : _database = database ?? AppDatabase.shared(),
      _walletLocalDataSource = BubbleCoinLocalDataSource(
        database ?? AppDatabase.shared(),
      ),
      _inventoryLocalDataSource = BubblePoolInventoryLocalDataSource(
        database ?? AppDatabase.shared(),
      ),
      _supabase = supabase ?? Supabase.instance.client;

  final AppDatabase _database;
  final BubbleCoinLocalDataSource _walletLocalDataSource;
  final BubblePoolInventoryLocalDataSource _inventoryLocalDataSource;
  final SupabaseClient _supabase;

  static final Set<String> _activePurchaseItemIds = <String>{};

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<BubblePoolPurchaseResult> buyItem(BubblePoolShopItem item) async {
    final userId = currentUserId;
    if (userId == null) {
      return const BubblePoolPurchaseResult(
        didPurchase: false,
        updatedBalance: 0,
        updatedItemCount: 0,
        message: 'Sign in to use the Bubble Pool shop.',
      );
    }

    if (!_activePurchaseItemIds.add(item.id)) {
      final wallet = await _loadWalletForUser(userId);
      final inventory = await _loadInventoryForUser(userId);
      return BubblePoolPurchaseResult(
        didPurchase: false,
        updatedBalance: wallet.balance,
        updatedItemCount: inventory.itemCountsByKind[item.kind.name] ?? 0,
        message: 'Purchase already in progress.',
      );
    }

    try {
      return await _database.transaction(() async {
        final wallet = await _loadWalletForUser(userId);
        final inventory = await _loadInventoryForUser(userId);

        if (wallet.balance < item.price) {
          return BubblePoolPurchaseResult(
            didPurchase: false,
            updatedBalance: wallet.balance,
            updatedItemCount: inventory.itemCountsByKind[item.kind.name] ?? 0,
            message: 'Not enough Bubble Coins yet.',
          );
        }

        final nextWallet = wallet.copyWith(
          balance: wallet.balance - item.price,
        );
        final nextCounts = Map<String, int>.from(inventory.itemCountsByKind);
        final nextCount = (nextCounts[item.kind.name] ?? 0) + 1;
        nextCounts[item.kind.name] = nextCount;

        await _walletLocalDataSource.save(
          wallet: nextWallet,
          reason: 'bubble_pool_shop_purchase',
        );
        await _inventoryLocalDataSource.save(
          inventory: inventory.copyWith(itemCountsByKind: nextCounts),
          reason: 'bubble_pool_shop_purchase',
        );

        return BubblePoolPurchaseResult(
          didPurchase: true,
          updatedBalance: nextWallet.balance,
          updatedItemCount: nextCount,
        );
      });
    } finally {
      _activePurchaseItemIds.remove(item.id);
    }
  }

  Future<BubbleCoinWallet> _loadWalletForUser(String userId) async {
    return await _walletLocalDataSource.load(userId: userId) ??
        BubbleCoinWallet.empty(userId: userId);
  }

  Future<BubblePoolInventory> _loadInventoryForUser(String userId) async {
    return await _inventoryLocalDataSource.load(userId: userId) ??
        BubblePoolInventory.empty(userId: userId);
  }
}
