import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'sync_job.dart';
import 'sync_status.dart';

class SyncQueueStore {
  SyncQueueStore(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<void> enqueueUpsertJob({
    required String scopeId,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await (_database.select(_database.syncJobs)
          ..where((tbl) {
            return tbl.scopeId.equals(scopeId) &
                tbl.entityType.equals(entityType) &
                tbl.entityId.equals(entityId) &
                tbl.action.equals(SyncJobAction.upsert.value) &
                tbl.state.isNotIn(
                  const <String>[
                    'completed',
                  ],
                );
          }))
        .getSingleOrNull();

    if (existing != null) {
      await (_database.update(_database.syncJobs)
            ..where((tbl) => tbl.id.equals(existing.id)))
          .write(
        SyncJobsCompanion(
          payloadJson: Value(payload == null ? null : jsonEncode(payload)),
          state: Value(SyncJobState.pending.value),
          availableAt: Value(now),
          updatedAt: Value(now),
          lastError: const Value(null),
        ),
      );
      return;
    }

    await _database.into(_database.syncJobs).insert(
          SyncJobsCompanion.insert(
            id: _uuid.v4(),
            scopeId: scopeId,
            entityType: entityType,
            entityId: entityId,
            action: SyncJobAction.upsert.value,
            state: SyncJobState.pending.value,
            payloadJson: Value(payload == null ? null : jsonEncode(payload)),
            availableAt: Value(now),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<List<SyncJobRecord>> pendingJobsForEntity(String entityType) async {
    final now = DateTime.now().toUtc();
    final rows = await (_database.select(_database.syncJobs)
          ..where(
            (tbl) =>
                tbl.entityType.equals(entityType) &
                tbl.state.isIn(
                  const <String>[
                    'pending',
                    'failed',
                  ],
                ) &
                (tbl.availableAt.isNull() | tbl.availableAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .get();

    return rows.map(_mapRecord).toList(growable: false);
  }

  Future<void> markRunning(String id) async {
    final now = DateTime.now().toUtc();
    await (_database.update(_database.syncJobs)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      SyncJobsCompanion(
        state: Value(SyncJobState.running.value),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markCompleted(String id) async {
    final now = DateTime.now().toUtc();
    await (_database.update(_database.syncJobs)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      SyncJobsCompanion(
        state: Value(SyncJobState.completed.value),
        updatedAt: Value(now),
        lastError: const Value(null),
      ),
    );
  }

  Future<void> markFailed(
    String id, {
    required String error,
    required int previousAttempts,
  }) async {
    final now = DateTime.now().toUtc();
    final nextAttempts = previousAttempts + 1;
    final retryDelayMinutes = nextAttempts.clamp(1, 5) * 2;
    await (_database.update(_database.syncJobs)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      SyncJobsCompanion(
        state: Value(SyncJobState.failed.value),
        attemptCount: Value(nextAttempts),
        lastError: Value(error),
        availableAt: Value(now.add(Duration(minutes: retryDelayMinutes))),
        updatedAt: Value(now),
      ),
    );
  }

  SyncJobRecord _mapRecord(SyncJob row) {
    Map<String, dynamic>? payload;
    final rawJson = row.payloadJson;
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return SyncJobRecord(
      id: row.id,
      scopeId: row.scopeId,
      entityType: row.entityType,
      entityId: row.entityId,
      action: SyncJobAction.fromValue(row.action),
      state: SyncJobState.fromValue(row.state),
      attemptCount: row.attemptCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      payload: payload,
      availableAt: row.availableAt,
      lastError: row.lastError,
    );
  }
}
