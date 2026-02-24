import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final journalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;
    if (user == null) return [];
    final response = await supa
        .from('journals')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    // Return as a list of maps; UI accesses by key
    return (response as List).cast<Map<String, dynamic>>();
  },
);

final sharedWithMeProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supa = Supabase.instance.client;
  final user = supa.auth.currentUser;
  if (user == null) return [];
  final nowIso = DateTime.now().toIso8601String();
  final response = await supa
      .from('journal_share_recipients')
      .select(
        'id, journal_id, owner_id, can_comment, media_visible, expires_at, '
        'journal:journal_id (id, title, text, created_at, user_id), '
        'owner:owner_id (username)',
      )
      .eq('recipient_id', user.id)
      .or('expires_at.is.null,expires_at.gt.$nowIso')
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

final addJournalProvider = FutureProvider.family
    .autoDispose<void, Map<String, dynamic>>((ref, payload) async {
      final supa = Supabase.instance.client;
      await supa.from('journals').insert(payload);
      // refresh list after insert
      ref.invalidate(journalsProvider);
    });
