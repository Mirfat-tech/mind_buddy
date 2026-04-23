import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/features/templates/data/template_local_first_support.dart';

class RemoteTemplateDefinitionRecord {
  const RemoteTemplateDefinitionRecord({
    required this.id,
    required this.templateKey,
    required this.name,
    required this.fields,
    this.userId,
  });

  final String id;
  final String templateKey;
  final String name;
  final String? userId;
  final List<Map<String, dynamic>> fields;
}

class TemplateLogsRemoteDataSource {
  TemplateLogsRemoteDataSource(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> fetchEntries({
    required String templateKey,
    required String userId,
  }) async {
    final rows = await _supabase
        .from(localFirstLogTableName(templateKey))
        .select()
        .eq('user_id', userId)
        .order('day', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> upsertEntry({
    required String templateKey,
    required Map<String, dynamic> payload,
  }) async {
    await _supabase
        .from(localFirstLogTableName(templateKey))
        .upsert(payload, onConflict: 'id');
  }

  Future<void> deleteEntry({
    required String templateKey,
    required String id,
  }) async {
    await _supabase
        .from(localFirstLogTableName(templateKey))
        .delete()
        .eq('id', id);
  }

  Future<RemoteTemplateDefinitionRecord?> fetchTemplateDefinition({
    required String templateId,
    required String templateKey,
    required String userId,
  }) async {
    final rows = await _supabase
        .from('log_templates_v2')
        .select('id, name, template_key, user_id')
        .or('user_id.eq.$userId,user_id.is.null')
        .eq('template_key', templateKey.trim().toLowerCase())
        .limit(20);

    final templates = List<Map<String, dynamic>>.from(rows);
    Map<String, dynamic>? selected;
    if (templateId.isNotEmpty) {
      for (final row in templates) {
        if ((row['id'] ?? '').toString() == templateId) {
          selected = row;
          break;
        }
      }
    }
    selected ??= templates.isEmpty ? null : templates.first;
    if (selected == null) return null;

    final resolvedTemplateId = (selected['id'] ?? '').toString();
    final fieldRows = await _supabase
        .from('log_template_fields_v2')
        .select(
          'id, field_key, label, field_type, options, sort_order, is_hidden',
        )
        .eq('template_id', resolvedTemplateId)
        .eq('is_hidden', false)
        .order('sort_order');

    return RemoteTemplateDefinitionRecord(
      id: resolvedTemplateId,
      templateKey: (selected['template_key'] ?? templateKey).toString(),
      name: (selected['name'] ?? templateKey).toString(),
      userId: (selected['user_id'] as String?),
      fields: List<Map<String, dynamic>>.from(fieldRows),
    );
  }
}
