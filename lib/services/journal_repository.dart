import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/services/journal_encryption_service.dart';

class JournalRepository {
  JournalRepository({
    SupabaseClient? client,
    JournalEncryptionService? encryptionService,
  }) : _client = client ?? Supabase.instance.client,
       _encryption = encryptionService ?? JournalEncryptionService.instance;

  final SupabaseClient _client;
  final JournalEncryptionService _encryption;

  static const String _journalsTable = 'journals';
  static const String _sharesTable = 'journal_shares';
  bool? _supportsEncryptionSchemaCache;
  bool? _supportsSharedCopySchemaCache;

  bool _isLocalPrivateJournalId(String journalId) =>
      journalId.startsWith('journal-');

  Future<List<Map<String, dynamic>>> fetchOwnedJournals() async {
    await _encryption.handleAuthScopeChanged();
    final user = _client.auth.currentUser;
    if (user == null) return const <Map<String, dynamic>>[];
    final supportsEncryptionSchema = await _supportsEncryptionSchema();
    _log('schema_compatibility_detected', {
      'context': 'owned_list',
      'supports_encryption_schema': supportsEncryptionSchema,
    });

    dynamic response;
    if (supportsEncryptionSchema) {
      try {
        response = await _client
            .from(_journalsTable)
            .select()
            .eq('user_id', user.id)
            .isFilter('share_source_journal_id', null)
            .order('created_at', ascending: false);
      } on PostgrestException catch (error) {
        if (!_isMissingSchemaFeature(error, const {
          'share_source_journal_id',
        })) {
          rethrow;
        }
        _supportsEncryptionSchemaCache = false;
        _supportsSharedCopySchemaCache = false;
        _log('fallback_triggered', {
          'context': 'owned_list',
          'reason': 'missing_share_source_journal_id',
          'code': error.code,
          'message': error.message,
        });
        response = await _fetchOwnedJournalsLegacy(user.id);
      }
    } else {
      _log('legacy_path_used', {
        'context': 'owned_list',
        'reason': 'schema_compatibility_mode',
      });
      response = await _fetchOwnedJournalsLegacy(user.id);
    }
    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final hydrated = <Map<String, dynamic>>[];
    final legacyRows = <Map<String, dynamic>>[];
    for (final row in rows) {
      final hydratedRow = await hydratePrivateRow(
        row,
        allowMigration: supportsEncryptionSchema,
        cacheResult: true,
      );
      hydrated.add(hydratedRow);
      if (supportsEncryptionSchema && _isLegacyPlaintextPrivateRow(row)) {
        legacyRows.add(Map<String, dynamic>.from(row));
      }
    }

    if (legacyRows.isNotEmpty) {
      _migrateLegacyRows(legacyRows);
    }

    return hydrated;
  }

  Future<List<Map<String, dynamic>>> fetchSharedWithMe() async {
    await _encryption.handleAuthScopeChanged();
    final user = _client.auth.currentUser;
    if (user == null) return const <Map<String, dynamic>>[];

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final supportsSharedCopySchema = await _supportsSharedCopySchema();
    _log('schema_compatibility_detected', {
      'context': 'shared_list',
      'supports_shared_copy_schema': supportsSharedCopySchema,
    });
    dynamic response;
    if (supportsSharedCopySchema) {
      try {
        response = await _client
            .from(_sharesTable)
            .select(
              'id, journal_id, shared_journal_id, sender_id, recipient_id, can_comment, media_visible, expires_at, created_at, '
              'shared_journal:shared_journal_id (id, title, text, created_at, user_id, folder_id, is_shared, share_source_journal_id, doodle_storage_path, doodle_bg_style, doodle_updated_at), '
              'source_journal:journal_id (id, title, text, created_at, user_id, folder_id, is_shared, share_source_journal_id, is_encrypted, encrypted_content, iv, encryption_version, key_version, doodle_storage_path, doodle_bg_style, doodle_updated_at)',
            )
            .eq('recipient_id', user.id)
            .or('expires_at.is.null,expires_at.gt.$nowIso')
            .order('created_at', ascending: false);
      } on PostgrestException catch (error) {
        if (!_isMissingSchemaFeature(error, const {
          'shared_journal_id',
          'share_source_journal_id',
          'is_encrypted',
          'encrypted_content',
          'iv',
          'encryption_version',
          'key_version',
        })) {
          rethrow;
        }
        _supportsEncryptionSchemaCache = false;
        _supportsSharedCopySchemaCache = false;
        _log('fallback_triggered', {
          'context': 'shared_list',
          'reason': 'missing_encryption_or_shared_copy_columns',
          'code': error.code,
          'message': error.message,
        });
        response = await _fetchSharedWithMeLegacy(user.id, nowIso);
      }
    } else {
      _log('legacy_path_used', {
        'context': 'shared_list',
        'reason': 'schema_compatibility_mode',
      });
      response = await _fetchSharedWithMeLegacy(user.id, nowIso);
    }

    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return rows.map(_normalizeShareRowForRecipient).toList();
  }

