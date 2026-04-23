import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';

class LocalSettingsRecord {
  const LocalSettingsRecord({
    required this.scopeId,
    required this.userId,
    required this.settings,
    required this.syncStatus,
    required this.updatedAt,
    this.lastSyncedAt,
    this.syncError,
  });

  final String scopeId;
  final String? userId;
  final SettingsModel settings;
  final SyncStatus syncStatus;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final String? syncError;
}

class SettingsLocalDataSource {
  SettingsLocalDataSource(this._database);

  final AppDatabase _database;
  static const legacyPrefsKey = 'mb_settings_v1';

  Future<LocalSettingsRecord?> load(String scopeId) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('SETTINGS_DB_PATH_RELOAD=$dbPath');
    debugPrint('SETTINGS_STATE_LOAD_FROM_LOCAL_START scopeId=$scopeId');
    debugPrint('THEME_DB_PATH_RELOAD=$dbPath');
    debugPrint('THEME_STATE_LOAD_FROM_LOCAL_START scopeId=$scopeId');
    final row = await (_database.select(
      _database.settingsRecords,
    )..where((tbl) => tbl.scopeId.equals(scopeId))).getSingleOrNull();
    if (row == null) {
      debugPrint(
        'SETTINGS_STATE_LOAD_FROM_LOCAL_RESULT scopeId=$scopeId found=false',
      );
      debugPrint(
        'THEME_STATE_LOAD_FROM_LOCAL_RESULT scopeId=$scopeId found=false themeId=none customThemeCount=0',
      );
      return null;
    }
    final record = _mapRow(row);
    debugPrint(
      'SETTINGS_STATE_LOAD_FROM_LOCAL_RESULT '
      'scopeId=$scopeId found=true '
      'themeId=${record.settings.themeId ?? 'none'} '
      'quietHoursEnabled=${record.settings.quietHoursEnabled} '
      'dailyCheckInEnabled=${record.settings.dailyCheckInEnabled} '
      'hapticsEnabled=${record.settings.hapticsEnabled} '
      'soundsEnabled=${record.settings.soundsEnabled} '
      'keepInstructionsEnabled=${record.settings.keepInstructionsEnabled}',
    );
    debugPrint(
      'THEME_STATE_LOAD_FROM_LOCAL_RESULT scopeId=$scopeId found=true themeId=${record.settings.themeId ?? 'none'} customThemeCount=${record.settings.customThemes.length}',
    );
    return record;
  }

  Stream<LocalSettingsRecord?> watch(String scopeId) {
    return (_database.select(_database.settingsRecords)
          ..where((tbl) => tbl.scopeId.equals(scopeId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _mapRow(row));
  }

  Future<void> save({
    required String scopeId,
    required String? userId,
    required SettingsModel settings,
    required SyncStatus syncStatus,
    DateTime? lastSyncedAt,
    String? syncError,
  }) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('SETTINGS_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'SETTINGS_STATE_SAVE_LOCAL_START '
      'scopeId=$scopeId '
      'themeId=${settings.themeId ?? 'none'} '
      'quietHoursEnabled=${settings.quietHoursEnabled} '
      'dailyCheckInEnabled=${settings.dailyCheckInEnabled} '
      'hapticsEnabled=${settings.hapticsEnabled} '
      'soundsEnabled=${settings.soundsEnabled} '
      'keepInstructionsEnabled=${settings.keepInstructionsEnabled} '
      'syncStatus=${syncStatus.value}',
    );
    debugPrint('THEME_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'THEME_STATE_SAVE_LOCAL_START scopeId=$scopeId themeId=${settings.themeId ?? 'none'} customThemeCount=${settings.customThemes.length} syncStatus=${syncStatus.value}',
    );
    final updatedAt =
        DateTime.tryParse(settings.updatedAt)?.toUtc() ??
        DateTime.now().toUtc();
    await _database
        .into(_database.settingsRecords)
        .insertOnConflictUpdate(
          SettingsRecordsCompanion.insert(
            scopeId: scopeId,
            userId: Value(userId),
            payloadJson: jsonEncode(settings.toJson()),
            updatedAt: updatedAt,
            version: Value(settings.version),
            syncStatus: syncStatus.value,
            lastSyncedAt: Value(lastSyncedAt?.toUtc()),
            syncError: Value(syncError),
          ),
        );
    debugPrint(
      'SETTINGS_STATE_SAVE_LOCAL_SUCCESS '
      'scopeId=$scopeId '
      'themeId=${settings.themeId ?? 'none'} '
      'quietHoursEnabled=${settings.quietHoursEnabled} '
      'dailyCheckInEnabled=${settings.dailyCheckInEnabled} '
      'hapticsEnabled=${settings.hapticsEnabled} '
      'soundsEnabled=${settings.soundsEnabled} '
      'keepInstructionsEnabled=${settings.keepInstructionsEnabled}',
    );
    debugPrint(
      'THEME_STATE_SAVE_LOCAL_SUCCESS scopeId=$scopeId themeId=${settings.themeId ?? 'none'} customThemeCount=${settings.customThemes.length}',
    );
  }

  Future<LocalSettingsRecord?> migrateLegacyPrefs({
    required String scopeId,
    required String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(legacyPrefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      final jsonMap = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
      if (jsonMap == null) return null;
      final settings = SettingsModel.fromJson(jsonMap);
      final syncStatus = userId == null
          ? SyncStatus.synced
          : SyncStatus.pendingUpsert;
      await save(
        scopeId: scopeId,
        userId: userId,
        settings: settings,
        syncStatus: syncStatus,
        lastSyncedAt: userId == null ? DateTime.now().toUtc() : null,
      );
      return load(scopeId);
    } catch (_) {
      return null;
    }
  }

  Future<void> markSyncState({
    required String scopeId,
    required SyncStatus syncStatus,
    DateTime? lastSyncedAt,
    String? syncError,
  }) async {
    await (_database.update(
      _database.settingsRecords,
    )..where((tbl) => tbl.scopeId.equals(scopeId))).write(
      SettingsRecordsCompanion(
        syncStatus: Value(syncStatus.value),
        lastSyncedAt: Value(lastSyncedAt?.toUtc()),
        syncError: Value(syncError),
      ),
    );
  }

  LocalSettingsRecord _mapRow(SettingsRecord row) {
    final decoded = jsonDecode(row.payloadJson);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final settings = SettingsModel.fromJson(
      payload,
      updatedAtOverride: row.updatedAt.toUtc().toIso8601String(),
    );
    return LocalSettingsRecord(
      scopeId: row.scopeId,
      userId: row.userId,
      settings: settings,
      syncStatus: SyncStatus.fromValue(row.syncStatus),
      updatedAt: row.updatedAt,
      lastSyncedAt: row.lastSyncedAt,
      syncError: row.syncError,
    );
  }
}
