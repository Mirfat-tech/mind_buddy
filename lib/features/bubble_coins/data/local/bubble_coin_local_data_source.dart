import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';
import 'package:mind_buddy/features/bubble_coins/bubble_coin_wallet.dart';

class BubbleCoinLocalDataSource {
  BubbleCoinLocalDataSource(this._database);

  final AppDatabase _database;

  String _scopeKey(String userId) => 'bubble_coin_wallet:$userId';

  Future<BubbleCoinWallet?> load({required String userId}) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('BUBBLE_COIN_DB_PATH_RELOAD=$dbPath');
    debugPrint('BUBBLE_COIN_LOAD_FROM_LOCAL_START userId=$userId');

    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_scopeKey(userId)))).getSingleOrNull();

    if (row == null || row.value == null || row.value!.isEmpty) {
      debugPrint('BUBBLE_COIN_DRIFT_ROW_NOT_FOUND userId=$userId');
      debugPrint(
        'BUBBLE_COIN_LOAD_FROM_LOCAL_RESULT userId=$userId found=false balance=0 rewardKeyCount=0',
      );
      return null;
    }

    final decoded = jsonDecode(row.value!);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final wallet = BubbleCoinWallet.fromJson(payload);
    debugPrint(
      'BUBBLE_COIN_DRIFT_ROW_FOUND userId=${wallet.userId} balance=${wallet.balance} rewardKeyCount=${wallet.rewardedCompletionKeys.length}',
    );
    debugPrint(
      'BUBBLE_COIN_LOAD_FROM_LOCAL_RESULT userId=${wallet.userId} found=true balance=${wallet.balance} rewardKeyCount=${wallet.rewardedCompletionKeys.length}',
    );
    return wallet;
  }

  Future<void> save({
    required BubbleCoinWallet wallet,
    required String reason,
  }) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('BUBBLE_COIN_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'BUBBLE_COIN_SAVE_LOCAL_START userId=${wallet.userId} reason=$reason balance=${wallet.balance} rewardKeyCount=${wallet.rewardedCompletionKeys.length}',
    );

    final now = DateTime.now().toUtc();
    final payload = jsonEncode(wallet.copyWith(updatedAt: now).toJson());

    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _scopeKey(wallet.userId),
            value: drift.Value(payload),
            updatedAt: now,
          ),
        );

    debugPrint(
      'BUBBLE_COIN_SAVE_LOCAL_SUCCESS userId=${wallet.userId} reason=$reason balance=${wallet.balance} rewardKeyCount=${wallet.rewardedCompletionKeys.length}',
    );
  }
}
