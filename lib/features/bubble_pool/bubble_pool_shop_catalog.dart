import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_item_definition.dart';

class BubblePoolShopItem {
  const BubblePoolShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.price,
  });

  final String id;
  final String title;
  final String description;
  final BubblePoolItemKind kind;
  final int price;
}

const List<BubblePoolShopItem> bubblePoolStarterCatalog = <BubblePoolShopItem>[
  BubblePoolShopItem(
    id: 'starter_cloud_bathtub',
    title: 'Cloud Bathtub',
    description: 'A soft little bathtub for the warmest corner of the pool.',
    kind: BubblePoolItemKind.bathtub,
    price: 6,
  ),
  BubblePoolShopItem(
    id: 'starter_pearl_bathtub',
    title: 'Pearl Bathtub',
    description: 'A rounder tub with a dreamy pearl-bubble feel.',
    kind: BubblePoolItemKind.bathtub,
    price: 8,
  ),
  BubblePoolShopItem(
    id: 'starter_lily_pad',
    title: 'Bubbly Lily Pad',
    description: 'A floaty little pad with bubble clusters and a calm sway.',
    kind: BubblePoolItemKind.bubblyLilyPad,
    price: 4,
  ),
  BubblePoolShopItem(
    id: 'starter_flower',
    title: 'Pool Flower',
    description: 'A tiny glowey flower to soften the waterline.',
    kind: BubblePoolItemKind.flower,
    price: 3,
  ),
];
