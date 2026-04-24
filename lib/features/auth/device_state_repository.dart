import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/auth/data/local/device_state_local_data_source.dart';
import 'package:mind_buddy/features/auth/device_session_service.dart';

class DeviceDisplaySession {
  const DeviceDisplaySession({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSeen,
    required this.sortKey,
    this.isActive = true,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String lastSeen;
  final String sortKey;
  final bool isActive;
}

class DeviceDisplayState {
  const DeviceDisplayState({
    required this.localDeviceId,
    required this.sessions,
  });

  final String localDeviceId;
  final List<DeviceDisplaySession> sessions;
}

class DeviceStateRepository {
  DeviceStateRepository({
    required AppDatabase database,
    SupabaseClient? supabase,
  }) : _localDataSource = DeviceStateLocalDataSource(database),
       _supabase = supabase ?? Supabase.instance.client;

  final DeviceStateLocalDataSource _localDataSource;
  final SupabaseClient _supabase;

  Future<DeviceDisplayState> loadLocal() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const DeviceDisplayState(localDeviceId: '', sessions: []);
    }
    final local = await _localDataSource.load(userId: user.id);
    if (local == null) {
      return const DeviceDisplayState(localDeviceId: '', sessions: []);
    }
    return DeviceDisplayState(
      localDeviceId: local.localDeviceId,
      sessions: local.sessions
          .map(
            (item) => DeviceDisplaySession(
              deviceId: item.deviceId,
              deviceName: item.deviceName,
              platform: item.platform,
              lastSeen: item.lastSeen,
              sortKey: item.sortKey,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<DeviceDisplayState> refreshRemoteAuthoritative() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const DeviceDisplayState(localDeviceId: '', sessions: []);
    }

    final localSnapshot = await DeviceSessionService.currentDeviceSnapshot();
    final registration = await DeviceSessionService.registerDevice();
    debugPrint('DEVICES_SCREEN_QUERY_START userId=${user.id}');

    final queryResult = await _loadActiveDeviceRows(user.id);
    var rows = queryResult.rows;
    final source = queryResult.source;

    var sessions = rows
        .map(
          (row) => DeviceDisplaySession(
            deviceId: (row['device_id'] ?? '').toString(),
            deviceName: (row['device_name'] ?? 'Unknown').toString(),
            platform: (row['platform'] ?? 'Unknown').toString(),
            lastSeen: _formatLastSeen(row['last_seen'] ?? row['last_seen_at']),
            sortKey: (row['last_seen'] ?? row['last_seen_at'] ?? '').toString(),
            isActive: row['is_active'] != false,
          ),
        )
        .where((session) => session.deviceId.isNotEmpty)
        .fold<Map<String, DeviceDisplaySession>>({}, (acc, session) {
          acc.putIfAbsent(session.deviceId, () => session);
          return acc;
        })
        .values
        .toList(growable: true);
    debugPrint('DEVICES_SCREEN_DEDUPED_COUNT count=${sessions.length}');
    debugPrint(
      'DEVICES_SCREEN_QUERY_RESULT rawCount=${rows.length} activeCount=${sessions.length}',
    );

    if (registration.devices != null && registration.devices!.isNotEmpty) {
      for (final row in registration.devices!) {
        final session = DeviceDisplaySession(
          deviceId: (row['device_id'] ?? '').toString(),
          deviceName: (row['device_name'] ?? 'Unknown').toString(),
          platform: (row['platform'] ?? 'Unknown').toString(),
          lastSeen: _formatLastSeen(row['last_seen']),
          sortKey: (row['last_seen'] ?? '').toString(),
          isActive: row['is_active'] != false,
        );
        if (session.deviceId.isEmpty) {
          continue;
        }
        final exists = sessions.any(
          (item) => item.deviceId == session.deviceId,
        );
        if (!exists) {
          sessions.add(session);
        }
      }
    }

    if (sessions.isEmpty && user.id.isNotEmpty) {
      debugPrint(
        'DEVICES_SCREEN_EMPTY_REPAIR_START userId=${user.id} deviceId=${localSnapshot.deviceId}',
      );
      final repairedRegistration = await DeviceSessionService.registerDevice();
      final repairedQueryResult = await _loadActiveDeviceRows(user.id);
      rows = repairedQueryResult.rows;
      sessions = rows
          .map(
            (row) => DeviceDisplaySession(
              deviceId: (row['device_id'] ?? '').toString(),
              deviceName: (row['device_name'] ?? 'Unknown').toString(),
              platform: (row['platform'] ?? 'Unknown').toString(),
              lastSeen: _formatLastSeen(
                row['last_seen'] ?? row['last_seen_at'],
              ),
              sortKey: (row['last_seen'] ?? row['last_seen_at'] ?? '')
                  .toString(),
              isActive: row['is_active'] != false,
            ),
          )
          .where((session) => session.deviceId.isNotEmpty)
          .fold<Map<String, DeviceDisplaySession>>({}, (acc, session) {
            acc.putIfAbsent(session.deviceId, () => session);
            return acc;
          })
          .values
          .toList(growable: true);
      if (sessions.isEmpty &&
          (repairedRegistration.allowed ||
              repairedRegistration.entitlementCheckFailed)) {
        sessions.add(
          DeviceDisplaySession(
            deviceId: localSnapshot.deviceId,
            deviceName: localSnapshot.deviceName,
            platform: localSnapshot.platform,
            lastSeen: _formatLastSeen(localSnapshot.lastSeen.toIso8601String()),
            sortKey: localSnapshot.lastSeen.toIso8601String(),
            isActive: true,
          ),
        );
      }
      debugPrint('DEVICES_SCREEN_EMPTY_REPAIR_RESULT count=${sessions.length}');
    }

    final hasCurrentDevice = sessions.any(
      (session) => session.deviceId == localSnapshot.deviceId,
    );
    if (!hasCurrentDevice &&
        (registration.allowed || registration.entitlementCheckFailed)) {
      sessions.insert(
        0,
        DeviceDisplaySession(
          deviceId: localSnapshot.deviceId,
          deviceName: localSnapshot.deviceName,
          platform: localSnapshot.platform,
          lastSeen: _formatLastSeen(localSnapshot.lastSeen.toIso8601String()),
          sortKey: localSnapshot.lastSeen.toIso8601String(),
          isActive: true,
        ),
      );
    }

    sessions.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    final normalized = DeviceDisplayState(
      localDeviceId: localSnapshot.deviceId,
      sessions: sessions,
    );
    debugPrint(
      'DEVICE_STATE_REMOTE_REFRESH userId=${user.id} source=$source sessionCount=${normalized.sessions.length} allowed=${registration.allowed} entitlementCheckFailed=${registration.entitlementCheckFailed}',
    );
    debugPrint(
      'DEVICES_SCREEN_ACTIVE_COUNT count=${normalized.sessions.length}',
    );
    await _localDataSource.save(
      userId: user.id,
      localDeviceId: normalized.localDeviceId,
      sessions: normalized.sessions
          .map(
            (item) => LocalDeviceSessionRecord(
              deviceId: item.deviceId,
              deviceName: item.deviceName,
              platform: item.platform,
              lastSeen: item.lastSeen,
              sortKey: item.sortKey,
            ),
          )
          .toList(growable: false),
    );
    return normalized;
  }

  Future<_DeviceQueryResult> _loadActiveDeviceRows(String userId) async {
    try {
      final rows = await _supabase
          .from('user_devices')
          .select(
            'device_id, device_name, platform, last_seen, is_active, revoked_at, signed_out_at',
          )
          .eq('user_id', userId)
          .eq('is_active', true)
          .isFilter('revoked_at', null)
          .isFilter('signed_out_at', null)
          .order('last_seen', ascending: false);
      return _DeviceQueryResult(source: 'user_devices', rows: rows);
    } catch (e) {
      debugPrint('DEVICES_SCREEN_QUERY_ERROR error=$e');
    }

    try {
      final rows = await _supabase
          .from('user_devices')
          .select('device_id, device_name, platform, last_seen')
          .eq('user_id', userId)
          .order('last_seen', ascending: false);
      return _DeviceQueryResult(source: 'user_devices_legacy', rows: rows);
    } catch (e) {
      debugPrint('DEVICES_SCREEN_QUERY_ERROR error=$e');
    }

    try {
      final rows = await _supabase
          .from('user_sessions')
          .select(
            'device_id, device_name, platform, last_seen_at, is_active, revoked_at, signed_out_at',
          )
          .eq('user_id', userId)
          .eq('is_active', true)
          .isFilter('revoked_at', null)
          .isFilter('signed_out_at', null)
          .order('last_seen_at', ascending: false);
      return _DeviceQueryResult(source: 'user_sessions', rows: rows);
    } catch (e) {
      debugPrint('DEVICES_SCREEN_QUERY_ERROR error=$e');
    }

    try {
      final rows = await _supabase
          .from('user_sessions')
          .select('device_id, device_name, platform, last_seen_at, last_seen')
          .eq('user_id', userId)
          .order('last_seen_at', ascending: false);
      return _DeviceQueryResult(source: 'user_sessions_legacy', rows: rows);
    } catch (e) {
      debugPrint('DEVICES_SCREEN_QUERY_ERROR error=$e');
    }

    return const _DeviceQueryResult(source: 'none', rows: []);
  }

  Future<void> clearLocalForUser(String userId) {
    return _localDataSource.clear(userId: userId);
  }

  Future<DeviceDisplayState> removeDeviceAndRefresh({
    required String deviceId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const DeviceDisplayState(localDeviceId: '', sessions: []);
    }
    await _supabase
        .from('user_devices')
        .delete()
        .eq('user_id', user.id)
        .eq('device_id', deviceId);
    return refreshRemoteAuthoritative();
  }

  static String _formatLastSeen(dynamic value) {
    if (value == null) return 'Unknown';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Unknown';
    final local = parsed.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _DeviceQueryResult {
  const _DeviceQueryResult({required this.source, required this.rows});

  final String source;
  final List rows;
}
