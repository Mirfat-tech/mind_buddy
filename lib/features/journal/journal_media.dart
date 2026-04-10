import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class JournalMediaItem {
  const JournalMediaItem({
    required this.type,
    this.url,
    this.path,
    this.bucket,
  });

  final String type; // 'image' | 'video'
  final String? url;
  final String? path;
  final String? bucket;
}

List<JournalMediaItem> extractMediaFromController(
  quill.QuillController controller,
) {
  final delta = controller.document.toDelta().toJson();
  return _extractMediaFromDelta(delta);
}

List<JournalMediaItem> extractMediaFromDelta(List<dynamic> delta) {
  return _extractMediaFromDelta(delta);
}

List<JournalMediaItem> _extractMediaFromDelta(List<dynamic> delta) {
  final items = <JournalMediaItem>[];
  for (final op in delta) {
    if (op is Map && op['insert'] is Map) {
      final insert = Map<String, dynamic>.from(op['insert'] as Map);
      if (insert.containsKey('image')) {
        final payload = _parseEmbedPayload(insert['image']?.toString() ?? '');
        items.add(
          JournalMediaItem(
            type: 'image',
            url: payload.url,
            path: payload.path,
            bucket: payload.bucket,
          ),
        );
      } else if (insert.containsKey('video')) {
        final payload = _parseEmbedPayload(insert['video']?.toString() ?? '');
        items.add(
          JournalMediaItem(
            type: 'video',
            url: payload.url,
            path: payload.path,
            bucket: payload.bucket,
          ),
        );
      }
    }
  }
  return items;
}

class _EmbedPayload {
  const _EmbedPayload({this.url, this.path, this.bucket});

  final String? url;
  final String? path;
  final String? bucket;
}

_EmbedPayload _parseEmbedPayload(String data) {
  if (data.isEmpty) return const _EmbedPayload();
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      return _EmbedPayload(
        url: map['url']?.toString(),
        path: map['path']?.toString(),
        bucket: map['bucket']?.toString(),
      );
    }
  } catch (_) {}
  return _EmbedPayload(url: data, path: data);
}

File? resolveMediaFile(JournalMediaItem item) {
  final data = item.path ?? item.url ?? '';
  if (data.startsWith('file://')) {
    return File.fromUri(Uri.parse(data));
  }
  if (data.startsWith('/')) {
    return File(data);
  }
  return null;
}

@immutable
class ResolvedJournalMedia {
  const ResolvedJournalMedia({this.file, this.url});

  final File? file;
  final String? url;
}

Future<ResolvedJournalMedia> resolveJournalMedia(
  JournalMediaItem item, {
  String debugContext = 'journal_media',
}) async {
  final file = resolveMediaFile(item);
  if (file != null) {
    developer.log(
      'journal_media event=render_attempt data={context: $debugContext, type: ${item.type}, source: local_file, path: ${file.path}}',
      name: 'journal_media',
    );
    return ResolvedJournalMedia(file: file);
  }

  final directUrl = item.url;
  if (directUrl != null &&
      directUrl.isNotEmpty &&
      !_looksLikeJsonBlob(directUrl) &&
      _looksLikeRenderableUrl(directUrl)) {
    developer.log(
      'journal_media event=render_attempt data={context: $debugContext, type: ${item.type}, source: direct_url, url: $directUrl}',
      name: 'journal_media',
    );
    return ResolvedJournalMedia(url: directUrl);
  }

  final path = item.path ?? '';
  if (path.isEmpty) {
    developer.log(
      'journal_media event=render_failed data={context: $debugContext, type: ${item.type}, reason: missing_path_and_url}',
      name: 'journal_media',
    );
    return const ResolvedJournalMedia();
  }

  final bucket = (item.bucket ?? 'journal-media').trim();
  try {
    final signed = await Supabase.instance.client.storage
        .from(bucket)
        .createSignedUrl(path, 3600);
    if (signed.isNotEmpty) {
      developer.log(
        'journal_media event=url_resolved data={context: $debugContext, type: ${item.type}, bucket: $bucket, path: $path, mode: signed}',
        name: 'journal_media',
      );
      return ResolvedJournalMedia(url: signed);
    }
  } catch (error) {
    developer.log(
      'journal_media event=url_resolve_failed data={context: $debugContext, type: ${item.type}, bucket: $bucket, path: $path, mode: signed, error: $error}',
      name: 'journal_media',
    );
  }

  try {
    final publicUrl = Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(path);
    if (publicUrl.isNotEmpty) {
      developer.log(
        'journal_media event=url_resolved data={context: $debugContext, type: ${item.type}, bucket: $bucket, path: $path, mode: public}',
        name: 'journal_media',
      );
      return ResolvedJournalMedia(url: publicUrl);
    }
  } catch (error) {
    developer.log(
      'journal_media event=url_resolve_failed data={context: $debugContext, type: ${item.type}, bucket: $bucket, path: $path, mode: public, error: $error}',
      name: 'journal_media',
    );
  }

  developer.log(
    'journal_media event=render_failed data={context: $debugContext, type: ${item.type}, bucket: $bucket, path: $path, reason: no_resolved_url}',
    name: 'journal_media',
  );
  return const ResolvedJournalMedia();
}

bool _looksLikeRenderableUrl(String value) {
  return value.startsWith('http://') || value.startsWith('https://');
}

bool _looksLikeJsonBlob(String value) {
  final trimmed = value.trimLeft();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}
