import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/services/username_resolver_service.dart';

class BlockStatus {
  const BlockStatus({
    required this.blockedByMe,
    required this.blockedByThem,
  });

  final bool blockedByMe;
  final bool blockedByThem;

  bool get blockedEither => blockedByMe || blockedByThem;
}

class BlockService {
  BlockService._();

  static final BlockService instance = BlockService._();

  void _log(String event, [Map<String, dynamic> data = const {}]) {
    final line = 'journal_share event=$event data=$data';
    developer.log(line, name: 'journal_share');
  }

  Future<BlockStatus> getBlockStatusWithUser(String otherUserId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || otherUserId.trim().isEmpty) {
      return const BlockStatus(blockedByMe: false, blockedByThem: false);
    }

    _log('block_check_start', {
      'user_id': user.id,
      'other_user_id': otherUserId,
    });

    try {
      final raw = await Supabase.instance.client.rpc(
        'get_block_status',
        params: {'other_user_id': otherUserId},
      );
      final rows = raw is List ? raw : const <dynamic>[];
      final row = rows.isEmpty
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(rows.first as Map);
      final status = BlockStatus(
        blockedByMe: row['blocked_by_me'] == true,
        blockedByThem: row['blocked_by_them'] == true,
      );
      _log('block_check_result', {
        'other_user_id': otherUserId,
        'blocked_by_me': status.blockedByMe,
        'blocked_by_them': status.blockedByThem,
      });
      return status;
    } on PostgrestException catch (e) {
      _log('block_check_error', {
        'other_user_id': otherUserId,
        'code': e.code,
        'message': e.message,
        'details': e.details,
        'hint': e.hint,
      });
      return const BlockStatus(blockedByMe: false, blockedByThem: false);
    }
  }

  Future<void> blockUser(String blockedId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || blockedId.trim().isEmpty || blockedId == user.id) {
      return;
    }
    await Supabase.instance.client.from('blocked_users').upsert({
      'user_id': user.id,
      'blocked_user_id': blockedId,
    }, onConflict: 'user_id,blocked_user_id');
    _log('block_insert_ok', {
      'blocker_id': user.id,
      'blocked_id': blockedId,
    });
  }

  Future<void> unblockUser(String blockedId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || blockedId.trim().isEmpty) return;
    await Supabase.instance.client
        .from('blocked_users')
        .delete()
        .eq('user_id', user.id)
        .eq('blocked_user_id', blockedId);
    _log('block_delete_ok', {
      'blocker_id': user.id,
      'blocked_id': blockedId,
    });
  }

  Future<List<Map<String, dynamic>>> listBlockedUsers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const <Map<String, dynamic>>[];
    final rows = await Supabase.instance.client
        .from('blocked_users')
        .select('id, blocked_user_id, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();
    final ids = list
        .map((e) => e['blocked_user_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final usernames = await UsernameResolverService.instance.resolveUsernamesByIds(
      ids,
    );

    return list
        .map((row) {
          final blockedId = row['blocked_user_id']?.toString() ?? '';
          return <String, dynamic>{
            ...row,
            'blocked_id': blockedId,
            'username': usernames[blockedId] ?? '',
          };
        })
        .where((row) => (row['blocked_id']?.toString() ?? '').isNotEmpty)
        .toList();
  }

  Future<Set<String>> listBlockedIds() async {
    final rows = await listBlockedUsers();
    return rows
        .map((row) => row['blocked_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<String?> blockByUsername(String input) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'Sign in required.';
    final normalized = input.trim().toLowerCase().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    if (normalized.isEmpty) return 'Enter a username.';
    final found = await UsernameResolverService.instance.findUserByUsername(
      normalized,
    );
    if (found == null) return 'User not found.';
    final targetId = found['id']?.toString() ?? '';
    if (targetId.isEmpty) return 'User not found.';
    if (targetId == user.id) return 'You can’t block yourself.';
    final existing = await Supabase.instance.client
        .from('blocked_users')
        .select('user_id')
        .eq('user_id', user.id)
        .eq('blocked_user_id', targetId)
        .maybeSingle();
    if (existing != null) return 'User already blocked.';
    await blockUser(targetId);
    return null;
  }
}
