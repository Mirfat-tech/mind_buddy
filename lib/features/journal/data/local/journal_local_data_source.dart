import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/files/app_paths.dart';

String? _journalNullable(Object? value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

class LocalJournalEntryRecord {
  const LocalJournalEntryRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.text,
    required this.dayId,
    required this.folderId,
    required this.isArchived,
    required this.isShared,
    required this.createdAt,
    required this.updatedAt,
    this.shareId,
  });

  final String id;
  final String userId;
  final String title;
  final String text;
  final String dayId;
  final String? folderId;
  final bool isArchived;
  final bool isShared;
  final String createdAt;
  final String updatedAt;
  final String? shareId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'title': title,
    'text': text,
    'day_id': dayId,
    'folder_id': folderId,
    'is_archived': isArchived,
    'is_shared': isShared,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'share_id': shareId,
  };

  static LocalJournalEntryRecord fromJson(Map<String, dynamic> json) {
    return LocalJournalEntryRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      dayId: (json['day_id'] ?? '').toString(),
      folderId: _journalNullable(json['folder_id']),
      isArchived: json['is_archived'] == true,
      isShared: json['is_shared'] == true,
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      shareId: _journalNullable(json['share_id']),
    );
  }
}

class LocalJournalFolderRecord {
  const LocalJournalFolderRecord({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorKey,
    required this.iconStyle,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String colorKey;
  final String iconStyle;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'name': name,
    'color': colorKey,
    'icon_style': iconStyle,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  static LocalJournalFolderRecord fromJson(Map<String, dynamic> json) {
    return LocalJournalFolderRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      colorKey: (json['color'] ?? 'pink').toString(),
      iconStyle: (json['icon_style'] ?? 'bubble_folder').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

class JournalLocalDataSource {
  JournalLocalDataSource(this._database);

  final AppDatabase _database;

  String _entriesKey(String userId) => 'journal_entries:$userId';
  String _foldersKey(String userId) => 'journal_folders:$userId';
  String _folderRowsImportedKey(String userId) =>
      'journal_folders_rows_imported:$userId';

  Future<List<LocalJournalEntryRecord>> loadEntries(String userId) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('JOURNAL_DB_PATH_RELOAD=$dbPath');
    debugPrint('JOURNAL_LOAD_FROM_LOCAL_START userId=$userId entity=entries');
    final rowEntries = await (_database.select(
      _database.journalEntries,
    )..where((tbl) => tbl.userId.equals(userId))).get();
    final entriesById = <String, LocalJournalEntryRecord>{
      for (final row in rowEntries) row.id: _entryFromRow(row),
    };
    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_entriesKey(userId)))).getSingleOrNull();
    if (row == null || row.value == null || row.value!.isEmpty) {
      if (entriesById.isNotEmpty) {
        final entries = entriesById.values.toList(growable: false);
        debugPrint(
          'JOURNAL_DRIFT_ROW_FOUND userId=$userId entity=entries count=${entries.length} source=row_table',
        );
        debugPrint(
          'JOURNAL_LOAD_FROM_LOCAL_RESULT userId=$userId entity=entries found=true count=${entries.length}',
        );
        return entries;
      }
      debugPrint('JOURNAL_DRIFT_ROW_NOT_FOUND userId=$userId entity=entries');
      debugPrint(
        'JOURNAL_LOAD_FROM_LOCAL_RESULT userId=$userId entity=entries found=false count=0',
      );
      return const <LocalJournalEntryRecord>[];
    }
    final decoded = jsonDecode(row.value!);
    final legacyEntries = _decodeList(decoded, LocalJournalEntryRecord.fromJson);
    for (final entry in legacyEntries) {
      entriesById.putIfAbsent(entry.id, () => entry);
    }
    final entries = entriesById.values.toList(growable: false);
    debugPrint(
      'JOURNAL_DRIFT_ROW_FOUND userId=$userId entity=entries count=${entries.length}',
    );
    debugPrint(
      'JOURNAL_LOAD_FROM_LOCAL_RESULT userId=$userId entity=entries found=true count=${entries.length}',
    );
    return entries;
  }

