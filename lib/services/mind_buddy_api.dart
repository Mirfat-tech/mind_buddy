import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// =======================
/// Chat API (HTTP backend)
/// =======================

class ChatResponse {
  final String reply;
  final int chatId;

  ChatResponse({required this.reply, required this.chatId});
}

class MindBuddyApi {
  final String baseUrl;

  MindBuddyApi({required this.baseUrl});

  Future<ChatResponse> sendMessage({
    required String message,
    int? chatId,
  }) async {
    final uri = Uri.parse('$baseUrl/chat');

    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'message': message,
            if (chatId != null) 'chat_id': chatId,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      // backend returns { error, details } on failure
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final details = data['details'] ?? data['error'] ?? res.body;
        throw Exception(details.toString());
      } catch (_) {
        throw Exception(res.body);
      }
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    return ChatResponse(
      reply: (data['reply'] ?? '').toString(),
      chatId: (data['chat_id'] as num).toInt(),
    );
  }
}

/// =======================
/// Hobonichi / Daily Pages
/// =======================
/// Tables assumed:
/// - days(id, user_id, cover_id?)
/// - pages(id, day_id, user_id, title, sort_order)
/// - boxes(id, user_id, page_id, type, sort_order, content)
/// - chats(id, user_id, title?)
class HobonichiRepo {
  HobonichiRepo(this.supabase);

  final SupabaseClient supabase;

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
      'content': {
        'mode': 'focus',
        'focusMinutes': 25,
        'shortBreakMinutes': 5,
        'longBreakMinutes': 15,
        'secondsLeft': 25 * 60,
        'running': false,
        'cyclesDone': 0,
      },
    });
  }

  /// Ensure the day row exists (id = yyyy-MM-dd).
  Future<void> ensureDayExists({
    required String dayId,
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

  /// List pages for a day (ordered).
  Future<List<Map<String, dynamic>>> listPages({
    required String dayId,
    required String userId,
  }) async {
    final rows = await supabase
        .from('pages')
        .select('*')
        .eq('day_id', dayId)
        .eq('user_id', userId)
        .order('sort_order', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Add a new page.
  Future<Map<String, dynamic>> addPage({
    required String dayId,
    required String userId,
    required int sortOrder,
    required String title,
  }) async {
    final inserted = await supabase
        .from('pages')
        .insert({
          'day_id': dayId,
          'user_id': userId,
          'title': title,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(inserted as Map);
  }

  /// ✅ 5b — get first page or create "Page 1".
  Future<Map<String, dynamic>> getOrCreateFirstPage({
    required String dayId,
    required String userId,
  }) async {
    final pages = await listPages(dayId: dayId, userId: userId);

    if (pages.isNotEmpty) {
      return pages.first;
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

    return Map<String, dynamic>.from(inserted as Map);
  }

  /// ✅ 5c — list boxes on a page (ordered).
  Future<List<Map<String, dynamic>>> listBoxes({required String pageId}) async {
    final rows = await supabase
        .from('boxes')
        .select('*')
        .eq('page_id', pageId)
        .order('sort_order', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Update content JSON for a box.
  Future<void> updateBoxContent({
    required String boxId,
    required Map<String, dynamic> content,
  }) async {
    await supabase.from('boxes').update({'content': content}).eq('id', boxId);
  }

  /// Add a journal box.
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
      'content': {'items': []},
    });
  }

  /// Create a chat row and return its id.
  Future<int> createChat({required String userId}) async {
    final row = await supabase
        .from('chats')
        .insert({'user_id': userId, 'title': null})
        .select()
        .single();

    final id = (row as Map)['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.parse(id.toString());
  }

  /// Add a chat box and store {chat_id} in content.
  Future<void> addChatBox({
    required String userId,
    required String pageId,
    required int sortOrder,
  }) async {
    final chatId = await createChat(userId: userId);

    await supabase.from('boxes').insert({
      'user_id': userId,
      'page_id': pageId,
      'type': 'chat',
      'sort_order': sortOrder,
      'content': {'chat_id': chatId},
    });
  }

  /// ✅ cover save (part of step 8)
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

  // =========================
  // Chat message persistence
  // =========================

  Future<List<Map<String, dynamic>>> listChatMessages({
    required int chatId,
    required String userId,
  }) async {
    final rows = await supabase
        .from('chat_messages')
        .select('*')
        .eq('chat_id', chatId)
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addChatMessage({
    required int chatId,
    required String userId,
    required String role, // 'user' | 'assistant' | 'system'
    required String text,
  }) async {
    await supabase.from('chat_messages').insert({
      'chat_id': chatId,
      'user_id': userId,
      'role': role,
      'text': text,
    });
  }
  // =====================
  // 3B) Chat messages repo
  // =====================

  Stream<List<Map<String, dynamic>>> streamMessages({required int chatId}) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> listMessages({required int chatId}) async {
    final rows = await supabase
        .from('messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addMessage({
    required int chatId,
    required String userId,
    required String role, // 'user' | 'assistant' | 'system'
    required String content,
  }) async {
    await supabase.from('messages').insert({
      'chat_id': chatId,
      'user_id': userId,
      'role': role,
      'content': content,
    });
  }

  Future<Set<String>> daysWithBoxesInRange({
    required String userId,
    required String startDayId, // "YYYY-MM-DD"
    required String endDayId, // "YYYY-MM-DD"
  }) async {
    // Fetch pages in range, then boxes via page ids
    final pagesRows = await supabase
        .from('pages')
        .select('id, day_id')
        .eq('user_id', userId)
        .gte('day_id', startDayId)
        .lte('day_id', endDayId);

    final pages = (pagesRows as List).cast<Map<String, dynamic>>();
    if (pages.isEmpty) return {};

    final pageIds = pages.map((p) => p['id'] as String).toList();
    final pageIdToDay = {
      for (final p in pages) (p['id'] as String): (p['day_id'] as String),
    };

    final boxRows = await supabase
        .from('boxes')
        .select('page_id')
        .inFilter('page_id', pageIds);

    final boxes = (boxRows as List).cast<Map<String, dynamic>>();
    final dayIds = <String>{};

    for (final b in boxes) {
      final pid = b['page_id'] as String;
      final dayId = pageIdToDay[pid];
      if (dayId != null) dayIds.add(dayId);
    }

    return dayIds;
  }
}
