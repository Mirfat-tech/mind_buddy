import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/database/app_database.dart';

class LocalNotificationHabitRecord {
  const LocalNotificationHabitRecord({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.categoryName,
  });

  final String id;
  final String name;
  final int sortOrder;
  final String? categoryName;
}

class LocalNotificationReminderRecord {
  const LocalNotificationReminderRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.day,
    required this.time,
    required this.repeat,
    required this.createdAt,
    required this.updatedAt,
    this.repeatDays,
    this.endDay,
    this.isCompleted = false,
    this.isDone = false,
    this.type,
    this.datetime,
    this.syncStatus,
    this.syncError,
  });

  final String id;
  final String userId;
  final String title;
  final String day;
  final String time;
  final String repeat;
  final String? repeatDays;
  final String? endDay;
  final bool isCompleted;
  final bool isDone;
  final String? type;
  final String? datetime;
  final String? syncStatus;
  final String? syncError;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'title': title,
    'day': day,
    'time': time,
    'repeat': repeat,
    'repeat_days': repeatDays,
    'end_day': endDay,
    'is_completed': isCompleted,
    'is_done': isDone,
    'type': type,
    'datetime': datetime,
    'sync_status': syncStatus,
    'sync_error': syncError,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class LocalNotificationReminderSkipRecord {
  const LocalNotificationReminderSkipRecord({
    required this.reminderId,
    required this.day,
    required this.createdAt,
  });

  final String reminderId;
  final String day;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'reminder_id': reminderId,
    'day': day,
    'created_at': createdAt.toIso8601String(),
  };
}

class LocalNotificationReminderStore {
  const LocalNotificationReminderStore({
    required this.reminders,
    required this.skips,
    required this.done,
  });

  final List<LocalNotificationReminderRecord> reminders;
  final List<LocalNotificationReminderSkipRecord> skips;
  final List<LocalNotificationReminderSkipRecord> done;
}

class NotificationsLocalDataSource {
  NotificationsLocalDataSource(this._database);

  final AppDatabase _database;

  String _habitsKey(String userId) => 'notifications:habits:$userId';
  String _calendarSnapshotKey(String userId) =>
      'notifications:calendar_snapshot:$userId';
  String _calendarRemindersKey(String userId) =>
      'notifications:calendar_reminders:$userId';
  String _calendarSkipsKey(String userId) =>
      'notifications:calendar_skips:$userId';
  String _calendarDoneKey(String userId) => 'notifications:calendar_done:$userId';
  String _calendarRowsImportedKey(String userId) =>
      'notifications:calendar_rows_imported:$userId';

  Future<void> saveHabitSnapshot({
    required String userId,
    required List<Map<String, dynamic>> habits,
  }) async {
    await _saveJson(key: _habitsKey(userId), value: jsonEncode(habits));
  }

