import 'package:flutter/material.dart';

@immutable
class JournalStickerDefinition {
  const JournalStickerDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.accentColor,
    this.assetPath,
  });

  final String id;
  final String label;
  final String category;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color? accentColor;
  final String? assetPath;
}

class JournalStickerCatalog {
  JournalStickerCatalog._();

  static const String starterPackId = 'brain_bubble_starter';

  static const List<JournalStickerDefinition> starterPack =
      <JournalStickerDefinition>[
        JournalStickerDefinition(
          id: 'heart_blossom',
          label: 'Heart',
          category: 'Warm',
          icon: Icons.favorite_rounded,
          backgroundColor: Color(0xFFFFE1E8),
          iconColor: Color(0xFFE85D86),
          accentColor: Color(0xFFFFB3C6),
        ),
        JournalStickerDefinition(
          id: 'soft_star',
          label: 'Star',
          category: 'Dreamy',
          icon: Icons.star_rounded,
          backgroundColor: Color(0xFFFFF1C7),
          iconColor: Color(0xFFE0A928),
          accentColor: Color(0xFFFFD86B),
        ),
        JournalStickerDefinition(
          id: 'sparkle_dust',
          label: 'Sparkle',
          category: 'Dreamy',
          icon: Icons.auto_awesome_rounded,
          backgroundColor: Color(0xFFEFE7FF),
          iconColor: Color(0xFF8C6BD6),
          accentColor: Color(0xFFC9B5FF),
        ),
        JournalStickerDefinition(
          id: 'cloud_hush',
          label: 'Cloud',
          category: 'Calm',
          icon: Icons.cloud_rounded,
          backgroundColor: Color(0xFFE6F4FF),
          iconColor: Color(0xFF63A3D8),
          accentColor: Color(0xFFB8DDFF),
        ),
        JournalStickerDefinition(
          id: 'sleepy_moon',
          label: 'Moon',
          category: 'Calm',
          icon: Icons.nightlight_round,
          backgroundColor: Color(0xFFECE8FF),
          iconColor: Color(0xFF7D74C7),
          accentColor: Color(0xFFC8C2FF),
        ),
        JournalStickerDefinition(
          id: 'petal_bloom',
          label: 'Flower',
          category: 'Cosy',
          icon: Icons.local_florist_rounded,
          backgroundColor: Color(0xFFFFEBF4),
          iconColor: Color(0xFFDB6B96),
          accentColor: Color(0xFFFFBED3),
        ),
        JournalStickerDefinition(
          id: 'soft_bow',
          label: 'Bow',
          category: 'Cosy',
          icon: Icons.interests_rounded,
          backgroundColor: Color(0xFFFFF0E5),
          iconColor: Color(0xFFD47A4A),
          accentColor: Color(0xFFFFD0B3),
        ),
        JournalStickerDefinition(
          id: 'gentle_smile',
          label: 'Smile',
          category: 'Playful',
          icon: Icons.sentiment_satisfied_alt_rounded,
          backgroundColor: Color(0xFFFFF6D6),
          iconColor: Color(0xFFC68B1F),
          accentColor: Color(0xFFFFE39B),
        ),
        JournalStickerDefinition(
          id: 'bubble_pop',
          label: 'Bubble',
          category: 'Playful',
          icon: Icons.bubble_chart_rounded,
          backgroundColor: Color(0xFFE2F4F8),
          iconColor: Color(0xFF4E9BAA),
          accentColor: Color(0xFFA6DDE6),
        ),
        JournalStickerDefinition(
          id: 'calm_leaf',
          label: 'Calm',
          category: 'Calm',
          icon: Icons.spa_rounded,
          backgroundColor: Color(0xFFE9F7E8),
          iconColor: Color(0xFF5C9B68),
          accentColor: Color(0xFFBCE3C1),
        ),
      ];

  static JournalStickerDefinition? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final sticker in starterPack) {
      if (sticker.id == id) return sticker;
    }
    return null;
  }
}

class JournalStickerArt extends StatelessWidget {
  const JournalStickerArt({
    super.key,
    required this.definition,
    this.showLabel = false,
  });

  final JournalStickerDefinition definition;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final accent = definition.accentColor ?? definition.iconColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            definition.backgroundColor,
            Color.lerp(definition.backgroundColor, Colors.white, 0.28)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: 10,
            right: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 18, height: 18),
            ),
          ),
          Center(
            child: Icon(
              definition.icon,
              color: definition.iconColor,
              size: 42,
            ),
          ),
          if (showLabel)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                definition.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: definition.iconColor.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
