import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/journal/journal_canvas_layer.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';
import 'package:mind_buddy/features/journal/journal_local_repository.dart';
import 'package:mind_buddy/features/journal/journal_page_codec.dart';
import 'package:mind_buddy/features/journal/journal_page_widgets.dart';
import 'package:mind_buddy/services/journal_access_service.dart';
import 'package:mind_buddy/services/journal_document_codec.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/username_resolver_service.dart';
import 'package:mind_buddy/services/block_service.dart';
import 'package:mind_buddy/services/journal_encryption_service.dart';
import 'package:mind_buddy/services/journal_repository.dart';

class JournalViewScreen extends StatefulWidget {
  const JournalViewScreen({
    super.key,
    required this.journalId,
    this.initialEntry,
  });

  final String journalId;
  final Map<String, dynamic>? initialEntry;

  @override
  State<JournalViewScreen> createState() => _JournalViewScreenState();
}

class _JournalViewScreenState extends State<JournalViewScreen> {
  static const _repliesTable = 'journal_share_replies';
  late Future<Map<String, dynamic>?> _future;
  Map<String, dynamic>? _loaded;
  bool _useSeededEntry = true;
  String? _resolvedJournalId;
  bool _isOwner = true;
  bool _shareBusy = false;
  bool _recipientCanComment = false;
  bool _recipientMediaVisible = true;
  bool _repliesBlockedByBlock = false;
  String? _journalOwnerId;
  Set<String> _blockedRecipientIds = <String>{};
  List<Map<String, dynamic>> _shareRecipients = [];
  List<Map<String, dynamic>> _replies = [];
  static const _recentShareCacheKey = 'recent_share_usernames_v1';
  Timer? _replyRefreshTimer;
  final JournalRepository _journalRepository = JournalRepository();
  final JournalLocalRepository _journalLocalRepository =
      JournalLocalRepository();
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  String get _activeJournalId => _resolvedJournalId ?? widget.journalId;
  bool _isLocalPrivateJournalId(String id) => id.startsWith('journal-');

  @override
  void dispose() {
    _pageController.dispose();
    _replyRefreshTimer?.cancel();
    super.dispose();
  }

  void _shareLog(String event, [Map<String, dynamic> data = const {}]) {
    if (!kDebugMode) return;
    final line = 'journal_share event=$event data=$data';
    developer.log(line, name: 'journal_share');
    debugPrint(line);
  }