  Future<List<LocalJournalFolderRecord>> loadFolders(String userId) async {
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('JOURNAL_DB_PATH_RELOAD=$dbPath');
    debugPrint('JOURNAL_LOAD_FROM_LOCAL_START userId=$userId entity=folders');
    await ensureFolderRowsImported(userId);
    final rowFolders = await (_database.select(
      _database.journalFolderRows,
    )..where((tbl) => tbl.userId.equals(userId))).get();
    if (rowFolders.isEmpty) {
      debugPrint('JOURNAL_DRIFT_ROW_NOT_FOUND userId=$userId entity=folders');
      debugPrint(
        'JOURNAL_LOAD_FROM_LOCAL_RESULT userId=$userId entity=folders found=false count=0',
      );
      return const <LocalJournalFolderRecord>[];
    }
    final folders = rowFolders.map(_folderFromRow).toList(growable: false);
    debugPrint(
      'JOURNAL_DRIFT_ROW_FOUND userId=$userId entity=folders count=${folders.length}',
    );
    debugPrint(
      'JOURNAL_LOAD_FROM_LOCAL_RESULT userId=$userId entity=folders found=true count=${folders.length}',
    );
    return folders;
  }

  Future<void> saveEntries(
    String userId,
    List<LocalJournalEntryRecord> entries, {
    required String reason,
  }) async {
    if (reason == 'create_entry' || reason == 'update_entry') {
      debugPrint('JOURNAL_LEGACY_METADATA_WRITE_BLOCKED source=saveJournal');
      return;
    }
    if (reason == 'assign_folder' || reason == 'delete_folder_reassign_entries') {
      debugPrint(
        'JOURNAL_LEGACY_FOLDER_BLOB_WRITE_BLOCKED method=saveEntries:$reason',
      );
      return;
    }
    if (reason == 'archive_entry' || reason == 'restore_entry') {
      debugPrint('JOURNAL_LEGACY_ARCHIVE_BLOCKED method=setArchived');
      return;
    }
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('JOURNAL_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'JOURNAL_SAVE_LOCAL_START userId=$userId entity=entries reason=$reason count=${entries.length}',
    );
    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _entriesKey(userId),
            value: drift.Value(
              jsonEncode(entries.map((entry) => entry.toJson()).toList()),
            ),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    debugPrint(
      'JOURNAL_SAVE_LOCAL_SUCCESS userId=$userId entity=entries reason=$reason count=${entries.length}',
    );
  }

