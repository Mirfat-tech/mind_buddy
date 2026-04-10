import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/services/username_resolver_service.dart';
import 'package:mind_buddy/services/journal_repository.dart';

import 'journal_folder_support.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository();
});

final journalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final repository = ref.watch(journalRepositoryProvider);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  developer.log(
    'journal_share event=journals_list_query data={table: journals, select: *, filters: user_id=auth.uid() and share_source_journal_id is null, order: created_at desc, limit: none}',
    name: 'journal_share',
  );
  try {
    final rows = await repository.fetchOwnedJournals();
    final sample = rows
        .take(5)
        .map((r) => r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    developer.log(
      'journal_share event=journals_list_fetch_ok data={count: ${rows.length}, first_ids_sample: $sample}',
      name: 'journal_share',
    );
    return rows;
  } on PostgrestException catch (e) {
    developer.log(
      'journal_share event=journals_list_fetch_fail data={code: ${e.code}, message: ${e.message}, details: ${e.details}, hint: ${e.hint}}',
      name: 'journal_share',
    );
    rethrow;
  }
});

final sharedWithMeProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final repository = ref.watch(journalRepositoryProvider);
  final supa = Supabase.instance.client;
  final user = supa.auth.currentUser;
  if (user == null) return [];
  developer.log(
    'journal_share event=journals_list_query data={table: journal_shares, select: recipient inbox with shared copy fallback, filters: recipient_id=auth.uid(), order: created_at desc, limit: none}',
    name: 'journal_share',
  );
  List<Map<String, dynamic>> rows;
  try {
    rows = await repository.fetchSharedWithMe();
  } on PostgrestException catch (e) {
    developer.log(
      'journal_share event=journals_list_fetch_fail data={code: ${e.code}, message: ${e.message}, details: ${e.details}, hint: ${e.hint}}',
      name: 'journal_share',
    );
    rethrow;
  }
  final blockedByMeRaw = await supa
      .from('blocked_users')
      .select('blocked_user_id')
      .eq('user_id', user.id);
  final blockedByMe = (blockedByMeRaw as List)
      .map((e) => (e as Map)['blocked_user_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
  if (rows.isNotEmpty) {
    final senderIds = rows
        .map((row) => row['sender_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final blockedByThemRaw = senderIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await supa
              .from('blocked_users')
              .select('user_id')
              .inFilter('user_id', senderIds)
              .eq('blocked_user_id', user.id);
    final blockedByThem = (blockedByThemRaw as List)
        .map((e) => (e as Map)['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    rows = rows.where((row) {
      final senderId = row['sender_id']?.toString() ?? '';
      if (senderId.isEmpty) return false;
      return !blockedByMe.contains(senderId) &&
          !blockedByThem.contains(senderId);
    }).toList();
  }
  final sample = rows.take(3).map((row) {
    return {
      'id': row['id'],
      'journal_id': row['journal_id'],
      'owner_id': row['sender_id'],
      'recipient_id': row['recipient_id'],
      'created_at': row['created_at'],
    };
  }).toList();
  developer.log(
    'journal_share event=shares_inbox_count data={count: ${rows.length}, sample: $sample}',
    name: 'journal_share',
  );
  final firstIdsSample = rows
      .take(5)
      .map((r) => r['journal_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toList();
  developer.log(
    'journal_share event=journals_list_fetch_ok data={count: ${rows.length}, first_ids_sample: $firstIdsSample}',
    name: 'journal_share',
  );
  final ownerIds = rows
      .map((row) => row['sender_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  final usernamesById = await UsernameResolverService.instance
      .resolveUsernamesByIds(ownerIds);
  return rows.map((row) {
    final ownerId = row['sender_id']?.toString() ?? '';
    return <String, dynamic>{
      ...row,
      'owner_id': ownerId,
      'owner_username': usernamesById[ownerId] ?? '',
    };
  }).toList();
});

final journalFoldersProvider = FutureProvider.autoDispose<List<JournalFolder>>((
  ref,
) async {
  return JournalFolderSupport.fetchFolders();
});

final addJournalProvider = FutureProvider.family
    .autoDispose<void, Map<String, dynamic>>((ref, payload) async {
      final supa = Supabase.instance.client;
      await supa.from('journals').insert(payload);
      // refresh list after insert
      ref.invalidate(journalsProvider);
    });
