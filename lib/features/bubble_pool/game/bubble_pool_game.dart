import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:mind_buddy/features/bubble_pool/bubble_pool_collection_service.dart';
import 'package:mind_buddy/features/bubble_pool/game/components/bubble_pool_collect_effect_component.dart';
import 'package:mind_buddy/features/bubble_pool/game/components/bubble_pool_decor_item_component.dart';
import 'package:mind_buddy/features/bubble_pool/game/components/bubble_pool_ripple_effect_component.dart';
import 'package:mind_buddy/features/bubble_pool/game/components/bubble_pool_scene_components.dart';
import 'package:mind_buddy/features/bubble_pool/game/components/bubble_pool_slot_component.dart';
import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_item_definition.dart';
import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_slot_definition.dart';

class BubblePoolScenePalette {
  const BubblePoolScenePalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.poolBase,
    required this.waterTop,
    required this.waterBottom,
    required this.glow,
    required this.rim,
    required this.itemLayerTint,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color poolBase;
  final Color waterTop;
  final Color waterBottom;
  final Color glow;
  final Color rim;
  final Color itemLayerTint;

  factory BubblePoolScenePalette.fromColorScheme(ColorScheme scheme) {
    return BubblePoolScenePalette(
      backgroundTop: Color.lerp(
        scheme.surfaceContainerHighest,
        scheme.primary,
        0.12,
      )!,
      backgroundBottom: Color.lerp(scheme.surface, scheme.primary, 0.02)!,
      poolBase: Color.lerp(
        scheme.surfaceContainerHighest,
        scheme.primary,
        0.18,
      )!,
      waterTop: Color.lerp(scheme.primary, Colors.white, 0.56)!,
      waterBottom: Color.lerp(
        scheme.primary,
        scheme.surfaceContainerHighest,
        0.34,
      )!,
      glow: scheme.primary.withValues(alpha: 0.2),
      rim: scheme.primary.withValues(alpha: 0.22),
      itemLayerTint: Color.lerp(
        scheme.primary.withValues(alpha: 0.12),
        scheme.surface,
        0.42,
      )!,
    );
  }
}

class BubblePoolGame extends FlameGame {
  BubblePoolGame({
    required BubblePoolScenePalette palette,
    this.onPlacedItem,
    this.onCollectItem,
  }) : _palette = palette {
    _initializeScene();
  }

  BubblePoolScenePalette _palette;
  final void Function(BubblePoolPlacedItemRecord record)? onPlacedItem;
  final Future<BubblePoolCollectResult> Function(BubblePoolItemDefinition item)?
  onCollectItem;

  late final SceneRectComponent _backgroundLayer;
  late final SceneRectComponent _poolBaseLayer;
  late final PoolStructureComponent _poolStructureLayer;
  late final SceneRectComponent _poolFloorLayer;
  late final SceneRectComponent _waterLayer;
  late final WaterShimmerComponent _waterShimmerLayer;
  late final BubbleDriftComponent _waterBubbleDriftLayer;
  late final GlowOrbComponent _ambientGlow;
  late final GlowOrbComponent _ambientGlowSecondary;
  late final SceneRectComponent _itemLayerGuide;
  late BubblePoolItemPalette _itemPalette;
  Map<BubblePoolItemKind, Sprite> _itemSpritesByKind =
      <BubblePoolItemKind, Sprite>{};
  final List<BubblePoolDecorItemComponent> _sampleItems =
      <BubblePoolDecorItemComponent>[];
  late final List<BubblePoolSlotComponent> _slotComponents;
  final Map<String, BubblePoolDecorItemComponent> _collectibleSampleItemsById =
      <String, BubblePoolDecorItemComponent>{};
  final Map<String, BubblePoolPlacedItemRecord> _placedItemsBySlotId =
      <String, BubblePoolPlacedItemRecord>{};
  final Map<String, BubblePoolDecorItemComponent>
  _placedItemComponentsBySlotId = <String, BubblePoolDecorItemComponent>{};

  BubblePoolItemKind? _placementItemKind;
  BubblePoolDecorItemComponent? _draggingItem;
  String? _dragOriginSlotId;
  String? _highlightedSlotId;
  final Set<String> _collectingSampleItemIds = <String>{};

