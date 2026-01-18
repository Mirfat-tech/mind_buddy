// lib/hobonichi_repo.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class HobonichiRepo {
  HobonichiRepo(this.supabase);
  final SupabaseClient supabase;

  Future<void> ensureDayExists({
    required String dayId, // "YYYY-MM-DD"
    required String userId,
  }) async {
    final existing = await supabase
        .from('days')
        .select('id')
        .eq('id', dayId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('days').insert({'id': dayId, 'user_id': userId});
    }
  }

  Future<Map<String, dynamic>> getOrCreateFirstPage({
    required String dayId,
    required String userId,
  }) async {
    final pages = await supabase
        .from('pages')
        .select('*')
        .eq('day_id', dayId)
        .eq('user_id', userId)
        .order('sort_order', ascending: true);

    final list = (pages as List);

    if (list.isNotEmpty) {
      return Map<String, dynamic>.from(list.first as Map);
    }

    final inserted = await supabase
        .from('pages')
        .insert({
          'day_id': dayId,
          'user_id': userId,
          'title': 'Page 1',
          'sort_order': 0,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(inserted);
  }

  Future<List<Map<String, dynamic>>> listBoxes({required String pageId}) async {
    final rows = await supabase
        .from('boxes')
        .select('*')
        .eq('page_id', pageId)
        .order('sort_order', ascending: true);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<String?> getCoverForDay({
    required String dayId,
    required String userId,
  }) async {
    final row = await supabase
        .from('days')
        .select('cover_id')
        .eq('id', dayId)
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return (row['cover_id'] as String?);
  }

  Future<void> setCoverForDay({
    required String dayId,
    required String userId,
    required String coverId,
  }) async {
    await supabase
        .from('days')
        .update({'cover_id': coverId})
        .eq('id', dayId)
        .eq('user_id', userId);
  }

  Future<void> updateBoxContent({
    required String boxId,
    required Map<String, dynamic> content,
  }) async {
    await supabase.from('boxes').update({'content': content}).eq('id', boxId);
  }

  // ---------- Add box helpers ----------

  Future<void> addJournalBox({
    required String userId,
    required String pageId,
    required int sortOrder,
  }) async {
    await supabase.from('boxes').insert({
      'user_id': userId,
      'page_id': pageId,
      'type': 'journal',
      'sort_order': sortOrder,
      'content': {'format': 'plain', 'text': ''},
    });
  }

  Future<void> addChatBox({
    required String userId,
    required String pageId,
    required int sortOrder,
  }) async {
    await supabase.from('boxes').insert({
      'user_id': userId,
      'page_id': pageId,
      'type': 'chat',
      'sort_order': sortOrder,
      'content': {},
    });
  }

  Future<void> addChecklistBox({
    required String userId,
    required String pageId,
    required int sortOrder,
  }) async {
    await supabase.from('boxes').insert({
      'user_id': userId,
      'page_id': pageId,
      'type': 'checklist',
      'sort_order': sortOrder,
      'content': {},
    });
  }

  Future<void> deleteBox({required String boxId}) async {
    await supabase.from('boxes').delete().eq('id', boxId);
  }

  Future<void> addPomodoroBox({
    required String userId,
    required String pageId,
    required int sortOrder,
  }) async {
    await supabase.from('boxes').insert({
      'user_id': userId,
      'page_id': pageId,
      'type': 'pomodoro',
      'sort_order': sortOrder,
      'content': {'workMinutes': 25, 'breakMinutes': 5},
    });
  }

  Future<void> addLogsBox({
    required String userId,
    required String pageId,
    required int sortOrder,
  }) async {
    await supabase.from('boxes').insert({
      'user_id': userId,
      'page_id': pageId,
      'type': 'logs',
      'sort_order': sortOrder,
      'content': {}, // actual rows live in your log_entries table
    });
  }
}
