import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _kDeviceLimitErrorCode = 'device_limit_reached';

class DeviceRegistrationResult {
  const DeviceRegistrationResult({
    required this.allowed,
    required this.deviceId,
    this.tier,
    this.subscriptionStatus,
    this.deviceLimit,
    this.deviceCount,
    this.errorCode,
    this.entitlementCheckFailed = false,
    this.devices,
  });

  final bool allowed;
  final String deviceId;
  final String? tier;
  final String? subscriptionStatus;
  final int? deviceLimit;
  final int? deviceCount;
  final String? errorCode;
  final bool entitlementCheckFailed;
  final List<Map<String, dynamic>>? devices;

  bool get isDeviceLimit => !allowed && errorCode == _kDeviceLimitErrorCode;

  String blockedMessage() {
    final limit = deviceLimit;
    final planLabel = SubscriptionPlanCatalog.fromRaw(tier).name;
    if (limit == null) {
      return 'Device limit reached. $planLabel currently allows a limited number of devices.';
    }
    if (limit < 0) {
      return 'Device limit reached. $planLabel currently allows a limited number of devices.';
    }
    if (limit == 1) {
      return 'Device limit reached. $planLabel allows only 1 device.';
    }
    return 'Device limit reached. $planLabel allows up to $limit devices.';
  }

  static DeviceRegistrationResult graceAllowed(String deviceId) {
    return DeviceRegistrationResult(
      allowed: true,
      deviceId: deviceId,
      entitlementCheckFailed: true,
    );
  }
}

class DeviceSessionService {
  static const _deviceIdKey = 'mb_device_id';
  static const _storage = FlutterSecureStorage();
  static const _legacyPrefsKey = 'mb_device_id';
  static const _deviceLimitErrorCode = _kDeviceLimitErrorCode;

