import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

import 'package:mind_buddy/services/journal_doodle_service.dart';
import 'package:mind_buddy/services/journal_document_codec.dart';

class JournalAccessService {
  JournalAccessService._();

  static const String mediaBucket = 'journal-media';

  static Future<bool> canAccessEntry(String entryId) async {
    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;
    if (user == null) return false;

    final nowIso = DateTime.now().toIso8601String();
    developer.log(
      'journal_encryption event=entry_access_check data={entry_id: $entryId, user_id: ${user.id}}',
      name: 'journal_encryption',
    );
    final directShare = await supa
        .from('journal_shares')
        .select('id')
        .eq('journal_id', entryId)
        .eq('recipient_id', user.id)
        .or('expires_at.is.null,expires_at.gt.$nowIso')
        .maybeSingle();
    if (directShare != null) return true;

    try {
      final sharedCopyShare = await supa
          .from('journal_shares')
          .select('id')
          .eq('shared_journal_id', entryId)
          .eq('recipient_id', user.id)
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .maybeSingle();
      if (sharedCopyShare != null) return true;
    } on PostgrestException catch (error) {
      final msg = '${error.message} ${error.details} ${error.hint}'
          .toLowerCase();
      final missingSharedCopyColumn =
          (error.code == '42703' || error.code == 'PGRST204') &&
          msg.contains('shared_journal_id');
      if (!missingSharedCopyColumn) rethrow;
      developer.log(
        'journal_encryption event=fallback_triggered data={context: entry_access_check, reason: missing_shared_journal_id, code: ${error.code}, message: ${error.message}}',
        name: 'journal_encryption',
      );
    }

    final journal = await supa
        .from('journals')
        .select('id, user_id')
        .eq('id', entryId)
        .maybeSingle();
    if (journal == null) return false;
    final ownerId = journal['user_id']?.toString();
    return ownerId == user.id;
  }

  static Future<String?> resolveDoodleUrl({
    required String entryId,
    required String? storagePath,
    DateTime? updatedAt,
  }) async {
    final allowed = await canAccessEntry(entryId);
    if (!allowed) return null;
    return JournalDoodleService.resolvePreviewUrl(
      storagePath: storagePath,
      updatedAt: updatedAt,
    );
  }

  static Future<String> hydrateMediaSignedUrls({
    required String entryId,
    required String rawText,
  }) async {
    if (rawText.trim().isEmpty) return rawText;

    final allowed = await canAccessEntry(entryId);
    if (!allowed) {
      throw Exception('You do not have access to this entry media.');
    }

    return JournalDocumentCodec.hydrateMediaSignedUrls(
      rawText: rawText,
      resolveSignedUrl: ({required String bucket, required String path}) =>
          _resolveMediaUrl(bucket: bucket, path: path),
    );
  }

  static Future<String?> _resolveMediaUrl({
    required String bucket,
    required String path,
  }) async {
    try {
      final signed = await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, 3600);
      if (signed.isNotEmpty) return signed;
    } catch (_) {}
    try {
      return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}
