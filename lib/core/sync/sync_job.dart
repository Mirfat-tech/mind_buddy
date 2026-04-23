import 'dart:convert';

import 'sync_status.dart';

class SyncJobRecord {
  const SyncJobRecord({
    required this.id,
    required this.scopeId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.state,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.payload,
    this.availableAt,
    this.lastError,
  });

  final String id;
  final String scopeId;
  final String entityType;
  final String entityId;
  final SyncJobAction action;
  final SyncJobState state;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? payload;
  final DateTime? availableAt;
  final String? lastError;

  String? get payloadJson => payload == null ? null : jsonEncode(payload);
}
