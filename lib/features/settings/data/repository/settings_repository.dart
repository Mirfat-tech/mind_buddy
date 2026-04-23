import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/core/repositories/local_first_repository.dart';
import 'package:mind_buddy/core/sync/sync_queue_store.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/settings/data/local/settings_local_data_source.dart';
import 'package:mind_buddy/features/settings/data/remote/settings_remote_data_source.dart';
import 'package:mind_buddy/features/settings/data/sync/settings_sync_service.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

import '../../../../core/database/app_database.dart';

class SettingsRepository implements LocalFirstRepository<SettingsModel> {
  SettingsRepository({
    required SettingsLocalDataSource localDataSource,
    required SettingsRemoteDataSource remoteDataSource,
    required SettingsSyncService syncService,
    required SupabaseClient supabase,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _syncService = syncService,
       _supabase = supabase;

  factory SettingsRepository.live({
    required AppDatabase database,
    required SupabaseClient supabase,
  }) {
    final localDataSource = SettingsLocalDataSource(database);
    final remoteDataSource = SettingsRemoteDataSource(supabase);
    final queueStore = SyncQueueStore(database);
    final syncService = SettingsSyncService(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      queueStore: queueStore,
    );
    return SettingsRepository(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncService: syncService,
      supabase: supabase,
    );
  }

  static SettingsRepository? _activeInstance;

  static SettingsRepository? get activeInstance => _activeInstance;

  static void registerActive(SettingsRepository repository) {
    _activeInstance = repository;
  }

  final SettingsLocalDataSource _localDataSource;
  final SettingsRemoteDataSource _remoteDataSource;
  final SettingsSyncService _syncService;
  final SupabaseClient _supabase;

  String get _scopeId => _supabase.auth.currentUser?.id ?? 'guest';
  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  Future<SettingsModel?> loadCached() async {
    final local = await _localDataSource.load(_scopeId);
    if (local != null) return local.settings;
    final migrated = await _localDataSource.migrateLegacyPrefs(
      scopeId: _scopeId,
      userId: _userId,
    );
    return migrated?.settings;
  }

  @override
  Future<SettingsModel> initialize() async {
    var local = await _localDataSource.load(_scopeId);
    local ??= await _localDataSource.migrateLegacyPrefs(
      scopeId: _scopeId,
      userId: _userId,
    );

    if (local == null) {
      final defaults = _normalized(SettingsModel.defaults());
      final initialSyncStatus = _userId == null
          ? SyncStatus.synced
          : SyncStatus.pendingUpsert;
      final initialLastSynced = _userId == null ? DateTime.now().toUtc() : null;
      await _localDataSource.save(
        scopeId: _scopeId,
        userId: _userId,
        settings: defaults,
        syncStatus: initialSyncStatus,
        lastSyncedAt: initialLastSynced,
      );
      local = await _localDataSource.load(_scopeId);
    }

    if (_userId == null) {
      return _normalized(local!.settings);
    }

    try {
      final remote = await _remoteDataSource.fetchRemote();
      if (remote != null) {
        final normalizedRemote = _normalized(remote);
        debugPrint(
          'SETTINGS_STATE_REMOTE_REFRESH '
          'scopeId=$_scopeId '
          'themeId=${normalizedRemote.themeId ?? 'none'} '
          'quietHoursEnabled=${normalizedRemote.quietHoursEnabled} '
          'dailyCheckInEnabled=${normalizedRemote.dailyCheckInEnabled} '
          'hapticsEnabled=${normalizedRemote.hapticsEnabled} '
          'soundsEnabled=${normalizedRemote.soundsEnabled} '
          'keepInstructionsEnabled=${normalizedRemote.keepInstructionsEnabled}',
        );
        debugPrint(
          'THEME_STATE_REMOTE_REFRESH scopeId=$_scopeId themeId=${normalizedRemote.themeId ?? 'none'} customThemeCount=${normalizedRemote.customThemes.length}',
        );
        if (local == null ||
            normalizedRemote.updatedAtDateTime.isAfter(
              local.settings.updatedAtDateTime,
            )) {
          await _localDataSource.save(
            scopeId: _scopeId,
            userId: _userId,
            settings: normalizedRemote,
            syncStatus: SyncStatus.synced,
            lastSyncedAt: DateTime.now().toUtc(),
          );
          return normalizedRemote;
        }
      }
    } catch (_) {
      // Local settings stay authoritative while remote fetch is unavailable.
    }

    final normalizedLocal = _normalized(local!.settings);
    if (normalizedLocal.themeId != local.settings.themeId) {
      await _localDataSource.save(
        scopeId: _scopeId,
        userId: _userId,
        settings: normalizedLocal,
        syncStatus: local.syncStatus,
        lastSyncedAt: local.lastSyncedAt,
        syncError: local.syncError,
      );
    }
    if (local.syncStatus != SyncStatus.synced) {
      await _enqueueAndSync();
    }
    return normalizedLocal;
  }

  @override
  Future<void> syncPending() => _syncService.syncPending();

  Future<SettingsModel> saveLocalFirst(SettingsModel settings) async {
    final normalized = _normalized(
      settings.copyWith(updatedAt: DateTime.now().toUtc().toIso8601String()),
    );
    final syncStatus = _userId == null
        ? SyncStatus.synced
        : SyncStatus.pendingUpsert;
    await _localDataSource.save(
      scopeId: _scopeId,
      userId: _userId,
      settings: normalized,
      syncStatus: syncStatus,
      lastSyncedAt: _userId == null ? DateTime.now().toUtc() : null,
    );
    if (_userId != null) {
      debugPrint(
        'SETTINGS_STATE_QUEUE_SYNC '
        'scopeId=$_scopeId '
        'themeId=${normalized.themeId ?? 'none'} '
        'quietHoursEnabled=${normalized.quietHoursEnabled} '
        'dailyCheckInEnabled=${normalized.dailyCheckInEnabled} '
        'hapticsEnabled=${normalized.hapticsEnabled} '
        'soundsEnabled=${normalized.soundsEnabled} '
        'keepInstructionsEnabled=${normalized.keepInstructionsEnabled}',
      );
      debugPrint(
        'THEME_STATE_QUEUE_SYNC scopeId=$_scopeId themeId=${normalized.themeId ?? 'none'} customThemeCount=${normalized.customThemes.length}',
      );
      await _enqueueAndSync();
    }
    return normalized;
  }

  Future<void> updateGuideState(Map<String, dynamic> guideState) async {
    final current =
        (await _localDataSource.load(_scopeId))?.settings ??
        SettingsModel.defaults();
    await saveLocalFirst(current.copyWith(guideState: guideState));
  }

  Future<void> setKeepInstructionsEnabled(bool enabled) async {
    final current =
        (await _localDataSource.load(_scopeId))?.settings ??
        SettingsModel.defaults();
    await saveLocalFirst(current.copyWith(keepInstructionsEnabled: enabled));
  }

  Stream<SettingsModel?> watchCurrent() {
    return _localDataSource.watch(_scopeId).map((record) => record?.settings);
  }

  Future<void> _enqueueAndSync() async {
    final userId = _userId;
    if (userId == null) return;
    await _syncService.enqueueUpsert(scopeId: _scopeId, userId: userId);
    unawaited(_syncService.syncPending());
  }

  SettingsModel _normalized(SettingsModel settings) {
    final themeId = (settings.themeId ?? '').trim();
    if (themeId.isEmpty || !isValidPaperStyleId(themeId)) {
      return settings.copyWith(themeId: kDefaultThemeId);
    }
    return settings;
  }
}
