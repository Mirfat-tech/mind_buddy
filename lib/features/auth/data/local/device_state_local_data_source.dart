import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';

class LocalDeviceSessionRecord {
  const LocalDeviceSessionRecord({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSeen,
    required this.sortKey,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String lastSeen;
  final String sortKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'device_id': deviceId,
    'device_name': deviceName,
    'platform': platform,
    'last_seen': lastSeen,
    'sort_key': sortKey,
  };

  static LocalDeviceSessionRecord fromJson(Map<String, dynamic> json) {
    return LocalDeviceSessionRecord(
      deviceId: (json['device_id'] ?? '').toString(),
      deviceName: (json['device_name'] ?? 'Unknown').toString(),
      platform: (json['platform'] ?? 'Unknown').toString(),
      lastSeen: (json['last_seen'] ?? 'Unknown').toString(),
      sortKey: (json['sort_key'] ?? '').toString(),
    );
  }
}

class LocalDeviceStateRecord {
  const LocalDeviceStateRecord({
    required this.localDeviceId,
    required this.sessions,
    required this.updatedAt,
  });

  final String localDeviceId;
  final List<LocalDeviceSessionRecord> sessions;
  final DateTime updatedAt;
}

class DeviceStateLocalDataSource {
  DeviceStateLocalDataSource(this._database);

  final AppDatabase _database;

  String _scopeKey(String userId) => 'device_state:$userId';

  Future<LocalDeviceStateRecord?> load({required String userId}) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('DEVICE_DB_PATH_RELOAD=$dbPath');
    debugPrint('DEVICE_STATE_LOAD_FROM_LOCAL_START userId=$userId');

    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_scopeKey(userId)))).getSingleOrNull();
    if (row == null || row.value == null || row.value!.isEmpty) {
      debugPrint(
        'DEVICE_STATE_LOAD_FROM_LOCAL_RESULT userId=$userId found=false sessionCount=0',
      );
      return null;
    }

    final decoded = jsonDecode(row.value!);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final rawSessions = payload['sessions'];
    final sessions = rawSessions is List
        ? rawSessions
              .whereType<Map>()
              .map(
                (item) => LocalDeviceSessionRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.deviceId.isNotEmpty)
              .toList(growable: false)
        : const <LocalDeviceSessionRecord>[];
    final updatedAt =
        DateTime.tryParse((payload['updated_at'] ?? '').toString())?.toUtc() ??
        row.updatedAt.toUtc();
    final record = LocalDeviceStateRecord(
      localDeviceId: (payload['local_device_id'] ?? '').toString(),
      sessions: sessions,
      updatedAt: updatedAt,
    );
    debugPrint(
      'DEVICE_STATE_LOAD_FROM_LOCAL_RESULT userId=$userId found=true sessionCount=${record.sessions.length} localDeviceId=${record.localDeviceId}',
    );
    return record;
  }

  Future<void> save({
    required String userId,
    required String localDeviceId,
    required List<LocalDeviceSessionRecord> sessions,
  }) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('DEVICE_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'DEVICE_STATE_SAVE_LOCAL_START userId=$userId sessionCount=${sessions.length} localDeviceId=$localDeviceId',
    );
    final now = DateTime.now().toUtc();
    final payload = jsonEncode(<String, dynamic>{
      'local_device_id': localDeviceId,
      'updated_at': now.toIso8601String(),
      'sessions': sessions.map((item) => item.toJson()).toList(growable: false),
    });
    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _scopeKey(userId),
            value: Value(payload),
            updatedAt: now,
          ),
        );
    debugPrint(
      'DEVICE_STATE_SAVE_LOCAL_SUCCESS userId=$userId sessionCount=${sessions.length} localDeviceId=$localDeviceId',
    );
    debugPrint(
      'DEVICE_STATE_QUEUE_SYNC userId=$userId action=device_display_cache_updated',
    );
  }
}