  void _initializeScene() {
    _backgroundLayer = SceneRectComponent(
      componentPriority: 0,
      gradientBuilder: () => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_palette.backgroundTop, _palette.backgroundBottom],
      ),
    );
    _poolBaseLayer = SceneRectComponent(
      componentPriority: 1,
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      radius: 34,
      gradientBuilder: () => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _palette.poolBase.withValues(alpha: 0.98),
          _palette.poolBase.withValues(alpha: 0.92),
        ],
      ),
    );
    _poolStructureLayer = PoolStructureComponent(
      componentPriority: 2,
      outerMargin: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      waterMargin: const EdgeInsets.fromLTRB(24, 44, 24, 26),
      outerRadius: 34,
      waterRadius: 28,
      frameColorBuilder: () =>
          Color.lerp(_palette.poolBase, Colors.white, 0.12)!,
      rimColorBuilder: () => _palette.rim,
      shadowColorBuilder: () => _palette.backgroundBottom,
      waterHighlightBuilder: () => _palette.waterTop,
    );
    _poolFloorLayer = SceneRectComponent(
      componentPriority: 3,
      margin: const EdgeInsets.fromLTRB(24, 44, 24, 26),
      radius: 28,
      gradientBuilder: () => RadialGradient(
        center: const Alignment(0, -0.24),
        radius: 1.02,
        colors: [
          Color.lerp(
            _palette.waterTop,
            Colors.white,
            0.28,
          )!.withValues(alpha: 0.96),
          Color.lerp(
            _palette.poolBase,
            _palette.waterBottom,
            0.38,
          )!.withValues(alpha: 0.98),
          Color.lerp(
            _palette.poolBase,
            _palette.backgroundBottom,
            0.18,
          )!.withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.58, 1.0],
      ),
    );
    _waterLayer = SceneRectComponent(
      componentPriority: 4,
      margin: const EdgeInsets.fromLTRB(24, 44, 24, 26),
      radius: 28,
      gradientBuilder: () => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _palette.waterTop.withValues(alpha: 0.44),
          _palette.waterBottom.withValues(alpha: 0.62),
        ],
      ),
      borderColorBuilder: () => _palette.rim.withValues(alpha: 0.24),
    );
    _waterShimmerLayer = WaterShimmerComponent(
      componentPriority: 5,
      margin: const EdgeInsets.fromLTRB(24, 44, 24, 26),
      radius: 28,
      colorBuilder: () => _palette.waterTop,
    );
    _waterBubbleDriftLayer = BubbleDriftComponent(
      componentPriority: 6,
      margin: const EdgeInsets.fromLTRB(24, 44, 24, 26),
      colorBuilder: () => _palette.waterTop,
    );
    _ambientGlow = GlowOrbComponent(
      componentPriority: 7,
      alignment: const Alignment(0, -0.18),
      diameterFactor: 0.72,
      colorBuilder: () => Colors.transparent,
    );
    _ambientGlowSecondary = GlowOrbComponent(
      componentPriority: 8,
      alignment: const Alignment(-0.44, -0.34),
      diameterFactor: 0.3,
      colorBuilder: () => Colors.transparent,
    );
    _itemLayerGuide = SceneRectComponent(
      componentPriority: 9,
      margin: const EdgeInsets.fromLTRB(28, 58, 28, 34),
      radius: 24,
      gradientBuilder: () => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.transparent],
      ),
    );
    _itemPalette = BubblePoolItemPalette.fromColorScheme(_buildColorScheme());
    _slotComponents = _buildSlots();
  }

  void applyPalette(BubblePoolScenePalette palette) {
    _palette = palette;
    if (!isMounted) return;
    _syncPalette();
  }

  void applyCollectibleCooldowns(Map<String, DateTime> cooldownsByItemId) {
    for (final entry in _collectibleSampleItemsById.entries) {
      entry.value.syncCollectibleState(
        cooldownEndsAt: cooldownsByItemId[entry.key],
        isCollecting: _collectingSampleItemIds.contains(entry.key),
      );
    }
  }

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    _itemSpritesByKind = await _loadItemSprites();
    _sampleItems
      ..clear()
      ..addAll(_buildSampleItems());

    await addAll([
      _poolStructureLayer,
      _poolFloorLayer,
      _waterLayer,
      _waterShimmerLayer,
      _waterBubbleDriftLayer,
      _itemLayerGuide,
      ..._slotComponents,
      ..._sampleItems,
    ]);
    _syncPalette();
  }

  void beginPlacement(BubblePoolItemKind kind) {
    _placementItemKind = kind;
    _syncPlacementState();
  }

  void cancelPlacement() {
    _placementItemKind = null;
    _syncPlacementState();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _backgroundLayer.syncLayout(size);
    _poolBaseLayer.syncLayout(size);
    _poolStructureLayer.syncLayout(size);
    _poolFloorLayer.syncLayout(size);
    _waterLayer.syncLayout(size);
    _waterShimmerLayer.syncLayout(size);
    _waterBubbleDriftLayer.syncLayout(size);
    _ambientGlow.syncLayout(size);
    _ambientGlowSecondary.syncLayout(size);
    _itemLayerGuide.syncLayout(size);
    final itemBounds = Rect.fromLTWH(
      _itemLayerGuide.position.x,
      _itemLayerGuide.position.y,
      _itemLayerGuide.size.x,
      _itemLayerGuide.size.y,
    );
    for (final slot in _slotComponents) {
      slot.syncLayout(itemBounds);
    }
    for (final item in _sampleItems) {
      item.syncLayout(itemBounds);
    }
    for (final item in _placedItemComponentsBySlotId.values) {
      item.syncLayout(itemBounds);
    }
  }

  void _syncPalette() {
    _backgroundLayer.refresh();
    _poolBaseLayer.refresh();
    _poolFloorLayer.refresh();
    _waterLayer.refresh();
    _ambientGlow.refresh();
    _ambientGlowSecondary.refresh();
    _itemLayerGuide.refresh();
    _itemPalette = BubblePoolItemPalette.fromColorScheme(_buildColorScheme());
    for (final item in _sampleItems) {
      item.updatePalette(_itemPalette);
    }
    for (final item in _placedItemComponentsBySlotId.values) {
      item.updatePalette(_itemPalette);
    }
    _syncPlacementState();
  }

  ColorScheme _buildColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: _palette.rim,
      primary: _palette.waterBottom,
      surface: _palette.backgroundTop,
    );
  }

  List<BubblePoolDecorItemComponent> _buildSampleItems() {
    const definitions = <BubblePoolItemDefinition>[
      BubblePoolItemDefinition(
        id: 'sample-bathtub',
        kind: BubblePoolItemKind.bathtub,
        normalizedX: 0.33,
        normalizedY: 0.69,
        baseSize: 0.31,
        floatAmplitude: 2.6,
        floatSpeed: 0.42,
        swayAmplitude: 0.015,
        swaySpeed: 0.28,
      ),
      BubblePoolItemDefinition(
        id: 'sample-lily-pad',
        kind: BubblePoolItemKind.bubblyLilyPad,
        normalizedX: 0.73,
        normalizedY: 0.5,
        baseSize: 0.235,
        floatAmplitude: 3.8,
        floatSpeed: 0.64,
        swayAmplitude: 0.03,
        swaySpeed: 0.44,
        isCollectible: true,
        collectReward: 1,
        collectCooldown: Duration(minutes: 20),
      ),
      BubblePoolItemDefinition(
        id: 'sample-flower',
        kind: BubblePoolItemKind.flower,
        normalizedX: 0.53,
        normalizedY: 0.32,
        baseSize: 0.17,
        floatAmplitude: 3.2,
        floatSpeed: 0.58,
        swayAmplitude: 0.028,
        swaySpeed: 0.4,
        isCollectible: true,
        collectReward: 1,
        collectCooldown: Duration(minutes: 15),
      ),
    ];

    return [for (final definition in definitions) _buildSampleItem(definition)];
  }

  BubblePoolDecorItemComponent _buildSampleItem(
    BubblePoolItemDefinition definition,
  ) {
    final component = BubblePoolDecorItemComponent(
      definition: definition,
      sprite: _itemSpritesByKind[definition.kind]!,
      palette: _itemPalette,
      collectEnabled: () => _placementItemKind == null && _draggingItem == null,
      onTapCollectItem: _handleCollectibleTap,
    );
    if (definition.isCollectible) {
      _collectibleSampleItemsById[definition.id] = component;
    }
    return component;
  }

  List<BubblePoolSlotComponent> _buildSlots() {
    const definitions = <BubblePoolSlotDefinition>[
      BubblePoolSlotDefinition(
        id: 'slot-top-left',
        normalizedX: 0.22,
        normalizedY: 0.22,
        itemBaseSize: 0.125,
      ),
      BubblePoolSlotDefinition(
        id: 'slot-top-right',
        normalizedX: 0.8,
        normalizedY: 0.22,
        itemBaseSize: 0.125,
      ),
      BubblePoolSlotDefinition(
        id: 'slot-mid-left',
        normalizedX: 0.18,
        normalizedY: 0.5,
        itemBaseSize: 0.18,
      ),
      BubblePoolSlotDefinition(
        id: 'slot-mid-right',
        normalizedX: 0.84,
        normalizedY: 0.54,
        itemBaseSize: 0.18,
      ),
      BubblePoolSlotDefinition(
        id: 'slot-bottom-center',
        normalizedX: 0.54,
        normalizedY: 0.8,
        itemBaseSize: 0.205,
      ),
    ];

    return [
      for (final definition in definitions)
        BubblePoolSlotComponent(
          definition: definition,
          onTapSlot: _handleSlotTap,
          color: _palette.glow,
        ),
    ];
  }

  void _syncPlacementState() {
    for (final slot in _slotComponents) {
      slot.updateVisualState(
        isPlacementActive: _placementItemKind != null,
        isOccupied: _placedItemsBySlotId.containsKey(slot.definition.id),
        isDragCandidate: _highlightedSlotId == slot.definition.id,
        glowColor: _palette.waterTop,
      );
    }
  }

  void _handleSlotTap(String slotId) {
    final itemKind = _placementItemKind;
    if (itemKind == null || _placedItemsBySlotId.containsKey(slotId)) return;

    final slot = _slotComponents.firstWhere(
      (item) => item.definition.id == slotId,
    );
    final record = BubblePoolPlacedItemRecord(
      slotId: slotId,
      itemId: itemKind.name,
    );
    _placeItemRecord(record, slot.definition);
    _placementItemKind = null;
    _syncPlacementState();
    onPlacedItem?.call(record);
  }

  void _placeItemRecord(
    BubblePoolPlacedItemRecord record,
    BubblePoolSlotDefinition slotDefinition, {
    BubblePoolDecorItemComponent? reuseComponent,
  }) {
    _placedItemsBySlotId[record.slotId] = record;

    final definition = BubblePoolItemDefinition(
      id: 'placed-${record.slotId}-${record.itemId}',
      kind: BubblePoolItemKind.values.firstWhere(
        (item) => item.name == record.itemId,
      ),
      normalizedX: slotDefinition.normalizedX,
      normalizedY: slotDefinition.normalizedY,
      baseSize: slotDefinition.itemBaseSize,
      floatAmplitude: 2.4,
      floatSpeed: 0.45,
      swayAmplitude: 0.018,
      swaySpeed: 0.34,
    );
    final component =
        reuseComponent ??
        BubblePoolDecorItemComponent(
          definition: definition,
          sprite: _itemSpritesByKind[definition.kind]!,
          palette: _itemPalette,
          dragEnabled: () => _placementItemKind == null,
          onDragStartItem: _handlePlacedItemDragStart,
          onDragUpdateItem: _handlePlacedItemDragUpdate,
          onDragEndItem: _handlePlacedItemDragEnd,
        );
    component.attachToSlot(slotDefinition);
    component.setDraggingVisual(false);
    _placedItemComponentsBySlotId[record.slotId] = component;
    if (reuseComponent == null) {
      add(component);
    }

    final itemBounds = Rect.fromLTWH(
      _itemLayerGuide.position.x,
      _itemLayerGuide.position.y,
      _itemLayerGuide.size.x,
      _itemLayerGuide.size.y,
    );
    final dragStartPosition = reuseComponent?.position.clone();
    component.syncLayout(itemBounds);
    if (dragStartPosition != null) {
      component.beginSettle(dragStartPosition, component.position.clone());
    }

    final slot = _slotComponents.firstWhere(
      (item) => item.definition.id == record.slotId,
    );
    add(
      BubblePoolRippleEffectComponent(
        center: Vector2(slot.position.x, slot.position.y),
        color: _palette.waterTop,
      ),
    );
  }

  void _handlePlacedItemDragStart(BubblePoolDecorItemComponent item) {
    final slotId = item.slotId;
    if (slotId == null) return;

    _draggingItem = item;
    _dragOriginSlotId = slotId;
    _placedItemsBySlotId.remove(slotId);
    _placedItemComponentsBySlotId.remove(slotId);
    item.setDraggingVisual(true);
    _highlightedSlotId = slotId;
    _syncPlacementState();
  }

  void _handlePlacedItemDragUpdate(BubblePoolDecorItemComponent item) {
    final originSlotId = _dragOriginSlotId;
    if (_draggingItem != item || originSlotId == null) return;
    _clampDraggedItemToPool(item);
    _highlightedSlotId = _findNearestValidSlotId(
      item.position,
      originSlotId: originSlotId,
    );
    _syncPlacementState();
  }

  void _handlePlacedItemDragEnd(BubblePoolDecorItemComponent item) {
    _finalizeDrag(item);
  }

  void _handleCollectibleTap(BubblePoolDecorItemComponent item) {
    final itemId = item.definition.id;
    if (_placementItemKind != null ||
        _draggingItem != null ||
        !item.definition.isCollectible ||
        !_collectingSampleItemIds.add(itemId)) {
      return;
    }
    item.syncCollectibleState(cooldownEndsAt: null, isCollecting: true);
    _collectFromItem(item);
  }

  Future<void> _collectFromItem(BubblePoolDecorItemComponent item) async {
    final callback = onCollectItem;
    final itemId = item.definition.id;
    if (callback == null) {
      _collectingSampleItemIds.remove(itemId);
      item.syncCollectibleState(cooldownEndsAt: null, isCollecting: false);
      return;
    }

    final result = await callback(item.definition);
    _collectingSampleItemIds.remove(itemId);
    item.syncCollectibleState(
      cooldownEndsAt: result.cooldownEndsAt,
      isCollecting: false,
    );
    if (result.didCollect) {
      add(
        BubblePoolCollectEffectComponent(
          center: Vector2(item.position.x, item.position.y),
          color: _palette.waterTop,
        ),
      );
    }
  }

  void _finalizeDrag(BubblePoolDecorItemComponent item) {
    final originSlotId = _dragOriginSlotId;
    if (_draggingItem != item || originSlotId == null) return;

    final targetSlotId =
        _highlightedSlotId ??
        _findNearestValidSlotId(item.position, originSlotId: originSlotId) ??
        originSlotId;
    final targetSlot = _slotComponents.firstWhere(
      (slot) => slot.definition.id == targetSlotId,
    );
    final record = BubblePoolPlacedItemRecord(
      slotId: targetSlotId,
      itemId: item.definition.kind.name,
    );
    _placeItemRecord(record, targetSlot.definition, reuseComponent: item);
    item.setDraggingVisual(false);
    _draggingItem = null;
    _dragOriginSlotId = null;
    _highlightedSlotId = null;
    _syncPlacementState();
  }

  String? _findNearestValidSlotId(
    Vector2 itemPosition, {
    required String originSlotId,
  }) {
    BubblePoolSlotComponent? bestSlot;
    double? bestDistance;

    for (final slot in _slotComponents) {
      final slotId = slot.definition.id;
      final occupied = _placedItemsBySlotId.containsKey(slotId);
      if (occupied) continue;
      final distance = slot.position.distanceTo(itemPosition);
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestSlot = slot;
      }
    }

    if (bestSlot == null) return originSlotId;
    final highlightThreshold = (_itemLayerGuide.size.x * 0.24).clamp(
      90.0,
      128.0,
    );
    if (bestDistance != null && bestDistance > highlightThreshold) {
      return originSlotId;
    }
    return bestSlot.definition.id;
  }

  void _clampDraggedItemToPool(BubblePoolDecorItemComponent item) {
    final bounds = Rect.fromLTWH(
      _itemLayerGuide.position.x,
      _itemLayerGuide.position.y,
      _itemLayerGuide.size.x,
      _itemLayerGuide.size.y,
    );
    final halfWidth = item.size.x * 0.5;
    final halfHeight = item.size.y * 0.5;
    final padding = item.size.x * 0.12;
    final clampedX = item.position.x.clamp(
      bounds.left + halfWidth + padding,
      bounds.right - halfWidth - padding,
    );
    final clampedY = item.position.y.clamp(
      bounds.top + halfHeight + padding,
      bounds.bottom - halfHeight - padding,
    );
    item.position = Vector2(clampedX.toDouble(), clampedY.toDouble());
  }

  Future<Map<BubblePoolItemKind, Sprite>> _loadItemSprites() async {
    final sprites = <BubblePoolItemKind, Sprite>{};
    for (final kind in BubblePoolItemKind.values) {
      final image = await images.load(kind.assetPath);
      sprites[kind] = Sprite(image);
    }
    return sprites;
  }
}
