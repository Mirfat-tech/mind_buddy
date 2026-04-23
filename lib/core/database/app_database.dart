import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../files/app_paths.dart';

part 'app_database.g.dart';

class SettingsRecords extends Table {
  TextColumn get scopeId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {scopeId};
}

class SyncJobs extends Table {
  TextColumn get id => text()();
  TextColumn get scopeId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get state => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get payloadJson => text().nullable()();
  DateTimeColumn get availableAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncMetadataEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class TemplateDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get templateKey => text()();
  TextColumn get name => text()();
  TextColumn get userId => text().nullable()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TemplateFields extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get fieldKey => text()();
  TextColumn get label => text()();
  TextColumn get fieldType => text()();
  TextColumn get optionsJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TemplateLogEntries extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text().nullable()();
  TextColumn get templateKey => text()();
  TextColumn get userId => text()();
  TextColumn get day => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarReminders extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get day => text()();
  TextColumn get time => text()();
  TextColumn get repeat => text().withDefault(const Constant('never'))();
  TextColumn get repeatDays => text().nullable()();
  TextColumn get endDay => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  TextColumn get type => text().nullable()();
  TextColumn get datetime => text().nullable()();
  TextColumn get syncStatus => text().nullable()();
  TextColumn get syncError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarReminderSkips extends Table {
  TextColumn get reminderId => text()();
  TextColumn get day => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {reminderId, day};
}

class CalendarReminderDone extends Table {
  TextColumn get reminderId => text()();
  TextColumn get day => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {reminderId, day};
}

class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get bodyText => text().named('text')();
  TextColumn get dayId => text()();
  TextColumn get folderId => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get shareId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class JournalFolderRows extends Table {
  @override
  String get tableName => 'journal_folders';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('pink'))();
  TextColumn get iconStyle =>
      text().named('icon_style').withDefault(const Constant('bubble_folder'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    SettingsRecords,
    SyncJobs,
    SyncMetadataEntries,
    TemplateDefinitions,
    TemplateFields,
    TemplateLogEntries,
    CalendarReminders,
    CalendarReminderSkips,
    CalendarReminderDone,
    JournalEntries,
    JournalFolderRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(_openConnection());
  static final AppDatabase _sharedInstance = AppDatabase._internal();

  factory AppDatabase.shared() => _sharedInstance;

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(templateDefinitions);
        await m.createTable(templateFields);
        await m.createTable(templateLogEntries);
      }
      if (from < 3) {
        await m.createTable(calendarReminders);
        await m.createTable(calendarReminderSkips);
        await m.createTable(calendarReminderDone);
      }
      if (from < 4) {
        await m.createTable(journalEntries);
      }
      if (from < 5) {
        await m.createTable(journalFolderRows);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await AppPaths.applicationSupportDirectory();
    final file = File(p.join(directory.path, 'mind_buddy.sqlite'));
    debugPrint('APP_DATABASE_PATH=${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
