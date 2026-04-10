import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show
        Attribute,
        DefaultListBlockStyle,
        DefaultStyles,
        DefaultTextBlockStyle,
        Document,
        LineHeightAttribute,
        VerticalSpacing;

import 'package:mind_buddy/services/journal_canvas_objects.dart';

enum JournalLineSpacing {
  single('single', 'Single', 1.0),
  oneFifteen('1.15', '1.15', 1.15),
  onePointFive('1.5', '1.5', 1.5),
  doubleSpacing('2.0', '2.0', 2.0);

  const JournalLineSpacing(this.storageValue, this.label, this.lineHeight);

  final String storageValue;
  final String label;
  final double lineHeight;

  static JournalLineSpacing fallback = JournalLineSpacing.oneFifteen;

  static JournalLineSpacing fromStorageValue(String? value) {
    switch (value) {
      case 'compact':
        return JournalLineSpacing.single;
      case 'normal':
        return JournalLineSpacing.oneFifteen;
      case 'relaxed':
        return JournalLineSpacing.onePointFive;
    }
    return JournalLineSpacing.values.firstWhere(
      (spacing) => spacing.storageValue == value,
      orElse: () => fallback,
    );
  }

  static JournalLineSpacing fromLineHeightValue(Object? value) {
    final lineHeight = switch (value) {
      int number => number.toDouble(),
      double number => number,
      String text => double.tryParse(text),
      _ => null,
    };
    if (lineHeight == null) return fallback;
    return JournalLineSpacing.values.firstWhere(
      (spacing) => spacing.lineHeight == lineHeight,
      orElse: () => fallback,
    );
  }

  Attribute<double?> get attribute {
    switch (this) {
      case JournalLineSpacing.single:
        return LineHeightAttribute.lineHeightNormal;
      case JournalLineSpacing.oneFifteen:
        return LineHeightAttribute.lineHeightTight;
      case JournalLineSpacing.onePointFive:
        return LineHeightAttribute.lineHeightOneAndHalf;
      case JournalLineSpacing.doubleSpacing:
        return LineHeightAttribute.lineHeightDouble;
    }
  }
}

class JournalDocumentCodec {
  JournalDocumentCodec._();

  static const String _opsKey = 'ops';
  static const String _metaKey = 'meta';
  static const String _canvasObjectsKey = 'canvas_objects';
  static const String _lineSpacingKey = 'line_spacing';
  static const String _lineHeightKey = 'line-height';

  static Document decode(String raw) {
    return decodeContent(raw).document;
  }

