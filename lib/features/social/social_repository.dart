import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind_buddy/core/database/database_providers.dart';
import 'package:mind_buddy/features/templates/built_in_log_templates.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';
import 'package:mind_buddy/features/templates/data/repository/template_logs_repository.dart';

class SocialRepository {
  SocialRepository(this._templateLogsRepository, this._localDataSource);

  static const String templateKey = 'social';
  static const String builtInTemplateId = 'builtin:social';

  final TemplateLogsRepository _templateLogsRepository;
  final TemplateLogsLocalDataSource _localDataSource;

  Future<List<Map<String, dynamic>>> loadFields({
    required String userId,
    String? templateId,
  }) async {
    await _localDataSource.ensureBuiltInDefinitions();
    final resolvedTemplateId = _resolveTemplateId(templateId);
    final local = await _localDataSource.loadTemplateDefinition(
      templateId: resolvedTemplateId,
      templateKey: templateKey,
    );
    if (local != null && local.fields.isNotEmpty) {
      return local.fields;
    }

    final builtIn = builtInLogTemplateByKey(templateKey);
    if (builtIn == null) {
      return const <Map<String, dynamic>>[];
    }

    await _localDataSource.ensureBuiltInDefinitions();
    final seeded = await _localDataSource.loadTemplateDefinition(
      templateId: builtIn.id,
      templateKey: templateKey,
    );
    return seeded?.fields ?? const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> loadEntries({
    required String userId,
    String? templateId,
  }) async {
    final resolvedTemplateId = _resolveTemplateId(templateId);
    debugPrint(
      'SOCIAL_RELOAD_QUERY userId=$userId templateKey=$templateKey templateId=$resolvedTemplateId',
    );
    final entries = await _localDataSource.loadEntries(
      templateKey: templateKey,
      userId: userId,
    );
    debugPrint(
      'SOCIAL_LIST_READ_FROM_LOCAL count=${entries.length} userId=$userId',
    );
    return entries;
  }

  Future<Map<String, dynamic>?> findExistingDailyLog({
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
    required String userId,
    required String day,
    required Map<String, dynamic> data,
    String? templateId,
  }) {
    debugPrint(
      'SOCIAL_SAVE_LOCAL_START day=$day userId=$userId templateId=${_resolveTemplateId(templateId)} data=$data',
    );
    return _templateLogsRepository
        .addEntry(
          scopeId: scopeId,
          templateId: _resolveTemplateId(templateId),
          templateKey: templateKey,
          userId: userId,
          day: day,
          data: data,
        )
        .then((_) {
          debugPrint('SOCIAL_SAVE_LOCAL_SUCCESS day=$day userId=$userId');
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('SOCIAL_SAVE_LOCAL_ERROR: $error');
          throw error;
        });
  }

  Future<void> updateEntry({
    required String scopeId,
    required String userId,
    required Map<String, dynamic> existingEntry,
    required String day,
    required Map<String, dynamic> data,
    String? templateId,
  }) {
    debugPrint(
      'SOCIAL_SAVE_LOCAL_START day=$day userId=$userId existingId=${existingEntry['id']} data=$data',
    );
    return _templateLogsRepository
        .updateEntry(
          scopeId: scopeId,
          templateId: _resolveTemplateId(templateId),
          templateKey: templateKey,
          userId: userId,
          existingEntry: existingEntry,
          day: day,
          data: data,
        )
        .then((_) {
          debugPrint(
            'SOCIAL_SAVE_LOCAL_SUCCESS day=$day userId=$userId existingId=${existingEntry['id']}',
          );
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('SOCIAL_SAVE_LOCAL_ERROR: $error');
          throw error;
        });
  }

  Future<void> deleteEntry({
    required String scopeId,
    required String userId,
    required Map<String, dynamic> entry,
  }) {
    return _templateLogsRepository.deleteEntry(
      scopeId: scopeId,
      templateKey: templateKey,
      userId: userId,
      entry: entry,
    );
  }

  String _resolveTemplateId(String? templateId) {
    final resolved = (templateId ?? '').trim();
    return resolved.isEmpty ? builtInTemplateId : resolved;
  }
}

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return SocialRepository(
    ref.watch(templateLogsRepositoryProvider),
    TemplateLogsLocalDataSource(database),
  );
});
