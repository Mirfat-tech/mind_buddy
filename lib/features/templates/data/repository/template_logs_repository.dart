import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/database/database_providers.dart';
import 'package:mind_buddy/core/sync/sync_queue_store.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/built_in_log_templates.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';
import 'package:mind_buddy/features/templates/data/remote/template_logs_remote_data_source.dart';
import 'package:mind_buddy/features/templates/data/sync/template_logs_sync_service.dart';
import 'package:mind_buddy/features/templates/data/template_local_first_support.dart';

class TemplateLogsRepository {
  TemplateLogsRepository({
    required TemplateLogsLocalDataSource localDataSource,
    required TemplateLogsRemoteDataSource remoteDataSource,
    required TemplateLogsSyncService syncService,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _syncService = syncService;

  factory TemplateLogsRepository.live({
    required AppDatabase database,
    required SupabaseClient supabase,
  }) {
    final localDataSource = TemplateLogsLocalDataSource(database);
    final remoteDataSource = TemplateLogsRemoteDataSource(supabase);
    final syncService = TemplateLogsSyncService(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      queueStore: SyncQueueStore(database),
    );
    return TemplateLogsRepository(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncService: syncService,
    );
  }

  static const _uuid = Uuid();

  final TemplateLogsLocalDataSource _localDataSource;
  final TemplateLogsRemoteDataSource _remoteDataSource;
  final TemplateLogsSyncService _syncService;

  bool supportsTemplate(String templateKey) {
    return isLocalFirstTemplateKey(templateKey);
  }

  Future<List<Map<String, dynamic>>> loadTemplateFields({
    required String templateId,
    required String templateKey,
    required String userId,
  }) async {
    await _localDataSource.ensureBuiltInDefinitions();
    final normalizedKey = templateKey.trim().toLowerCase();
    final local = await _localDataSource.loadTemplateDefinition(
      templateId: templateId,
      templateKey: normalizedKey,
    );
    if (local != null && local.fields.isNotEmpty) {
      return local.fields;
    }

    final builtIn = builtInLogTemplateByKey(normalizedKey);
    if (builtIn != null) {
      await _localDataSource.ensureBuiltInDefinitions();
      final seeded = await _localDataSource.loadTemplateDefinition(
        templateId: builtIn.id,
        templateKey: normalizedKey,
      );
      return seeded?.fields ?? const <Map<String, dynamic>>[];
    }

    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> loadEntries({
    required String templateId,
    required String templateKey,
    required String userId,
  }) async {
    final normalizedKey = templateKey.trim().toLowerCase();
    debugPrint(
      'TEMPLATE_LOG_REPOSITORY_LOAD_ENTRY templateKey=$normalizedKey path=TemplateLogsRepository.loadEntries',
    );
    var localEntries = await _localDataSource.loadEntries(
      templateKey: normalizedKey,
      userId: userId,
    );
    if (localEntries.isNotEmpty) {
      if (normalizedKey == 'mood') {
        debugPrint(
          'MOOD_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'cycle') {
        debugPrint(
          'CYCLE_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'expenses') {
        debugPrint(
          'EXPENSES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'fast') {
        debugPrint(
          'FAST_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'income') {
        debugPrint(
          'INCOME_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'meditation') {
        debugPrint(
          'MEDITATION_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'movies') {
        debugPrint(
          'MOVIES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'places') {
        debugPrint(
          'PLACES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'restaurants') {
        debugPrint(
          'RESTAURANT_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'skin_care') {
        debugPrint(
          'SKINCARE_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'social') {
        debugPrint(
          'SOCIAL_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'study') {
        debugPrint(
          'STUDY_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'tasks') {
        debugPrint(
          'TASKS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'tv_log') {
        debugPrint(
          'TVLOGS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'wishlist') {
        debugPrint(
          'WISHLIST_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'workout') {
        debugPrint(
          'WORKOUT_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'bills') {
        debugPrint(
          'BILLS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'books') {
        debugPrint(
          'BOOKS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'sleep') {
        debugPrint(
          'SLEEP_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (normalizedKey == 'water') {
        debugPrint(
          'WATER_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-cache-hit',
        );
      } else if (builtInLogTemplateByKey(normalizedKey) == null) {
        debugPrint(
          'CUSTOM_TEMPLATE_RELOAD_RESULT count=${localEntries.length} source=repository-cache-hit',
        );
      }
      return localEntries;
    }

    await _localDataSource.importLegacyPreviewEntriesIfNeeded(
      templateId: templateId,
      templateKey: normalizedKey,
      userId: userId,
      path: 'repository',
    );
    localEntries = await _localDataSource.loadEntries(
      templateKey: normalizedKey,
      userId: userId,
    );
    if (localEntries.isNotEmpty) {
      if (normalizedKey == 'mood') {
        debugPrint(
          'MOOD_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'cycle') {
        debugPrint(
          'CYCLE_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'expenses') {
        debugPrint(
          'EXPENSES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'fast') {
        debugPrint(
          'FAST_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'income') {
        debugPrint(
          'INCOME_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'meditation') {
        debugPrint(
          'MEDITATION_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'movies') {
        debugPrint(
          'MOVIES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'places') {
        debugPrint(
          'PLACES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'restaurants') {
        debugPrint(
          'RESTAURANT_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'skin_care') {
        debugPrint(
          'SKINCARE_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'social') {
        debugPrint(
          'SOCIAL_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'study') {
        debugPrint(
          'STUDY_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'tasks') {
        debugPrint(
          'TASKS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'tv_log') {
        debugPrint(
          'TVLOGS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'wishlist') {
        debugPrint(
          'WISHLIST_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'workout') {
        debugPrint(
          'WORKOUT_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'bills') {
        debugPrint(
          'BILLS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'books') {
        debugPrint(
          'BOOKS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'sleep') {
        debugPrint(
          'SLEEP_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (normalizedKey == 'water') {
        debugPrint(
          'WATER_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-legacy-import',
        );
      } else if (builtInLogTemplateByKey(normalizedKey) == null) {
        debugPrint(
          'CUSTOM_TEMPLATE_RELOAD_RESULT count=${localEntries.length} source=repository-post-legacy-import',
        );
      }
      return localEntries;
    }

    if (normalizedKey == 'mood') {
      debugPrint(
        'MOOD_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'cycle') {
      debugPrint(
        'CYCLE_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'expenses') {
      debugPrint(
        'EXPENSES_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'fast') {
      debugPrint(
        'FAST_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'income') {
      debugPrint(
        'INCOME_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'meditation') {
      debugPrint(
        'MEDITATION_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'movies') {
      debugPrint(
        'MOVIES_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'places') {
      debugPrint(
        'PLACES_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'restaurants') {
      debugPrint(
        'RESTAURANT_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'skin_care') {
      debugPrint(
        'SKINCARE_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'social') {
      debugPrint(
        'SOCIAL_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'study') {
      debugPrint(
        'STUDY_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'tasks') {
      debugPrint(
        'TASKS_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'tv_log') {
      debugPrint(
        'TVLOGS_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'wishlist') {
      debugPrint(
        'WISHLIST_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'workout') {
      debugPrint(
        'WORKOUT_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'bills') {
      debugPrint(
        'BILLS_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'books') {
      debugPrint(
        'BOOKS_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'sleep') {
      debugPrint(
        'SLEEP_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (normalizedKey == 'water') {
      debugPrint(
        'WATER_LIST_READ_FROM_LOCAL count=0 source=repository-cache-miss',
      );
    } else if (builtInLogTemplateByKey(normalizedKey) == null) {
      debugPrint(
        'CUSTOM_TEMPLATE_RELOAD_RESULT count=0 source=repository-cache-miss',
      );
    }
    if (builtInLogTemplateByKey(normalizedKey) == null) {
      return localEntries;
    }
    final remoteEntries = await _remoteDataSource.fetchEntries(
      templateKey: normalizedKey,
      userId: userId,
    );
    await _localDataSource.mergeRemoteEntries(
      templateKey: normalizedKey,
      userId: userId,
      templateId: templateId,
      remoteEntries: remoteEntries,
    );
    localEntries = await _localDataSource.loadEntries(
      templateKey: normalizedKey,
      userId: userId,
    );
    if (normalizedKey == 'mood') {
      debugPrint(
        'MOOD_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'cycle') {
      debugPrint(
        'CYCLE_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'expenses') {
      debugPrint(
        'EXPENSES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'fast') {
      debugPrint(
        'FAST_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'income') {
      debugPrint(
        'INCOME_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'meditation') {
      debugPrint(
        'MEDITATION_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'movies') {
      debugPrint(
        'MOVIES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'places') {
      debugPrint(
        'PLACES_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'restaurants') {
      debugPrint(
        'RESTAURANT_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'skin_care') {
      debugPrint(
        'SKINCARE_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'social') {
      debugPrint(
        'SOCIAL_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'study') {
      debugPrint(
        'STUDY_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'tasks') {
      debugPrint(
        'TASKS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'tv_log') {
      debugPrint(
        'TVLOGS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'wishlist') {
      debugPrint(
        'WISHLIST_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'workout') {
      debugPrint(
        'WORKOUT_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'bills') {
      debugPrint(
        'BILLS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'books') {
      debugPrint(
        'BOOKS_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'sleep') {
      debugPrint(
        'SLEEP_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (normalizedKey == 'water') {
      debugPrint(
        'WATER_LIST_READ_FROM_LOCAL count=${localEntries.length} source=repository-post-merge',
      );
    } else if (builtInLogTemplateByKey(normalizedKey) == null) {
      debugPrint(
        'CUSTOM_TEMPLATE_RELOAD_RESULT count=${localEntries.length} source=repository-post-merge',
      );
    }
    return localEntries;
  }

  Future<Map<String, dynamic>?> findExistingDailyLog({
    required String templateKey,
    required String userId,
    required String day,
    String? excludeId,
  }) {
    return _localDataSource.findExistingDailyLog(
      templateKey: templateKey,
      userId: userId,
      day: day,
      excludeId: excludeId,
    );
  }

  Future<void> addEntry({
    required String scopeId,
    required String? templateId,
    required String templateKey,
    required String userId,
    required String day,
    required Map<String, dynamic> data,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final payload = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'day': day,
      ...data,
    };
    await _localDataSource.saveEntry(
      id: id,
      templateId: templateId,
      templateKey: templateKey,
      userId: userId,
      day: day,
      payload: payload,
      syncStatus: SyncStatus.pendingUpsert,
      createdAt: now,
      updatedAt: now,
    );
    if (templateKey.trim().toLowerCase() == 'mood') {
      debugPrint('MOOD_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'cycle') {
      debugPrint('CYCLE_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'expenses') {
      debugPrint('EXPENSES_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'fast') {
      debugPrint('FAST_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'income') {
      debugPrint('INCOME_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'meditation') {
      debugPrint('MEDITATION_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'movies') {
      debugPrint('MOVIES_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'places') {
      debugPrint('PLACES_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'restaurants') {
      debugPrint('RESTAURANT_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'skin_care') {
      debugPrint('SKINCARE_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'social') {
      debugPrint('SOCIAL_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'study') {
      debugPrint('STUDY_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'tasks') {
      debugPrint('TASKS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'tv_log') {
      debugPrint('TVLOGS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'wishlist') {
      debugPrint('WISHLIST_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'workout') {
      debugPrint('WORKOUT_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'bills') {
      debugPrint('BILLS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'books') {
      debugPrint('BOOKS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'sleep') {
      debugPrint('SLEEP_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'water') {
      debugPrint('WATER_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (builtInLogTemplateByKey(templateKey.trim().toLowerCase()) ==
        null) {
      debugPrint('CUSTOM_TEMPLATE_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    }
    await _syncService.enqueueUpsert(
      scopeId: scopeId,
      entryId: id,
      templateKey: templateKey,
    );
    unawaited(_syncService.syncPending());
  }

  Future<void> updateEntry({
    required String scopeId,
    required String? templateId,
    required String templateKey,
    required String userId,
    required Map<String, dynamic> existingEntry,
    required String day,
    required Map<String, dynamic> data,
  }) async {
    final id = (existingEntry['id'] ?? '').toString();
    if (id.isEmpty) {
      throw StateError('Cannot update a log entry without an id.');
    }

    final existingLocal = await _localDataSource.loadEntryById(id);
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      ...existingEntry,
      'id': id,
      'user_id': userId,
      'day': day,
      ...data,
    };
    await _localDataSource.saveEntry(
      id: id,
      templateId: templateId,
      templateKey: templateKey,
      userId: userId,
      day: day,
      payload: payload,
      syncStatus: SyncStatus.pendingUpsert,
      createdAt: existingLocal?.createdAt ?? now,
      updatedAt: now,
      lastSyncedAt: existingLocal?.lastSyncedAt,
      version: (existingLocal?.version ?? 0) + 1,
    );
    if (templateKey.trim().toLowerCase() == 'mood') {
      debugPrint('MOOD_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'cycle') {
      debugPrint('CYCLE_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'expenses') {
      debugPrint('EXPENSES_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'fast') {
      debugPrint('FAST_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'income') {
      debugPrint('INCOME_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'meditation') {
      debugPrint('MEDITATION_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'movies') {
      debugPrint('MOVIES_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'places') {
      debugPrint('PLACES_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'restaurants') {
      debugPrint('RESTAURANT_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'skin_care') {
      debugPrint('SKINCARE_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'social') {
      debugPrint('SOCIAL_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'study') {
      debugPrint('STUDY_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'tasks') {
      debugPrint('TASKS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'tv_log') {
      debugPrint('TVLOGS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'wishlist') {
      debugPrint('WISHLIST_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'workout') {
      debugPrint('WORKOUT_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'bills') {
      debugPrint('BILLS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'books') {
      debugPrint('BOOKS_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'sleep') {
      debugPrint('SLEEP_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (templateKey.trim().toLowerCase() == 'water') {
      debugPrint('WATER_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    } else if (builtInLogTemplateByKey(templateKey.trim().toLowerCase()) ==
        null) {
      debugPrint('CUSTOM_TEMPLATE_SAVE_QUEUE_SYNC entryId=$id action=enqueue');
    }
    await _syncService.enqueueUpsert(
      scopeId: scopeId,
      entryId: id,
      templateKey: templateKey,
    );
    unawaited(_syncService.syncPending());
  }

  Future<void> deleteEntry({
    required String scopeId,
    required String templateKey,
    required String userId,
    required Map<String, dynamic> entry,
  }) async {
    final id = (entry['id'] ?? '').toString();
    if (id.isEmpty) {
      throw StateError('Cannot delete a log entry without an id.');
    }

    final existingLocal = await _localDataSource.loadEntryById(id);
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{...entry, 'id': id, 'user_id': userId};
    await _localDataSource.saveEntry(
      id: id,
      templateId: existingLocal?.templateId,
      templateKey: templateKey,
      userId: userId,
      day: (entry['day'] ?? '').toString(),
      payload: payload,
      syncStatus: SyncStatus.pendingDelete,
      createdAt: existingLocal?.createdAt ?? now,
      updatedAt: now,
      deletedAt: now,
      lastSyncedAt: existingLocal?.lastSyncedAt,
      version: (existingLocal?.version ?? 0) + 1,
    );
    await _syncService.enqueueUpsert(
      scopeId: scopeId,
      entryId: id,
      templateKey: templateKey,
    );
    unawaited(_syncService.syncPending());
  }
}

final templateLogsRepositoryProvider = Provider<TemplateLogsRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return TemplateLogsRepository.live(
    database: database,
    supabase: Supabase.instance.client,
  );
});