  static Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    // Migrate pre-existing ID so older installs stay recognized.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _deviceIdKey, value: legacy);
      return legacy;
    }

    final id = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  static Future<DeviceRegistrationResult> registerDevice() async {
    final user = Supabase.instance.client.auth.currentUser;
    final deviceId = await getOrCreateDeviceId();
    if (user == null) {
      return DeviceRegistrationResult(
        allowed: false,
        deviceId: deviceId,
        errorCode: 'not_authenticated',
      );
    }

    final deviceInfo = await _getDeviceInfo();
    final payload = {
      'user_id': user.id,
      'device_id': deviceId,
      'device_name': deviceInfo.name,
      'platform': deviceInfo.platform,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res = await Supabase.instance.client.rpc(
        'register_user_device',
        params: {
          'p_device_id': deviceId,
          'p_platform': deviceInfo.platform,
          'p_device_name': deviceInfo.name,
        },
      );
      if (kDebugMode) {
        debugPrint('DeviceRegistration rpc_response=$res');
      }
      final parsed = _parseRpcResult(deviceId, res);
      _debugLog(user.id, deviceId, parsed);
      return parsed;
    } on PostgrestException catch (e) {
      if (e.code == '42883' || e.code == '42P01') {
        // Backward-compatible fallback when RPC or new table is not deployed yet.
        final fallbackResult = await _legacyUpsertFallback(payload, deviceId);
        _debugLog(user.id, deviceId, fallbackResult);
        return fallbackResult;
      }
      final message = e.message.toLowerCase();
      if (e.code == _deviceLimitErrorCode || message.contains('device limit')) {
        final result = DeviceRegistrationResult(
          allowed: false,
          deviceId: deviceId,
          errorCode: _deviceLimitErrorCode,
        );
        _debugLog(user.id, deviceId, result);
        return result;
      }
      if (kDebugMode) {
        debugPrint(
          'registerDevice PostgrestException code=${e.code} message=${e.message} details=${e.details}',
        );
      }
      // If entitlement RPC failed for non-limit reasons, still try local device write.
      final result = await _legacyUpsertFallback(
        payload,
        deviceId,
        onFailure: DeviceRegistrationResult.graceAllowed(deviceId),
      );
      _debugLog(user.id, deviceId, result);
      return result;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('registerDevice unexpected error: $e');
        debugPrint('$st');
      }
      final result = await _legacyUpsertFallback(
        payload,
        deviceId,
        onFailure: DeviceRegistrationResult.graceAllowed(deviceId),
      );
      _debugLog(user.id, deviceId, result);
      return result;
    }
  }

  static Future<bool> recordSession() async {
    final result = await registerDevice();
    return result.allowed;
  }

  static DeviceRegistrationResult _parseRpcResult(
    String deviceId,
    dynamic res,
  ) {
    if (res is! Map) {
      return DeviceRegistrationResult(allowed: true, deviceId: deviceId);
    }
    final map = Map<String, dynamic>.from(res);
    return DeviceRegistrationResult(
      allowed: map['allowed'] != false,
      deviceId: deviceId,
      tier: map['tier']?.toString().toLowerCase(),
      subscriptionStatus: map['subscription_status']?.toString().toLowerCase(),
      deviceLimit: _asInt(map['device_limit']),
      deviceCount: _asInt(map['device_count']),
      errorCode: map['error_code']?.toString(),
      devices: (map['devices'] is List)
          ? (map['devices'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : null,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Future<DeviceRegistrationResult> _legacyUpsertFallback(
    Map<String, dynamic> payload,
    String deviceId, {
    DeviceRegistrationResult? onFailure,
  }) async {
    try {
      await Supabase.instance.client
          .from('user_devices')
          .upsert(payload, onConflict: 'user_id,device_id');
      return DeviceRegistrationResult(allowed: true, deviceId: deviceId);
    } on PostgrestException {
      try {
        await Supabase.instance.client.from('user_sessions').upsert({
          ...payload,
          'last_seen_at': payload['last_seen'],
        }, onConflict: 'user_id,device_id');
        return DeviceRegistrationResult(allowed: true, deviceId: deviceId);
      } catch (_) {
        return onFailure ?? DeviceRegistrationResult.graceAllowed(deviceId);
      }
    } catch (_) {
      return onFailure ?? DeviceRegistrationResult.graceAllowed(deviceId);
    }
  }

  static void _debugLog(
    String userId,
    String deviceId,
    DeviceRegistrationResult result,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      'DeviceRegistration user_id=$userId device_id=$deviceId '
      'tier=${result.tier ?? 'unknown'} limit=${result.deviceLimit?.toString() ?? 'unknown'} '
      'count=${result.deviceCount?.toString() ?? 'unknown'} allowed=${result.allowed} '
      'error=${result.errorCode ?? 'none'} entitlement_check_failed=${result.entitlementCheckFailed}',
    );
    if (result.devices != null) {
      debugPrint('DeviceRegistration devices=${result.devices}');
    }
  }

  static Future<_DeviceInfo> _getDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await plugin.iosInfo;
      final name = ios.name.isNotEmpty ? ios.name : 'iPhone';
      final model = ios.utsname.machine.isNotEmpty
          ? ios.utsname.machine
          : ios.model;
      return _DeviceInfo(name: '$name ($model)', platform: 'iOS');
    }
    if (Platform.isAndroid) {
      final android = await plugin.androidInfo;
      final brand = android.brand.isNotEmpty ? android.brand : 'Android';
      final model = android.model.isNotEmpty ? android.model : android.device;
      return _DeviceInfo(name: '$brand $model', platform: 'Android');
    }
    if (Platform.isMacOS) {
      final mac = await plugin.macOsInfo;
      return _DeviceInfo(name: mac.model, platform: 'macOS');
    }
    if (Platform.isWindows) {
      final win = await plugin.windowsInfo;
      return _DeviceInfo(name: win.computerName, platform: 'Windows');
    }
    if (Platform.isLinux) {
      final linux = await plugin.linuxInfo;
      return _DeviceInfo(name: linux.prettyName, platform: 'Linux');
    }
    return const _DeviceInfo(name: 'Unknown', platform: 'Unknown');
  }
}

class _DeviceInfo {
  const _DeviceInfo({required this.name, required this.platform});

  final String name;
  final String platform;
}