  static JournalContentData decodeContent(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return JournalContentData(
          document: Document.fromJson(_normalizeOps(decoded)),
          canvasObjects: const <JournalCanvasObject>[],
        );
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final ops = map[_opsKey];
        if (ops is List) {
          final meta = map[_metaKey] is Map
              ? Map<String, dynamic>.from(map[_metaKey] as Map)
              : const <String, dynamic>{};
          final legacySpacing = JournalLineSpacing.fromStorageValue(
            meta[_lineSpacingKey]?.toString(),
          );
          final objects = _decodeCanvasObjects(map[_canvasObjectsKey]);
          return JournalContentData(
            document: Document.fromJson(
              _normalizeOps(ops, legacyGlobalSpacing: legacySpacing),
            ),
            canvasObjects: objects,
          );
        }
      }
    } catch (_) {}

    return JournalContentData(
      document: Document()..insert(0, raw),
      canvasObjects: const <JournalCanvasObject>[],
    );
  }

  static String encode({
    required Document document,
    List<JournalCanvasObject> canvasObjects = const <JournalCanvasObject>[],
  }) {
    if (canvasObjects.isEmpty) {
      return jsonEncode(document.toDelta().toJson());
    }
    return jsonEncode(<String, dynamic>{
      _opsKey: document.toDelta().toJson(),
      _canvasObjectsKey: canvasObjects.map((object) => object.toJson()).toList(),
    });
  }

  static List<JournalCanvasObject> _decodeCanvasObjects(Object? raw) {
    if (raw is! List) return const <JournalCanvasObject>[];
    return raw
        .map(JournalCanvasObject.fromJson)
        .whereType<JournalCanvasObject>()
        .toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  static String encodeLegacy({required Document document}) {
    return jsonEncode(document.toDelta().toJson());
  }

  static Future<String> hydrateMediaSignedUrls({
    required String rawText,
    required Future<String?> Function({
      required String bucket,
      required String path,
    })
    resolveSignedUrl,
  }) async {
    if (rawText.trim().isEmpty) return rawText;

    dynamic decoded;
    try {
      decoded = jsonDecode(rawText);
    } catch (_) {
      return rawText;
    }

    if (decoded is List) {
      final patched = await _patchOpsWithSignedUrls(
        _normalizeOps(decoded),
        resolveSignedUrl,
      );
      return patched == null ? rawText : jsonEncode(patched);
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final ops = map[_opsKey];
      if (ops is! List) return rawText;
      final meta = map[_metaKey] is Map
          ? Map<String, dynamic>.from(map[_metaKey] as Map)
          : const <String, dynamic>{};
      final legacySpacing = JournalLineSpacing.fromStorageValue(
        meta[_lineSpacingKey]?.toString(),
      );
      final patched = await _patchOpsWithSignedUrls(
        _normalizeOps(ops, legacyGlobalSpacing: legacySpacing),
        resolveSignedUrl,
      );
      if (patched == null) {
        map[_opsKey] = _normalizeOps(ops, legacyGlobalSpacing: legacySpacing);
        return jsonEncode(map);
      }
      map[_opsKey] = patched;
      return jsonEncode(map);
    }

    return rawText;
  }

  static DefaultStyles buildEditorStyles(BuildContext context) {
    final base = DefaultStyles.getInstance(context);
    final baseTextColor = Theme.of(context).colorScheme.onSurface;
    return base.merge(
      DefaultStyles(
        paragraph: _copyBlockStyleWithColor(base.paragraph, baseTextColor),
        lists: _copyListBlockStyleWithColor(base.lists, baseTextColor),
        quote: _copyBlockStyleWithColor(base.quote, baseTextColor),
        code: _copyBlockStyleWithColor(base.code, baseTextColor),
        indent: _copyBlockStyleWithColor(base.indent, baseTextColor),
        align: _copyBlockStyleWithColor(base.align, baseTextColor),
        leading: _copyBlockStyleWithColor(base.leading, baseTextColor),
        lineHeightNormal: _copyLineHeightStyle(
          base.lineHeightNormal,
          JournalLineSpacing.single.lineHeight,
        ),
        lineHeightTight: _copyLineHeightStyle(
          base.lineHeightTight,
          JournalLineSpacing.oneFifteen.lineHeight,
        ),
        lineHeightOneAndHalf: _copyLineHeightStyle(
          base.lineHeightOneAndHalf,
          JournalLineSpacing.onePointFive.lineHeight,
        ),
        lineHeightDouble: _copyLineHeightStyle(
          base.lineHeightDouble,
          JournalLineSpacing.doubleSpacing.lineHeight,
        ),
      ),
    );
  }

  static DefaultTextBlockStyle? _copyLineHeightStyle(
    DefaultTextBlockStyle? source,
    double lineHeight,
  ) {
    if (source == null) return null;
    return source.copyWith(
      style: source.style.copyWith(height: lineHeight),
      lineSpacing: VerticalSpacing.zero,
    );
  }

  static DefaultTextBlockStyle? _copyBlockStyleWithColor(
    DefaultTextBlockStyle? source,
    Color color,
  ) {
    if (source == null) return null;
    return source.copyWith(
      style: source.style.copyWith(color: color, fontWeight: FontWeight.w400),
    );
  }

  static DefaultListBlockStyle? _copyListBlockStyleWithColor(
    DefaultListBlockStyle? source,
    Color color,
  ) {
    if (source == null) return null;
    return source.copyWith(
      style: source.style.copyWith(color: color, fontWeight: FontWeight.w400),
    );
  }

  static List<Map<String, dynamic>> _normalizeOps(
    List<dynamic> ops, {
    JournalLineSpacing? legacyGlobalSpacing,
  }) {
    final normalized = <Map<String, dynamic>>[];

    for (final rawOp in ops) {
      final op = Map<String, dynamic>.from(rawOp as Map);
      if (legacyGlobalSpacing == null ||
          op['insert'] is! String ||
          !(op['insert'] as String).contains('\n')) {
        normalized.add(op);
        continue;
      }

      final insert = op['insert'] as String;
      final attrs = op['attributes'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(op['attributes'] as Map<String, dynamic>)
          : op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};

      if (attrs.containsKey(_lineHeightKey)) {
        normalized.add(op);
        continue;
      }

      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        final text = parts[i];
        if (text.isNotEmpty) {
          normalized.add({
            'insert': text,
            if (attrs.isNotEmpty) 'attributes': attrs,
          });
        }
        if (i == parts.length - 1) continue;
        normalized.add({
          'insert': '\n',
          'attributes': {
            ...attrs,
            _lineHeightKey: legacyGlobalSpacing.lineHeight,
          },
        });
      }
    }

    return normalized;
  }

  static Future<List<Map<String, dynamic>>?> _patchOpsWithSignedUrls(
    List<Map<String, dynamic>> ops,
    Future<String?> Function({required String bucket, required String path})
    resolveSignedUrl,
  ) async {
    var patched = false;
    final nextOps = <Map<String, dynamic>>[];

    for (final rawOp in ops) {
      final op = Map<String, dynamic>.from(rawOp);
      if (op['insert'] is Map) {
        final insert = Map<String, dynamic>.from(op['insert'] as Map);
        for (final key in const ['image', 'video']) {
          final payloadRaw = insert[key]?.toString();
          if (payloadRaw == null || payloadRaw.isEmpty) continue;
          final payload = _parsePayload(payloadRaw);
          final path = payload['path']?.toString();
          if (path == null || path.isEmpty) continue;
          final bucket = payload['bucket']?.toString() ?? 'journal-media';
          final signed = await resolveSignedUrl(bucket: bucket, path: path);
          if (signed == null) continue;
          payload['bucket'] = bucket;
          payload['path'] = path;
          payload['url'] = signed;
          insert[key] = jsonEncode(payload);
          patched = true;
        }
        op['insert'] = insert;
      }
      nextOps.add(op);
    }

    return patched ? nextOps : null;
  }

  static Map<String, dynamic> _parsePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{'path': raw};
  }
}

@immutable
class JournalContentData {
  const JournalContentData({
    required this.document,
    required this.canvasObjects,
  });

  final Document document;
  final List<JournalCanvasObject> canvasObjects;
}
