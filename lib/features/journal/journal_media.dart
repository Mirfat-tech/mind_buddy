import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

@immutable
class JournalMediaItem {
  const JournalMediaItem({
    required this.type,
    this.url,
    this.path,
  });

  final String type; // 'image' | 'video'
  final String? url;
  final String? path;
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
          ),
        );
      } else if (insert.containsKey('video')) {
        final payload = _parseEmbedPayload(insert['video']?.toString() ?? '');
        items.add(
          JournalMediaItem(
            type: 'video',
            url: payload.url,
            path: payload.path,
          ),
        );
      }
    }
  }
  return items;
}

class _EmbedPayload {
  const _EmbedPayload({this.url, this.path});

  final String? url;
  final String? path;
}

_EmbedPayload _parseEmbedPayload(String data) {
  if (data.isEmpty) return const _EmbedPayload();
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded as Map);
      return _EmbedPayload(
        url: map['url']?.toString(),
        path: map['path']?.toString(),
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
