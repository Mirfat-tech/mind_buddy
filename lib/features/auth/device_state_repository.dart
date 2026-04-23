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
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String lastSeen;
  final String sortKey;
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

    List rows;
    String source = 'user_devices';
    try {
      rows = await _supabase
          .from('user_devices')
          .select('device_id, device_name, platform, last_seen')
          .eq('user_id', user.id)
          .order('last_seen', ascending: false);
    } on PostgrestException {
      source = 'user_sessions';
      rows = await _supabase
          .from('user_sessions')
          .select('device_id, device_name, platform, last_seen_at')
          .eq('user_id', user.id)
          .order('last_seen_at', ascending: false);
    }

    final sessions = rows
        .map(
          (row) => DeviceDisplaySession(
            deviceId: (row['device_id'] ?? '').toString(),
            deviceName: (row['device_name'] ?? 'Unknown').toString(),
            platform: (row['platform'] ?? 'Unknown').toString(),
            lastSeen: _formatLastSeen(row['last_seen'] ?? row['last_seen_at']),
            sortKey: (row['last_seen'] ?? row['last_seen_at'] ?? '').toString(),
          ),
        )
        .where((session) => session.deviceId.isNotEmpty)
        .fold<Map<String, DeviceDisplaySession>>({}, (acc, session) {
          acc.putIfAbsent(session.deviceId, () => session);
          return acc;
        })
        .values
        .toList(growable: true);

    if (registration.devices != null && registration.devices!.isNotEmpty) {
      for (final row in registration.devices!) {
        final session = DeviceDisplaySession(
          deviceId: (row['device_id'] ?? '').toString(),
          deviceName: (row['device_name'] ?? 'Unknown').toString(),
          platform: (row['platform'] ?? 'Unknown').toString(),
          lastSeen: _formatLastSeen(row['last_seen']),
          sortKey: (row['last_seen'] ?? '').toString(),
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
