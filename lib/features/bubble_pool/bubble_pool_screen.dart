import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/bubble_coins/bubble_coin_reward_service.dart';
import 'package:mind_buddy/features/bubble_coins/widgets/bubble_coin_icon.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_collection_service.dart';
import 'package:mind_buddy/features/bubble_pool/game/bubble_pool_game.dart';
import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_item_definition.dart';
import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_slot_definition.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_inventory_service.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_launch_config.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_shop_catalog.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_shop_service.dart';

class BubblePoolScreen extends StatefulWidget {
  const BubblePoolScreen({super.key});

  @override
  State<BubblePoolScreen> createState() => _BubblePoolScreenState();
}

class _BubblePoolScreenState extends State<BubblePoolScreen> {
  final BubbleCoinRewardService _bubbleCoinRewardService =
      BubbleCoinRewardService();
  final BubblePoolInventoryService _inventoryService =
      BubblePoolInventoryService();
  final BubblePoolCollectionService _collectionService =
      BubblePoolCollectionService();
  final BubblePoolShopService _shopService = BubblePoolShopService();
  final Map<BubblePoolItemKind, int> _inventoryCounts =
      <BubblePoolItemKind, int>{};
  final Map<String, DateTime> _collectibleCooldownsByItemId =
      <String, DateTime>{};
  final Set<String> _buyingShopItemIds = <String>{};

