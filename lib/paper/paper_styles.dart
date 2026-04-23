import 'dart:math' as math;

import 'package:flutter/material.dart';

class PaperStyle {
  const PaperStyle({
    required this.id,
    required this.name,
    required this.paper,
    required this.boxFill,
    required this.border,
    required this.text,
    required this.mutedText,
    required this.accent,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final Color paper;
  final Color boxFill;
  final Color border;
  final Color text;
  final Color mutedText;
  final Color accent;
  final bool isCustom;

  PaperStyle copyWith({
    String? id,
    String? name,
    Color? paper,
    Color? boxFill,
    Color? border,
    Color? text,
    Color? mutedText,
    Color? accent,
    bool? isCustom,
  }) {
    return PaperStyle(
      id: id ?? this.id,
      name: name ?? this.name,
      paper: paper ?? this.paper,
      boxFill: boxFill ?? this.boxFill,
      border: border ?? this.border,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      accent: accent ?? this.accent,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'paper': paper.toARGB32(),
      'boxFill': boxFill.toARGB32(),
      'border': border.toARGB32(),
      'text': text.toARGB32(),
      'mutedText': mutedText.toARGB32(),
      'accent': accent.toARGB32(),
      'isCustom': isCustom,
    };
  }

  factory PaperStyle.fromJson(Map<String, dynamic> json) {
    return PaperStyle(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Custom Theme').toString(),
      paper: _colorFromJson(json['paper'], fallback: const Color(0xFFEFF7FF)),
      boxFill: _colorFromJson(
        json['boxFill'],
        fallback: const Color(0xFFFFFFFF),
      ),
      border: _colorFromJson(json['border'], fallback: const Color(0xFFB7D9FF)),
      text: _colorFromJson(json['text'], fallback: const Color(0xFF1E2A35)),
      mutedText: _colorFromJson(
        json['mutedText'],
        fallback: const Color(0xFF5D7286),
      ),
      accent: _colorFromJson(json['accent'], fallback: const Color(0xFFFF4FB7)),
      isCustom: json['isCustom'] != false,
    );
  }
}

final List<PaperStyle> _presetPaperStyles = <PaperStyle>[
  const PaperStyle(
    id: 'paper_blush',
    name: 'Paper Blush',
    paper: Color(0xFFFFF4F0),
    boxFill: Color(0xFFFFF0F3),
    border: Color(0xFFFFD2DC),
    text: Color(0xFF2B2B2B),
    mutedText: Color(0xFF8A6B74),
    accent: Color(0xFFFF5AA5),
  ),
  const PaperStyle(
    id: 'cream_pop',
    name: 'Cream Pop',
    paper: Color(0xFFFFF7E9),
    boxFill: Color(0xFFFFF1FB),
    border: Color(0xFFFFC7E6),
    text: Color(0xFF2A2A2A),
    mutedText: Color(0xFF7A6B6B),
    accent: Color(0xFFFF3DBA),
  ),
  const PaperStyle(
    id: 'mint_cream',
    name: 'Mint Cream',
    paper: Color(0xFFFFF7E9),
    boxFill: Color(0xFFEFFFF7),
    border: Color(0xFFB7FFD8),
    text: Color(0xFF242424),
    mutedText: Color(0xFF6E7A74),
    accent: Color.fromARGB(255, 28, 195, 150),
  ),
  const PaperStyle(
    id: 'lilac_dream',
    name: 'Lilac Dream',
    paper: Color(0xFFF6F0FF),
    boxFill: Color(0xFFEEF6FF),
    border: Color(0xFFCDBBFF),
    text: Color(0xFF26233A),
    mutedText: Color(0xFF6E6790),
    accent: Color(0xFF5E7BFF),
  ),
  const PaperStyle(
    id: 'lilac_and_pink',
    name: 'Hot and Pink',
    paper: Color(0xFFF6F0FF),
    boxFill: Color(0xFFEEF6FF),
    border: Color(0xFFCDBBFF),
    text: Color(0xFF26233A),
    mutedText: Color(0xFF6E6790),
    accent: Color(0xFFFF4FB7),
  ),
  const PaperStyle(
    id: 'baby_blue',
    name: 'Baby Blue',
    paper: Color(0xFFEFF7FF),
    boxFill: Color(0xFFFFFFFF),
    border: Color(0xFFB7D9FF),
    text: Color(0xFF1E2A35),
    mutedText: Color(0xFF5D7286),
    accent: Color(0xFFFF4FB7),
  ),
  const PaperStyle(
    id: 'Aqua_blue',
    name: 'Aqua Blue',
    paper: Color(0xFFEFF7FF),
    boxFill: Color(0xFFFFFFFF),
    border: Color(0xFFB7D9FF),
    text: Color(0xFF1E2A35),
    mutedText: Color(0xFF5D7286),
    accent: Color.fromARGB(255, 3, 177, 189),
  ),
  const PaperStyle(
    id: 'sage_dream',
    name: 'Sage Dream',
    paper: Color.fromARGB(255, 231, 254, 209),
    boxFill: Color(0xFFEFFFF7),
    border: Color.fromARGB(255, 174, 239, 203),
    text: Color(0xFF242424),
    mutedText: Color(0xFF6E7A74),
    accent: Color(0xFFFF4FB7),
  ),
  const PaperStyle(
    id: 'midnight_pink',
    name: 'Midnight Pink',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color(0xFFF2F4FF),
    mutedText: Color(0xFFA2AACB),
    accent: Color.fromARGB(255, 176, 15, 112),
  ),
  const PaperStyle(
    id: 'midnight_blue',
    name: 'Midnight Blue',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color.fromARGB(255, 196, 196, 206),
    mutedText: Color(0xFFA2AACB),
    accent: Color.fromARGB(255, 5, 80, 255),
  ),
  const PaperStyle(
    id: 'Dark_Orange',
    name: 'Dark & Orange',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color.fromARGB(255, 199, 191, 197),
    mutedText: Color.fromARGB(255, 222, 6, 178),
    accent: Color.fromARGB(255, 186, 42, 28),
  ),
  const PaperStyle(
    id: 'Midnight_green',
    name: 'Midnight green',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color.fromARGB(255, 199, 191, 197),
    mutedText: Color.fromARGB(255, 222, 6, 178),
    accent: Color.fromARGB(255, 34, 121, 12),
  ),
  const PaperStyle(
    id: 'linen_gray',
    name: 'Linen Gray',
    paper: Color(0xFFECEBE8),
    boxFill: Color(0xFFF2F1EE),
    border: Color(0xFFD4D1CA),
    text: Color(0xFF2D2D2D),
    mutedText: Color(0xFF7F7C76),
    accent: Color(0xFFB7B2A8),
  ),
  const PaperStyle(
    id: 'dusty_blue',
    name: 'Dusty Blue Margin',
    paper: Color(0xFFF3F0E8),
    boxFill: Color(0xFFF6F3EC),
    border: Color(0xFFD7D2C8),
    text: Color(0xFF2C2C2C),
    mutedText: Color(0xFF7B766F),
    accent: Color(0xFF6E7C91),
  ),
];

List<PaperStyle> _customPaperStyles = <PaperStyle>[];

const String kDefaultThemeId = 'baby_blue';
const String kFreeFallbackThemeId = 'baby_blue';

const Set<String> kFreeUnlockedThemeIds = <String>{
  'baby_blue',
  'midnight_pink',
};

List<PaperStyle> get presetPaperStyles =>
    List<PaperStyle>.unmodifiable(_presetPaperStyles);

List<PaperStyle> get customPaperStyles =>
    List<PaperStyle>.unmodifiable(_customPaperStyles);

List<PaperStyle> get paperStyles => List<PaperStyle>.unmodifiable(<PaperStyle>[
  ..._presetPaperStyles,
  ..._customPaperStyles,
]);

void setCustomPaperStyles(List<PaperStyle> styles) {
  final seen = <String>{};
  _customPaperStyles = styles
      .where((style) => style.id.trim().isNotEmpty)
      .where(
        (style) => !_presetPaperStyles.any((preset) => preset.id == style.id),
      )
      .where((style) => seen.add(style.id))
      .map((style) => style.copyWith(isCustom: true))
      .toList(growable: false);
}

bool isValidPaperStyleId(String? id) {
  if (id == null || id.trim().isEmpty) return false;
  return paperStyles.any((s) => s.id == id);
}

bool isCustomPaperStyleId(String? id) {
  if (id == null || id.trim().isEmpty) return false;
  return _customPaperStyles.any((s) => s.id == id);
}

PaperStyle styleById(String? id) {
  final resolvedId = isValidPaperStyleId(id) ? id : kDefaultThemeId;
  return paperStyles.firstWhere(
    (s) => s.id == resolvedId,
    orElse: () => _presetPaperStyles.first,
  );
}

bool isThemeAccessibleForFree(PaperStyle style) {
  return !style.isCustom && kFreeUnlockedThemeIds.contains(style.id);
}

String normalizeThemeName(String rawName) {
  final normalized = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.isEmpty ? 'Custom Theme' : normalized;
}

String slugifyThemeName(String rawName) {
  final normalized = rawName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'custom_theme' : normalized;
}

String generateUniqueThemeId(String rawName, Iterable<String> existingIds) {
  final base = slugifyThemeName(rawName);
  final used = existingIds.toSet();
  if (!used.contains(base)) return base;

  var index = 2;
  while (used.contains('${base}_$index')) {
    index += 1;
  }
  return '${base}_$index';
}

PaperStyle buildGuidedCustomPaperStyle({
  required String name,
  required Color paper,
  required Color accent,
  required Iterable<String> existingIds,
  Color? borderOverride,
}) {
  final resolvedName = normalizeThemeName(name);
  final safePaper = _normalizePaper(paper);
  final safeAccent = _normalizeAccent(accent, paper: safePaper);
  final text = _deriveTextColor(safePaper, safeAccent);
  final mutedText = _deriveMutedTextColor(
    paper: safePaper,
    text: text,
    accent: safeAccent,
  );
  final boxFill = _deriveBoxFill(safePaper, safeAccent);
  final border =
      borderOverride ?? _deriveBorder(safePaper, safeAccent, boxFill, text);

  return PaperStyle(
    id: generateUniqueThemeId(resolvedName, existingIds),
    name: resolvedName,
    paper: safePaper,
    boxFill: boxFill,
    border: border,
    text: text,
    mutedText: mutedText,
    accent: safeAccent,
    isCustom: true,
  );
}

Color _normalizePaper(Color color) {
  final hsl = HSLColor.fromColor(color);
  var saturation = hsl.saturation.clamp(0.04, 0.92);
  var lightness = hsl.lightness.clamp(0.06, 0.96);

  // Keep the chosen hue as the source of truth and only gently soften
  // very intense paper tones so they still feel like BrainBubble.
  if (saturation > 0.82) {
    saturation = saturation - 0.08;
  }
  if (lightness > 0.92 && saturation > 0.78) {
    saturation = saturation - 0.04;
  }

  return hsl.withSaturation(saturation).withLightness(lightness).toColor();
}

Color _normalizeAccent(Color color, {required Color paper}) {
  var hsl = HSLColor.fromColor(color);
  final paperHsl = HSLColor.fromColor(paper);
  final paperLuminance = paper.computeLuminance();

  var saturation = hsl.saturation.clamp(0.18, 0.96);
  var lightness = hsl.lightness.clamp(0.16, 0.82);

  if (paperLuminance > 0.82 && lightness > 0.74) {
    lightness = 0.74;
  }
  if (paperLuminance < 0.2 && lightness < 0.2) {
    lightness = 0.2;
  }
  if ((hsl.hue - paperHsl.hue).abs() < 8 && saturation > 0.84) {
    saturation = 0.84;
  }

  hsl = hsl.withSaturation(saturation).withLightness(lightness);
  return hsl.toColor();
}

Color _deriveTextColor(Color paper, Color accent) {
  final paperLum = paper.computeLuminance();
  final preferLight = paperLum < 0.28;
  final seed = preferLight
      ? Color.lerp(Colors.white, accent, 0.06)!
      : Color.lerp(const Color(0xFF172033), accent, 0.08)!;

  return _ensureContrast(
    _soften(seed, amount: 0.12),
    background: paper,
    preferLight: preferLight,
    minContrast: 7.0,
  );
}

Color _deriveMutedTextColor({
  required Color paper,
  required Color text,
  required Color accent,
}) {
  final seed = Color.lerp(
    text,
    paper,
    paper.computeLuminance() < 0.3 ? 0.34 : 0.42,
  )!;
  final touched = Color.lerp(seed, accent, 0.06)!;
  return _ensureContrast(
    _soften(touched, amount: 0.18),
    background: paper,
    preferLight: paper.computeLuminance() < 0.3,
    minContrast: 4.0,
  );
}

Color _deriveBoxFill(Color paper, Color accent) {
  final paperLum = paper.computeLuminance();
  final lifted = paperLum < 0.28
      ? Color.lerp(paper, Colors.white, 0.05)!
      : Color.lerp(paper, Colors.white, 0.12)!;
  final tinted = Color.lerp(lifted, accent, paperLum < 0.28 ? 0.06 : 0.035)!;
  return _soften(tinted, amount: 0.05);
}

Color _deriveBorder(Color paper, Color accent, Color boxFill, Color text) {
  final paperLum = paper.computeLuminance();
  final base = Color.lerp(boxFill, accent, paperLum < 0.28 ? 0.16 : 0.1)!;
  final balanced = Color.lerp(base, text, paperLum < 0.28 ? 0.06 : 0.1)!;
  return _soften(
    paperLum < 0.28
        ? Color.lerp(balanced, Colors.white, 0.05)!
        : Color.lerp(balanced, paper, 0.08)!,
    amount: 0.08,
  );
}

Color _ensureContrast(
  Color candidate, {
  required Color background,
  required bool preferLight,
  required double minContrast,
}) {
  var color = candidate;
  var hsl = HSLColor.fromColor(candidate);
  var attempts = 0;
  while (_contrastRatio(color, background) < minContrast && attempts < 24) {
    final delta = preferLight ? 0.03 : -0.03;
    final nextLightness = (hsl.lightness + delta).clamp(0.02, 0.98);
    hsl = hsl.withLightness(nextLightness);
    color = hsl.toColor();
    attempts += 1;
  }
  return color;
}

Color _soften(Color color, {double amount = 0.12}) {
  final hsl = HSLColor.fromColor(color);
  final nextSaturation = math.max(0.0, hsl.saturation - amount);
  return hsl.withSaturation(nextSaturation).toColor();
}

double _contrastRatio(Color a, Color b) {
  final light = math.max(a.computeLuminance(), b.computeLuminance());
  final dark = math.min(a.computeLuminance(), b.computeLuminance());
  return (light + 0.05) / (dark + 0.05);
}

Color _colorFromJson(dynamic value, {required Color fallback}) {
  final intValue = value is int ? value : (value as num?)?.toInt();
  if (intValue == null) return fallback;
  return Color(intValue);
}
