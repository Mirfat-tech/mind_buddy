import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final journalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final supa = Supabase.instance.client;
    final response = await supa
        .from('journals')
        .select()
        .order('created_at', ascending: false);
    // Return as a list of maps; UI accesses by key
    return (response as List).cast<Map<String, dynamic>>();
  },
);

final addJournalProvider = FutureProvider.family
    .autoDispose<void, Map<String, dynamic>>((ref, payload) async {
      final supa = Supabase.instance.client;
      await supa.from('journals').insert(payload);
      // refresh list after insert
      ref.invalidate(journalsProvider);
    });