  String _normalizeUsernameForLookup(String raw) {
    var value = raw.trim().toLowerCase();
    while (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value;
  }

  bool _isUserSearchSchemaOrRpcIssue(PostgrestException e) {
    const knownCodes = <String>{
      'PGRST202', // function missing/overloaded mismatch
      '42883', // undefined function
      '42703', // undefined column
      '42P01', // undefined table
      '42501', // insufficient_privilege / RLS
    };
    if (knownCodes.contains(e.code)) return true;
    final msg = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
    return msg.contains('find_user_by_username') ||
        msg.contains('profiles') ||
        msg.contains('permission') ||
        msg.contains('row-level security');
  }

  bool _isMissingRepliesRpcInSchemaCache(Object error) {
    if (error is! PostgrestException) return false;
    if (error.code == 'PGRST202' || error.code == '42883') return true;
    final msg = '${error.message} ${error.details} ${error.hint}'.toLowerCase();
    return msg.contains('schema cache') ||
        msg.contains('get_journal_replies_for_entry');
  }

  bool _isMissingEntryViewRpcInSchemaCache(Object error) {
    if (error is! PostgrestException) return false;
    if (error.code == 'PGRST202' || error.code == '42883') return true;
    final msg = '${error.message} ${error.details} ${error.hint}'.toLowerCase();
    return msg.contains('schema cache') ||
        msg.contains('get_journal_entry_for_view');
  }

  Future<Map<String, dynamic>?> _mapRpcEntryResult(dynamic raw) async {
    if (raw is List) {
      if (raw.isEmpty) return null;
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchEntryForView(String journalId) async {
    if (_isLocalPrivateJournalId(journalId)) {
      debugPrint(
        'JOURNAL_REMOTE_CALL_BLOCKED reason=private_flow method=_fetchEntryForView id=$journalId',
      );
      return null;
    }
    final variants = <Map<String, dynamic>>[
      {'p_journal_id': journalId},
      {'journal_id': journalId},
      {'p_entry_id': journalId},
      {'entry_id': journalId},
    ];
    PostgrestException? lastPgError;
    for (final params in variants) {
      try {
        final raw = await Supabase.instance.client.rpc(
          'get_journal_entry_for_view',
          params: params,
        );
        return _mapRpcEntryResult(raw);
      } on PostgrestException catch (e) {
        lastPgError = e;
        if (!_isMissingEntryViewRpcInSchemaCache(e)) rethrow;
      }
    }
    if (lastPgError != null) throw lastPgError;
    return null;
  }

  Future<Map<String, dynamic>?> _fetchEntryFromTableCandidate({
    required String table,
    required String journalId,
  }) async {
    if (_isLocalPrivateJournalId(journalId)) {
      debugPrint(
        'JOURNAL_REMOTE_CALL_BLOCKED reason=private_flow method=_fetchEntryFromTableCandidate id=$journalId',
      );
      return null;
    }
    final row = await Supabase.instance.client
        .from(table)
        .select()
        .eq('id', journalId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>?> _fetchEntryByTableFallback(
    String journalId,
  ) async {
    if (_isLocalPrivateJournalId(journalId)) {
      debugPrint(
        'JOURNAL_REMOTE_CALL_BLOCKED reason=private_flow method=_fetchEntryByTableFallback id=$journalId',
      );
      return null;
    }
    const candidates = <String>['journals', 'journal_entries'];
    for (final table in candidates) {
      try {
        _shareLog('legacy_read_attempted', {
          'table': table,
          'journal_id': journalId,
        });
        final row = await _fetchEntryFromTableCandidate(
          table: table,
          journalId: journalId,
        );
        _shareLog('entry_table_fallback_probe', {
          'table': table,
          'journal_id': journalId,
          'returned': row != null,
        });
        if (row != null) return row;
      } on PostgrestException catch (e) {
        _shareLog('entry_table_fallback_probe_fail', {
          'table': table,
          'journal_id': journalId,
          'code': e.code,
          'message': e.message,
          'details': e.details,
          'hint': e.hint,
        });
      } catch (e) {
        _shareLog('entry_table_fallback_probe_fail', {
          'table': table,
          'journal_id': journalId,
          'error': e.toString(),
        });
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchEntryViaShareJoinFallback(
    String incomingId,
  ) async {
    if (_isLocalPrivateJournalId(incomingId)) {
      debugPrint(
        'JOURNAL_REMOTE_CALL_BLOCKED reason=private_flow method=_fetchEntryViaShareJoinFallback id=$incomingId',
      );
      return null;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    Future<Map<String, dynamic>?> runShareQuery({
      String? journalId,
      String? shareRowId,
      required String mode,
    }) async {
      try {
        var query = Supabase.instance.client
            .from('journal_shares')
            .select(
              'id,journal_id,shared_journal_id,sender_id,recipient_id,expires_at,'
              'shared_journal:shared_journal_id(*),source_journal:journal_id(*)',
            );
        if (journalId != null && journalId.isNotEmpty) {
          query = query.eq('journal_id', journalId);
        }
        if (shareRowId != null && shareRowId.isNotEmpty) {
          query = query.eq('id', shareRowId);
        }
        final row = await query
            .or('recipient_id.eq.${user.id},sender_id.eq.${user.id}')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row == null) {
          _shareLog('entry_share_join_fallback', {
            'mode': mode,
            'incoming_id': incomingId,
            'matched': false,
          });
          return null;
        }
        final map = Map<String, dynamic>.from(row as Map);
        final journal = switch ((
          map['shared_journal'],
          map['source_journal'],
        )) {
          (Map shared, _) => shared,
          (_, Map source) => source,
          _ => null,
        };
        if (journal == null) {
          _shareLog('entry_share_join_fallback', {
            'mode': mode,
            'incoming_id': incomingId,
            'matched': true,
            'journal_embedded': false,
          });
          return null;
        }
        _shareLog('entry_share_join_fallback', {
          'mode': mode,
          'incoming_id': incomingId,
          'matched': true,
          'journal_embedded': true,
          'resolved_journal_id': map['journal_id']?.toString(),
          'resolved_shared_journal_id': map['shared_journal_id']?.toString(),
          'share_row_id': map['id']?.toString(),
        });
        return Map<String, dynamic>.from(journal);
      } on PostgrestException catch (e) {
        _shareLog('entry_share_join_fallback_fail', {
          'mode': mode,
          'incoming_id': incomingId,
          'code': e.code,
          'message': e.message,
          'details': e.details,
          'hint': e.hint,
        });
        return null;
      }
    }

    final byJournalId = await runShareQuery(
      journalId: incomingId,
      mode: 'by_journal_id',
    );
    if (byJournalId != null) return byJournalId;

    final byShareRowId = await runShareQuery(
      shareRowId: incomingId,
      mode: 'by_share_row_id',
    );
    if (byShareRowId != null) return byShareRowId;

    return null;
  }

  Future<Map<String, dynamic>?> _lookupRecipient(String typedInput) async {
    final normalized = _normalizeUsernameForLookup(typedInput);
    _shareLog('share_user_lookup_start', {'input': typedInput});
    _shareLog('share_user_lookup_normalized', {
      'normalized': normalized,
      'has_at': typedInput.trim().startsWith('@'),
    });
    if (normalized.isEmpty) return null;

    try {
      _shareLog('share_user_lookup_rpc_query', {
        'rpc': 'find_user_by_username',
        'params': {'input_username': normalized},
      });
      final mapped = await UsernameResolverService.instance.findUserByUsername(
        normalized,
      );
      _shareLog('share_user_lookup_rows', {
        'count': mapped == null ? 0 : 1,
        'via': 'rpc',
      });
      _shareLog('share_user_lookup_selected', mapped ?? const {});
      return mapped;
    } on PostgrestException catch (e) {
      _shareLog('share_user_lookup_error', {
        'code': e.code,
        'message': e.message,
        'details': e.details,
        'hint': e.hint,
      });
      if (!_isUserSearchSchemaOrRpcIssue(e)) rethrow;
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    _replyRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted || _loaded == null) return;
      await _refreshShareAndReplies();
    });
  }

  Future<void> _refreshShareAndReplies() async {
    try {
      await _loadShareState();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _load() async {
    if (_isLocalPrivateJournalId(widget.journalId)) {
      return _loadPrivateEntryLocal(widget.journalId);
    }
    _shareLog('entry_open_attempt', {'incoming_id': widget.journalId});
    if (_useSeededEntry && widget.initialEntry != null) {
      final seeded = await _hydrateForViewer(
        Map<String, dynamic>.from(widget.initialEntry!),
      );
      final seededId = seeded['id']?.toString() ?? '';
      if (seededId.isNotEmpty) {
        _resolvedJournalId = seededId;
      }
      try {
        seeded['text'] = await JournalAccessService.hydrateMediaSignedUrls(
          entryId: _activeJournalId,
          rawText: seeded['text']?.toString() ?? '',
        );
      } catch (_) {}
      await _resolveDoodlePreview(seeded);
      _loaded = seeded;
      final user = Supabase.instance.client.auth.currentUser;
      _journalOwnerId = seeded['user_id']?.toString();
      _isOwner = user != null && user.id == seeded['user_id'];
      _shareLog('entry_identity', {
        'incoming_id': widget.journalId,
        'resolved_journal_id': _activeJournalId,
        'viewer_user_id': user?.id,
        'owner_user_id': _journalOwnerId,
        'is_owner': _isOwner,
        'source': 'route_extra_seed',
      });
      try {
        await _loadShareState();
      } catch (_) {}
      _useSeededEntry = false;
      return seeded;
    }

    var resolvedJournalId = widget.journalId;
    Map<String, dynamic>? data;
    final viewerUserId = Supabase.instance.client.auth.currentUser?.id;
    _shareLog('entry_rpc_call', {'p_journal_id': resolvedJournalId});
    try {
      data = await _fetchEntryForView(resolvedJournalId);
      _shareLog('entry_rpc_ok', {'returned': data != null});
    } catch (e) {
      if (e is PostgrestException) {
        _shareLog('entry_rpc_fail', {
          'code': e.code,
          'message': e.message,
          'details': e.details,
          'hint': e.hint,
        });
      } else {
        _shareLog('entry_rpc_fail', {'error': e.toString()});
      }
      if (_isMissingEntryViewRpcInSchemaCache(e)) {
        _shareLog('entry_fetch_source_fallback', {
          'source': 'table',
          'reason': 'rpc_missing_schema_cache',
          'incoming_id': widget.journalId,
        });
        data = await _fetchEntryByTableFallback(resolvedJournalId);
        data ??= await _fetchEntryViaShareJoinFallback(resolvedJournalId);
      } else {
        rethrow;
      }
    }

    if (data == null) {
      try {
        var sharesMatchByJournalIdCount = 0;
        var sharesMatchByShareRowIdCount = 0;
        List<Map<String, dynamic>> byShareRows = const <Map<String, dynamic>>[];
        try {
          final byJournalRows = await Supabase.instance.client
              .from('journal_shares')
              .select('id,journal_id')
              .eq('journal_id', widget.journalId)
              .limit(20);
          sharesMatchByJournalIdCount = (byJournalRows as List).length;
        } catch (_) {}
        try {
          final shareRows = await Supabase.instance.client
              .from('journal_shares')
              .select('id,journal_id')
              .eq('id', widget.journalId)
              .limit(20);
          byShareRows = (shareRows as List).cast<Map<String, dynamic>>();
          sharesMatchByShareRowIdCount = byShareRows.length;
        } catch (_) {}
        _shareLog('entry_not_found_probe', {
          'widgetJournalId': widget.journalId,
          'entryTableTried': 'journals',
          'entrySelectFilter': 'id=eq.${widget.journalId}',
          'sharesMatchByJournalIdCount': sharesMatchByJournalIdCount,
          'sharesMatchByShareRowIdCount': sharesMatchByShareRowIdCount,
        });
        if (sharesMatchByShareRowIdCount > 0) {
          final fixedJournalId = byShareRows.first['journal_id']?.toString();
          if (fixedJournalId != null && fixedJournalId.isNotEmpty) {
            resolvedJournalId = fixedJournalId;
            _shareLog('entry_rpc_call', {'p_journal_id': resolvedJournalId});
            try {
              data = await _fetchEntryForView(resolvedJournalId);
              _shareLog('entry_rpc_ok', {'returned': data != null});
            } catch (e) {
              if (e is PostgrestException) {
                _shareLog('entry_rpc_fail', {
                  'code': e.code,
                  'message': e.message,
                  'details': e.details,
                  'hint': e.hint,
                });
              } else {
                _shareLog('entry_rpc_fail', {'error': e.toString()});
              }
              if (_isMissingEntryViewRpcInSchemaCache(e)) {
                data = await _fetchEntryByTableFallback(resolvedJournalId);
                data ??= await _fetchEntryViaShareJoinFallback(
                  resolvedJournalId,
                );
              } else {
                rethrow;
              }
            }
          }
        }
      } catch (e) {
        _shareLog('entry_not_found_probe_error', {
          'widgetJournalId': widget.journalId,
          'error': e.toString(),
        });
      }
      if (data == null) {
        data = await _journalRepository.fetchJournalForEditor(
          resolvedJournalId,
        );
        _shareLog('entry_repository_fallback', {
          'journal_id': resolvedJournalId,
          'returned': data != null,
        });
      }
      if (data == null) {
        return null;
      }
    }

    data = await _hydrateForViewer(data);
    _resolvedJournalId = resolvedJournalId;
    try {
      data['text'] = await JournalAccessService.hydrateMediaSignedUrls(
        entryId: _activeJournalId,
        rawText: data['text']?.toString() ?? '',
      );
    } catch (_) {}
    await _resolveDoodlePreview(data);
    _loaded = data;
    final user = Supabase.instance.client.auth.currentUser;
    _journalOwnerId = data['user_id']?.toString();
    _isOwner = user != null && user.id == data['user_id'];
    _shareLog('entry_identity', {
      'incoming_id': widget.journalId,
      'resolved_journal_id': _activeJournalId,
      'viewer_user_id': viewerUserId,
      'owner_user_id': _journalOwnerId,
      'is_owner': _isOwner,
      'source': widget.journalId == _activeJournalId
          ? (_isOwner ? 'owned' : 'shared')
          : 'share_row_id_corrected',
    });
    try {
      await _loadShareState();
    } catch (_) {}
    return data;
  }

  Future<Map<String, dynamic>> _hydrateForViewer(
    Map<String, dynamic> row,
  ) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final ownerId = row['user_id']?.toString();
    final isOwner = currentUserId != null && currentUserId == ownerId;
    _shareLog('entry_read_attempt', {
      'journal_id': row['id']?.toString(),
      'is_owner': isOwner,
      'is_encrypted': row['is_encrypted'] == true,
    });
    if (!isOwner && row['is_encrypted'] == true) {
      _shareLog('entry_open_failed', {
        'journal_id': row['id']?.toString(),
        'reason': 'encrypted_source_requires_shared_copy',
      });
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.missingKey,
        'This private source entry is encrypted. Shared access requires a readable shared copy.',
      );
    }
    return _journalRepository.hydratePrivateRow(
      row,
      allowMigration: isOwner,
      cacheResult: true,
    );
  }

  Future<void> _resolveDoodlePreview(Map<String, dynamic> data) async {
    if (_isLocalPrivateJournalId(_activeJournalId)) {
      debugPrint('JOURNAL_PRIVATE_DOODLE_REMOTE_BLOCKED id=$_activeJournalId');
      data['doodle_preview_url'] = null;
      return;
    }
    final path = data['doodle_storage_path']?.toString();
    final updatedRaw = data['doodle_updated_at']?.toString();
    final updatedAt = updatedRaw == null ? null : DateTime.tryParse(updatedRaw);
    try {
      final url = await JournalAccessService.resolveDoodleUrl(
        entryId: _activeJournalId,
        storagePath: path,
        updatedAt: updatedAt,
      );
      data['doodle_preview_url'] = url;
    } catch (error) {
      _shareLog('entry_optional_probe_failed', {
        'probe': 'doodle_preview',
        'journal_id': _activeJournalId,
        'error': error.toString(),
      });
      data['doodle_preview_url'] = null;
    }
  }

  Future<void> _deleteEntry() async {
    final row = _loaded;
    if (row == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    if (_isLocalPrivateJournalId(_activeJournalId)) {
      await _journalLocalRepository.deleteJournal(_activeJournalId);
      if (!mounted) return;
      context.pop(true);
      return;
    }

    await Supabase.instance.client
        .from('journals')
        .delete()
        .eq('id', row['id']);

    if (!mounted) return;
    context.pop(true);
  }

  Future<void> _loadShareState() async {
    if (_isLocalPrivateJournalId(_activeJournalId)) {
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (_isOwner) {
        final rows = await Supabase.instance.client
            .from('journal_shares')
            .select(
              'id, sender_id, recipient_id, can_comment, media_visible, expires_at, created_at',
            )
            .eq('journal_id', _activeJournalId)
            .eq('sender_id', user.id)
            .or('expires_at.is.null,expires_at.gt.$nowIso')
            .order('created_at', ascending: true);
        final recipientRows = (rows as List).cast<Map<String, dynamic>>();
        final recipientIds = recipientRows
            .map((row) => row['recipient_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final resolved = await UsernameResolverService.instance
            .resolveUsernamesByIdsDetailed(recipientIds);
        _shareRecipients = recipientRows.map((row) {
          final recipientId = row['recipient_id']?.toString() ?? '';
          final username = resolved.usernamesById[recipientId] ?? '';
          final fallback = resolved.hadError
              ? '@unavailable'
              : (resolved.missingIds.contains(recipientId)
                    ? '@deleted'
                    : '@unavailable');
          return <String, dynamic>{
            ...row,
            'profile': <String, dynamic>{'username': username},
            'recipient_username': username,
            'recipient_fallback': fallback,
          };
        }).toList();
        _blockedRecipientIds = await BlockService.instance.listBlockedIds();
        _repliesBlockedByBlock = false;
      } else {
        _blockedRecipientIds = <String>{};
        final row = await Supabase.instance.client
            .from('journal_shares')
            .select('sender_id, can_comment, media_visible, expires_at')
            .eq('journal_id', _activeJournalId)
            .eq('recipient_id', user.id)
            .or('expires_at.is.null,expires_at.gt.$nowIso')
            .maybeSingle();
        _recipientCanComment = row?['can_comment'] == true;
        _recipientMediaVisible = row?['media_visible'] != false;
        final ownerId = _journalOwnerId ?? '';
        if (ownerId.isNotEmpty) {
          final status = await BlockService.instance.getBlockStatusWithUser(
            ownerId,
          );
          _repliesBlockedByBlock = status.blockedEither;
          if (_repliesBlockedByBlock) {
            _recipientCanComment = false;
          }
        } else {
          _repliesBlockedByBlock = false;
        }
      }
      await _loadReplies();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadReplies() async {
    if (_isLocalPrivateJournalId(_activeJournalId)) {
      return;
    }
    final viewerUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _shareLog('replies_fetch_start', {
      'journal_id': _activeJournalId,
      'entry_id': _activeJournalId,
      'viewer_user_id': viewerUserId,
      'filter': 'eq(journal_id,${_activeJournalId}) order(created_at,asc)',
      'role': _isOwner ? 'owner' : 'recipient',
    });
    _shareLog('replies_query', {
      'table': _repliesTable,
      'filter': 'journal_id == ${_activeJournalId}',
      'order': 'created_at asc',
    });
    _shareLog('replies_query_identity', {
      'activeJournalId': _activeJournalId,
      'journal_id_used_for_replies': _activeJournalId,
    });
    if (_isOwner) {
      _shareLog('journal_replies_owner_fetch_start', {
        'journal_id': _activeJournalId,
      });
    }
    try {
      List<Map<String, dynamic>> replyRows;
      try {
        _shareLog('replies_rpc_call', {
          'fn': 'get_journal_replies_for_entry',
          'p_journal_id': _activeJournalId,
          'p_journal_id_type': _activeJournalId.runtimeType.toString(),
        });
        final rpcRows = await Supabase.instance.client
            .rpc(
              'get_journal_replies_for_entry',
              params: {'p_journal_id': _activeJournalId},
            )
            .select('id,journal_id,author_id,text,created_at');
        replyRows = (rpcRows as List).cast<Map<String, dynamic>>();
        _shareLog('replies_fetch_source', {'source': 'rpc'});
      } catch (rpcError) {
        if (!_isMissingRepliesRpcInSchemaCache(rpcError)) rethrow;
        _shareLog('replies_fetch_source_fallback', {
          'source': 'table',
          'reason': 'rpc_missing_schema_cache',
          'rpc_error': rpcError.toString(),
        });
        final rows = await Supabase.instance.client
            .from(_repliesTable)
            .select('id,journal_id,author_id,text,created_at')
            .eq('journal_id', _activeJournalId)
            .order('created_at', ascending: true);
        replyRows = (rows as List).cast<Map<String, dynamic>>();
        _shareLog('replies_fetch_source', {'source': 'table'});
      }
      _shareLog('replies_fetch_keys', {
        'table': _repliesTable,
        'keys': replyRows.isEmpty
            ? const <String>[]
            : replyRows.first.keys.map((e) => e.toString()).toList(),
      });
      if (replyRows.isEmpty) {
        _shareLog('empty_replies_result', {
          'entry_id': _activeJournalId,
          'viewer_user_id': viewerUserId,
          'filter': 'eq(journal_id,${_activeJournalId})',
        });
        try {
          final exactCount = await Supabase.instance.client
              .from(_repliesTable)
              .select()
              .eq('journal_id', _activeJournalId);
          _shareLog('replies_empty_probe_count', {
            'table': _repliesTable,
            'journal_id': _activeJournalId,
            'count': exactCount.length,
          });
        } catch (probeError) {
          _shareLog('replies_empty_probe_count_error', {
            'table': _repliesTable,
            'journal_id': _activeJournalId,
            'error': probeError.toString(),
          });
        }
        if (_shareRecipients.isNotEmpty) {
          final shareRowIds = _shareRecipients
              .map((r) => r['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          if (shareRowIds.isNotEmpty) {
            try {
              final wrongKeyCount = await Supabase.instance.client
                  .from(_repliesTable)
                  .select()
                  .inFilter('journal_id', shareRowIds);
              _shareLog('replies_wrong_fk_probe', {
                'table': _repliesTable,
                'probe': 'journal_id IN share_row_ids',
                'share_row_ids_count': shareRowIds.length,
                'count': wrongKeyCount.length,
              });
            } catch (wrongFkError) {
              _shareLog('replies_wrong_fk_probe_error', {
                'error': wrongFkError.toString(),
              });
            }
          }
        }
      }
      final firstRowSummary = replyRows.isEmpty
          ? null
          : <String, dynamic>{
              'id': replyRows.first['id'],
              'author_id': replyRows.first['author_id'],
              'created_at': replyRows.first['created_at'],
            };
      _shareLog('replies_count', {
        'count': replyRows.length,
        'first_row': firstRowSummary,
      });
      if (_isOwner) {
        final sampleKeys = replyRows.isEmpty
            ? <String>[]
            : replyRows.first.keys.map((k) => k.toString()).toList();
        _shareLog('journal_replies_owner_rows', {
          'count': replyRows.length,
          'sample_keys': sampleKeys,
        });
      }
      _shareLog('reply_query_count', {
        'journal_id': _activeJournalId,
        'count': replyRows.length,
      });
      final authorIds = replyRows
          .map((row) => row['author_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final resolved = await UsernameResolverService.instance
          .resolveUsernamesByIdsDetailed(authorIds);
      _replies = replyRows.map((row) {
        final authorId = row['author_id']?.toString() ?? '';
        final username = resolved.usernamesById[authorId] ?? '';
        final fallback = resolved.hadError
            ? '@unavailable'
            : (resolved.missingIds.contains(authorId)
                  ? '@deleted'
                  : '@unavailable');
        final replyText = (row['text'] ?? '').toString();
        return <String, dynamic>{
          ...row,
          'reply_text': replyText,
          'author_username': username,
          'author_fallback': fallback,
        };
      }).toList();
      _shareLog('reply_mapping_result', {
        'source_count': replyRows.length,
        'mapped_count': _replies.length,
        'removed': replyRows.length - _replies.length,
      });
      _shareLog('replies_fetch_ok', {
        'count': _replies.length,
        'role': _isOwner ? 'owner' : 'recipient',
      });
      _shareLog('replies_render_mode', {
        'mode': _isOwner ? 'owner' : 'recipient',
        'count': _replies.length,
      });
    } catch (e) {
      _shareLog('replies_fetch_fail', {'error': e.toString()});
      _replies = <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> _loadPrivateEntryLocal(String journalId) async {
    debugPrint('JOURNAL_PRIVATE_VIEW_LOAD_LOCAL id=$journalId');
    final row =
        widget.initialEntry != null &&
            (widget.initialEntry!['id']?.toString() ?? '') == journalId
        ? Map<String, dynamic>.from(widget.initialEntry!)
        : await _journalLocalRepository.loadJournalForEditor(journalId);
    if (row == null) return null;
    _resolvedJournalId = journalId;
    _loaded = row;
    _journalOwnerId = row['user_id']?.toString();
    _isOwner = true;
    row['doodle_preview_url'] = null;
    return row;
  }

  Future<List<Map<String, dynamic>>> _loadRecentRecipientsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentShareCacheKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveRecentRecipient(Map<String, dynamic> recipient) async {
    final id = recipient['id']?.toString() ?? '';
    final username = recipient['username']?.toString() ?? '';
    if (id.isEmpty || username.isEmpty) return;
    final current = await _loadRecentRecipientsFromCache();
    final next = <Map<String, dynamic>>[
      {'id': id, 'username': username},
      ...current.where((row) => row['id']?.toString() != id),
    ];
    final trimmed = next.take(20).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentShareCacheKey, jsonEncode(trimmed));
  }

  Future<List<Map<String, dynamic>>> _loadRecentRecipientsFromDb() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return <Map<String, dynamic>>[];
    final rows = await Supabase.instance.client
        .from('journal_shares')
        .select('recipient_id, created_at')
        .eq('journal_id', _activeJournalId)
        .eq('sender_id', user.id)
        .order('created_at', ascending: false)
        .limit(30);
    final recipientIds = <String>[];
    for (final raw in (rows as List)) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['recipient_id']?.toString() ?? '';
      if (id.isEmpty || recipientIds.contains(id)) continue;
      recipientIds.add(id);
    }
    if (recipientIds.isEmpty) return <Map<String, dynamic>>[];
    final usernamesById = await UsernameResolverService.instance
        .resolveUsernamesByIds(recipientIds);
    final list = <Map<String, dynamic>>[];
    for (final id in recipientIds) {
      final username = usernamesById[id] ?? '';
      if (id.isEmpty || username.isEmpty) continue;
      list.add({'id': id, 'username': username});
    }
    return list;
  }

  Future<void> _openShareSheet() async {
    if (!_isOwner) return;
    _shareLog('share_sheet_open_start', {'entry_id': _activeJournalId});
    await _loadShareState();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final count = _shareRecipients.length;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Page Privacy', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                count == 0
                    ? 'Private (only you can see this page)'
                    : 'Shared with $count ${count == 1 ? 'person' : 'people'}',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (count > 0)
                Column(
                  children: _shareRecipients.map((r) {
                    final profile = r['profile'] as Map<String, dynamic>?;
                    final username = (profile?['username'] ?? '').toString();
                    final fallback = (r['recipient_fallback'] ?? '@unavailable')
                        .toString();
                    final canComment = r['can_comment'] == true;
                    final recipientId = r['recipient_id']?.toString() ?? '';
                    final isBlocked = _blockedRecipientIds.contains(
                      recipientId,
                    );
                    final expiresAt = r['expires_at']?.toString();
                    final expiresLabel = expiresAt == null
                        ? 'Forever'
                        : DateFormat(
                            'MMM d',
                          ).format(DateTime.parse(expiresAt).toLocal());
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              username.isEmpty ? fallback : '@$username',
                            ),
                          ),
                          if (isBlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Theme.of(
                                  ctx,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                              child: const Text('Blocked'),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${canComment ? 'View + reply' : 'View only'} • $expiresLabel',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'remove') {
                            await _removeRecipient(r);
                            return;
                          }
                          if (value == 'block') {
                            await _blockRecipient(recipientId);
                            return;
                          }
                          if (value == 'unblock') {
                            await _unblockRecipient(recipientId);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Text('Remove share'),
                          ),
                          if (isBlocked)
                            const PopupMenuItem<String>(
                              value: 'unblock',
                              child: Text('Unblock user'),
                            )
                          else
                            const PopupMenuItem<String>(
                              value: 'block',
                              child: Text('Block user'),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              if (count > 0) const Divider(),
              FilledButton.icon(
                onPressed: _shareBusy
                    ? null
                    : () async {
                        final shared = await _addRecipient();
                        if (shared && ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Share with someone'),
              ),
              const SizedBox(height: 8),
              Text(
                'Shared pages stay private inside MyBrainBubble.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              FutureBuilder<SubscriptionInfo>(
                future: SubscriptionLimits.fetchForCurrentUser(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  if (info == null) return const SizedBox.shrink();
                  return Text(
                    SubscriptionPlanCatalog.sharesPerDayHelpText(info.plan),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _blockRecipient(String recipientId) async {
    if (recipientId.isEmpty) return;
    await BlockService.instance.blockUser(recipientId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User blocked.')));
    await _loadShareState();
    if (mounted) setState(() {});
  }

  Future<void> _unblockRecipient(String recipientId) async {
    if (recipientId.isEmpty) return;
    await BlockService.instance.unblockUser(recipientId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User unblocked.')));
    await _loadShareState();
    if (mounted) setState(() {});
  }

  Future<bool> _addRecipient() async {
    if (_shareBusy) return false;
    final info = await SubscriptionLimits.fetchForCurrentUser();
    if (!info.plan.canShareEntries) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sharing is not available on your current plan.'),
          ),
        );
      }
      return false;
    }
    if (info.sharesPerDay >= 0) {
      final usedShares = await JournalShareUsageTracker.todayCount();
      if (usedShares >= info.sharesPerDay) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shares per day reached on ${info.planName}: ${info.sharesPerDay}/${info.sharesPerDay}.',
              ),
            ),
          );
        }
        return false;
      }
    }
    final usernameController = TextEditingController();
    final usernameFocusNode = FocusNode();
    String normalizeName(String value) =>
        value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
    List<Map<String, dynamic>> dedupeByUsername(
      Iterable<Map<String, dynamic>> items,
    ) {
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final item in items) {
        final username = (item['username'] ?? '').toString();
        final key = normalizeName(username);
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        out.add({'id': item['id'], 'username': username});
      }
      return out;
    }

    final cachedRecent = await _loadRecentRecipientsFromCache();
    List<Map<String, dynamic>> recentRecipients = dedupeByUsername(
      cachedRecent,
    );
    final blockedIds = await BlockService.instance.listBlockedIds();
    try {
      final dbRecent = await _loadRecentRecipientsFromDb();
      if (dbRecent.isNotEmpty) {
        recentRecipients = dedupeByUsername(dbRecent);
      }
    } catch (_) {}
    List<Map<String, dynamic>> suggestions = <Map<String, dynamic>>[];
    Map<String, dynamic>? selectedRecipient;
    bool searching = false;
    String? pickerError;
    String? blockNotice;
    bool shareDisabledByBlock = false;
    bool canComment = false;
    bool mediaVisible = true;
    var queryToken = 0;
    Timer? lookupDebounce;

    Future<void> syncSelectedBlockState(
      StateSetter setModalState,
      Map<String, dynamic>? row,
    ) async {
      if (row == null) {
        setModalState(() {
          blockNotice = null;
          shareDisabledByBlock = false;
        });
        return;
      }
      final recipientId = row['id']?.toString() ?? '';
      if (recipientId.isEmpty) {
        setModalState(() {
          blockNotice = null;
          shareDisabledByBlock = false;
        });
        return;
      }
      final status = await BlockService.instance.getBlockStatusWithUser(
        recipientId,
      );
      setModalState(() {
        if (status.blockedByMe) {
          blockNotice = 'You’ve blocked this user. Unblock to share.';
          shareDisabledByBlock = true;
        } else if (status.blockedByThem) {
          blockNotice = 'You can’t share with this user.';
          shareDisabledByBlock = true;
        } else {
          blockNotice = null;
          shareDisabledByBlock = false;
        }
      });
    }

    Future<void> runSuggestionQuery(
      String raw,
      StateSetter setModalState,
    ) async {
      final normalized = _normalizeUsernameForLookup(raw);
      if (normalized.length < 2) {
        setModalState(() {
          suggestions = <Map<String, dynamic>>[];
          searching = false;
          pickerError = null;
        });
        return;
      }
      if (selectedRecipient != null &&
          _normalizeUsernameForLookup(
                selectedRecipient?['username']?.toString() ?? '',
              ) !=
              normalized) {
        selectedRecipient = null;
        blockNotice = null;
        shareDisabledByBlock = false;
      }
      if (normalized.isEmpty) {
        setModalState(() {
          suggestions = <Map<String, dynamic>>[];
          searching = false;
          pickerError = null;
        });
        return;
      }

      final token = ++queryToken;
      setModalState(() {
        searching = true;
        pickerError = null;
      });
      _shareLog('share_user_lookup_query', {
        'rpc': 'search_usernames',
        'query': normalized,
      });
      try {
        final rows = await UsernameResolverService.instance.searchUsernames(
          normalized,
          maxResults: 8,
        );
        if (token != queryToken) return;
        _shareLog('share_user_lookup_rows', {'count': rows.length});
        final fromRecent = recentRecipients
            .where(
              (row) => (row['username'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(normalized),
            )
            .toList();
        final merged =
            dedupeByUsername(<Map<String, dynamic>>[
              ...fromRecent,
              ...rows.where((row) {
                final id = row['id']?.toString() ?? '';
                return fromRecent.every((r) => r['id']?.toString() != id);
              }),
            ]).where((row) {
              final username = (row['username'] ?? '').toString();
              return normalizeName(username) != normalized;
            }).toList();
        setModalState(() {
          suggestions = merged.take(10).toList();
          searching = false;
        });
      } on PostgrestException catch (e) {
        if (token != queryToken) return;
        _shareLog('share_user_lookup_error', {
          'code': e.code,
          'message': e.message,
          'details': e.details,
          'hint': e.hint,
        });
        setModalState(() {
          suggestions = <Map<String, dynamic>>[];
          searching = false;
          pickerError = 'Couldn’t search users right now.';
        });
      }
    }

    _shareLog('share_sheet_open_start', {'entry_id': _activeJournalId});
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (usernameFocusNode.canRequestFocus) {
            usernameFocusNode.requestFocus();
          }
        });
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final insets = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, insets + 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share with someone',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      focusNode: usernameFocusNode,
                      autofocus: true,
                      onChanged: (value) {
                        lookupDebounce?.cancel();
                        lookupDebounce = Timer(
                          const Duration(milliseconds: 220),
                          () => runSuggestionQuery(value, setModalState),
                        );
                      },
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: '@alex',
                        errorText: pickerError,
                      ),
                    ),
                    if (_normalizeUsernameForLookup(
                          usernameController.text,
                        ).isEmpty &&
                        recentRecipients.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Previously shared with',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            ...recentRecipients.take(10).map((item) {
                              final username = (item['username'] ?? '')
                                  .toString();
                              final id = item['id']?.toString() ?? '';
                              final isBlocked = blockedIds.contains(id);
                              if (username.isEmpty || id.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('@$username'),
                                subtitle: isBlocked
                                    ? const Text('Blocked')
                                    : null,
                                onTap: () async {
                                  usernameController.text = '@$username';
                                  usernameController
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(
                                      offset: usernameController.text.length,
                                    ),
                                  );
                                  setModalState(() {
                                    selectedRecipient = {
                                      'id': item['id'],
                                      'username': username,
                                    };
                                    pickerError = null;
                                    suggestions = <Map<String, dynamic>>[];
                                  });
                                  await syncSelectedBlockState(
                                    setModalState,
                                    selectedRecipient,
                                  );
                                  usernameFocusNode.requestFocus();
                                  _shareLog('share_lookup_ok', {
                                    'recipient_id': id,
                                    'username': username,
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (suggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            final id = item['id']?.toString() ?? '';
                            final username = (item['username'] ?? '')
                                .toString();
                            final selected =
                                selectedRecipient?['id']?.toString() == id;
                            return ListTile(
                              dense: true,
                              title: Text('@$username'),
                              trailing: selected
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () async {
                                setModalState(() {
                                  selectedRecipient = {
                                    'id': id,
                                    'username': username,
                                  };
                                  pickerError = null;
                                  suggestions = <Map<String, dynamic>>[];
                                });
                                usernameController.text = '@$username';
                                usernameController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(
                                        offset: usernameController.text.length,
                                      ),
                                    );
                                _shareLog('share_lookup_ok', {
                                  'recipient_id': id,
                                  'username': username,
                                });
                                await syncSelectedBlockState(
                                  setModalState,
                                  selectedRecipient,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    if (blockNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          blockNotice!,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow replies'),
                      value: canComment,
                      onChanged: (v) => setModalState(() => canComment = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show photos & videos'),
                      value: mediaVisible,
                      onChanged: (v) => setModalState(() => mediaVisible = v),
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Time limit'),
                      subtitle: Text('Forever'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: shareDisabledByBlock
                              ? null
                              : () async {
                                  _shareLog('share_sheet_submit_tapped', {
                                    'input': usernameController.text,
                                  });
                                  final typedInput = usernameController.text;
                                  final normalized =
                                      _normalizeUsernameForLookup(typedInput);
                                  if (normalized.isEmpty) {
                                    setModalState(
                                      () => pickerError = 'Select a user',
                                    );
                                    return;
                                  }
                                  var resolved = selectedRecipient;
                                  if (resolved == null ||
                                      _normalizeUsernameForLookup(
                                            resolved['username']?.toString() ??
                                                '',
                                          ) !=
                                          normalized) {
                                    resolved = await _lookupRecipient(
                                      typedInput,
                                    );
                                  }
                                  if (resolved == null ||
                                      _normalizeUsernameForLookup(
                                            resolved['username']?.toString() ??
                                                '',
                                          ) !=
                                          normalized) {
                                    setModalState(
                                      () => pickerError = 'Select a user',
                                    );
                                    return;
                                  }
                                  _shareLog('share_lookup_ok', {
                                    'recipient_id': resolved['id'],
                                    'username': resolved['username'],
                                  });
                                  await syncSelectedBlockState(
                                    setModalState,
                                    resolved,
                                  );
                                  if (shareDisabledByBlock) return;
                                  await _saveRecentRecipient(resolved);
                                  Navigator.pop(ctx, {
                                    'recipient': resolved,
                                    'can_comment': canComment,
                                    'media_visible': mediaVisible,
                                    'duration': 'forever',
                                  });
                                },
                          child: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    usernameFocusNode.dispose();
    usernameController.dispose();
    lookupDebounce?.cancel();
    if (result == null) {
      _shareLog('share_sheet_closed', {'result': false});
      return false;
    }

    final recipient = Map<String, dynamic>.from(
      result['recipient'] as Map<String, dynamic>,
    );
    final canCommentFinal = result['can_comment'] == true;
    final mediaVisibleFinal = result['media_visible'] != false;
    setState(() => _shareBusy = true);
    try {
      final recipientId = recipient['id'].toString();
      _shareLog('share_insert_start', {
        'entry_id': _activeJournalId,
        'recipient_id': recipientId,
      });
      final status = await BlockService.instance.getBlockStatusWithUser(
        recipientId,
      );
      if (status.blockedByMe) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You’ve blocked this user. Unblock to share.'),
            ),
          );
        }
        return false;
      }
      if (status.blockedByThem) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can’t share with this user.')),
          );
        }
        return false;
      }
      const expiresAt = null;
      final sourceJournal = Map<String, dynamic>.from(_loaded ?? const {});
      final currentBody = sourceJournal['text']?.toString() ?? '';
      await _journalRepository.sharePrivateJournal(
        journalId: _activeJournalId,
        recipientId: recipientId,
        canComment: canCommentFinal,
        mediaVisible: mediaVisibleFinal,
        expiresAt: expiresAt,
        title: sourceJournal['title']?.toString(),
        body: currentBody,
        sourceJournal: sourceJournal,
      );
      _shareLog('share_insert_ok', {
        'journal_id': _activeJournalId,
        'recipient_id': recipientId,
      });
      await Supabase.instance.client
          .from('journals')
          .update({'is_shared': true})
          .eq('id', _activeJournalId);
      await JournalShareUsageTracker.increment();
      await _loadShareState();
      _shareLog('share_confirm_ok', {
        'journal_id': _activeJournalId,
        'recipient_id': recipientId,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sent!')));
      }
      _shareLog('share_sheet_closed', {'result': true});
      return true;
    } on PostgrestException catch (e) {
      _shareLog('share_insert_error', {
        'code': e.code,
        'message': e.message,
        'details': e.details,
        'hint': e.hint,
      });
      if (!mounted) return false;
      final msg = e.code == '23505'
          ? 'This journal is already shared with that user.'
          : 'Couldn’t share right now. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _shareLog('share_sheet_closed', {'result': false});
      return false;
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _removeRecipient(Map<String, dynamic> recipient) async {
    final recipientRowId = recipient['id'];
    await _journalRepository.removeJournalShare(
      shareRowId: recipientRowId,
      sourceJournalId: _activeJournalId,
    );
    await _loadShareState();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _addReply() async {
    final ownerId = _journalOwnerId ?? '';
    if (ownerId.isNotEmpty) {
      final status = await BlockService.instance.getBlockStatusWithUser(
        ownerId,
      );
      if (status.blockedEither) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Replies disabled due to blocking.')),
          );
        }
        return;
      }
    }
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Share a gentle reply…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    _shareLog('reply_insert', {
      'entry_id': _activeJournalId,
      'journal_id': _activeJournalId,
      'author_id': Supabase.instance.client.auth.currentUser!.id,
    });
    await Supabase.instance.client.from('journal_share_replies').insert({
      'journal_id': _activeJournalId,
      'author_id': Supabase.instance.client.auth.currentUser!.id,
      'text': text,
    });
    await _loadReplies();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Journal Entry'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/journals'),
        ),
        actions: [
          if (_isOwner)
            MbGlowIconButton(
              tooltip: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: () async {
                final updated = await context.push<bool>(
                  '/journals/edit/${_activeJournalId}',
                );
                if (updated == true && mounted) {
                  setState(() {
                    _useSeededEntry = false;
                    _future = _load();
                  });
                }
              },
            ),
          if (_isOwner)
            MbGlowIconButton(
              tooltip: 'Share',
              icon: Icons.share_outlined,
              onPressed: _openShareSheet,
            ),
          if (_isOwner)
            MbGlowIconButton(
              tooltip: 'Delete',
              icon: Icons.delete_outline,
              onPressed: _deleteEntry,
            ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_journal_view',
        text: 'Use the menu to share or edit when you feel ready.',
        iconText: '✨',
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final error = snap.error;
              _shareLog('entry_open_failed', {
                'incoming_id': widget.journalId,
                'error': error.toString(),
              });
              final message = error is JournalEncryptionException
                  ? error.message
                  : 'Unable to open this journal right now.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              );
            }
            if (!snap.hasData || snap.data == null) {
              return const Center(child: Text('Entry not found.'));
            }

            final row = snap.data!;
            final title = (row['title'] as String?)?.trim().isNotEmpty == true
                ? row['title'] as String
                : 'Untitled entry';
            final createdAtRaw = row['created_at']?.toString();
            final createdAt = createdAtRaw != null
                ? DateFormat(
                    'MMM d, yyyy • h:mm a',
                  ).format(DateTime.parse(createdAtRaw).toLocal())
                : null;
            final raw = row['text']?.toString() ?? '';
            final pagesData = JournalPageCodec.decode(raw);
            final pages = pagesData.pages.isEmpty
                ? const <JournalEntryPageData>[
                    JournalEntryPageData(id: 'page-1', body: ''),
                  ]
                : pagesData.pages;
            final safePageIndex = _currentPageIndex.clamp(0, pages.length - 1);
            if (safePageIndex != _currentPageIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _currentPageIndex = safePageIndex);
              });
            }
            final doodleUrl = row['doodle_preview_url']?.toString();
            final editorStyles = JournalDocumentCodec.buildEditorStyles(
              context,
            );

            return Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox.expand(
                child: _GlowPanel(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              createdAt,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      if (!_isOwner)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Shared Page',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      JournalPageControls(
                        currentPage: safePageIndex,
                        pageCount: pages.length,
                        isBookmarked: pages[safePageIndex].isBookmarked,
                        onAddPage: () {},
                        onDeletePage: () {},
                        onToggleBookmark: () {},
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: pages.length,
                          onPageChanged: (index) {
                            if (!mounted) return;
                            setState(() => _currentPageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            final controller = quill.QuillController(
                              document: JournalDocumentCodec.decodeContent(
                                pages[index].body,
                              ).document,
                              selection: const TextSelection.collapsed(
                                offset: 0,
                              ),
                              readOnly: true,
                            );
                            final content = JournalDocumentCodec.decodeContent(
                              pages[index].body,
                            );
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                ),
                                if (doodleUrl != null && doodleUrl.isNotEmpty)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Image.network(
                                        doodleUrl,
                                        fit: BoxFit.fill,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                quill.QuillEditor.basic(
                                  controller: controller,
                                  config: quill.QuillEditorConfig(
                                    expands: true,
                                    padding: const EdgeInsets.all(12),
                                    autoFocus: false,
                                    customStyles: editorStyles,
                                    embedBuilders:
                                        (_isOwner || _recipientMediaVisible)
                                        ? const [
                                            LocalImageEmbedBuilder(),
                                            LocalVideoEmbedBuilder(),
                                          ]
                                        : const [],
                                  ),
                                ),
                                if (content.canvasObjects.isNotEmpty)
                                  Positioned.fill(
                                    child: JournalCanvasLayer(
                                      objects: content.canvasObjects,
                                      selectedObjectId: null,
                                      onSelectObject: (_) {},
                                      onUpdateObject: (_) {},
                                      onDeleteObject: (_) {},
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      if (_isOwner || _recipientMediaVisible)
                        Builder(
                          builder: (context) {
                            final activeContent =
                                JournalDocumentCodec.decodeContent(
                                  pages[safePageIndex].body,
                                );
                            final media = extractMediaFromDelta(
                              activeContent.document.toDelta().toJson(),
                            );
                            return _MediaPreviewStrip(
                              items: media,
                              onTap: (index) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => JournalMediaViewer(
                                      items: media,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      if (_replies.isNotEmpty ||
                          (_isOwner && _shareRecipients.isNotEmpty) ||
                          (!_isOwner && _recipientCanComment) ||
                          (!_isOwner && _repliesBlockedByBlock))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Replies',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              if (_replies.isNotEmpty)
                                ..._replies.map((r) {
                                  final author = (r['author_username'] ?? '')
                                      .toString();
                                  final fallback =
                                      (r['author_fallback'] ?? '@unavailable')
                                          .toString();
                                  final created =
                                      r['created_at']?.toString() ?? '';
                                  final createdLabel = created.isEmpty
                                      ? ''
                                      : DateFormat('MMM d • h:mm a').format(
                                          DateTime.parse(created).toLocal(),
                                        );
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          author.isEmpty
                                              ? fallback
                                              : '@$author',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        if (createdLabel.isNotEmpty)
                                          Text(
                                            createdLabel,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (r['reply_text'] ?? r['text'] ?? '')
                                              .toString(),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              if (_isOwner &&
                                  _shareRecipients.isNotEmpty &&
                                  _replies.isEmpty)
                                Text(
                                  'No replies yet.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (!_isOwner && _repliesBlockedByBlock)
                                Text(
                                  'Replies disabled due to blocking.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              else if (_isOwner || _recipientCanComment)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _addReply,
                                    icon: const Icon(Icons.reply),
                                    label: const Text('Reply'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_isOwner && _shareRecipients.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                'Shared with',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              ..._shareRecipients.map((r) {
                                final profile =
                                    r['profile'] as Map<String, dynamic>?;
                                final username = (profile?['username'] ?? '')
                                    .toString();
                                final fallback =
                                    (r['recipient_fallback'] ?? '@unavailable')
                                        .toString();
                                final canComment = r['can_comment'] == true;
                                final expiresAt = r['expires_at']?.toString();
                                final expiresLabel = expiresAt == null
                                    ? 'Forever'
                                    : DateFormat('MMM d, yyyy • h:mm a').format(
                                        DateTime.parse(expiresAt).toLocal(),
                                      );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '${username.isEmpty ? fallback : '@$username'} · ${canComment ? 'View + reply' : 'View only'} · $expiresLabel',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlowPanel extends StatelessWidget {
  const _GlowPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MediaPreviewStrip extends StatelessWidget {
  const _MediaPreviewStrip({required this.items, required this.onTap});

  final List<JournalMediaItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(top: 8),
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final thumb = item.type == 'video'
              ? _VideoThumb(item: item)
              : _ImageThumb(item: item);
          return GestureDetector(
            onTap: () => onTap(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 96, height: 96, child: thumb),
            ),
          );
        },
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.item});

  final JournalMediaItem item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(
        item,
        debugContext: 'journal_view_image_thumb',
      ),
      builder: (context, snap) {
        final resolved = snap.data;
        if (resolved?.file != null) {
          return Image.file(resolved!.file!, fit: BoxFit.cover);
        }
        if (resolved?.url != null && resolved!.url!.isNotEmpty) {
          return Image.network(
            resolved.url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _thumbFallback('Photo'),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return _thumbFallback('Photo');
      },
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.item});

  final JournalMediaItem item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(
        item,
        debugContext: 'journal_view_video_thumb',
      ),
      builder: (context, snap) {
        final resolved = snap.data;
        final child = resolved?.file != null
            ? Image.file(resolved!.file!, fit: BoxFit.cover)
            : (resolved?.url != null && resolved!.url!.isNotEmpty)
            ? Image.network(
                resolved.url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbFallback('Video'),
              )
            : snap.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _thumbFallback('Video');
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: child),
            Container(color: Colors.black26),
            const Icon(Icons.play_circle, color: Colors.white, size: 32),
          ],
        );
      },
    );
  }
}

Widget _thumbFallback(String label) {
  return Container(
    color: Colors.black12,
    alignment: Alignment.center,
    child: Text('$label unavailable'),
  );
}
