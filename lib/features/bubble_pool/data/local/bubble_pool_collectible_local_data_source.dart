import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/bubble_pool/models/bubble_pool_collectible_state.dart';

class BubblePoolCollectibleLocalDataSource {
  BubblePoolCollectibleLocalDataSource(this._database);

  final AppDatabase _database;

  String _scopeKey(String userId) => 'bubble_pool_collectible_state:$userId';

  Future<BubblePoolCollectibleState?> load({required String userId}) async {
    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_scopeKey(userId)))).getSingleOrNull();

    if (row == null || row.value == null || row.value!.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(row.value!);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    return BubblePoolCollectibleState.fromJson(payload);
  }

  Future<void> save({
    required BubblePoolCollectibleState state,
    required String reason,
  }) async {
    final now = DateTime.now().toUtc();
    final payload = jsonEncode(state.copyWith(updatedAt: now).toJson());

    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _scopeKey(state.userId),
            value: drift.Value(payload),
            updatedAt: now,
          ),
        );
  }
}
