import 'package:flutter/material.dart';

enum BubblePoolItemKind { bathtub, bubblyLilyPad, flower }

extension BubblePoolItemKindUi on BubblePoolItemKind {
  String get label {
    return switch (this) {
      BubblePoolItemKind.bathtub => 'Bathtub',
      BubblePoolItemKind.bubblyLilyPad => 'Lily Pad',
      BubblePoolItemKind.flower => 'Flower',
    };
  }

  IconData get icon {
    return switch (this) {
      BubblePoolItemKind.bathtub => Icons.bathtub_outlined,
      BubblePoolItemKind.bubblyLilyPad => Icons.spa_outlined,
      BubblePoolItemKind.flower => Icons.local_florist_outlined,
    };
  }

  String get assetPath {
    return switch (this) {
      BubblePoolItemKind.bathtub => 'bubble_pool/items/bathtub_pastel.png',
      BubblePoolItemKind.bubblyLilyPad =>
        'bubble_pool/items/lily_pad_pastel.png',
      BubblePoolItemKind.flower => 'bubble_pool/items/flower_pastel.png',
    };
  }
}

class BubblePoolItemDefinition {
  const BubblePoolItemDefinition({
    required this.id,
    required this.kind,
    required this.normalizedX,
    required this.normalizedY,
    required this.baseSize,
    this.floatAmplitude = 3,
    this.floatSpeed = 0.55,
    this.swayAmplitude = 0.025,
    this.swaySpeed = 0.42,
    this.isCollectible = false,
    this.collectReward = 0,
    this.collectCooldown = Duration.zero,
  });

  final String id;
  final BubblePoolItemKind kind;
  final double normalizedX;
  final double normalizedY;
  final double baseSize;
  final double floatAmplitude;
  final double floatSpeed;
  final double swayAmplitude;
  final double swaySpeed;
  final bool isCollectible;
  final int collectReward;
  final Duration collectCooldown;
}

class BubblePoolItemPalette {
  const BubblePoolItemPalette({
    required this.tubShell,
    required this.tubRim,
    required this.water,
    required this.waterFoam,
    required this.lilyLeaf,
    required this.lilyGlow,
    required this.flowerPetal,
    required this.flowerCenter,
    required this.shadow,
    required this.outline,
  });

  final Color tubShell;
  final Color tubRim;
  final Color water;
  final Color waterFoam;
  final Color lilyLeaf;
  final Color lilyGlow;
  final Color flowerPetal;
  final Color flowerCenter;
  final Color shadow;
  final Color outline;

  factory BubblePoolItemPalette.fromColorScheme(ColorScheme scheme) {
    return BubblePoolItemPalette(
      tubShell: Color.lerp(scheme.surface, scheme.primary, 0.1)!,
      tubRim: Color.lerp(scheme.outline, scheme.primary, 0.24)!,
      water: Color.lerp(scheme.primary, Colors.white, 0.74)!,
      waterFoam: Colors.white.withValues(alpha: 0.88),
      lilyLeaf: Color.lerp(scheme.primary, Colors.green, 0.35)!,
      lilyGlow: scheme.primary.withValues(alpha: 0.18),
      flowerPetal: Color.lerp(scheme.primary, Colors.pink.shade100, 0.58)!,
      flowerCenter: Color.lerp(scheme.primary, Colors.amber.shade200, 0.45)!,
      shadow: Colors.black.withValues(alpha: 0.08),
      outline: scheme.outline.withValues(alpha: 0.18),
    );
  }
}
