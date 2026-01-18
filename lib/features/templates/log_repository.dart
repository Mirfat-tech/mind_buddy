import 'package:supabase_flutter/supabase_flutter.dart';

class LogEntry {
  final String id;
  final String userId;
  final String dayId;
  final String category;
  final String title;
  final int? rating;
  final String? note;

  LogEntry({
    required this.id,
    required this.userId,
    required this.dayId,
    required this.category,
    required this.title,
    this.rating,
    this.note,
  });

  factory LogEntry.fromMap(Map<String, dynamic> m) {
    return LogEntry(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      dayId: m['day_id'] as String,
      category: (m['category'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      rating: m['rating'] == null ? null : (m['rating'] as num).toInt(),
      note: m['note'] as String?,
    );
  }
}

class LogRepository {
  final SupabaseClient supabase;
  LogRepository(this.supabase);

  Future<List<LogEntry>> listForDay({
    required String userId,
    required String dayId,
  }) async {
    final res = await supabase
        .from('logs')
        .select()
        .eq('user_id', userId)
        .eq('day_id', dayId)
        .order('created_at', ascending: true);

    final rows = (res as List).cast<Map<String, dynamic>>();
    return rows.map(LogEntry.fromMap).toList();
  }

  Future<void> add({
    required String userId,
    required String dayId,
    required String category,
    required String title,
    int? rating,
    String? note,
  }) async {
    await supabase.from('logs').insert({
      'user_id': userId,
      'day_id': dayId,
      'category': category,
      'title': title,
      'rating': rating,
      'note': note,
    });
  }

  Future<void> update({
    required String id,
    required String userId,
    required String dayId,
    required String category,
    required String title,
    int? rating,
    String? note,
  }) async {
    await supabase
        .from('logs')
        .update({
          'category': category,
          'title': title,
          'rating': rating,
          'note': note,
        })
        .eq('id', id)
        .eq('user_id', userId)
        .eq('day_id', dayId);
  }

  Future<void> delete({required String id, required String userId}) async {
    await supabase.from('logs').delete().eq('id', id).eq('user_id', userId);
  }

  Future<List<LogEntry>> getEntriesForTemplateDay({
    required String templateId,
    required String day, // yyyy-mm-dd
  }) async {
    final rows = await supabase
        .from('log_entries')
        .select('*')
        .eq('template_id', templateId) // ✅ use the parameter
        .eq('day', day) // ✅ correct column
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => LogEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
