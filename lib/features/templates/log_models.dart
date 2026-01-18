import 'package:flutter/foundation.dart';

@immutable
class LogTemplate {
  final String id;
  final String name;

  const LogTemplate({required this.id, required this.name});

  factory LogTemplate.fromJson(Map<String, dynamic> json) {
    return LogTemplate(id: json['id'] as String, name: json['name'] as String);
  }
}

@immutable
class LogTemplateField {
  final String id;
  final String templateId;
  final String fieldKey; // e.g. title, rating
  final String label; // e.g. Movie, Rating
  final String fieldType; // text | number | rating
  final int sortOrder;

  const LogTemplateField({
    required this.id,
    required this.templateId,
    required this.fieldKey,
    required this.label,
    required this.fieldType,
    required this.sortOrder,
  });

  factory LogTemplateField.fromJson(Map<String, dynamic> json) {
    return LogTemplateField(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      fieldKey: json['field_key'] as String,
      label: json['label'] as String,
      fieldType: json['field_type'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class LogEntry {
  final String id;
  final String templateId;
  final DateTime day; // stored as date in DB
  final Map<String, dynamic> data;

  const LogEntry({
    required this.id,
    required this.templateId,
    required this.day,
    required this.data,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      day: DateTime.parse(json['day'] as String),
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
