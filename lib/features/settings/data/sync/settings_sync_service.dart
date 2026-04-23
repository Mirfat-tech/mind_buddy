import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/sync/sync_queue_store.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/settings/data/local/settings_local_data_source.dart';
import 'package:mind_buddy/features/settings/data/remote/settings_remote_data_source.dart';

class SettingsSyncService {
  SettingsSyncService({
    required SettingsLocalDataSource localDataSource,
    required SettingsRemoteDataSource remoteDataSource,
    required SyncQueueStore queueStore,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _queueStore = queueStore;

  final SettingsLocalDataSource _localDataSource;
  final SettingsRemoteDataSource _remoteDataSource;
  final SyncQueueStore _queueStore;
  Future<void>? _inFlight;

  Future<void> enqueueUpsert({
    required String scopeId,
    required String userId,
  }) async {
    await _queueStore.enqueueUpsertJob(
      scopeId: scopeId,
      entityType: 'settings',
      entityId: scopeId,
      payload: <String, dynamic>{'user_id': userId},
    );
  }

  Future<void> syncPending() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _runPending();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _runPending() async {
    final jobs = await _queueStore.pendingJobsForEntity('settings');
    for (final job in jobs) {
      await _queueStore.markRunning(job.id);
      final local = await _localDataSource.load(job.scopeId);
      if (local == null || local.userId == null) {
        await _queueStore.markCompleted(job.id);
        continue;
      }

      try {
        await _remoteDataSource.upsertRemote(local.settings);
        await _localDataSource.markSyncState(
          scopeId: job.scopeId,
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.now().toUtc(),
          syncError: null,
        );
        await _queueStore.markCompleted(job.id);
      } catch (error, stackTrace) {
        debugPrint('Settings sync failed: $error\n$stackTrace');
        await _localDataSource.markSyncState(
          scopeId: job.scopeId,
          syncStatus: SyncStatus.syncFailed,
          syncError: error.toString(),
        );
        await _queueStore.markFailed(
          job.id,
          error: error.toString(),
          previousAttempts: job.attemptCount,
        );
      }
    }
  }
}