  Future<Map<String, dynamic>?> fetchJournalForEditor(String journalId) async {
    if (_isLocalPrivateJournalId(journalId)) {
      debugPrint(
        'JOURNAL_REMOTE_CALL_BLOCKED reason=private_flow method=fetchJournalForEditor id=$journalId',
      );
      return null;
    }
    await _encryption.handleAuthScopeChanged();
    _log('entry_open_attempt', {
      'context': 'editor_fetch',
      'journal_id': journalId,
    });
    final row = await _client
        .from(_journalsTable)
        .select()
        .eq('id', journalId)
        .maybeSingle();
    if (row == null) return null;
    _log('legacy_path_used', {
      'context': 'editor_fetch',
      'journal_id': journalId,
      'reason': 'table_select',
    });
    return hydratePrivateRow(
      Map<String, dynamic>.from(row as Map),
      allowMigration: true,
      cacheResult: true,
    );
  }

  Future<Map<String, dynamic>> savePrivateJournal({
    String? journalId,
    required String title,
    required String body,
    required String dayId,
    required String? folderId,
    required DateTime now,
  }) async {
    await _encryption.handleAuthScopeChanged();
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user available for journal save.');
    }

    final supportsEncryptionSchema = await _supportsEncryptionSchema();
    _log('schema_compatibility_detected', {
      'context': 'save',
      'supports_encryption_schema': supportsEncryptionSchema,
      'journal_id': journalId,
    });

    if (!supportsEncryptionSchema) {
      _log('legacy_path_used', {
        'context': 'save',
        'reason': 'schema_compatibility_mode',
        'journal_id': journalId,
      });
      return _savePrivateJournalLegacy(
        journalId: journalId,
        userId: user.id,
        title: title,
        body: body,
        dayId: dayId,
        folderId: folderId,
        now: now,
      );
    }

