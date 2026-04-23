import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';

class BrainFogThoughtRecord {
  const BrainFogThoughtRecord({
    required this.id,
    required this.text,
    required this.dx,
    required this.dy,
  });

  final String id;
  final String text;
  final double dx;
  final double dy;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'dx': dx,
    'dy': dy,
  };

  static BrainFogThoughtRecord fromJson(Map<String, dynamic> json) {
    return BrainFogThoughtRecord(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      dx: _toDouble(json['dx']),
      dy: _toDouble(json['dy']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}

class BrainFogLocalStateRecord {
  const BrainFogLocalStateRecord({
    required this.userId,
    required this.thoughts,
    required this.isDeleteMode,
    required this.figureOutMode,
    required this.figureStep,
    required this.controllableIds,
    required this.focusOrder,
    required this.updatedAt,
  });

  final String userId;
  final List<BrainFogThoughtRecord> thoughts;
  final bool isDeleteMode;
  final bool figureOutMode;
  final int figureStep;
  final Set<String> controllableIds;
  final List<String> focusOrder;
  final DateTime updatedAt;
}

class BrainFogLocalDataSource {
  BrainFogLocalDataSource(this._database);

  final AppDatabase _database;

  String _scopeKey(String userId) => 'brain_fog_state:$userId';

  Future<BrainFogLocalStateRecord?> load({required String userId}) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('BRAINFOG_DB_PATH_RELOAD=$dbPath');
    debugPrint('BRAINFOG_LOAD_FROM_LOCAL_START userId=$userId');

    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_scopeKey(userId)))).getSingleOrNull();

    if (row == null || row.value == null || row.value!.isEmpty) {
      debugPrint('BRAINFOG_DRIFT_ROW_NOT_FOUND userId=$userId');
      debugPrint(
        'BRAINFOG_LOAD_FROM_LOCAL_RESULT userId=$userId found=false thoughtCount=0 figureStep=0 figureOutMode=false',
      );
      return null;
    }

    final decoded = jsonDecode(row.value!);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final rawThoughts = payload['thoughts'];
    final thoughts = rawThoughts is List
        ? rawThoughts
              .whereType<Map>()
              .map(
                (item) => BrainFogThoughtRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : const <BrainFogThoughtRecord>[];
    final controllableIds =
        (payload['controllable_ids'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toSet() ??
        const <String>{};
    final focusOrder =
        (payload['focus_order'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final record = BrainFogLocalStateRecord(
      userId: (payload['user_id'] ?? userId).toString(),
      thoughts: thoughts,
      isDeleteMode: payload['is_delete_mode'] == true,
      figureOutMode: payload['figure_out_mode'] == true,
      figureStep: (payload['figure_step'] as num?)?.toInt() ?? 0,
      controllableIds: controllableIds,
      focusOrder: focusOrder,
      updatedAt:
          DateTime.tryParse(
            (payload['updated_at'] ?? '').toString(),
          )?.toUtc() ??
          row.updatedAt.toUtc(),
    );
    debugPrint(
      'BRAINFOG_DRIFT_ROW_FOUND userId=${record.userId} thoughtCount=${record.thoughts.length} figureStep=${record.figureStep} figureOutMode=${record.figureOutMode}',
    );
    debugPrint(
      'BRAINFOG_LOAD_FROM_LOCAL_RESULT userId=${record.userId} found=true thoughtCount=${record.thoughts.length} figureStep=${record.figureStep} figureOutMode=${record.figureOutMode}',
    );
    return record;
  }

  Future<void> save({
    required String userId,
    required List<BrainFogThoughtRecord> thoughts,
    required bool isDeleteMode,
    required bool figureOutMode,
    required int figureStep,
    required Set<String> controllableIds,
    required List<String> focusOrder,
    required String reason,
  }) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('BRAINFOG_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'BRAINFOG_SAVE_LOCAL_START userId=$userId reason=$reason thoughtCount=${thoughts.length} figureStep=$figureStep figureOutMode=$figureOutMode',
    );

    final now = DateTime.now().toUtc();
    final payload = jsonEncode(<String, dynamic>{
      'user_id': userId,
      'updated_at': now.toIso8601String(),
      'thoughts': thoughts.map((item) => item.toJson()).toList(growable: false),
      'is_delete_mode': isDeleteMode,
      'figure_out_mode': figureOutMode,
      'figure_step': figureStep,
      'controllable_ids': controllableIds.toList(growable: false),
      'focus_order': focusOrder,
    });

    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _scopeKey(userId),
            value: Value(payload),
            updatedAt: now,
          ),
        );

    debugPrint(
      'BRAINFOG_SAVE_LOCAL_SUCCESS userId=$userId reason=$reason thoughtCount=${thoughts.length} figureStep=$figureStep figureOutMode=$figureOutMode',
    );
  }
}
