import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/templates/built_in_log_templates.dart';
import 'package:mind_buddy/features/templates/data/template_local_first_support.dart';
import 'package:mind_buddy/features/templates/template_preview_store.dart';

class LocalTemplateDefinitionRecord {
  const LocalTemplateDefinitionRecord({
    required this.id,
    required this.templateKey,
    required this.name,
    required this.isBuiltIn,
    required this.fields,
    this.userId,
  });

  final String id;
  final String templateKey;
  final String name;
  final bool isBuiltIn;
  final String? userId;
  final List<Map<String, dynamic>> fields;
}

class LocalLogEntryRecord {
  const LocalLogEntryRecord({
    required this.id,
    required this.templateKey,
    required this.userId,
    required this.day,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.templateId,
    this.deletedAt,
    this.lastSyncedAt,
    this.syncError,
    this.version = 1,
  });

  final String id;
  final String? templateId;
  final String templateKey;
  final String userId;
  final String day;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final String? syncError;
  final int version;
}

class TemplateLogsLocalDataSource {
  TemplateLogsLocalDataSource(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  String _legacyPreviewImportKey(String userId, String templateKey) =>
      'template_logs_legacy_preview_imported:$userId:${templateKey.trim().toLowerCase()}';

  Future<void> ensureBuiltInDefinitions() async {
    final now = DateTime.now().toUtc();
    for (final definition in builtInLogTemplateDefinitions) {
      await _database.transaction(() async {
        await _database
            .into(_database.templateDefinitions)
            .insertOnConflictUpdate(
              TemplateDefinitionsCompanion.insert(
                id: definition.id,
                templateKey: definition.templateKey,
                name: definition.name,
                userId: const Value(null),
                isBuiltIn: const Value(true),
                syncStatus: const Value('synced'),
                updatedAt: now,
                lastSyncedAt: Value(now),
                syncError: const Value(null),
              ),
            );

        await (_database.delete(
          _database.templateFields,
        )..where((tbl) => tbl.templateId.equals(definition.id))).go();

        for (final field in definition.fields) {
          final fieldKey = (field['field_key'] ?? '').toString().trim();
          if (fieldKey.isEmpty) continue;
          await _database
              .into(_database.templateFields)
              .insert(
                TemplateFieldsCompanion.insert(
                  id: 'builtin:${definition.templateKey}:$fieldKey',
                  templateId: definition.id,
                  fieldKey: fieldKey,
                  label: (field['label'] ?? fieldKey).toString(),
                  fieldType: (field['field_type'] ?? 'text').toString(),
                  optionsJson: Value(field['options']?.toString()),
                  sortOrder: Value((field['sort_order'] as num?)?.toInt() ?? 0),
                  isHidden: Value(field['is_hidden'] == true),
                  updatedAt: now,
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      });
    }
  }

  Future<LocalTemplateDefinitionRecord?> loadTemplateDefinition({
    required String templateId,
    required String templateKey,
  }) async {
    final normalizedKey = templateKey.trim().toLowerCase();
    TemplateDefinition? template;
    if (templateId.isNotEmpty) {
      template = await (_database.select(
        _database.templateDefinitions,
      )..where((tbl) => tbl.id.equals(templateId))).getSingleOrNull();
    }
    final matchingTemplates =
        await (_database.select(_database.templateDefinitions)
              ..where((tbl) => tbl.templateKey.equals(normalizedKey))
              ..orderBy([
                (tbl) => OrderingTerm.desc(tbl.isBuiltIn),
                (tbl) => OrderingTerm.asc(tbl.name),
              ]))
            .get();
    template ??= matchingTemplates.isEmpty ? null : matchingTemplates.first;

    if (template == null) return null;
    final resolvedTemplate = template;
    final fields =
        await (_database.select(_database.templateFields)
              ..where((tbl) => tbl.templateId.equals(resolvedTemplate.id))
              ..where((tbl) => tbl.isHidden.equals(false))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
            .get();

    return LocalTemplateDefinitionRecord(
      id: resolvedTemplate.id,
      templateKey: resolvedTemplate.templateKey,
      name: resolvedTemplate.name,
      isBuiltIn: resolvedTemplate.isBuiltIn,
      userId: resolvedTemplate.userId,
      fields: fields
          .map(
            (field) => <String, dynamic>{
              'id': field.id,
              'template_id': field.templateId,
              'field_key': field.fieldKey,
              'label': field.label,
              'field_type': field.fieldType,
              'options': field.optionsJson,
              'sort_order': field.sortOrder,
              'is_hidden': field.isHidden,
            },
          )
          .toList(growable: false),
    );
  }

  Future<List<LocalTemplateDefinitionRecord>> listTemplateDefinitions({
    required String userId,
    bool includeBuiltIn = true,
  }) async {
    final query = _database.select(_database.templateDefinitions)
      ..where(
        (tbl) =>
            tbl.userId.equals(userId) |
            (includeBuiltIn
                ? tbl.isBuiltIn.equals(true)
                : const Constant(false)),
      )
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.isBuiltIn),
        (tbl) => OrderingTerm.asc(tbl.name),
      ]);

    final templates = await query.get();
    final records = <LocalTemplateDefinitionRecord>[];
    for (final template in templates) {
      final fields =
          await (_database.select(_database.templateFields)
                ..where((tbl) => tbl.templateId.equals(template.id))
                ..where((tbl) => tbl.isHidden.equals(false))
                ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
              .get();
      records.add(
        LocalTemplateDefinitionRecord(
          id: template.id,
          templateKey: template.templateKey,
          name: template.name,
          isBuiltIn: template.isBuiltIn,
          userId: template.userId,
          fields: fields
              .map(
                (field) => <String, dynamic>{
                  'id': field.id,
                  'template_id': field.templateId,
                  'field_key': field.fieldKey,
                  'label': field.label,
                  'field_type': field.fieldType,
                  'options': field.optionsJson,
                  'sort_order': field.sortOrder,
                  'is_hidden': field.isHidden,
                },
              )
              .toList(growable: false),
        ),
      );
    }
    return records;
  }

  Future<void> saveTemplateDefinition({
    required String id,
    required String templateKey,
    required String name,
    required String userId,
    required List<Map<String, dynamic>> fields,
    bool isBuiltIn = false,
    String syncStatus = 'pending_upsert',
  }) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.templateDefinitions)
          .insertOnConflictUpdate(
            TemplateDefinitionsCompanion.insert(
              id: id,
              templateKey: templateKey.trim().toLowerCase(),
              name: name,
              userId: Value(userId),
              isBuiltIn: Value(isBuiltIn),
              syncStatus: Value(syncStatus),
              updatedAt: now,
              lastSyncedAt: const Value(null),
              syncError: const Value(null),
            ),
          );

      await (_database.delete(
        _database.templateFields,
      )..where((tbl) => tbl.templateId.equals(id))).go();

      for (final entry in fields.asMap().entries) {
        final index = entry.key;
        final field = entry.value;
        final fieldKey = (field['field_key'] ?? '').toString().trim();
        if (fieldKey.isEmpty) continue;
        final fieldId = (field['id'] ?? '').toString().trim();
        await _database
            .into(_database.templateFields)
            .insert(
              TemplateFieldsCompanion.insert(
                id: fieldId.isEmpty ? 'custom:$id:$fieldKey' : fieldId,
                templateId: id,
                fieldKey: fieldKey,
                label: (field['label'] ?? fieldKey).toString().trim(),
                fieldType: (field['field_type'] ?? 'text').toString().trim(),
                optionsJson: Value(field['options']?.toString()),
                sortOrder: Value(
                  (field['sort_order'] as num?)?.toInt() ?? index,
                ),
                isHidden: Value(field['is_hidden'] == true),
                updatedAt: now,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> deleteTemplateDefinition({
    required String templateId,
    required String userId,
    required String templateKey,
  }) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.templateFields,
      )..where((tbl) => tbl.templateId.equals(templateId))).go();
      await (_database.delete(_database.templateLogEntries)..where(
            (tbl) =>
                tbl.templateId.equals(templateId) & tbl.userId.equals(userId),
          ))
          .go();
      await (_database.delete(_database.templateDefinitions)..where(
            (tbl) =>
                tbl.id.equals(templateId) &
                tbl.userId.equals(userId) &
                tbl.templateKey.equals(templateKey.trim().toLowerCase()),
          ))
          .go();
    });
  }

