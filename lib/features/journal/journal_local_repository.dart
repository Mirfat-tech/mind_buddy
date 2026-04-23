import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/journal/data/local/journal_local_data_source.dart';
import 'package:mind_buddy/features/journal/journal_folder_support.dart';

class JournalLocalRepository {
  JournalLocalRepository({AppDatabase? database, SupabaseClient? supabase})
    : _localDataSource = JournalLocalDataSource(
        database ?? AppDatabase.shared(),
      ),
      _supabase = supabase ?? Supabase.instance.client;

  static const _uuid = Uuid();
  static Future<void> _journalWriteChain = Future<void>.value();

  final JournalLocalDataSource _localDataSource;
  final SupabaseClient _supabase;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<T> _withJournalWriteLock<T>(Future<T> Function() action) async {
    final previous = _journalWriteChain;
    final completer = Completer<void>();
    _journalWriteChain = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  Future<List<Map<String, dynamic>>> loadOwnedJournals() async {
    final userId = _userId;
    if (userId == null) return const <Map<String, dynamic>>[];
    final entries = await _localDataSource.loadEntries(userId);
    final rows = entries.map((entry) => entry.toJson()).toList(growable: false)
      ..sort(
        (a, b) => ((b['created_at'] ?? '').toString()).compareTo(
          (a['created_at'] ?? '').toString(),
        ),
      );
    return rows;
  }

  Future<Map<String, dynamic>?> loadJournalForEditor(String journalId) async {
    final userId = _userId;
    if (userId == null) return null;
    final entries = await _localDataSource.loadEntries(userId);
    for (final entry in entries) {
      if (entry.id == journalId) {
        return entry.toJson();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> saveJournal({
    required String? journalId,
    required String title,
    required String body,
    required String dayId,
    required String? folderId,
    required DateTime now,
  }) async {
    return _withJournalWriteLock(() async {
      final userId = _userId;
      if (userId == null) {
        throw StateError('No authenticated user available for journal save.');
      }
      final resolvedId = journalId ?? 'journal-${_uuid.v4()}';
      debugPrint('JOURNAL_LOCAL_ROW_SAVE_START id=$resolvedId');
      try {
        final existing = await _localDataSource.loadJournalRowById(resolvedId);
        final entry = LocalJournalEntryRecord(
          id: resolvedId,
          userId: userId,
          title: title,
          text: body,
          dayId: dayId,
          folderId: folderId,
          isArchived: existing?.isArchived ?? false,
          isShared: existing?.isShared ?? false,
          createdAt: existing?.createdAt ?? now.toUtc().toIso8601String(),
          updatedAt: now.toUtc().toIso8601String(),
          shareId: existing?.shareId,
        );
        await _localDataSource.upsertJournalRow(entry);
        debugPrint('JOURNAL_LOCAL_ROW_SAVE_SUCCESS id=$resolvedId');
        final readBack = await _localDataSource.loadJournalRowById(resolvedId);
        debugPrint(
          'JOURNAL_LOCAL_ROW_READBACK_FOUND id=$resolvedId present=${readBack != null}',
        );
        if (readBack == null) {
          throw StateError('Journal row readback failed for $resolvedId');
        }
        _logSync(userId, journalId == null ? 'create_entry' : 'update_entry');
        return readBack.toJson();
      } catch (error) {
        debugPrint('JOURNAL_LOCAL_ROW_SAVE_ERROR error=$error');
        rethrow;
      }
    });
  }

  Future<void> deleteJournal(String journalId) async {
    final userId = _userId;
    if (userId == null) return;
    final entries = await _localDataSource.loadEntries(userId);
    final filtered = entries
        .where((entry) => entry.id != journalId)
        .toList(growable: false);
    await _localDataSource.saveEntries(
      userId,
      filtered,
      reason: 'delete_entry',
    );
    _logSync(userId, 'delete_entry');
  }

  Future<void> setArchived(Iterable<String> ids, bool archived) async {
    await _withJournalWriteLock(() async {
      final userId = _userId;
      if (userId == null) return;
      final updatedAt = DateTime.now().toUtc();
      for (final id in ids) {
        final journalId = id.toString();
        debugPrint(
          'JOURNAL_ARCHIVE_LOCAL journalId=$journalId isArchived=$archived',
        );
        await _localDataSource.updateJournalArchived(
          journalId,
          archived,
          updatedAt: updatedAt,
        );
        final readBack = await _localDataSource.loadJournalRowById(journalId);
        debugPrint(
          'JOURNAL_ARCHIVE_READBACK journalId=$journalId isArchived=${readBack?.isArchived}',
        );
      }
      _logSync(userId, archived ? 'archive_entry' : 'restore_entry');
    });
  }

  Future<List<JournalFolder>> loadFolders() async {
    final userId = _userId;
    if (userId == null) return const <JournalFolder>[];
    final folders = await _localDataSource.loadFolders(userId);
    return folders
        .map(
          (folder) => JournalFolder(
            id: folder.id,
            userId: folder.userId,
            name: folder.name,
            colorKey: folder.colorKey,
            iconStyle: folder.iconStyle,
            createdAt:
                DateTime.tryParse(folder.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt:
                DateTime.tryParse(folder.updatedAt) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveFolder({
    required String? folderId,
    required String name,
    required String colorKey,
    required String iconStyle,
  }) async {
    await _withJournalWriteLock(() async {
      final userId = _userId;
      if (userId == null) {
        throw StateError('No authenticated user available for folder save.');
      }
      final resolvedId = folderId ?? 'journal-folder-${_uuid.v4()}';
      debugPrint('JOURNAL_FOLDER_LOCAL_SAVE_START id=$resolvedId');
      final existing = await _localDataSource.loadFolderRowById(resolvedId);
      final now = DateTime.now().toUtc().toIso8601String();
      final folder = LocalJournalFolderRecord(
        id: resolvedId,
        userId: userId,
        name: name,
        colorKey: colorKey,
        iconStyle: iconStyle,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _localDataSource.upsertFolderRow(folder);
      debugPrint('JOURNAL_FOLDER_LOCAL_SAVE_SUCCESS id=$resolvedId');
      _logSync(userId, folderId == null ? 'create_folder' : 'update_folder');
    });
  }

  Future<void> deleteFolder(String folderId) async {
    await _withJournalWriteLock(() async {
      final userId = _userId;
      if (userId == null) return;
      final entries = await _localDataSource.loadEntries(userId);
      final now = DateTime.now().toUtc();
      for (final entry in entries) {
        if (entry.folderId != folderId) continue;
        await _localDataSource.updateJournalFolderId(
          journalId: entry.id,
          folderId: null,
          updatedAt: now,
        );
      }
      await _localDataSource.deleteFolderRow(folderId);
      _logSync(userId, 'delete_folder');
    });
  }

  Future<void> assignEntryToFolder(String journalId, String? folderId) async {
    await _withJournalWriteLock(() async {
      final userId = _userId;
      if (userId == null) return;
      debugPrint(
        'JOURNAL_FOLDER_ASSIGN_LOCAL journalId=$journalId folderId=$folderId',
      );
      await _localDataSource.updateJournalFolderId(
        journalId: journalId,
        folderId: folderId,
        updatedAt: DateTime.now().toUtc(),
      );
      final readBack = await _localDataSource.loadJournalRowById(journalId);
      debugPrint(
        'JOURNAL_FOLDER_ASSIGN_READBACK journalId=$journalId folderId=${readBack?.folderId}',
      );
      _logSync(userId, 'assign_folder');
    });
  }

  void _logSync(String userId, String reason) {
    debugPrint('JOURNAL_QUEUE_SYNC userId=$userId reason=$reason');
    debugPrint(
      'JOURNAL_REMOTE_SKIPPED_OFFLINE userId=$userId reason=journal_sync_not_enabled',
    );
  }
}