  Future<void> saveFolders(
    String userId,
    List<LocalJournalFolderRecord> folders, {
    required String reason,
  }) async {
    if (reason == 'create_folder' ||
        reason == 'update_folder' ||
        reason == 'delete_folder') {
      debugPrint(
        'JOURNAL_LEGACY_FOLDER_BLOB_WRITE_BLOCKED method=saveFolders:$reason',
      );
      return;
    }
    final dbPath = await AppPaths.databaseFilePath();
    debugPrint('JOURNAL_DB_PATH_SAVE=$dbPath');
    debugPrint(
      'JOURNAL_SAVE_LOCAL_START userId=$userId entity=folders reason=$reason count=${folders.length}',
    );
    await _database
        .into(_database.syncMetadataEntries)
        .insertOnConflictUpdate(
          SyncMetadataEntriesCompanion.insert(
            key: _foldersKey(userId),
            value: drift.Value(
              jsonEncode(folders.map((folder) => folder.toJson()).toList()),
            ),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    debugPrint(
      'JOURNAL_SAVE_LOCAL_SUCCESS userId=$userId entity=folders reason=$reason count=${folders.length}',
    );
  }

  static List<T> _decodeList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return <T>[];
    return raw
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> upsertJournalRow(LocalJournalEntryRecord entry) async {
    await _database.into(_database.journalEntries).insertOnConflictUpdate(
      JournalEntriesCompanion.insert(
        id: entry.id,
        userId: entry.userId,
        title: entry.title,
        bodyText: entry.text,
        dayId: entry.dayId,
        folderId: drift.Value(entry.folderId),
        isArchived: drift.Value(entry.isArchived),
        isShared: drift.Value(entry.isShared),
        createdAt: DateTime.parse(entry.createdAt).toUtc(),
        updatedAt: DateTime.parse(entry.updatedAt).toUtc(),
        shareId: drift.Value(entry.shareId),
      ),
    );
  }

  Future<LocalJournalEntryRecord?> loadJournalRowById(String id) async {
    final row = await (_database.select(
      _database.journalEntries,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _entryFromRow(row);
  }

  LocalJournalEntryRecord _entryFromRow(JournalEntry row) {
    return LocalJournalEntryRecord(
      id: row.id,
      userId: row.userId,
      title: row.title,
      text: row.bodyText,
      dayId: row.dayId,
      folderId: row.folderId,
      isArchived: row.isArchived,
      isShared: row.isShared,
      createdAt: row.createdAt.toUtc().toIso8601String(),
      updatedAt: row.updatedAt.toUtc().toIso8601String(),
      shareId: row.shareId,
    );
  }

  Future<void> upsertFolderRow(LocalJournalFolderRecord folder) async {
    await _database.into(_database.journalFolderRows).insertOnConflictUpdate(
      JournalFolderRowsCompanion.insert(
        id: folder.id,
        userId: folder.userId,
        name: folder.name,
        color: drift.Value(folder.colorKey),
        iconStyle: drift.Value(folder.iconStyle),
        createdAt: DateTime.parse(folder.createdAt).toUtc(),
        updatedAt: DateTime.parse(folder.updatedAt).toUtc(),
      ),
    );
  }

  Future<List<LocalJournalFolderRecord>> loadFolderRows(String userId) async {
    final rows = await (_database.select(
      _database.journalFolderRows,
    )..where((tbl) => tbl.userId.equals(userId))).get();
    return rows.map(_folderFromRow).toList(growable: false);
  }

  Future<LocalJournalFolderRecord?> loadFolderRowById(String id) async {
    final row = await (_database.select(
      _database.journalFolderRows,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _folderFromRow(row);
  }

  Future<void> deleteFolderRow(String id) async {
    await (_database.delete(
      _database.journalFolderRows,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> updateJournalFolderId({
    required String journalId,
    required String? folderId,
    required DateTime updatedAt,
  }) async {
    await (_database.update(
      _database.journalEntries,
    )..where((tbl) => tbl.id.equals(journalId))).write(
      JournalEntriesCompanion(
        folderId: drift.Value(folderId),
        updatedAt: drift.Value(updatedAt.toUtc()),
      ),
    );
  }

  Future<void> updateJournalArchived(
    String journalId,
    bool isArchived, {
    required DateTime updatedAt,
  }) async {
    await (_database.update(
      _database.journalEntries,
    )..where((tbl) => tbl.id.equals(journalId))).write(
      JournalEntriesCompanion(
        isArchived: drift.Value(isArchived),
        updatedAt: drift.Value(updatedAt.toUtc()),
      ),
    );
  }

  Future<void> ensureFolderRowsImported(String userId) async {
    final importedFlag = await _loadMetadataValue(_folderRowsImportedKey(userId));
    if (importedFlag == '1') return;

    final rowCount = await _countFolderRows(userId);
    if (rowCount > 0) {
      await _saveMetadataValue(_folderRowsImportedKey(userId), '1');
      return;
    }

    final legacyRow = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(_foldersKey(userId)))).getSingleOrNull();
    final raw = legacyRow?.value;
    if (raw == null || raw.isEmpty) {
      await _saveMetadataValue(_folderRowsImportedKey(userId), '1');
      return;
    }

    final decoded = jsonDecode(raw);
    final legacyFolders = _decodeList(decoded, LocalJournalFolderRecord.fromJson);
    for (final folder in legacyFolders) {
      await upsertFolderRow(folder);
    }
    await _saveMetadataValue(_folderRowsImportedKey(userId), '1');
  }

  LocalJournalFolderRecord _folderFromRow(JournalFolderRow row) {
    return LocalJournalFolderRecord(
      id: row.id,
      userId: row.userId,
      name: row.name,
      colorKey: row.color,
      iconStyle: row.iconStyle,
      createdAt: row.createdAt.toUtc().toIso8601String(),
      updatedAt: row.updatedAt.toUtc().toIso8601String(),
    );
  }

  Future<int> _countFolderRows(String userId) async {
    final countExp = _database.journalFolderRows.id.count();
    final query = _database.selectOnly(_database.journalFolderRows)
      ..addColumns([countExp])
      ..where(_database.journalFolderRows.userId.equals(userId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<String?> _loadMetadataValue(String key) async {
    final row = await (_database.select(
      _database.syncMetadataEntries,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _saveMetadataValue(String key, String value) async {
    await _database.into(_database.syncMetadataEntries).insertOnConflictUpdate(
      SyncMetadataEntriesCompanion.insert(
        key: key,
        value: drift.Value(value),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
