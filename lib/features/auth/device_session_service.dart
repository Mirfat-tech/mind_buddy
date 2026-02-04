import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class DeviceSessionService {
  static const _deviceIdKey = 'mb_device_id';

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static Future<bool> recordSession() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final deviceId = await getOrCreateDeviceId();
    final deviceInfo = await _getDeviceInfo();
    final payload = {
      'user_id': user.id,
      'device_id': deviceId,
      'device_name': deviceInfo.name,
      'platform': deviceInfo.platform,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await Supabase.instance.client
          .from('user_sessions')
          .upsert(payload, onConflict: 'user_id,device_id');
      return true;
    } on PostgrestException {
      return false;
    } catch (_) {
      return true;
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
      );
    }
    if (Platform.isAndroid) {
      final android = await plugin.androidInfo;
      final brand = android.brand.isNotEmpty ? android.brand : 'Android';
      final model = android.model.isNotEmpty ? android.model : android.device;
      return _DeviceInfo(
        name: '$brand $model',
        platform: 'Android',
      );
    }
    if (Platform.isMacOS) {
      final mac = await plugin.macOsInfo;
      return _DeviceInfo(
        name: mac.model,
        platform: 'macOS',
      );
    }
    if (Platform.isWindows) {
      final win = await plugin.windowsInfo;
      return _DeviceInfo(
        name: win.computerName,
        platform: 'Windows',
      );
    }
    if (Platform.isLinux) {
      final linux = await plugin.linuxInfo;
      return _DeviceInfo(
        name: linux.prettyName,
        platform: 'Linux',
      );
    }
    return const _DeviceInfo(name: 'Unknown', platform: 'Unknown');
  }
}

class _DeviceInfo {
  const _DeviceInfo({required this.name, required this.platform});

  final String name;
  final String platform;
}