  Future<List<LocalNotificationHabitRecord>> loadHabitSnapshot({
    required String userId,
  }) async {
    final raw = await _loadJson(_habitsKey(userId));
    if (raw == null || raw.isEmpty) {
      return const <LocalNotificationHabitRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <LocalNotificationHabitRecord>[];
    return decoded
        .whereType<Map>()
        .map((rawHabit) {
          final habit = Map<String, dynamic>.from(rawHabit);
          return LocalNotificationHabitRecord(
            id: (habit['id'] ?? '').toString().trim(),
            name: (habit['name'] ?? '').toString().trim(),
            sortOrder: switch (habit['sort_order']) {
              int value => value,
              double value => value.round(),
              String value => int.tryParse(value) ?? 999,
              _ => 999,
            },
            categoryName: (habit['category_name'] ?? '').toString().trim(),
          );
        })
        .where((habit) => habit.id.isNotEmpty && habit.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> ensureReminderRowsImported({
    required String userId,
  }) async {
    final importedFlag = await _loadJson(_calendarRowsImportedKey(userId));
    if (importedFlag == '1') return;

    final reminderCount = await _countReminderRows(userId: userId);
    if (reminderCount > 0) {
      await _saveJson(key: _calendarRowsImportedKey(userId), value: '1');
      return;
    }

    final legacy = await _loadLegacyCalendarReminderStore(userId);
    final totalLegacyCount =
        legacy.reminders.length + legacy.skips.length + legacy.done.length;
    if (totalLegacyCount == 0) {
      await _saveJson(key: _calendarRowsImportedKey(userId), value: '1');
      debugPrint(
        'REMINDER_LEGACY_IMPORT userId=$userId reminders=0 skips=0 done=0 imported=false',
      );
      return;
    }

    await _database.transaction(() async {
      for (final row in legacy.reminders) {
        await _database.into(_database.calendarReminders).insertOnConflictUpdate(
          CalendarRemindersCompanion.insert(
            id: row.id,
            userId: row.userId,
            title: row.title,
            day: row.day,
            time: row.time,
            repeat: Value(row.repeat),
            repeatDays: Value(row.repeatDays),
            endDay: Value(row.endDay),
            isCompleted: Value(row.isCompleted),
            isDone: Value(row.isDone),
            type: Value(row.type),
            datetime: Value(row.datetime),
            syncStatus: Value(row.syncStatus),
            syncError: Value(row.syncError),
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        );
      }
      for (final row in legacy.skips) {
        await _database
            .into(_database.calendarReminderSkips)
            .insertOnConflictUpdate(
              CalendarReminderSkipsCompanion.insert(
                reminderId: row.reminderId,
                day: row.day,
                createdAt: row.createdAt,
              ),
            );
      }
      for (final row in legacy.done) {
        await _database.into(_database.calendarReminderDone).insertOnConflictUpdate(
          CalendarReminderDoneCompanion.insert(
            reminderId: row.reminderId,
            day: row.day,
            createdAt: row.createdAt,
          ),
        );
      }
      await _saveJson(key: _calendarRowsImportedKey(userId), value: '1');
    });

    debugPrint(
      'REMINDER_LEGACY_IMPORT userId=$userId reminders=${legacy.reminders.length} skips=${legacy.skips.length} done=${legacy.done.length} imported=true',
    );
  }

  Future<LocalNotificationReminderStore> loadReminderStore({
    required String userId,
  }) async {
    await ensureReminderRowsImported(userId: userId);
    final reminders =
        await (_database.select(_database.calendarReminders)
              ..where((tbl) => tbl.userId.equals(userId))
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.day),
                (tbl) => OrderingTerm.asc(tbl.updatedAt),
              ]))
            .get();
    final skips = await (_database.select(
      _database.calendarReminderSkips,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.day)])).get();
    final done = await (_database.select(
      _database.calendarReminderDone,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.day)])).get();
    return LocalNotificationReminderStore(
      reminders: reminders.map(_mapReminderRow).toList(growable: false),
      skips: skips.map(_mapSkipRow).toList(growable: false),
      done: done.map(_mapDoneRow).toList(growable: false),
    );
  }

  Future<List<LocalNotificationReminderRecord>> loadReminderRows({
    required String userId,
  }) async {
    final store = await loadReminderStore(userId: userId);
    return store.reminders;
  }

  Future<LocalNotificationReminderRecord?> loadReminderById({
    required String id,
  }) async {
    final row =
        await (_database.select(
          _database.calendarReminders,
        )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapReminderRow(row);
  }

  Future<void> upsertReminderRow({
    required Map<String, dynamic> payload,
  }) async {
    final id = (payload['id'] ?? '').toString().trim();
    final day = (payload['day'] ?? '').toString().trim();
    if (id.isEmpty || day.isEmpty) {
      throw ArgumentError('Reminder payload requires non-empty id and day.');
    }
    final now = DateTime.now().toUtc();
    final existing = await (_database.select(
      _database.calendarReminders,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    debugPrint('REMINDER_LOCAL_ROW_SAVE_START id=$id day=$day');
    await _database.into(_database.calendarReminders).insertOnConflictUpdate(
      CalendarRemindersCompanion.insert(
        id: id,
        userId: (payload['user_id'] ?? '').toString(),
        title: (payload['title'] ?? 'Reminder').toString(),
        day: day,
        time: (payload['time'] ?? '').toString(),
        repeat: Value((payload['repeat'] ?? 'never').toString()),
        repeatDays: Value(_nullableString(payload['repeat_days'])),
        endDay: Value(_nullableString(payload['end_day'])),
        isCompleted: Value(payload['is_completed'] == true),
        isDone: Value(payload['is_done'] == true),
        type: Value(_nullableString(payload['type'])),
        datetime: Value(_nullableString(payload['datetime'])),
        syncStatus: Value(_nullableString(payload['sync_status'])),
        syncError: Value(_nullableString(payload['sync_error'])),
        createdAt: existing?.createdAt ?? _parseDateTime(payload['created_at']) ?? now,
        updatedAt: now,
      ),
    );
    debugPrint('REMINDER_LOCAL_ROW_SAVE_SUCCESS id=$id');
    final readBack = await loadReminderById(id: id);
    debugPrint(
      'REMINDER_LOCAL_ROW_READBACK_FOUND id=$id present=${readBack != null}',
    );
  }

  Future<void> deleteReminderRow({
    required String id,
  }) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.calendarReminderSkips,
      )..where((tbl) => tbl.reminderId.equals(id))).go();
      await (_database.delete(
        _database.calendarReminderDone,
      )..where((tbl) => tbl.reminderId.equals(id))).go();
      await (_database.delete(
        _database.calendarReminders,
      )..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  Future<void> upsertReminderSkip({
    required String reminderId,
    required String day,
  }) async {
    await _database.into(_database.calendarReminderSkips).insertOnConflictUpdate(
      CalendarReminderSkipsCompanion.insert(
        reminderId: reminderId,
        day: day,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> removeReminderSkip({
    required String reminderId,
    required String day,
  }) async {
    await (_database.delete(
      _database.calendarReminderSkips,
    )..where(
      (tbl) => tbl.reminderId.equals(reminderId) & tbl.day.equals(day),
    )).go();
  }

  Future<void> upsertReminderDone({
    required String reminderId,
    required String day,
  }) async {
    await _database.into(_database.calendarReminderDone).insertOnConflictUpdate(
      CalendarReminderDoneCompanion.insert(
        reminderId: reminderId,
        day: day,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> removeReminderDone({
    required String reminderId,
    required String day,
  }) async {
    await (_database.delete(
      _database.calendarReminderDone,
    )..where(
      (tbl) => tbl.reminderId.equals(reminderId) & tbl.day.equals(day),
    )).go();
  }

  Future<int> _countReminderRows({
    required String userId,
  }) async {
    final countExp = _database.calendarReminders.id.count();
    final query = _database.selectOnly(_database.calendarReminders)
      ..addColumns([countExp])
      ..where(_database.calendarReminders.userId.equals(userId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<void> _saveJson({required String key, required String value}) async {
    await _database.into(_database.syncMetadataEntries).insertOnConflictUpdate(
      SyncMetadataEntriesCompanion.insert(
        key: key,
        value: Value(value),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<String?> _loadJson(String key) async {
    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<LocalNotificationReminderStore> _loadLegacyCalendarReminderStore(
    String userId,
  ) async {
    final combinedRaw = await _loadJson(_calendarSnapshotKey(userId));
    if (combinedRaw != null && combinedRaw.isNotEmpty) {
      return _decodeCombinedSnapshot(userId, combinedRaw);
    }
    final remindersRaw = await _loadJson(_calendarRemindersKey(userId));
    final skipsRaw = await _loadJson(_calendarSkipsKey(userId));
    final doneRaw = await _loadJson(_calendarDoneKey(userId));
    return LocalNotificationReminderStore(
      reminders: _decodeReminderRows(userId, remindersRaw),
      skips: _decodeSkipRows(skipsRaw),
      done: _decodeSkipRows(doneRaw),
    );
  }

  LocalNotificationReminderStore _decodeCombinedSnapshot(
    String userId,
    String raw,
  ) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const LocalNotificationReminderStore(
        reminders: <LocalNotificationReminderRecord>[],
        skips: <LocalNotificationReminderSkipRecord>[],
        done: <LocalNotificationReminderSkipRecord>[],
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    return LocalNotificationReminderStore(
      reminders: _decodeReminderRows(
        userId,
        jsonEncode(map['reminders'] ?? const []),
      ),
      skips: _decodeSkipRows(jsonEncode(map['skips'] ?? const [])),
      done: _decodeSkipRows(jsonEncode(map['done'] ?? const [])),
    );
  }

  List<LocalNotificationReminderRecord> _decodeReminderRows(
    String userId,
    String? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return const <LocalNotificationReminderRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <LocalNotificationReminderRecord>[];
    return decoded
        .whereType<Map>()
        .map((item) {
          final row = Map<String, dynamic>.from(item);
          return LocalNotificationReminderRecord(
            id: (row['id'] ?? '').toString().trim(),
            userId: (row['user_id'] ?? userId).toString().trim(),
            title: (row['title'] ?? 'Reminder').toString().trim(),
            day: (row['day'] ?? '').toString().trim(),
            time: (row['time'] ?? '').toString().trim(),
            repeat: (row['repeat'] ?? 'never').toString().trim(),
            repeatDays: _nullableString(row['repeat_days']),
            endDay: _nullableString(row['end_day']),
            isCompleted: row['is_completed'] == true,
            isDone: row['is_done'] == true,
            type: _nullableString(row['type']),
            datetime: _nullableString(row['datetime']),
            syncStatus: _nullableString(row['sync_status']),
            syncError: _nullableString(row['sync_error']),
            createdAt:
                _parseDateTime(row['created_at']) ?? DateTime.now().toUtc(),
            updatedAt:
                _parseDateTime(row['updated_at']) ?? DateTime.now().toUtc(),
          );
        })
        .where(
          (row) =>
              row.id.isNotEmpty &&
              row.userId.isNotEmpty &&
              row.day.isNotEmpty &&
              row.time.isNotEmpty,
        )
        .toList(growable: false);
  }

  List<LocalNotificationReminderSkipRecord> _decodeSkipRows(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <LocalNotificationReminderSkipRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <LocalNotificationReminderSkipRecord>[];
    return decoded
        .whereType<Map>()
        .map((item) {
          final row = Map<String, dynamic>.from(item);
          return LocalNotificationReminderSkipRecord(
            reminderId: (row['reminder_id'] ?? '').toString().trim(),
            day: (row['day'] ?? '').toString().trim(),
            createdAt:
                _parseDateTime(row['created_at']) ?? DateTime.now().toUtc(),
          );
        })
        .where((row) => row.reminderId.isNotEmpty && row.day.isNotEmpty)
        .toList(growable: false);
  }

  LocalNotificationReminderRecord _mapReminderRow(CalendarReminder row) {
    return LocalNotificationReminderRecord(
      id: row.id,
      userId: row.userId,
      title: row.title,
      day: row.day,
      time: row.time,
      repeat: row.repeat,
      repeatDays: row.repeatDays,
      endDay: row.endDay,
      isCompleted: row.isCompleted,
      isDone: row.isDone,
      type: row.type,
      datetime: row.datetime,
      syncStatus: row.syncStatus,
      syncError: row.syncError,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  LocalNotificationReminderSkipRecord _mapSkipRow(CalendarReminderSkip row) {
    return LocalNotificationReminderSkipRecord(
      reminderId: row.reminderId,
      day: row.day,
      createdAt: row.createdAt,
    );
  }

  LocalNotificationReminderSkipRecord _mapDoneRow(CalendarReminderDoneData row) {
    return LocalNotificationReminderSkipRecord(
      reminderId: row.reminderId,
      day: row.day,
      createdAt: row.createdAt,
    );
  }

  DateTime? _parseDateTime(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  String? _nullableString(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