    try {
      return await _savePrivateJournalEncrypted(
        journalId: journalId,
        userId: user.id,
        title: title,
        body: body,
        dayId: dayId,
        folderId: folderId,
        now: now,
      );
    } on PostgrestException catch (error) {
      if (!_isMissingSchemaFeature(error, const {
        'encrypted_content',
        'iv',
        'is_encrypted',
        'encryption_version',
        'key_version',
      })) {
        rethrow;
      }
      _supportsEncryptionSchemaCache = false;
      _supportsSharedCopySchemaCache = false;
      _log('fallback_triggered', {
        'context': 'save',
        'reason': 'missing_encryption_columns',
        'code': error.code,
        'message': error.message,
        'journal_id': journalId,
      });
      return _savePrivateJournalLegacy(
        journalId: journalId,
        userId: user.id,
        title: title,
        body: body,
        dayId: dayId,
        folderId: folderId,
        now: now,
      );
    }
  }

  Future<Map<String, dynamic>> _savePrivateJournalEncrypted({
    required String? journalId,
    required String userId,
    required String title,
    required String body,
    required String dayId,
    required String? folderId,
    required DateTime now,
  }) async {
    _log('encrypted_path_attempted', {
      'context': 'save',
      'journal_id': journalId,
    });
    final encrypted = await _encryption.encryptBodyForCurrentUser(body);
    final payload = <String, dynamic>{
      'user_id': userId,
      'day_id': dayId,
      'title': title.isEmpty ? null : title,
      'folder_id': folderId,
      'created_at': now.toIso8601String(),
      ...encrypted.toColumns(),
    };

    Map<String, dynamic> saved;
    String? resolvedJournalId = journalId;
    if (journalId == null) {
      final inserted = await _client
          .from(_journalsTable)
          .insert(payload)
          .select('id, share_id')
          .single();
      saved = Map<String, dynamic>.from(inserted);
      resolvedJournalId = saved['id']?.toString();
    } else {
      payload.remove('user_id');
      payload.remove('created_at');
      final updated = await _client
          .from(_journalsTable)
          .update(payload)
          .eq('id', journalId)
          .eq('user_id', userId)
          .select('id, share_id')
          .single();
      saved = Map<String, dynamic>.from(updated);
    }

    if (resolvedJournalId != null) {
      _encryption.cacheDecryptedBody(resolvedJournalId, body);
      await _refreshSharedCopiesForJournal(
        journalId: resolvedJournalId,
        title: title.isEmpty ? null : title,
        body: body,
      );
    }

    _log('encrypted_path_used', {
      'context': 'save',
      'journal_id': resolvedJournalId,
    });
    return saved;
  }

  Future<Map<String, dynamic>> _savePrivateJournalLegacy({
    required String? journalId,
    required String userId,
    required String title,
    required String body,
    required String dayId,
    required String? folderId,
    required DateTime now,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'day_id': dayId,
      'title': title.isEmpty ? null : title,
      'folder_id': folderId,
      'text': body,
      'created_at': now.toIso8601String(),
    };

    Map<String, dynamic> saved;
    String? resolvedJournalId = journalId;
    if (journalId == null) {
      final inserted = await _client
          .from(_journalsTable)
          .insert(payload)
          .select('id, share_id')
          .single();
      saved = Map<String, dynamic>.from(inserted);
      resolvedJournalId = saved['id']?.toString();
    } else {
      payload.remove('user_id');
      payload.remove('created_at');
      final updated = await _client
          .from(_journalsTable)
          .update(payload)
          .eq('id', journalId)
          .eq('user_id', userId)
          .select('id, share_id')
          .single();
      saved = Map<String, dynamic>.from(updated);
    }

    if (resolvedJournalId != null) {
      _encryption.cacheDecryptedBody(resolvedJournalId, body);
    }

    return saved;
  }

  Future<Map<String, dynamic>> sharePrivateJournal({
    required String journalId,
    required String recipientId,
    required bool canComment,
    required bool mediaVisible,
    required DateTime? expiresAt,
    required String? title,
    required String body,
    required Map<String, dynamic> sourceJournal,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user available for journal sharing.');
    }
    final supportsSharedCopySchema = await _supportsSharedCopySchema();
    _log('schema_compatibility_detected', {
      'context': 'share',
      'supports_shared_copy_schema': supportsSharedCopySchema,
    });
    if (!supportsSharedCopySchema) {
      _log('legacy_path_used', {
        'context': 'share',
        'reason': 'schema_compatibility_mode',
        'journal_id': journalId,
      });
      final shareRow = await _client
          .from(_sharesTable)
          .upsert({
            'journal_id': journalId,
            'sender_id': user.id,
            'recipient_id': recipientId,
            'can_comment': canComment,
            'media_visible': mediaVisible,
            'expires_at': expiresAt?.toIso8601String(),
          }, onConflict: 'journal_id,recipient_id')
          .select()
          .single();
      await _client
          .from(_journalsTable)
          .update({'is_shared': true})
          .eq('id', journalId)
          .eq('user_id', user.id);
      return Map<String, dynamic>.from(shareRow);
    }

    // Shared recipients do not reuse the owner's device-bound key. Instead we
    // generate a readable shared copy while keeping the private source row
    // encrypted and unchanged.
    final existingShare = await _client
        .from(_sharesTable)
        .select('id, shared_journal_id')
        .eq('journal_id', journalId)
        .eq('recipient_id', recipientId)
        .maybeSingle();
    final existingShareMap = existingShare == null
        ? null
        : Map<String, dynamic>.from(existingShare as Map);

    final sharedCopyId = await _upsertSharedCopy(
      existingSharedJournalId: existingShareMap?['shared_journal_id']
          ?.toString(),
      journalId: journalId,
      ownerId: user.id,
      recipientId: recipientId,
      title: title,
      body: body,
      sourceJournal: sourceJournal,
    );

    final shareRow = await _client
        .from(_sharesTable)
        .upsert({
          'journal_id': journalId,
          'shared_journal_id': sharedCopyId,
          'sender_id': user.id,
          'recipient_id': recipientId,
          'can_comment': canComment,
          'media_visible': mediaVisible,
          'expires_at': expiresAt?.toIso8601String(),
        }, onConflict: 'journal_id,recipient_id')
        .select()
        .single();

    await _client
        .from(_journalsTable)
        .update({'is_shared': true})
        .eq('id', journalId)
        .eq('user_id', user.id);

    return Map<String, dynamic>.from(shareRow);
  }

  Future<void> removeJournalShare({
    required dynamic shareRowId,
    required String sourceJournalId,
  }) async {
    final supportsSharedCopySchema = await _supportsSharedCopySchema();
    if (!supportsSharedCopySchema) {
      await _client.from(_sharesTable).delete().eq('id', shareRowId);
      await _syncIsSharedFlag(sourceJournalId);
      return;
    }
    final existing = await _client
        .from(_sharesTable)
        .select('id, shared_journal_id')
        .eq('id', shareRowId)
        .maybeSingle();

    await _client.from(_sharesTable).delete().eq('id', shareRowId);

    final sharedJournalId = existing == null
        ? null
        : (existing as Map)['shared_journal_id']?.toString();
    if (sharedJournalId != null && sharedJournalId.isNotEmpty) {
      await _client.from(_journalsTable).delete().eq('id', sharedJournalId);
    }

    await _syncIsSharedFlag(sourceJournalId);
  }

  Future<void> unshareAllForJournal(String journalId) async {
    final supportsSharedCopySchema = await _supportsSharedCopySchema();
    if (!supportsSharedCopySchema) {
      await _client.from(_sharesTable).delete().eq('journal_id', journalId);
      await _client
          .from(_journalsTable)
          .update({'is_shared': false})
          .eq('id', journalId);
      return;
    }
    final rows = await _client
        .from(_sharesTable)
        .select('id, shared_journal_id')
        .eq('journal_id', journalId);
    for (final raw in (rows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final sharedJournalId = row['shared_journal_id']?.toString();
      if (sharedJournalId != null && sharedJournalId.isNotEmpty) {
        await _client.from(_journalsTable).delete().eq('id', sharedJournalId);
      }
    }
    await _client.from(_sharesTable).delete().eq('journal_id', journalId);
    await _client
        .from(_journalsTable)
        .update({'is_shared': false})
        .eq('id', journalId);
  }

  Future<Map<String, dynamic>> hydratePrivateRow(
    Map<String, dynamic> row, {
    required bool allowMigration,
    required bool cacheResult,
  }) async {
    final supportsEncryptionSchema = await _supportsEncryptionSchema();
    final journalId = row['id']?.toString();
    final cached = journalId == null
        ? null
        : _encryption.getCachedDecryptedBody(journalId);
    if (cached != null) {
      row['text'] = cached;
      row['decryption_error'] = null;
      _log('legacy_path_used', {
        'context': 'read',
        'journal_id': journalId,
        'reason': 'memory_cache',
      });
      return row;
    }

    if (supportsEncryptionSchema && row['is_encrypted'] == true) {
      _log('encrypted_path_attempted', {
        'context': 'read',
        'journal_id': journalId,
      });
      final decrypted = await _encryption.decryptBodyForCurrentUser(
        encryptedContent: row['encrypted_content']?.toString() ?? '',
        iv: row['iv']?.toString() ?? '',
        encryptionVersion: row['encryption_version'] as int?,
      );
      row['text'] = decrypted;
      row['decryption_error'] = null;
      if (cacheResult && journalId != null) {
        _encryption.cacheDecryptedBody(journalId, decrypted);
      }
      _log('encrypted_path_used', {'context': 'read', 'journal_id': journalId});
      return row;
    }

    _log('legacy_path_used', {
      'context': 'read',
      'journal_id': journalId,
      'reason': supportsEncryptionSchema
          ? 'plaintext_row'
          : 'schema_compatibility_mode',
    });
    final plaintext = row['text']?.toString() ?? '';
    row['text'] = plaintext;
    row['decryption_error'] = null;
    if (cacheResult && journalId != null) {
      _encryption.cacheDecryptedBody(journalId, plaintext);
    }

    if (supportsEncryptionSchema &&
        allowMigration &&
        _isLegacyPlaintextPrivateRow(row) &&
        journalId != null) {
      await migrateLegacyPlaintextRow(row);
    }

    return row;
  }

  Future<void> migrateLegacyPlaintextRow(Map<String, dynamic> row) async {
    final supportsEncryptionSchema = await _supportsEncryptionSchema();
    if (!supportsEncryptionSchema) {
      _log('legacy_path_used', {
        'context': 'migration_skip',
        'journal_id': row['id']?.toString(),
        'reason': 'schema_compatibility_mode',
      });
      return;
    }
    if (!_isLegacyPlaintextPrivateRow(row)) return;
    final journalId = row['id']?.toString();
    if (journalId == null || journalId.isEmpty) return;

    final title = row['title']?.toString();
    final body = row['text']?.toString() ?? '';
    if (body.isEmpty) {
      final encrypted = await _encryption.encryptBodyForCurrentUser('');
      await _client
          .from(_journalsTable)
          .update(encrypted.toColumns())
          .eq('id', journalId);
      return;
    }

    final encrypted = await _encryption.encryptBodyForCurrentUser(body);
    await _refreshSharedCopiesForJournal(
      journalId: journalId,
      title: title,
      body: body,
      sourceJournal: row,
    );
    await _client
        .from(_journalsTable)
        .update(encrypted.toColumns())
        .eq('id', journalId);
    _encryption.cacheDecryptedBody(journalId, body);
  }

  bool _isLegacyPlaintextPrivateRow(Map<String, dynamic> row) {
    final text = row['text']?.toString();
    return row['share_source_journal_id'] == null &&
        row['is_encrypted'] != true &&
        text != null;
  }

  Map<String, dynamic> _normalizeShareRowForRecipient(
    Map<String, dynamic> row,
  ) {
    final sharedJournal = row['shared_journal'] is Map
        ? Map<String, dynamic>.from(row['shared_journal'] as Map)
        : null;
    final sourceJournal = row['source_journal'] is Map
        ? Map<String, dynamic>.from(row['source_journal'] as Map)
        : null;
    final legacyJournal = row['journal'] is Map
        ? Map<String, dynamic>.from(row['journal'] as Map)
        : null;
    final journal =
        sharedJournal ?? sourceJournal ?? legacyJournal ?? <String, dynamic>{};
    final normalized = <String, dynamic>{...row, 'journal': journal};
    normalized['shared_journal'] = sharedJournal;
    normalized['source_journal'] = sourceJournal;
    return normalized;
  }

  Future<String> _upsertSharedCopy({
    required String? existingSharedJournalId,
    required String journalId,
    required String ownerId,
    required String recipientId,
    required String? title,
    required String body,
    required Map<String, dynamic> sourceJournal,
  }) async {
    final copyPayload = <String, dynamic>{
      'user_id': ownerId,
      'title': title,
      'text': body,
      'is_encrypted': false,
      'encrypted_content': null,
      'iv': null,
      'encryption_version': null,
      'key_version': null,
      'is_shared': false,
      'share_source_journal_id': journalId,
      'shared_recipient_id': recipientId,
      'folder_id': null,
      'doodle_storage_path': sourceJournal['doodle_storage_path'],
      'doodle_bg_style': sourceJournal['doodle_bg_style'],
      'doodle_updated_at': sourceJournal['doodle_updated_at'],
    };

    if (existingSharedJournalId != null && existingSharedJournalId.isNotEmpty) {
      final updated = await _client
          .from(_journalsTable)
          .update(copyPayload)
          .eq('id', existingSharedJournalId)
          .select('id')
          .single();
      return updated['id'].toString();
    }

    final inserted = await _client
        .from(_journalsTable)
        .insert(copyPayload)
        .select('id')
        .single();
    return inserted['id'].toString();
  }

  Future<void> _refreshSharedCopiesForJournal({
    required String journalId,
    required String? title,
    required String body,
    Map<String, dynamic>? sourceJournal,
  }) async {
    final rows = await _client
        .from(_sharesTable)
        .select('recipient_id, shared_journal_id')
        .eq('journal_id', journalId);
    if ((rows as List).isEmpty) return;

    final source =
        sourceJournal ??
        await (() async {
          final row = await _client
              .from(_journalsTable)
              .select('doodle_storage_path, doodle_bg_style, doodle_updated_at')
              .eq('id', journalId)
              .maybeSingle();
          return row == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(row as Map);
        })();

    for (final raw in rows) {
      final share = Map<String, dynamic>.from(raw as Map);
      final recipientId = share['recipient_id']?.toString();
      if (recipientId == null || recipientId.isEmpty) continue;
      await _upsertSharedCopy(
        existingSharedJournalId: share['shared_journal_id']?.toString(),
        journalId: journalId,
        ownerId: _client.auth.currentUser!.id,
        recipientId: recipientId,
        title: title,
        body: body,
        sourceJournal: source,
      );
    }
  }

  Future<void> _syncIsSharedFlag(String journalId) async {
    final rows = await _client
        .from(_sharesTable)
        .select('id')
        .eq('journal_id', journalId)
        .limit(1);
    final hasShares = (rows as List).isNotEmpty;
    await _client
        .from(_journalsTable)
        .update({'is_shared': hasShares})
        .eq('id', journalId);
  }

  void _migrateLegacyRows(List<Map<String, dynamic>> rows) {
    Future<void>(() async {
      for (final row in rows) {
        try {
          await migrateLegacyPlaintextRow(row);
        } catch (error, stackTrace) {
          developer.log(
            'journal_encryption event=legacy_migration_failed data={id: ${row['id']}, error: $error}',
            name: 'journal_encryption',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    });
  }

  Future<List<dynamic>> _fetchOwnedJournalsLegacy(String userId) {
    return _client
        .from(_journalsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<List<dynamic>> _fetchSharedWithMeLegacy(String userId, String nowIso) {
    return _client
        .from(_sharesTable)
        .select(
          'id, journal_id, sender_id, recipient_id, can_comment, media_visible, expires_at, created_at, '
          'journal:journal_id (id, title, text, created_at, user_id, folder_id, is_shared, doodle_storage_path, doodle_bg_style, doodle_updated_at)',
        )
        .eq('recipient_id', userId)
        .or('expires_at.is.null,expires_at.gt.$nowIso')
        .order('created_at', ascending: false);
  }

  Future<bool> _supportsEncryptionSchema() async {
    final cached = _supportsEncryptionSchemaCache;
    if (cached != null) return cached;
    try {
      await _client
          .from(_journalsTable)
          .select(
            'id, encrypted_content, iv, is_encrypted, encryption_version, key_version, share_source_journal_id, shared_recipient_id',
          )
          .limit(1);
      _supportsEncryptionSchemaCache = true;
      _log('schema_compatibility_detected', {
        'context': 'journals_encryption_probe',
        'supports_encryption_schema': true,
      });
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingSchemaFeature(error, const {
        'encrypted_content',
        'iv',
        'is_encrypted',
        'encryption_version',
        'key_version',
        'share_source_journal_id',
        'shared_recipient_id',
      })) {
        _supportsEncryptionSchemaCache = false;
        _supportsSharedCopySchemaCache = false;
        _log('schema_compatibility_detected', {
          'context': 'journals_encryption_probe',
          'supports_encryption_schema': false,
          'code': error.code,
          'message': error.message,
        });
        return false;
      }
      rethrow;
    }
  }

  Future<bool> _supportsSharedCopySchema() async {
    final cached = _supportsSharedCopySchemaCache;
    if (cached != null) return cached;
    final supportsEncryptionSchema = await _supportsEncryptionSchema();
    if (!supportsEncryptionSchema) {
      _supportsSharedCopySchemaCache = false;
      return false;
    }
    try {
      await _client.from(_sharesTable).select('id, shared_journal_id').limit(1);
      _supportsSharedCopySchemaCache = true;
      _log('schema_compatibility_detected', {
        'context': 'journal_shares_probe',
        'supports_shared_copy_schema': true,
      });
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingSchemaFeature(error, const {'shared_journal_id'})) {
        _supportsSharedCopySchemaCache = false;
        _log('schema_compatibility_detected', {
          'context': 'journal_shares_probe',
          'supports_shared_copy_schema': false,
          'code': error.code,
          'message': error.message,
        });
        return false;
      }
      rethrow;
    }
  }

  void _log(String event, Map<String, Object?> data) {
    developer.log(
      'journal_encryption event=$event data=$data',
      name: 'journal_encryption',
    );
  }

  bool _isMissingSchemaFeature(
    PostgrestException error,
    Set<String> expectedNames,
  ) {
    final code = error.code?.toLowerCase() ?? '';
    final message = '${error.message} ${error.details} ${error.hint}'
        .toLowerCase();
    if (code == '42703' || code == 'pgrst204' || code == 'pgrst202') {
      return expectedNames.any(message.contains);
    }
    return false;
  }
}
