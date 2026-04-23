import 'package:flutter/foundation.dart';
import 'package:mind_buddy/core/sync/sync_queue_store.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/built_in_log_templates.dart';

import '../local/template_logs_local_data_source.dart';
import '../remote/template_logs_remote_data_source.dart';

class TemplateLogsSyncService {
  TemplateLogsSyncService({
    required TemplateLogsLocalDataSource localDataSource,
    required TemplateLogsRemoteDataSource remoteDataSource,
    required SyncQueueStore queueStore,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _queueStore = queueStore;

  static const entityType = 'template_log_entry';

  final TemplateLogsLocalDataSource _localDataSource;
  final TemplateLogsRemoteDataSource _remoteDataSource;
  final SyncQueueStore _queueStore;

  Future<void> enqueueUpsert({
    required String scopeId,
    required String entryId,
    required String templateKey,
  }) {
    return _queueStore.enqueueUpsertJob(
      scopeId: scopeId,
      entityType: entityType,
      entityId: entryId,
      payload: <String, dynamic>{'template_key': templateKey},
    );
  }

  Future<void> syncPending() async {
    final jobs = await _queueStore.pendingJobsForEntity(entityType);
    for (final job in jobs) {
      await _queueStore.markRunning(job.id);
      try {
        final localEntry = await _localDataSource.loadEntryById(job.entityId);
        if (localEntry == null) {
          await _queueStore.markCompleted(job.id);
          continue;
        }

        if (localEntry.deletedAt != null ||
            localEntry.syncStatus == SyncStatus.pendingDelete) {
          await _remoteDataSource.deleteEntry(
            templateKey: localEntry.templateKey,
            id: localEntry.id,
          );
          await _localDataSource.purgeEntry(localEntry.id);
        } else {
          if (localEntry.templateKey == 'mood') {
            debugPrint(
              'MOOD_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'cycle') {
            debugPrint(
              'CYCLE_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'expenses') {
            debugPrint(
              'EXPENSES_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'fast') {
            debugPrint(
              'FAST_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'income') {
            debugPrint(
              'INCOME_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'meditation') {
            debugPrint(
              'MEDITATION_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'movies') {
            debugPrint(
              'MOVIES_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'places') {
            debugPrint(
              'PLACES_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'restaurants') {
            debugPrint(
              'RESTAURANT_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'skin_care') {
            debugPrint(
              'SKINCARE_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'social') {
            debugPrint(
              'SOCIAL_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'study') {
            debugPrint(
              'STUDY_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'tasks') {
            debugPrint(
              'TASKS_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'tv_log') {
            debugPrint(
              'TVLOGS_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'wishlist') {
            debugPrint(
              'WISHLIST_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'workout') {
            debugPrint(
              'WORKOUT_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'bills') {
            debugPrint(
              'BILLS_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'books') {
            debugPrint(
              'BOOKS_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'sleep') {
            debugPrint(
              'SLEEP_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (localEntry.templateKey == 'water') {
            debugPrint(
              'WATER_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          } else if (builtInLogTemplateByKey(localEntry.templateKey) == null) {
            debugPrint(
              'CUSTOM_TEMPLATE_SAVE_QUEUE_SYNC entryId=${localEntry.id} action=remote-upsert',
            );
          }
          await _remoteDataSource.upsertEntry(
            templateKey: localEntry.templateKey,
            payload: localEntry.payload,
          );
          await _localDataSource.markEntrySynced(localEntry.id);
        }

        await _queueStore.markCompleted(job.id);
      } catch (error) {
        final localEntry = await _localDataSource.loadEntryById(job.entityId);
        if (localEntry?.templateKey == 'mood') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('MOOD_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('MOOD_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'cycle') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('CYCLE_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('CYCLE_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'expenses') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('EXPENSES_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('EXPENSES_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'fast') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('FAST_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('FAST_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'income') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('INCOME_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('INCOME_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'meditation') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('MEDITATION_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('MEDITATION_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'movies') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('MOVIES_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('MOVIES_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'places') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('PLACES_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('PLACES_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'restaurants') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('RESTAURANT_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('RESTAURANT_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'skin_care') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('SKINCARE_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('SKINCARE_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'social') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('SOCIAL_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('SOCIAL_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'study') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('STUDY_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('STUDY_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'tasks') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('TASKS_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('TASKS_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'tv_log') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('TVLOGS_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('TVLOGS_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'wishlist') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('WISHLIST_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('WISHLIST_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'workout') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('WORKOUT_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('WORKOUT_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'bills') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('BILLS_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('BILLS_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'books') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('BOOKS_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('BOOKS_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'sleep') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('SLEEP_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('SLEEP_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry?.templateKey == 'water') {
          if (_isLikelyOfflineError(error)) {
            debugPrint('WATER_SAVE_REMOTE_SKIPPED_OFFLINE error=$error');
          } else {
            debugPrint('WATER_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        } else if (localEntry != null &&
            builtInLogTemplateByKey(localEntry.templateKey) == null) {
          if (_isLikelyOfflineError(error)) {
            debugPrint(
              'CUSTOM_TEMPLATE_SAVE_REMOTE_SKIPPED_OFFLINE error=$error',
            );
          } else {
            debugPrint('CUSTOM_TEMPLATE_SAVE_LOCAL_ERROR: sync_failed $error');
          }
        }
        await _localDataSource.markEntrySyncFailed(
          job.entityId,
          error.toString(),
        );
        await _queueStore.markFailed(
          job.id,
          error: error.toString(),
          previousAttempts: job.attemptCount,
        );
      }
    }
  }

  bool _isLikelyOfflineError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed') ||
        text.contains('network is unreachable');
  }
}
