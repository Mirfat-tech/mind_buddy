import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/features/settings/settings_model.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';

class SettingsRemoteDataSource {
  SettingsRemoteDataSource(this._supabase);

  final SupabaseClient _supabase;

  Future<SettingsModel?> fetchRemote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final bundle = await StartupUserDataService.instance.fetchCombinedForUser(
      user.id,
    );
    if (bundle.failedTables.contains('user_settings')) {
      throw Exception('user_settings fetch failed');
    }
    final row = bundle.settingsRow;
    if (row == null) return null;

    final rawSettings = row['settings'];
    final updatedAt = row['updated_at']?.toString();

    if (rawSettings is Map<String, dynamic>) {
      return SettingsModel.fromJson(
        rawSettings,
        updatedAtOverride: updatedAt,
      );
    }
    if (rawSettings is Map) {
      return SettingsModel.fromJson(
        Map<String, dynamic>.from(rawSettings),
        updatedAtOverride: updatedAt,
      );
    }
    if (rawSettings is String && rawSettings.isNotEmpty) {
      final decoded = jsonDecode(rawSettings);
      final jsonMap = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
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
    StartupUserDataService.instance.invalidateUser(user.id);
  }
}
