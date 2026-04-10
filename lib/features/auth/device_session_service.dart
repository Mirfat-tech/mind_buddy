import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  bool get isLimitEnforcedTier => tier == 'free';
  bool get shouldBlockForDeviceLimit => isDeviceLimit && isLimitEnforcedTier;

  String blockedMessage() {
    if (tier == 'free') {
      return 'This bubble can only stay open on one device in Free mode right now 🫧\nIt looks like another device is already connected.\nYou can sign out from the other one, or visit Settings > Subscription to explore a little more room.';
    }
    final limit = deviceLimit;
    final planLabel = SubscriptionPlanCatalog.fromRaw(tier).name;
    if (limit == null) {
      return 'Device limit reached. $planLabel currently allows a limited number of devices.';
    }
    if (limit < 0) {
      return '$planLabel allows unlimited devices, so this device limit check should not have happened. Please try again.';
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

class DeviceSessionSnapshot {
  const DeviceSessionSnapshot({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSeen,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime lastSeen;
}

class DeviceSessionService {
  static const _deviceIdKey = 'mb_device_id';
  static const _storage = FlutterSecureStorage();
  static const _legacyPrefsKey = 'mb_device_id';
  static const _deviceLimitErrorCode = _kDeviceLimitErrorCode;

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);

    try {
      final existing = await _storage.read(key: _deviceIdKey);
      if (existing != null && existing.isNotEmpty) {
        await _persistDeviceId(existing, prefs: prefs, writeSecure: false);
        return existing;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getOrCreateDeviceId read failed: $e');
      }
    }

    if (legacy != null && legacy.isNotEmpty) {
      await _persistDeviceId(legacy, prefs: prefs);
      return legacy;
    }

    final id = const Uuid().v4();
    await _persistDeviceId(id, prefs: prefs);
    return id;
  }

  static Future<void> _persistDeviceId(
    String deviceId, {
    SharedPreferences? prefs,
    bool writeSecure = true,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();

    try {
      await resolvedPrefs.setString(_legacyPrefsKey, deviceId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getOrCreateDeviceId prefs write failed: $e');
      }
    }

    if (!writeSecure) return;

    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('getOrCreateDeviceId write failed: $e');
      }
      final existing = await _storage.read(key: _deviceIdKey);
      if (existing != null && existing.isNotEmpty) {
        if (existing != deviceId) {
          await resolvedPrefs.setString(_legacyPrefsKey, existing);
        }
        return;
      }
      try {
        await _storage.delete(key: _deviceIdKey);
        await _storage.write(key: _deviceIdKey, value: deviceId);
      } catch (_) {
        return;
      }
    }
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
      'device_model': deviceInfo.model,
      'system_version': deviceInfo.systemVersion,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res = await Supabase.instance.client.rpc(
        'register_user_device',
        params: {
          'p_device_id': deviceId,
          'p_platform': deviceInfo.platform,
          'p_device_name': deviceInfo.name,
          'p_device_model': deviceInfo.model,
          'p_system_version': deviceInfo.systemVersion,
        },
      );
      if (kDebugMode) {
        debugPrint('DeviceRegistration rpc_response=$res');
      }
      final parsed = _parseRpcResult(deviceId, res);
      final normalized = await _normalizeForEntitlement(user.id, parsed);
      _debugLog(user.id, deviceId, normalized);
      return normalized;
    } on PostgrestException catch (e) {
      final rpcMissingFromSchemaCache =
          e.code == 'PGRST202' ||
          e.code == '42883' ||
          e.code == '42P01' ||
          '${e.message} ${e.details} ${e.hint}'.toLowerCase().contains(
            'register_user_device',
          );
      if (rpcMissingFromSchemaCache) {
        // Backward-compatible fallback when the newer RPC signature is not
        // deployed yet or PostgREST has not refreshed its schema cache.
        final fallbackResult = await _legacyUpsertFallback(payload, deviceId);
        _debugLog(user.id, deviceId, fallbackResult);
        return fallbackResult;
      }
      final message = e.message.toLowerCase();
      if (e.code == _deviceLimitErrorCode || message.contains('device limit')) {
        if (!await _isEnforcedDeviceLimitTier(user.id)) {
          final result = DeviceRegistrationResult(
            allowed: true,
            deviceId: deviceId,
            tier: await _fetchEntitlementTier(user.id),
            deviceLimit: null,
          );
          _debugLog(user.id, deviceId, result);
          return result;
        }
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
    final tier = SubscriptionPlanCatalog.databaseTierFor(
      SubscriptionPlanCatalog.resolveTier(map['tier']),
    );
    final isEnforcedTier = tier == 'free';
    final isDeviceLimitError =
        map['error_code']?.toString() == _kDeviceLimitErrorCode;
    final allowedRaw = map['allowed'] != false;
    final allowed = allowedRaw || (isDeviceLimitError && !isEnforcedTier);
    final limit = tier == 'plus' ? -1 : _asInt(map['device_limit']);
    return DeviceRegistrationResult(
      allowed: allowed,
      deviceId: deviceId,
      tier: tier,
      subscriptionStatus: map['subscription_status']?.toString().toLowerCase(),
      deviceLimit: tier == 'plus' ? -1 : (isEnforcedTier ? limit : null),
      deviceCount: _asInt(map['device_count']),
      errorCode: allowed ? null : map['error_code']?.toString(),
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

  static Future<DeviceRegistrationResult> _normalizeForEntitlement(
    String userId,
    DeviceRegistrationResult result,
  ) async {
    if (!result.isDeviceLimit || result.allowed || result.isLimitEnforcedTier) {
      return result;
    }

    final tier = await _fetchEntitlementTier(userId);
    if (tier == 'free') {
      return DeviceRegistrationResult(
        allowed: false,
        deviceId: result.deviceId,
        tier: tier,
        subscriptionStatus: result.subscriptionStatus,
        deviceLimit: result.deviceLimit,
        deviceCount: result.deviceCount,
        errorCode: result.errorCode,
        entitlementCheckFailed: result.entitlementCheckFailed,
        devices: result.devices,
      );
    }

    return DeviceRegistrationResult(
      allowed: true,
      deviceId: result.deviceId,
      tier: tier ?? result.tier,
      subscriptionStatus: result.subscriptionStatus,
      deviceLimit: null,
      deviceCount: result.deviceCount,
      errorCode: null,
      entitlementCheckFailed: result.entitlementCheckFailed,
      devices: result.devices,
    );
  }

  static Future<bool> _isEnforcedDeviceLimitTier(String userId) async {
    final tier = await _fetchEntitlementTier(userId);
    return tier == 'free';
  }

  static Future<DeviceSessionSnapshot> currentDeviceSnapshot() async {
    final deviceId = await getOrCreateDeviceId();
    final info = await _getDeviceInfo();
    return DeviceSessionSnapshot(
      deviceId: deviceId,
      deviceName: info.name,
      platform: info.platform,
      lastSeen: DateTime.now(),
    );
  }

  static Future<String?> _fetchEntitlementTier(String userId) async {
    try {
      final res = await Supabase.instance.client.rpc('get_my_entitlement');
      if (res is Map) {
        final tier = SubscriptionPlanCatalog.databaseTierFor(
          SubscriptionPlanCatalog.resolveTier(res['subscription_tier']),
        );
        return tier.isEmpty ? null : tier;
      }
    } catch (_) {}

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', userId)
          .maybeSingle();
      final tier = SubscriptionPlanCatalog.databaseTierFor(
        SubscriptionPlanCatalog.resolveTier(profile?['subscription_tier']),
      );
      return tier.isEmpty ? null : tier;
    } catch (_) {
      return null;
    }
  }

  static Future<DeviceRegistrationResult> _legacyUpsertFallback(
    Map<String, dynamic> payload,
    String deviceId, {
    DeviceRegistrationResult? onFailure,
  }) async {
    final seenIso = payload['last_seen']?.toString();
    final payloadWithoutLastSeen = <String, dynamic>{...payload}
      ..remove('last_seen');
    final payloadCompat = <String, dynamic>{...payloadWithoutLastSeen}
      ..remove('device_model')
      ..remove('system_version');

    try {
      try {
        await Supabase.instance.client
            .from('user_devices')
            .upsert(payload, onConflict: 'user_id,device_id');
      } on PostgrestException catch (e) {
        final msg = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
        final missingLastSeen = e.code == '42703' && msg.contains('last_seen');
        final missingDeviceMetadata =
            e.code == '42703' &&
            (msg.contains('device_model') || msg.contains('system_version'));
        if (missingLastSeen) {
          await Supabase.instance.client
              .from('user_devices')
              .upsert(payloadCompat, onConflict: 'user_id,device_id');
        } else if (missingDeviceMetadata) {
          await Supabase.instance.client.from('user_devices').upsert({
            ...payloadCompat,
            if (seenIso != null && seenIso.isNotEmpty) 'last_seen': seenIso,
          }, onConflict: 'user_id,device_id');
        } else {
          rethrow;
        }
      }
      return DeviceRegistrationResult(allowed: true, deviceId: deviceId);
    } on PostgrestException {
      try {
        final base = <String, dynamic>{...payloadCompat};
        if (seenIso != null && seenIso.isNotEmpty) {
          base['last_seen_at'] = seenIso;
          base['last_seen'] = seenIso;
        }
        try {
          await Supabase.instance.client
              .from('user_sessions')
              .upsert(base, onConflict: 'user_id,device_id');
        } on PostgrestException catch (e) {
          final msg = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
          if (!(e.code == '42703' && msg.contains('last_seen'))) rethrow;
          final retry = <String, dynamic>{...base}..remove('last_seen');
          await Supabase.instance.client
              .from('user_sessions')
              .upsert(retry, onConflict: 'user_id,device_id');
        }
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
      return _DeviceInfo(
        name: '$name ($model)',
        platform: 'iOS',
        model: model,
        systemVersion: ios.systemVersion,
      );
    }
    if (Platform.isAndroid) {
      final android = await plugin.androidInfo;
      final brand = android.brand.isNotEmpty ? android.brand : 'Android';
      final model = android.model.isNotEmpty ? android.model : android.device;
      return _DeviceInfo(
        name: '$brand $model',
        platform: 'Android',
        model: model,
        systemVersion: android.version.release,
      );
    }
    if (Platform.isMacOS) {
      final mac = await plugin.macOsInfo;
      return _DeviceInfo(
        name: mac.model,
        platform: 'macOS',
        model: mac.model,
        systemVersion: mac.osRelease,
      );
    }
    if (Platform.isWindows) {
      final win = await plugin.windowsInfo;
      return _DeviceInfo(
        name: win.computerName,
        platform: 'Windows',
        model: win.computerName,
        systemVersion: win.displayVersion,
      );
    }
    if (Platform.isLinux) {
      final linux = await plugin.linuxInfo;
      return _DeviceInfo(
        name: linux.prettyName,
        platform: 'Linux',
        model: linux.name,
        systemVersion: linux.version ?? '',
      );
    }
    return const _DeviceInfo(name: 'Unknown', platform: 'Unknown');
  }
}

class _DeviceInfo {
  const _DeviceInfo({
    required this.name,
    required this.platform,
    this.model,
    this.systemVersion,
  });

  final String name;
  final String platform;
  final String? model;
  final String? systemVersion;
}
