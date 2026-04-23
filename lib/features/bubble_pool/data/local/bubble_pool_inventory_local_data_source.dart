import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';
import 'package:mind_buddy/features/bubble_pool/models/bubble_pool_inventory.dart';

class BubblePoolInventoryLocalDataSource {
  BubblePoolInventoryLocalDataSource(this._database);

  final AppDatabase _database;

  String _scopeKey(String userId) => 'bubble_pool_inventory:$userId';

  Future<BubblePoolInventory?> load({required String userId}) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('BUBBLE_POOL_INVENTORY_DB_PATH_RELOAD=$dbPath');
    debugPrint('BUBBLE_POOL_INVENTORY_LOAD_START userId=$userId');

    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_scopeKey(userId)))).getSingleOrNull();

    if (row == null || row.value == null || row.value!.isEmpty) {
      debugPrint('BUBBLE_POOL_INVENTORY_ROW_NOT_FOUND userId=$userId');
      return null;
    }

    final decoded = jsonDecode(row.value!);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final inventory = BubblePoolInventory.fromJson(payload);
    debugPrint(
      'BUBBLE_POOL_INVENTORY_LOAD_SUCCESS userId=${inventory.userId} itemKindCount=${inventory.itemCountsByKind.length}',
    );
    return inventory;
  }

  Future<void> save({
    required BubblePoolInventory inventory,
    required String reason,
  }) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('BUBBLE_POOL_INVENTORY_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'BUBBLE_POOL_INVENTORY_SAVE_START userId=${inventory.userId} reason=$reason itemKindCount=${inventory.itemCountsByKind.length}',
    );

    final now = DateTime.now().toUtc();
    final payload = jsonEncode(inventory.copyWith(updatedAt: now).toJson());

    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _scopeKey(inventory.userId),
            value: drift.Value(payload),
            updatedAt: now,
          ),
        );

    debugPrint(
      'BUBBLE_POOL_INVENTORY_SAVE_SUCCESS userId=${inventory.userId} reason=$reason itemKindCount=${inventory.itemCountsByKind.length}',
    );
  }
}