  Future<List<Map<String, dynamic>>> loadEntries({
    required String templateKey,
    required String userId,
  }) async {
    final normalizedTemplateKey = templateKey.trim().toLowerCase();
    final builtInDefinition = builtInLogTemplateByKey(normalizedTemplateKey);
    if (builtInDefinition != null) {
      await importLegacyPreviewEntriesIfNeeded(
        templateId: builtInDefinition.id,
        templateKey: normalizedTemplateKey,
        userId: userId,
        path: 'feature_repository',
      );
    }
    if (normalizedTemplateKey == 'mood') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('MOOD_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'MOOD_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'MOOD_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'cycle') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('CYCLE_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'CYCLE_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'CYCLE_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'expenses') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('EXPENSES_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'EXPENSES_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'EXPENSES_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'fast') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('FAST_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'FAST_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'FAST_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'income') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('INCOME_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'INCOME_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'INCOME_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'meditation') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('MEDITATION_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'MEDITATION_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'MEDITATION_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'movies') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('MOVIES_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'MOVIES_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'MOVIES_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'places') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('PLACES_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'PLACES_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'PLACES_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'restaurants') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('RESTAURANT_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'RESTAURANT_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'RESTAURANT_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'skin_care') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('SKINCARE_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'SKINCARE_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'SKINCARE_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'social') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('SOCIAL_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'SOCIAL_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'SOCIAL_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'study') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('STUDY_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'STUDY_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'STUDY_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'tasks') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('TASKS_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'TASKS_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'TASKS_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'tv_log') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('TVLOGS_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'TVLOGS_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'TVLOGS_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'wishlist') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('WISHLIST_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'WISHLIST_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'WISHLIST_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'workout') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('WORKOUT_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'WORKOUT_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'WORKOUT_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'bills') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('BILLS_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'BILLS_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'BILLS_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'books') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('BOOKS_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'BOOKS_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'BOOKS_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'sleep') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('SLEEP_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'SLEEP_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'SLEEP_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (normalizedTemplateKey == 'water') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('WATER_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'WATER_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
      debugPrint(
        'WATER_RELOAD_QUERY userId=$userId day=* templateKey=$normalizedTemplateKey templateId=*',
      );
    } else if (builtInLogTemplateByKey(normalizedTemplateKey) == null) {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('CUSTOM_TEMPLATE_DB_PATH_RELOAD=$dbPath');
      debugPrint(
        'CUSTOM_TEMPLATE_RELOAD_FROM_LOCAL_START userId=$userId templateKey=$normalizedTemplateKey',
      );
    }
    final rows =
        await (_database.select(_database.templateLogEntries)
              ..where(
                (tbl) =>
                    tbl.templateKey.equals(normalizedTemplateKey) &
                    tbl.userId.equals(userId) &
                    tbl.deletedAt.isNull(),
              )
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.day)]))
            .get();

    final entries = rows.map(_decodeEntryPayload).toList(growable: false);
    if (normalizedTemplateKey == 'mood') {
      if (rows.isEmpty) {
        debugPrint(
          'MOOD_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'MOOD_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('MOOD_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'MOOD_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'cycle') {
      if (rows.isEmpty) {
        debugPrint(
          'CYCLE_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'CYCLE_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('CYCLE_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'CYCLE_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'expenses') {
      if (rows.isEmpty) {
        debugPrint(
          'EXPENSES_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'EXPENSES_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('EXPENSES_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'EXPENSES_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'fast') {
      if (rows.isEmpty) {
        debugPrint(
          'FAST_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'FAST_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('FAST_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'FAST_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'income') {
      if (rows.isEmpty) {
        debugPrint(
          'INCOME_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'INCOME_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('INCOME_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'INCOME_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'meditation') {
      if (rows.isEmpty) {
        debugPrint(
          'MEDITATION_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'MEDITATION_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('MEDITATION_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'MEDITATION_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'movies') {
      if (rows.isEmpty) {
        debugPrint(
          'MOVIES_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'MOVIES_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('MOVIES_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'MOVIES_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'places') {
      if (rows.isEmpty) {
        debugPrint(
          'PLACES_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'PLACES_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('PLACES_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'PLACES_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'restaurants') {
      if (rows.isEmpty) {
        debugPrint(
          'RESTAURANT_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'RESTAURANT_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('RESTAURANT_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'RESTAURANT_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'skin_care') {
      if (rows.isEmpty) {
        debugPrint(
          'SKINCARE_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'SKINCARE_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('SKINCARE_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'SKINCARE_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'social') {
      if (rows.isEmpty) {
        debugPrint(
          'SOCIAL_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'SOCIAL_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('SOCIAL_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'SOCIAL_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'study') {
      if (rows.isEmpty) {
        debugPrint(
          'STUDY_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'STUDY_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('STUDY_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'STUDY_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'tasks') {
      if (rows.isEmpty) {
        debugPrint(
          'TASKS_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'TASKS_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('TASKS_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'TASKS_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'tv_log') {
      if (rows.isEmpty) {
        debugPrint(
          'TVLOGS_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'TVLOGS_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('TVLOGS_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'TVLOGS_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'wishlist') {
      if (rows.isEmpty) {
        debugPrint(
          'WISHLIST_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'WISHLIST_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('WISHLIST_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'WISHLIST_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'workout') {
      if (rows.isEmpty) {
        debugPrint(
          'WORKOUT_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'WORKOUT_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('WORKOUT_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'WORKOUT_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'bills') {
      if (rows.isEmpty) {
        debugPrint(
          'BILLS_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'BILLS_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('BILLS_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'BILLS_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'books') {
      if (rows.isEmpty) {
        debugPrint(
          'BOOKS_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'BOOKS_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('BOOKS_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'BOOKS_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'sleep') {
      if (rows.isEmpty) {
        debugPrint(
          'SLEEP_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'SLEEP_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('SLEEP_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'SLEEP_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (normalizedTemplateKey == 'water') {
      if (rows.isEmpty) {
        debugPrint(
          'WATER_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'WATER_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('WATER_RELOAD_FROM_LOCAL_RESULT count=${entries.length}');
      debugPrint(
        'WATER_LIST_READ_FROM_LOCAL count=${entries.length} source=drift userId=$userId',
      );
    } else if (builtInLogTemplateByKey(normalizedTemplateKey) == null) {
      if (rows.isEmpty) {
        debugPrint(
          'CUSTOM_TEMPLATE_DRIFT_ROW_NOT_FOUND userId=$userId templateKey=$normalizedTemplateKey',
        );
      } else {
        for (final row in rows) {
          debugPrint(
            'CUSTOM_TEMPLATE_DRIFT_ROW_FOUND id=${row.id} day=${row.day} templateId=${row.templateId} templateKey=${row.templateKey} userId=${row.userId} syncStatus=${row.syncStatus}',
          );
        }
      }
      debugPrint('CUSTOM_TEMPLATE_RELOAD_RESULT count=${entries.length}');
    }
    return entries;
  }

  Future<LocalLogEntryRecord?> loadEntryById(String id) async {
    final row = await (_database.select(
      _database.templateLogEntries,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _mapEntryRecord(row);
  }

  Future<void> importLegacyPreviewEntriesIfNeeded({
    required String templateId,
    required String templateKey,
    required String userId,
    required String path,
  }) async {
    final normalizedTemplateKey = templateKey.trim().toLowerCase();
    final existingCount = await _entryCount(
      templateKey: normalizedTemplateKey,
      userId: userId,
    );
    if (existingCount > 0) {
      debugPrint(
        'TEMPLATE_LOG_LEGACY_IMPORT_SKIPPED reason=drift_not_empty templateKey=$normalizedTemplateKey path=$path',
      );
      return;
    }
    if (await wasLegacyPreviewImported(
      userId: userId,
      templateKey: normalizedTemplateKey,
    )) {
      debugPrint(
        'TEMPLATE_LOG_LEGACY_IMPORT_SKIPPED reason=already_imported templateKey=$normalizedTemplateKey path=$path',
      );
      return;
    }

    final tableName = localFirstLogTableName(normalizedTemplateKey);
    debugPrint(
      'TEMPLATE_LOG_LEGACY_IMPORT_START templateKey=$normalizedTemplateKey path=$path',
    );
    final legacyEntries = await TemplatePreviewStore.loadEntries(
      userId: userId,
      tableName: tableName,
    );
    if (legacyEntries.isEmpty) {
      debugPrint(
        'TEMPLATE_LOG_LEGACY_IMPORT_SKIPPED reason=no_preview_entries templateKey=$normalizedTemplateKey path=$path',
      );
      await markLegacyPreviewImported(
        userId: userId,
        templateKey: normalizedTemplateKey,
      );
      return;
    }

    debugPrint('TEMPLATE_LOG_LEGACY_IMPORT_FOUND count=${legacyEntries.length}');
    var imported = 0;
    for (final rawEntry in legacyEntries) {
      final payload = _sanitizeLegacyPreviewEntry(rawEntry, userId: userId);
      final day = (payload['day'] ?? '').toString().trim();
      if (day.isEmpty) continue;
      final id = (payload['id'] ?? '').toString().trim().isNotEmpty
          ? (payload['id'] ?? '').toString().trim()
          : _uuid.v4();
      final existing = await loadEntryById(id);
      if (existing != null) continue;
      final createdAt = _parseLegacyPreviewTimestamp(
        rawEntry[TemplatePreviewStore.createdAtKey] ?? rawEntry['created_at'],
      );
      final updatedAt = _parseLegacyPreviewTimestamp(
        rawEntry['updated_at'] ?? rawEntry[TemplatePreviewStore.createdAtKey],
      );
      await saveEntry(
        id: id,
        templateId: templateId,
        templateKey: normalizedTemplateKey,
        userId: userId,
        day: day,
        payload: <String, dynamic>{...payload, 'id': id, 'user_id': userId},
        syncStatus: SyncStatus.synced,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastSyncedAt: updatedAt,
      );
      imported += 1;
    }
    await markLegacyPreviewImported(
      userId: userId,
      templateKey: normalizedTemplateKey,
    );
    debugPrint('TEMPLATE_LOG_LEGACY_IMPORT_SUCCESS imported=$imported');
  }

  Future<bool> wasLegacyPreviewImported({
    required String userId,
    required String templateKey,
  }) async {
    final key = _legacyPreviewImportKey(userId, templateKey);
    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value == '1';
  }

  Future<void> markLegacyPreviewImported({
    required String userId,
    required String templateKey,
  }) async {
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _legacyPreviewImportKey(userId, templateKey),
            value: const Value('1'),
            updatedAt: now,
          ),
        );
  }

  Future<int> _entryCount({
    required String templateKey,
    required String userId,
  }) async {
    final countExpr = _database.templateLogEntries.id.count();
    final row =
        await (_database.selectOnly(_database.templateLogEntries)
              ..addColumns([countExpr])
              ..where(
                _database.templateLogEntries.templateKey.equals(templateKey) &
                    _database.templateLogEntries.userId.equals(userId) &
                    _database.templateLogEntries.deletedAt.isNull(),
              ))
            .getSingle();
    return row.read(countExpr) ?? 0;
  }

  Map<String, dynamic> _sanitizeLegacyPreviewEntry(
    Map<String, dynamic> rawEntry, {
    required String userId,
  }) {
    final payload = Map<String, dynamic>.from(rawEntry);
    payload.remove(TemplatePreviewStore.createdAtKey);
    payload.remove(TemplatePreviewStore.expiresAtKey);
    payload.remove(TemplatePreviewStore.isPreviewKey);
    payload.remove('_preview_saved_at');
    payload.remove('_preview_table_name');
    payload['user_id'] = userId;
    return payload;
  }

  DateTime _parseLegacyPreviewTimestamp(Object? raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString());
    return (parsed ?? DateTime.now()).toUtc();
  }

  Future<Map<String, dynamic>?> findExistingDailyLog({
    required String templateKey,
    required String userId,
    required String day,
    String? excludeId,
  }) async {
    final rows =
        await (_database.select(_database.templateLogEntries)
              ..where(
                (tbl) =>
                    tbl.templateKey.equals(templateKey.trim().toLowerCase()) &
                    tbl.userId.equals(userId) &
                    tbl.day.equals(day) &
                    tbl.deletedAt.isNull(),
              )
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
            .get();

    for (final row in rows) {
      if (excludeId != null && row.id == excludeId) {
        continue;
      }
      return _decodeEntryPayload(row);
    }
    return null;
  }

  Future<void> saveEntry({
    required String id,
    required String? templateId,
    required String templateKey,
    required String userId,
    required String day,
    required Map<String, dynamic> payload,
    required SyncStatus syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? lastSyncedAt,
    String? syncError,
    int version = 1,
  }) async {
    final now = DateTime.now().toUtc();
    if (templateKey.trim().toLowerCase() == 'mood') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('MOOD_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'MOOD_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'MOOD_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'cycle') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('CYCLE_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'CYCLE_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'CYCLE_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'expenses') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('EXPENSES_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'EXPENSES_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'EXPENSES_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'fast') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('FAST_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'FAST_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'FAST_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'income') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('INCOME_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'INCOME_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'INCOME_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'meditation') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('MEDITATION_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'MEDITATION_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'MEDITATION_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'movies') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('MOVIES_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'MOVIES_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'MOVIES_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'places') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('PLACES_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'PLACES_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'PLACES_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'restaurants') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('RESTAURANT_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'RESTAURANT_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'RESTAURANT_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'skin_care') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('SKINCARE_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'SKINCARE_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'SKINCARE_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'social') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('SOCIAL_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'SOCIAL_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'SOCIAL_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'study') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('STUDY_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'STUDY_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'STUDY_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'tasks') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('TASKS_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'TASKS_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'TASKS_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'tv_log') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('TVLOGS_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'TVLOGS_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'TVLOGS_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'wishlist') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('WISHLIST_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'WISHLIST_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'WISHLIST_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'workout') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('WORKOUT_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'WORKOUT_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'WORKOUT_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'bills') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('BILLS_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'BILLS_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'BILLS_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'books') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('BOOKS_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'BOOKS_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'BOOKS_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'sleep') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('SLEEP_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'SLEEP_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'SLEEP_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'water') {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('WATER_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'WATER_SAVE_LOCAL_PERSIST_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'WATER_SAVE_LOCAL_START source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (builtInLogTemplateByKey(templateKey.trim().toLowerCase()) ==
        null) {
      final dbPath = await AppPaths.databaseFilePath();
      debugPrint('CUSTOM_TEMPLATE_DB_PATH_SAVE=$dbPath');
      debugPrint(
        'CUSTOM_TEMPLATE_SAVE_LOCAL_START id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
    }
    await _database
        .into(_database.templateLogEntries)
        .insertOnConflictUpdate(
          TemplateLogEntriesCompanion.insert(
            id: id,
            templateId: Value(templateId),
            templateKey: templateKey.trim().toLowerCase(),
            userId: userId,
            day: day,
            payloadJson: jsonEncode(payload),
            createdAt: createdAt ?? now,
            updatedAt: updatedAt ?? now,
            deletedAt: Value(deletedAt),
            version: Value(version),
            syncStatus: syncStatus.value,
            lastSyncedAt: Value(lastSyncedAt),
            syncError: Value(syncError),
          ),
        );
    if (templateKey.trim().toLowerCase() == 'mood') {
      debugPrint(
        'MOOD_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'MOOD_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'cycle') {
      debugPrint(
        'CYCLE_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'CYCLE_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'expenses') {
      debugPrint(
        'EXPENSES_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'EXPENSES_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'fast') {
      debugPrint(
        'FAST_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'FAST_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'income') {
      debugPrint(
        'INCOME_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'INCOME_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'meditation') {
      debugPrint(
        'MEDITATION_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'MEDITATION_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'movies') {
      debugPrint(
        'MOVIES_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'MOVIES_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'places') {
      debugPrint(
        'PLACES_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'PLACES_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'restaurants') {
      debugPrint(
        'RESTAURANT_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'RESTAURANT_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'skin_care') {
      debugPrint(
        'SKINCARE_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'SKINCARE_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'social') {
      debugPrint(
        'SOCIAL_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'SOCIAL_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'study') {
      debugPrint(
        'STUDY_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'STUDY_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'tasks') {
      debugPrint(
        'TASKS_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'TASKS_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'tv_log') {
      debugPrint(
        'TVLOGS_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'TVLOGS_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'wishlist') {
      debugPrint(
        'WISHLIST_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'WISHLIST_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'workout') {
      debugPrint(
        'WORKOUT_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'WORKOUT_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'bills') {
      debugPrint(
        'BILLS_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'BILLS_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'books') {
      debugPrint(
        'BOOKS_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'BOOKS_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'sleep') {
      debugPrint(
        'SLEEP_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'SLEEP_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (templateKey.trim().toLowerCase() == 'water') {
      debugPrint(
        'WATER_SAVE_LOCAL_PERSIST_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      debugPrint(
        'WATER_SAVE_LOCAL_SUCCESS source=drift id=$id day=$day templateId=$templateId',
      );
    } else if (builtInLogTemplateByKey(templateKey.trim().toLowerCase()) ==
        null) {
      debugPrint(
        'CUSTOM_TEMPLATE_SAVE_LOCAL_SUCCESS id=$id day=$day templateId=$templateId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
    }
  }

  Future<void> mergeRemoteEntries({
    required String templateKey,
    required String userId,
    required String? templateId,
    required List<Map<String, dynamic>> remoteEntries,
  }) async {
    final now = DateTime.now().toUtc();
    for (final entry in remoteEntries) {
      final id = (entry['id'] ?? '').toString();
      final day = (entry['day'] ?? '').toString();
      if (id.isEmpty || day.isEmpty) continue;

      final existing = await loadEntryById(id);
      if (existing != null &&
          existing.syncStatus != SyncStatus.synced &&
          existing.deletedAt == null) {
        continue;
      }

      await saveEntry(
        id: id,
        templateId: templateId,
        templateKey: templateKey,
        userId: userId,
        day: day,
        payload: Map<String, dynamic>.from(entry),
        syncStatus: SyncStatus.synced,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastSyncedAt: now,
        version: existing?.version ?? 1,
      );
    }
  }

  Future<void> markEntrySynced(String id) async {
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.templateLogEntries,
    )..where((tbl) => tbl.id.equals(id))).write(
      TemplateLogEntriesCompanion(
        syncStatus: const Value('synced'),
        lastSyncedAt: Value(now),
        syncError: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markEntrySyncFailed(String id, String error) async {
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.templateLogEntries,
    )..where((tbl) => tbl.id.equals(id))).write(
      TemplateLogEntriesCompanion(
        syncStatus: const Value('sync_failed'),
        syncError: Value(error),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> purgeEntry(String id) async {
    await (_database.delete(
      _database.templateLogEntries,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  LocalLogEntryRecord _mapEntryRecord(TemplateLogEntry row) {
    return LocalLogEntryRecord(
      id: row.id,
      templateId: row.templateId,
      templateKey: row.templateKey,
      userId: row.userId,
      day: row.day,
      payload: _decodeJson(row.payloadJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncStatus: SyncStatus.fromValue(row.syncStatus),
      lastSyncedAt: row.lastSyncedAt,
      syncError: row.syncError,
      version: row.version,
    );
  }

  Map<String, dynamic> _decodeEntryPayload(TemplateLogEntry row) {
    return _decodeJson(row.payloadJson);
  }

  Map<String, dynamic> _decodeJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }
}