  BubblePoolGame? _game;
  BubblePoolItemKind? _selectedInventoryItem;
  bool _poolExpanded = false;
  int _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reloadPoolState();
  }

  Future<void> _reloadPoolState() async {
    final wallet = await _bubbleCoinRewardService.loadWallet();
    final inventory = await _inventoryService.loadInventory();
    final collectibleState = await _collectionService.loadState();
    final nextCounts = <BubblePoolItemKind, int>{};
    for (final kind in BubblePoolItemKind.values) {
      nextCounts[kind] = inventory.itemCountsByKind[kind.name] ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _balance = wallet.balance;
      _inventoryCounts
        ..clear()
        ..addAll(nextCounts);
      _collectibleCooldownsByItemId
        ..clear()
        ..addAll(collectibleState.cooldownEndsAtByItemId);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!bubblePoolEnabledForLaunch) {
      debugPrint('BUBBLE_POOL_DISABLED_FOR_LAUNCH_SHOW_COMING_SOON');
      return buildBubbleComingSoonPage('bubble_pool');
    }
    final scheme = Theme.of(context).colorScheme;
    final palette = BubblePoolScenePalette.fromColorScheme(scheme);
    final game = _game ??= BubblePoolGame(
      palette: palette,
      onPlacedItem: _handlePlacedItem,
      onCollectItem: _handleCollectItem,
    );
    game.applyPalette(palette);
    game.applyCollectibleCooldowns(_collectibleCooldownsByItemId);

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        leading: MbGlowBackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Bubble Pool'),
        actions: [
          _AppBarCoinAction(
            balance: _balance,
            loading: _loading,
            onTap: _openCoinSheet,
          ),
          MbGlowIconButton(
            tooltip: 'Shop',
            icon: Icons.storefront_outlined,
            onPressed: _openShopSheet,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          children: [
            _BubblePoolSceneCard(
              game: game,
              expanded: _poolExpanded,
              onToggleExpanded: _togglePoolExpanded,
            ),
            const SizedBox(height: 10),
            _BubblePoolHintRow(hasSelection: _selectedInventoryItem != null),
            const SizedBox(height: 12),
            _BottomStashButton(onTap: _openStashSheet),
          ],
        ),
      ),
    );
  }

  void _handleInventoryTap(BubblePoolItemKind kind) {
    final count = _inventoryCounts[kind] ?? 0;
    if (count <= 0) return;
    final game = _game;
    if (game == null) return;

    setState(() {
      _selectedInventoryItem = kind;
    });
    game.beginPlacement(kind);
  }

  void _cancelPlacement() {
    _game?.cancelPlacement();
    setState(() {
      _selectedInventoryItem = null;
    });
  }

  void _togglePoolExpanded() {
    setState(() {
      _poolExpanded = !_poolExpanded;
    });
  }

  Future<void> _handlePlacedItem(BubblePoolPlacedItemRecord record) async {
    final kind = BubblePoolItemKind.values.firstWhere(
      (item) => item.name == record.itemId,
    );
    final didConsume = await _inventoryService.consumePlacedItem(kind);
    if (!mounted || !didConsume) return;
    setState(() {
      final current = _inventoryCounts[kind] ?? 0;
      _inventoryCounts[kind] = current > 0 ? current - 1 : 0;
      _selectedInventoryItem = null;
    });
  }

  Future<BubblePoolCollectResult> _handleCollectItem(
    BubblePoolItemDefinition item,
  ) async {
    final result = await _collectionService.collectFromItem(
      collectibleId: item.id,
      rewardAmount: item.collectReward,
      cooldown: item.collectCooldown,
    );
    if (!mounted) return result;
    setState(() {
      _balance = result.updatedBalance;
      if (result.cooldownEndsAt != null) {
        _collectibleCooldownsByItemId[item.id] = result.cooldownEndsAt!;
      } else {
        _collectibleCooldownsByItemId.remove(item.id);
      }
    });
    return result;
  }

  Future<void> _openShopSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetBuilderContext) {
        return StatefulBuilder(
          builder: (modalBuilderContext, setModalState) {
            Future<void> handleBuy(BubblePoolShopItem item) async {
              if (_buyingShopItemIds.contains(item.id)) return;
              setModalState(() => _buyingShopItemIds.add(item.id));
              final result = await _shopService.buyItem(item);
              if (!mounted) return;
              setModalState(() => _buyingShopItemIds.remove(item.id));
              if (result.didPurchase) {
                setState(() {
                  _balance = result.updatedBalance;
                  _inventoryCounts[item.kind] = result.updatedItemCount;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.title} added to inventory.')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message ?? 'Could not buy that item.'),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bubble Pool Shop',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A tiny starter catalogue for now. Purchases use your Bubble Coin wallet directly.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.74),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ShopWalletStrip(balance: _balance),
                    const SizedBox(height: 14),
                    for (final item in bubblePoolStarterCatalog) ...[
                      _ShopItemCard(
                        item: item,
                        buying: _buyingShopItemIds.contains(item.id),
                        onBuy: () => handleBuy(item),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openStashSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHeader(
                  title: 'Stash',
                  actionLabel: 'Close',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 14),
                _InventoryPanel(
                  inventory: _inventoryCounts,
                  selectedItem: _selectedInventoryItem,
                  horizontal: true,
                  showHeader: false,
                  onItemTap: (kind) {
                    Navigator.of(context).pop();
                    _handleInventoryTap(kind);
                  },
                  onCancel: _selectedInventoryItem == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _cancelPlacement();
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCoinSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bubble Coins',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _BubblePoolWalletCard(balance: _balance, loading: _loading),
                const SizedBox(height: 16),
                Text(
                  'Want more Bubble Coins?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final option in const [50, 100, 250]) ...[
                  _CoinOptionTile(amount: option),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BubblePoolWalletCard extends StatelessWidget {
  const _BubblePoolWalletCard({required this.balance, required this.loading});

  final int balance;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            scheme.surface.withValues(alpha: 0.8),
            scheme.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const BubbleCoinIcon(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bubble Coins',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            loading ? '...' : '$balance',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              shadows: [
                Shadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarCoinAction extends StatelessWidget {
  const _AppBarCoinAction({
    required this.balance,
    required this.loading,
    required this.onTap,
  });

  final int balance;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BubbleCoinIcon(size: 24),
                const SizedBox(width: 6),
                Text(
                  loading ? '...' : '$balance',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePoolSceneCard extends StatelessWidget {
  const _BubblePoolSceneCard({
    required this.game,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final BubblePoolGame game;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final collapsedHeight = (viewportHeight * 0.69).clamp(520.0, 740.0);
    final expandedHeight = (viewportHeight * 0.86).clamp(620.0, 920.0);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: collapsedHeight,
        end: expanded ? expandedHeight : collapsedHeight,
      ),
      builder: (context, height, child) {
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: GameWidget<BubblePoolGame>(game: game)),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggleExpanded,
                    borderRadius: BorderRadius.circular(999),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          expanded
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BubblePoolHintRow extends StatelessWidget {
  const _BubblePoolHintRow({required this.hasSelection});
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.clamp(0.0, 560.0).toDouble();
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        hasSelection
                            ? Icons.open_with_rounded
                            : Icons.auto_awesome_rounded,
                        size: 16,
                        color: scheme.primary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hasSelection
                            ? 'Tap a glowing slot to place.'
                            : 'Tap a glowing collectible, or press and hold a placed item to move it.',
                        softWrap: true,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomStashButton extends StatelessWidget {
  const _BottomStashButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.inventory_2_outlined, size: 18, color: scheme.primary),
        label: Text(
          'View stash',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.inventory,
    required this.selectedItem,
    required this.onItemTap,
    required this.onCancel,
    this.horizontal = false,
    this.showHeader = true,
  });

  final Map<BubblePoolItemKind, int> inventory;
  final BubblePoolItemKind? selectedItem;
  final void Function(BubblePoolItemKind kind) onItemTap;
  final VoidCallback? onCancel;
  final bool horizontal;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            scheme.surface.withValues(alpha: 0.94),
            scheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stash',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onCancel != null)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (horizontal)
            SizedBox(
              height: 136,
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 4),
                  itemCount: BubblePoolItemKind.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final kind = BubblePoolItemKind.values[index];
                    return SizedBox(
                      width: 112,
                      child: _InventoryChip(
                        kind: kind,
                        count: inventory[kind] ?? 0,
                        selected: selectedItem == kind,
                        disabled: false,
                        onTap: () => onItemTap(kind),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final kind in BubblePoolItemKind.values)
                  _InventoryChip(
                    kind: kind,
                    count: inventory[kind] ?? 0,
                    selected: selectedItem == kind,
                    disabled: false,
                    onTap: () => onItemTap(kind),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.actionLabel,
    required this.onClose,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onClose,
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.68),
            foregroundColor: scheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onClose, child: Text(actionLabel)),
      ],
    );
  }
}

class _CoinOptionTile extends StatelessWidget {
  const _CoinOptionTile({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            scheme.surface.withValues(alpha: 0.96),
            scheme.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const BubbleCoinIcon(size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$amount coins',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.tonal(
            onPressed: () {},
            child: const Text('Coming soon'),
          ),
        ],
      ),
    );
  }
}

class _InventoryChip extends StatelessWidget {
  const _InventoryChip({
    required this.kind,
    required this.count,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final BubblePoolItemKind kind;
  final int count;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = count > 0 && !disabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? [
                      Colors.white.withValues(alpha: 0.28),
                      scheme.primary.withValues(alpha: 0.22),
                      scheme.primary.withValues(alpha: 0.1),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.18),
                      scheme.surface.withValues(alpha: 0.98),
                      scheme.primary.withValues(alpha: 0.06),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.28)
                  : scheme.primary.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? scheme.primary : scheme.primary).withValues(
                  alpha: selected ? 0.14 : 0.08,
                ),
                blurRadius: selected ? 18 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            (selected
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest)
                                .withValues(alpha: 0.98),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(
                              alpha: selected ? 0.18 : 0.08,
                            ),
                            blurRadius: selected ? 12 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        kind.icon,
                        size: 21,
                        color: enabled
                            ? scheme.primary.withValues(alpha: 0.95)
                            : scheme.onSurface.withValues(alpha: 0.32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kind.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: enabled
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.42),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopWalletStrip extends StatelessWidget {
  const _ShopWalletStrip({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.16),
            scheme.surface,
            scheme.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const BubbleCoinIcon(size: 30),
          const SizedBox(width: 10),
          Text(
            '$balance Bubble Coins',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.item,
    required this.buying,
    required this.onBuy,
  });

  final BubblePoolShopItem item;
  final bool buying;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            scheme.surface.withValues(alpha: 0.94),
            scheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  scheme.primary.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Icon(item.kind.icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BubbleCoinIcon(size: 22, glow: false),
                    const SizedBox(width: 8),
                    Text(
                      '${item.price}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: buying ? null : onBuy,
            child: Text(buying ? 'Buying...' : 'Buy'),
          ),
        ],
      ),
    );
  }
}
