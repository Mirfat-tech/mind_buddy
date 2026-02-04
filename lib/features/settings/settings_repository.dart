import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings_model.dart';

class SettingsRepository {
  SettingsRepository(this._supabase);

  final SupabaseClient _supabase;
  static const _localKey = 'mb_settings_v1';

  Future<SettingsModel?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null || raw.isEmpty) return null;
    final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    return SettingsModel.fromJson(jsonMap);
  }

  Future<void> saveLocal(SettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode(settings.toJson()));
  }

  Future<SettingsModel?> fetchRemote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final row = await _supabase
        .from('user_settings')
        .select('settings, updated_at')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) return null;

    final rawSettings = row['settings'];
    final updatedAt = row['updated_at']?.toString();

    if (rawSettings is Map<String, dynamic>) {
      return SettingsModel.fromJson(rawSettings, updatedAtOverride: updatedAt);
    }
    if (rawSettings is String && rawSettings.isNotEmpty) {
      final jsonMap = jsonDecode(rawSettings) as Map<String, dynamic>;
      return SettingsModel.fromJson(jsonMap, updatedAtOverride: updatedAt);
    }
    return null;
  }

  Future<void> upsertRemote(SettingsModel settings) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('user_settings').upsert({
      'user_id': user.id,
      'settings': settings.toJson(),
      'updated_at': settings.updatedAt,
    });
  }
}
