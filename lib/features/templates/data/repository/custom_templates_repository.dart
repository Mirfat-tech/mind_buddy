import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:mind_buddy/core/database/database_providers.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

class CustomTemplateDraftField {
  const CustomTemplateDraftField({
    required this.label,
    required this.fieldKey,
    required this.fieldType,
    this.id,
    this.options,
  });

  final String? id;
  final String label;
  final String fieldKey;
  final String fieldType;
  final String? options;

  Map<String, dynamic> toMap(int sortOrder) => <String, dynamic>{
    'id': id,
    'field_key': fieldKey,
    'label': label,
    'field_type': fieldType,
    'options': options,
    'sort_order': sortOrder,
    'is_hidden': false,
  };
}

class CustomTemplateRecord {
  const CustomTemplateRecord({
    required this.id,
    required this.name,
    required this.templateKey,
    required this.userId,
    required this.isBuiltIn,
    required this.fields,
  });

  final String id;
  final String name;
  final String templateKey;
  final String? userId;
  final bool isBuiltIn;
  final List<Map<String, dynamic>> fields;
}

class CustomTemplatesRepository {
  CustomTemplatesRepository(this._localDataSource);

  static const _uuid = Uuid();
  final TemplateLogsLocalDataSource _localDataSource;

  Future<List<CustomTemplateRecord>> loadTemplates({
    required String userId,
  }) async {
    await _localDataSource.ensureBuiltInDefinitions();
    debugPrint('CUSTOM_TEMPLATE_RELOAD_FROM_LOCAL_START userId=$userId');
    final templates = await _localDataSource.listTemplateDefinitions(
      userId: userId,
      includeBuiltIn: true,
    );
    final results = templates
        .map(
          (template) => CustomTemplateRecord(
            id: template.id,
            name: template.name,
            templateKey: template.templateKey,
            userId: template.userId,
            isBuiltIn: template.isBuiltIn,
            fields: template.fields,
          ),
        )
        .toList(growable: false);
    debugPrint('CUSTOM_TEMPLATE_RELOAD_RESULT count=${results.length}');
    return results;
  }

  Future<CustomTemplateRecord?> loadTemplateById({
    required String templateId,
    required String userId,
  }) async {
    await _localDataSource.ensureBuiltInDefinitions();
    final record = await _localDataSource.loadTemplateDefinition(
      templateId: templateId,
      templateKey: '',
    );
    if (record == null) {
      debugPrint(
        'CUSTOM_TEMPLATE_DRIFT_ROW_NOT_FOUND id=$templateId userId=$userId',
      );
      return null;
    }
    debugPrint(
      'CUSTOM_TEMPLATE_DRIFT_ROW_FOUND id=${record.id} templateKey=${record.templateKey} userId=${record.userId ?? 'null'}',
    );
    return CustomTemplateRecord(
      id: record.id,
      name: record.name,
      templateKey: record.templateKey,
      userId: record.userId,
      isBuiltIn: record.isBuiltIn,
      fields: record.fields,
    );
  }

  Future<CustomTemplateRecord?> loadTemplateByKey({
    required String templateKey,
    required String userId,
  }) async {
    await _localDataSource.ensureBuiltInDefinitions();
    final record = await _localDataSource.loadTemplateDefinition(
      templateId: '',
      templateKey: templateKey,
    );
    if (record == null) {
      debugPrint(
        'CUSTOM_TEMPLATE_DRIFT_ROW_NOT_FOUND templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
      );
      return null;
    }
    if (record.isBuiltIn || record.userId == userId) {
      debugPrint(
        'CUSTOM_TEMPLATE_DRIFT_ROW_FOUND id=${record.id} templateKey=${record.templateKey} userId=${record.userId ?? 'null'}',
      );
      return CustomTemplateRecord(
        id: record.id,
        name: record.name,
        templateKey: record.templateKey,
        userId: record.userId,
        isBuiltIn: record.isBuiltIn,
        fields: record.fields,
      );
    }
    return null;
  }

  Future<String> uniqueTemplateKey({
    required String userId,
    required String baseKey,
    String? excludeTemplateId,
  }) async {
    final normalizedBase = baseKey.trim().toLowerCase();
    final templates = await _localDataSource.listTemplateDefinitions(
      userId: userId,
      includeBuiltIn: true,
    );
    final existing = templates
        .where((template) => template.id != excludeTemplateId)
        .map((template) => template.templateKey)
        .toSet();

    var key = normalizedBase;
    var i = 2;
    while (existing.contains(key)) {
      key = '${normalizedBase}_$i';
      i++;
    }
    return key;
  }

  Future<String> saveTemplate({
    required String userId,
    required String name,
    required String templateKey,
    required List<CustomTemplateDraftField> fields,
    String? templateId,
  }) async {
    final resolvedId = (templateId == null || templateId.trim().isEmpty)
        ? 'custom:${_uuid.v4()}'
        : templateId.trim();
    debugPrint(
      'CUSTOM_TEMPLATE_SAVE_UI_TRIGGERED templateId=$resolvedId templateKey=${templateKey.trim().toLowerCase()} userId=$userId',
    );
    debugPrint('CUSTOM_TEMPLATE_SAVE_LOCAL_START templateId=$resolvedId');
    final mappedFields = fields
        .asMap()
        .entries
        .map((entry) => entry.value.toMap(entry.key))
        .toList(growable: false);

    await _localDataSource.saveTemplateDefinition(
      id: resolvedId,
      templateKey: templateKey,
      name: name,
      userId: userId,
      fields: mappedFields,
    );
    debugPrint('CUSTOM_TEMPLATE_SAVE_LOCAL_SUCCESS templateId=$resolvedId');
    debugPrint(
      'CUSTOM_TEMPLATE_SAVE_QUEUE_SYNC templateId=$resolvedId action=definition_deferred',
    );
    debugPrint(
      'CUSTOM_TEMPLATE_SAVE_REMOTE_SKIPPED_OFFLINE templateId=$resolvedId reason=definition_sync_not_required',
    );
    return resolvedId;
  }

  Future<void> deleteTemplate({
    required String templateId,
    required String templateKey,
    required String userId,
  }) async {
    debugPrint(
      'CUSTOM_TEMPLATE_SAVE_LOCAL_START delete templateId=$templateId',
    );
    await _localDataSource.deleteTemplateDefinition(
      templateId: templateId,
      userId: userId,
      templateKey: templateKey,
    );
    debugPrint(
      'CUSTOM_TEMPLATE_SAVE_LOCAL_SUCCESS delete templateId=$templateId',
    );
    debugPrint(
      'CUSTOM_TEMPLATE_SAVE_QUEUE_SYNC templateId=$templateId action=delete_deferred',
    );
    debugPrint(
      'CUSTOM_TEMPLATE_SAVE_REMOTE_SKIPPED_OFFLINE templateId=$templateId reason=definition_sync_not_required',
    );
  }
}

final customTemplatesRepositoryProvider = Provider<CustomTemplatesRepository>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return CustomTemplatesRepository(TemplateLogsLocalDataSource(database));
});
