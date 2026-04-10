import 'package:flutter/foundation.dart';

enum GratitudeCarouselItemType { photo, video, text }

@immutable
class GratitudeCarouselSticker {
  const GratitudeCarouselSticker({
    required this.id,
    required this.stickerId,
    required this.stickerPackId,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });

  final String id;
  final String stickerId;
  final String stickerPackId;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  GratitudeCarouselSticker copyWith({
    String? id,
    String? stickerId,
    String? stickerPackId,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return GratitudeCarouselSticker(
      id: id ?? this.id,
      stickerId: stickerId ?? this.stickerId,
      stickerPackId: stickerPackId ?? this.stickerPackId,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sticker_id': stickerId,
      'sticker_pack_id': stickerPackId,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
    };
  }

  static GratitudeCarouselSticker? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString();
    final stickerId = map['sticker_id']?.toString();
    final stickerPackId = map['sticker_pack_id']?.toString();
    if (id == null ||
        id.isEmpty ||
        stickerId == null ||
        stickerId.isEmpty ||
        stickerPackId == null ||
        stickerPackId.isEmpty) {
      return null;
    }
    return GratitudeCarouselSticker(
      id: id,
      stickerId: stickerId,
      stickerPackId: stickerPackId,
      x: _asDouble(map['x'], fallback: 0.72),
      y: _asDouble(map['y'], fallback: 0.22),
      scale: _asDouble(map['scale'], fallback: 1),
      rotation: _asDouble(map['rotation'], fallback: 0),
    );
  }
}

@immutable
class GratitudeCarouselItem {
  const GratitudeCarouselItem({
    required this.id,
    required this.type,
    this.filePath,
    this.caption = '',
    this.text = '',
    this.stickers = const <GratitudeCarouselSticker>[],
  });

  final String id;
  final GratitudeCarouselItemType type;
  final String? filePath;
  final String caption;
  final String text;
  final List<GratitudeCarouselSticker> stickers;

  bool get isMedia =>
      type == GratitudeCarouselItemType.photo ||
      type == GratitudeCarouselItemType.video;

  GratitudeCarouselItem copyWith({
    String? id,
    GratitudeCarouselItemType? type,
    String? filePath,
    bool clearFilePath = false,
    String? caption,
    String? text,
    List<GratitudeCarouselSticker>? stickers,
  }) {
    return GratitudeCarouselItem(
      id: id ?? this.id,
      type: type ?? this.type,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      caption: caption ?? this.caption,
      text: text ?? this.text,
      stickers: stickers ?? this.stickers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': switch (type) {
        GratitudeCarouselItemType.photo => 'photo',
        GratitudeCarouselItemType.video => 'video',
        GratitudeCarouselItemType.text => 'text',
      },
      if (filePath != null) 'file_path': filePath,
      if (caption.isNotEmpty) 'caption': caption,
      if (text.isNotEmpty) 'text': text,
      if (stickers.isNotEmpty)
        'stickers': stickers.map((sticker) => sticker.toJson()).toList(),
    };
  }

  static GratitudeCarouselItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString();
    final type = _itemTypeFromStorage(map['type']?.toString());
    if (id == null || id.isEmpty || type == null) return null;
    final rawStickers = map['stickers'];
    final stickers = rawStickers is List
        ? rawStickers
              .map(GratitudeCarouselSticker.fromJson)
              .whereType<GratitudeCarouselSticker>()
              .toList()
        : const <GratitudeCarouselSticker>[];
    return GratitudeCarouselItem(
      id: id,
      type: type,
      filePath: map['file_path']?.toString(),
      caption: map['caption']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      stickers: stickers,
    );
  }
}

@immutable
class GratitudeCarouselEntry {
  const GratitudeCarouselEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.seededBubbleTexts = const <String>[],
    this.items = const <GratitudeCarouselItem>[],
  });

  final String id;
  final DateTime date;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> seededBubbleTexts;
  final List<GratitudeCarouselItem> items;

  GratitudeCarouselEntry copyWith({
    String? id,
    DateTime? date,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? seededBubbleTexts,
    List<GratitudeCarouselItem>? items,
  }) {
    return GratitudeCarouselEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      seededBubbleTexts: seededBubbleTexts ?? this.seededBubbleTexts,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'seeded_bubble_texts': seededBubbleTexts,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  static GratitudeCarouselEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString();
    final dateText = map['date']?.toString();
    final title = map['title']?.toString();
    final createdAtText = map['created_at']?.toString();
    final updatedAtText = map['updated_at']?.toString();
    if (id == null ||
        id.isEmpty ||
        dateText == null ||
        title == null ||
        createdAtText == null ||
        updatedAtText == null) {
      return null;
    }
    final date = DateTime.tryParse(dateText);
    final createdAt = DateTime.tryParse(createdAtText);
    final updatedAt = DateTime.tryParse(updatedAtText);
    if (date == null || createdAt == null || updatedAt == null) return null;
    final seeded = (map['seeded_bubble_texts'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    final items = (map['items'] as List?)
            ?.map(GratitudeCarouselItem.fromJson)
            .whereType<GratitudeCarouselItem>()
            .toList() ??
        const <GratitudeCarouselItem>[];
    return GratitudeCarouselEntry(
      id: id,
      date: date,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      seededBubbleTexts: seeded,
      items: items,
    );
  }
}

double _asDouble(Object? value, {required double fallback}) {
  return switch (value) {
    int number => number.toDouble(),
    double number => number,
    String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

GratitudeCarouselItemType? _itemTypeFromStorage(String? value) {
  switch (value) {
    case 'photo':
      return GratitudeCarouselItemType.photo;
    case 'video':
      return GratitudeCarouselItemType.video;
    case 'text':
      return GratitudeCarouselItemType.text;
    default:
      return null;
  }
}
