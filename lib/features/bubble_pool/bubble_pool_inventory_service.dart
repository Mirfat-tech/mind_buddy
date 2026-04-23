import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/bubble_pool/data/local/bubble_pool_inventory_local_data_source.dart';
import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_item_definition.dart';
import 'package:mind_buddy/features/bubble_pool/models/bubble_pool_inventory.dart';

class BubblePoolInventoryService {
  BubblePoolInventoryService({AppDatabase? database, SupabaseClient? supabase})
    : _database = database ?? AppDatabase.shared(),
      _localDataSource = BubblePoolInventoryLocalDataSource(
        database ?? AppDatabase.shared(),
      ),
      _supabase = supabase ?? Supabase.instance.client;

  final AppDatabase _database;
  final BubblePoolInventoryLocalDataSource _localDataSource;
  final SupabaseClient _supabase;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<BubblePoolInventory> loadInventory() async {
    final userId = currentUserId;
    if (userId == null) {
      return BubblePoolInventory.empty(userId: '');
    }
    return _loadInventoryForUser(userId);
  }

  Future<bool> consumePlacedItem(BubblePoolItemKind kind) async {
    final userId = currentUserId;
    if (userId == null) return false;

    return _database.transaction(() async {
      final inventory = await _loadInventoryForUser(userId);
      final nextCounts = Map<String, int>.from(inventory.itemCountsByKind);
      final key = kind.name;
      final current = nextCounts[key] ?? 0;
      if (current <= 0) return false;
      final next = current - 1;
      if (next <= 0) {
        nextCounts.remove(key);
      } else {
        nextCounts[key] = next;
      }
      await _localDataSource.save(
        inventory: inventory.copyWith(itemCountsByKind: nextCounts),
        reason: 'place_item',
      );
      return true;
    });
  }

  Future<BubblePoolInventory> _loadInventoryForUser(String userId) async {
    return await _localDataSource.load(userId: userId) ??
        BubblePoolInventory.empty(userId: userId);
  }
}
