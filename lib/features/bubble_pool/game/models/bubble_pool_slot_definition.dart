class BubblePoolSlotDefinition {
  const BubblePoolSlotDefinition({
    required this.id,
    required this.normalizedX,
    required this.normalizedY,
    required this.itemBaseSize,
  });

  final String id;
  final double normalizedX;
  final double normalizedY;
  final double itemBaseSize;
}

class BubblePoolPlacedItemRecord {
  const BubblePoolPlacedItemRecord({
    required this.slotId,
    required this.itemId,
  });

  final String slotId;
  final String itemId;
}
