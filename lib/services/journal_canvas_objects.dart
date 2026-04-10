import 'package:flutter/foundation.dart';

enum JournalCanvasObjectType { image, video, gif, sticker }

@immutable
class JournalCanvasObject {
  const JournalCanvasObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.zIndex,
    this.url,
    this.path,
    this.bucket,
    this.stickerId,
    this.stickerPackId,
  });

  final String id;
  final JournalCanvasObjectType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int zIndex;
  final String? url;
  final String? path;
  final String? bucket;
  final String? stickerId;
  final String? stickerPackId;

  bool get isSticker => type == JournalCanvasObjectType.sticker;
  bool get isImage => type == JournalCanvasObjectType.image;
  bool get isVideo => type == JournalCanvasObjectType.video;
  bool get isGif => type == JournalCanvasObjectType.gif;

  JournalCanvasObject copyWith({
    String? id,
    JournalCanvasObjectType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    String? url,
    String? path,
    String? bucket,
    String? stickerId,
    String? stickerPackId,
    bool clearUrl = false,
    bool clearPath = false,
    bool clearBucket = false,
    bool clearStickerId = false,
    bool clearStickerPackId = false,
  }) {
    return JournalCanvasObject(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      url: clearUrl ? null : (url ?? this.url),
      path: clearPath ? null : (path ?? this.path),
      bucket: clearBucket ? null : (bucket ?? this.bucket),
      stickerId: clearStickerId ? null : (stickerId ?? this.stickerId),
      stickerPackId: clearStickerPackId
          ? null
          : (stickerPackId ?? this.stickerPackId),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': _typeToStorage(type),
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'z_index': zIndex,
      if (url != null) 'url': url,
      if (path != null) 'path': path,
      if (bucket != null) 'bucket': bucket,
      if (stickerId != null) 'sticker_id': stickerId,
      if (stickerPackId != null) 'sticker_pack_id': stickerPackId,
    };
  }

  static JournalCanvasObject? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString();
    final type = _typeFromStorage(map['type']?.toString());
    if (id == null || id.isEmpty || type == null) {
      return null;
    }
    return JournalCanvasObject(
      id: id,
      type: type,
      x: _toDouble(map['x'], fallback: 0.1),
      y: _toDouble(map['y'], fallback: 0.12),
      width: _toDouble(map['width'], fallback: 0.32),
      height: _toDouble(map['height'], fallback: 0.24),
      rotation: _toDouble(map['rotation'], fallback: 0),
      zIndex: _toInt(map['z_index'], fallback: 0),
      url: map['url']?.toString(),
      path: map['path']?.toString(),
      bucket: map['bucket']?.toString(),
      stickerId: map['sticker_id']?.toString(),
      stickerPackId: map['sticker_pack_id']?.toString(),
    );
  }

  static double _toDouble(Object? value, {required double fallback}) {
    return switch (value) {
      int number => number.toDouble(),
      double number => number,
      String text => double.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }

  static int _toInt(Object? value, {required int fallback}) {
    return switch (value) {
      int number => number,
      double number => number.round(),
      String text => int.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }
}

String _typeToStorage(JournalCanvasObjectType type) {
  switch (type) {
    case JournalCanvasObjectType.image:
      return 'image';
    case JournalCanvasObjectType.video:
      return 'video';
    case JournalCanvasObjectType.gif:
      return 'gif';
    case JournalCanvasObjectType.sticker:
      return 'sticker';
  }
}

JournalCanvasObjectType? _typeFromStorage(String? value) {
  switch (value) {
    case 'image':
      return JournalCanvasObjectType.image;
    case 'video':
      return JournalCanvasObjectType.video;
    case 'gif':
      return JournalCanvasObjectType.gif;
    case 'sticker':
      return JournalCanvasObjectType.sticker;
    default:
      return null;
  }
}
