import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JournalDoodleRecord {
  const JournalDoodleRecord({
    required this.storagePath,
    required this.bgStyle,
    required this.updatedAt,
    this.previewUrl,
  });

  final String? storagePath;
  final String? bgStyle;
  final DateTime? updatedAt;
  final String? previewUrl;
}

class JournalDoodleService {
  JournalDoodleService._();

  static const String doodlesBucket = 'journal_doodles';

  static Future<JournalDoodleRecord> fetchDoodle(String journalEntryId) async {
    final row = await Supabase.instance.client
        .from('journals')
        .select('doodle_storage_path, doodle_bg_style, doodle_updated_at')
        .eq('id', journalEntryId)
        .maybeSingle();

    if (row == null) {
      return const JournalDoodleRecord(
        storagePath: null,
        bgStyle: null,
        updatedAt: null,
      );
    }

    final storagePath = row['doodle_storage_path']?.toString();
    final bgStyle = row['doodle_bg_style']?.toString();
    final updatedAtRaw = row['doodle_updated_at']?.toString();
    final updatedAt = updatedAtRaw == null
        ? null
        : DateTime.tryParse(updatedAtRaw);
    final previewUrl = await resolvePreviewUrl(
      storagePath: storagePath,
      updatedAt: updatedAt,
    );
    return JournalDoodleRecord(
      storagePath: storagePath,
      bgStyle: bgStyle,
      updatedAt: updatedAt,
      previewUrl: previewUrl,
    );
  }

  static Future<String?> resolvePreviewUrl({
    required String? storagePath,
    DateTime? updatedAt,
  }) async {
    if (storagePath == null || storagePath.isEmpty) {
      return null;
    }

    final url = await _resolvePreviewUrlFromBucket(storagePath: storagePath);
    if (url == null) return null;

    if (updatedAt == null) {
      return url;
    }
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}t=${updatedAt.millisecondsSinceEpoch}';
  }

  static Future<void> saveDoodle({
    required String journalEntryId,
    required Uint8List pngBytes,
    required String bgStyle,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final path = '${user.id}/journals/$journalEntryId/doodle.png';
    final savedAt = DateTime.now().toUtc();
    final supabase = Supabase.instance.client;
    final supabaseUrl = supabase.rest.url.replaceAll('/rest/v1', '');
    print('Doodle save → url=$supabaseUrl bucket=$doodlesBucket path=$path');
    if (kDebugMode) {
      try {
        final buckets = await supabase.storage.listBuckets();
        print(
          'Doodle save → visible buckets=${buckets.map((b) => b.id).join(',')}',
        );
      } catch (e) {
        print('Doodle save → listBuckets unavailable for client (ok): $e');
      }
    }

    try {
      await supabase.storage
          .from(doodlesBucket)
          .uploadBinary(
            path,
            pngBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      throw Exception(_storageErrorMessage(e));
    }

    await _updateDoodleMetadata(
      journalEntryId: journalEntryId,
      storagePath: path,
      bgStyle: bgStyle,
      savedAt: savedAt,
    );
  }

  static Future<void> clearDoodle(String journalEntryId) async {
    final supa = Supabase.instance.client;
    try {
      await supa
          .from('journals')
          .update({
            'doodle_storage_path': null,
            'doodle_bg_style': null,
            'doodle_updated_at': null,
          })
          .eq('id', journalEntryId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' &&
          (e.message.contains('doodle_bg_style') ||
              e.message.contains('doodle_updated_at'))) {
        await supa
            .from('journals')
            .update({'doodle_storage_path': null})
            .eq('id', journalEntryId);
        return;
      }
      rethrow;
    }
  }

  static String _storageErrorMessage(StorageException e) {
    final message = e.message.toLowerCase();
    final statusCode = e.statusCode;
    final isRlsError =
        statusCode == '403' &&
        (message.contains('row-level security') ||
            message.contains('violates row-level security policy'));
    if (isRlsError) {
      return "Storage upload blocked by RLS policy on bucket '$doodlesBucket' "
          '(status=$statusCode). Add storage.objects INSERT policy for authenticated users.';
    }
    final isBucketMissing =
        statusCode == '404' ||
        message.contains('bucket') && message.contains('not found');
    if (isBucketMissing) {
      return "Storage bucket '$doodlesBucket' not found "
          '(status=$statusCode, message=${e.message}). '
          'Create it in the same Supabase project your app is using or update bucket name.';
    }
    return 'Storage upload failed (status=$statusCode): ${e.message}';
  }

  static Future<String?> _resolvePreviewUrlFromBucket({
    required String storagePath,
  }) async {
    try {
      final signed = await Supabase.instance.client.storage
          .from(doodlesBucket)
          .createSignedUrl(storagePath, 3600);
      if (signed.isNotEmpty) return signed;
    } catch (_) {}
    try {
      return Supabase.instance.client.storage
          .from(doodlesBucket)
          .getPublicUrl(storagePath);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _updateDoodleMetadata({
    required String journalEntryId,
    required String storagePath,
    required String bgStyle,
    required DateTime savedAt,
  }) async {
    final supa = Supabase.instance.client;
    final fullPayload = <String, dynamic>{
      'doodle_storage_path': storagePath,
      'doodle_bg_style': bgStyle,
      'doodle_updated_at': savedAt.toIso8601String(),
    };

    try {
      await supa.from('journals').update(fullPayload).eq('id', journalEntryId);
      return;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST204') {
        throw Exception('Failed to update doodle metadata: $e');
      }

      // Backward-compatible fallback for environments that have not yet added
      // all doodle metadata columns.
      final fallback = <String, dynamic>{'doodle_storage_path': storagePath};
      if (!e.message.contains('doodle_updated_at')) {
        fallback['doodle_updated_at'] = savedAt.toIso8601String();
      }
      if (!e.message.contains('doodle_bg_style')) {
        fallback['doodle_bg_style'] = bgStyle;
      }

      try {
        await supa.from('journals').update(fallback).eq('id', journalEntryId);
        return;
      } catch (fallbackError) {
        throw Exception('Failed to update doodle metadata: $fallbackError');
      }
    } catch (e) {
      throw Exception('Failed to update doodle metadata: $e');
    }
  }
}
