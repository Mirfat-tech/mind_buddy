import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';

import 'bubble_entry.dart';
import 'bubble_board_storage.dart';

enum BubblePopEffect { none, waterDroplets }

class BubbleVisualSpec {
  const BubbleVisualSpec({
    required this.color,
    this.glowStrength = 0.4,
    this.opacity = 1,
    this.badgeText,
    this.badgeBackgroundColor,
    this.badgeTextColor = Colors.white,
  });

  final Color color;
  final double glowStrength;
  final double opacity;
  final String? badgeText;
  final Color? badgeBackgroundColor;
  final Color badgeTextColor;
}

class BubbleBoardController {
  const BubbleBoardController({
    required this.entries,
    required this.isDeleteMode,
    required this.isLoading,
    required this.addEntry,
    required this.toggleDeleteMode,
    required this.showEditSheet,
    required this.showSecondaryFieldSheet,
    required this.deleteEntry,
    required this.popEntry,
  });

  final List<BubbleEntry> entries;
  final bool isDeleteMode;
  final bool isLoading;
  final VoidCallback addEntry;
  final VoidCallback toggleDeleteMode;
  final void Function(BubbleEntry entry) showEditSheet;
  final void Function(BubbleEntry entry) showSecondaryFieldSheet;
  final Future<void> Function(BubbleEntry entry) deleteEntry;
  final Future<void> Function(BubbleEntry entry) popEntry;
}

typedef BubbleOverlayBuilder =
    Widget Function(BuildContext context, BubbleBoardController controller);
typedef BubbleVisualBuilder =
    BubbleVisualSpec Function(
      BuildContext context,
      BubbleEntry entry,
      BubbleBoardController controller,
      BubbleVisualSpec defaults,
    );
typedef BubbleTapHandler =
    void Function(
      BuildContext context,
      BubbleEntry entry,
      BubbleBoardController controller,
    );
typedef BubbleAppBarActionsBuilder =
    List<Widget> Function(
      BuildContext context,
      BubbleBoardController controller,
    );

class BubbleBoardScreen extends StatefulWidget {
  const BubbleBoardScreen({
    super.key,
    required this.title,
    required this.storage,
    required this.centerPromptText,
    required this.editSheetHintText,
    required this.saveButtonText,
    required this.clearAllDialogTitle,
    required this.deleteSnackBarText,
    required this.floatingHintKey,
    required this.floatingHintText,
    this.floatingHintIconText = '🫧',
    this.bubblePlaceholderText = 'Tap...',
    this.crowdedHintText = 'Too crowded? Pinch to zoom.',
    this.showSecondaryFieldInEditSheet = false,
    this.secondaryFieldPromptText,
    this.secondaryFieldHintText,
    this.solutionBubblePromptText,
    this.addButtonKey,
    this.canvasContainerKey,
    this.deleteButtonKey,
    this.topOverlayBuilder,
    this.bottomOverlayBuilder,
    this.bubbleVisualBuilder,
    this.onBubbleTap,
    this.appBarActionsBuilder,
    this.onLoaded,
    this.onBackPressed,
    this.popEffect = BubblePopEffect.none,
    this.popAnimationDuration = const Duration(milliseconds: 220),
  });

  final String title;
  final BubbleBoardStorage storage;
  final String centerPromptText;
  final String editSheetHintText;
  final String saveButtonText;
  final String clearAllDialogTitle;
  final String deleteSnackBarText;
  final String floatingHintKey;
  final String floatingHintText;
  final String floatingHintIconText;
  final String bubblePlaceholderText;
  final String crowdedHintText;
  final bool showSecondaryFieldInEditSheet;
  final String? secondaryFieldPromptText;
  final String? secondaryFieldHintText;
  final String? solutionBubblePromptText;
  final GlobalKey? addButtonKey;
  final GlobalKey? canvasContainerKey;
  final GlobalKey? deleteButtonKey;
  final BubbleOverlayBuilder? topOverlayBuilder;
  final BubbleOverlayBuilder? bottomOverlayBuilder;
  final BubbleVisualBuilder? bubbleVisualBuilder;
  final BubbleTapHandler? onBubbleTap;
  final BubbleAppBarActionsBuilder? appBarActionsBuilder;
  final VoidCallback? onLoaded;
  final VoidCallback? onBackPressed;
  final BubblePopEffect popEffect;
  final Duration popAnimationDuration;

  @override
  State<BubbleBoardScreen> createState() => _BubbleBoardScreenState();
}

class _BubbleBoardScreenState extends State<BubbleBoardScreen>
    with TickerProviderStateMixin {
  final List<BubbleEntry> _entries = [];
  final Set<String> _poppingIds = <String>{};
  final TransformationController _canvasController = TransformationController();
  bool _isDeleteMode = false;
  bool _isLoading = true;
  Size? _lastCanvasSize;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _fetchEntries();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  BubbleBoardController _controller() {
    return BubbleBoardController(
      entries: List<BubbleEntry>.unmodifiable(_entries),
      isDeleteMode: _isDeleteMode,
      isLoading: _isLoading,
      addEntry: _addEntry,
      toggleDeleteMode: _toggleDeleteMode,
      showEditSheet: _showEditSheet,
      showSecondaryFieldSheet: _showSecondaryFieldSheet,
      deleteEntry: _deleteEntry,
      popEntry: _popEntry,
    );
  }

  Future<void> _fetchEntries() async {
    try {
      final data = await widget.storage.fetchEntries();
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(data);
        _isLoading = false;
      });
      widget.onLoaded?.call();
    } catch (e) {
      debugPrint('Fetch error for ${widget.title}: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onLoaded?.call();
    }
  }

  Future<void> _upsertEntry(BubbleEntry entry) async {
    try {
      await widget.storage.saveEntry(entry);
      if (!mounted) return;
      setState(() {});
      await _fetchEntries();
    } catch (e) {
      debugPrint('Upsert error for ${widget.title}: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _popEntry(BubbleEntry entry) async {
    if (_poppingIds.contains(entry.id)) return;
    setState(() => _poppingIds.add(entry.id));
    await Future<void>.delayed(widget.popAnimationDuration);
    await _deleteEntry(entry);
    if (!mounted) return;
    setState(() => _poppingIds.remove(entry.id));
  }

  Future<void> _deleteEntry(BubbleEntry entry) async {
    final deletedEntry = entry;
    final originalIndex = _entries.indexOf(entry);

    setState(() {
      _entries.remove(entry);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.deleteSnackBarText),
        backgroundColor: Colors.teal.shade900,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.fixed,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _entries.insert(originalIndex, deletedEntry);
            });
          },
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      controller.close();
    });
    controller.closed.then((reason) async {
      if (reason == SnackBarClosedReason.action) return;
      await widget.storage.deleteEntry(deletedEntry);
    });
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      _isDeleteMode
          ? _shakeController.repeat(reverse: true)
          : _shakeController.stop();
    });
  }

  void _confirmClearAll() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.clearAllDialogTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await widget.storage.clearAll();
              if (!mounted) return;
              setState(() => _entries.clear());
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry() async {
    final size = MediaQuery.of(context).size;
    final viewportCenter = size.center(Offset.zero);
    final worldCenter = _canvasController.toScene(viewportCenter);
    final canvasSize = Size(size.width * 3, size.height * 3);
    final worldOffset = Offset(
      (canvasSize.width - size.width) / 2,
      (canvasSize.height - size.height) / 2,
    );
    final center = Offset(
      worldCenter.dx - worldOffset.dx - 55,
      worldCenter.dy - worldOffset.dy - 100,
    );
    final newEntry = BubbleEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      offset: center,
      createdAt: DateTime.now(),
    );
    final result = await _presentEditSheet(
      initialText: newEntry.text,
      initialSolutionText: newEntry.solutionText,
      includeSecondaryField: false,
    );
    if (!mounted || result == null) return;
    setState(() {
      newEntry.text = result.text;
      newEntry.solutionText = result.solutionText;
      _entries.add(newEntry);
    });
    await _upsertEntry(newEntry);
  }

  void _showEditSheet(BubbleEntry entry) {
    _showEditSheetInternal(entry);
  }

  Future<void> _showEditSheetInternal(BubbleEntry entry) async {
    final result = await _presentEditSheet(
      initialText: entry.text,
      initialSolutionText: entry.solutionText,
      includeSecondaryField: widget.showSecondaryFieldInEditSheet,
    );
    if (!mounted || result == null) return;
    setState(() {
      entry.text = result.text;
      entry.solutionText = result.solutionText;
    });
    await _upsertEntry(entry);
  }

  void _showSecondaryFieldSheet(BubbleEntry entry) {
    _showSecondaryFieldSheetInternal(entry);
  }

  Future<void> _showSecondaryFieldSheetInternal(BubbleEntry entry) async {
    if (widget.secondaryFieldPromptText == null ||
        widget.secondaryFieldHintText == null) {
      await _showEditSheetInternal(entry);
      return;
    }
    final result = await _presentSecondaryFieldSheet(
      entryText: entry.text,
      initialSolutionText: entry.solutionText,
    );
    if (!mounted || result == null) return;
    setState(() {
      entry.solutionText = result.remove ? '' : result.solutionText;
    });
    await _upsertEntry(entry);
  }

  Future<_BubbleEditResult?> _presentEditSheet({
    required String initialText,
    required String initialSolutionText,
    required bool includeSecondaryField,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasSecondaryField =
        includeSecondaryField &&
        widget.secondaryFieldPromptText != null &&
        widget.secondaryFieldHintText != null;
    return showModalBottomSheet<_BubbleEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      builder: (context) => _BubbleEditSheet(
        hintText: widget.editSheetHintText,
        saveButtonText: widget.saveButtonText,
        initialText: initialText,
        initialSolutionText: initialSolutionText,
        secondaryFieldPromptText: hasSecondaryField
            ? widget.secondaryFieldPromptText
            : null,
        secondaryFieldHintText: hasSecondaryField
            ? widget.secondaryFieldHintText
            : null,
      ),
    );
  }

  Future<_SecondaryFieldResult?> _presentSecondaryFieldSheet({
    required String entryText,
    required String initialSolutionText,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<_SecondaryFieldResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      builder: (context) => _SecondaryFieldSheet(
        promptText: widget.secondaryFieldPromptText!,
        hintText: widget.secondaryFieldHintText!,
        saveButtonText: widget.saveButtonText,
        entryText: entryText,
        initialSolutionText: initialSolutionText,
      ),
    );
  }

  double _getBubbleSize(String text, {double scale = 1}) {
    final size = (110.0 + (text.length / 10) * 15).clamp(110.0, 220.0);
    return size * scale;
  }

  BubbleVisualSpec _bubbleVisualSpec(
    BuildContext context,
    BubbleEntry entry,
    BubbleBoardController controller,
  ) {
    final cs = Theme.of(context).colorScheme;
    final defaults = BubbleVisualSpec(color: cs.surface.withOpacity(0.6));
    return widget.bubbleVisualBuilder?.call(
          context,
          entry,
          controller,
          defaults,
        ) ??
        defaults;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final crowdFactor = ((_entries.length - 8).clamp(0, 6)) / 6;
    final crowdScale = (1 - (0.15 * crowdFactor)).clamp(0.75, 1.0);
    final canvasSize = Size(size.width * 3, size.height * 3);
    final worldOffset = Offset(
      (canvasSize.width - size.width) / 2,
      (canvasSize.height - size.height) / 2,
    );
    final controller = _controller();

    if (_lastCanvasSize != size) {
      _lastCanvasSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _canvasController.value = Matrix4.identity()
          ..translate(-worldOffset.dx, -worldOffset.dy);
      });
    }

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: Text(widget.title),
        leading: MbGlowBackButton(
          onPressed:
              widget.onBackPressed ??
              () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
        ),
        actions: [
          ...?widget.appBarActionsBuilder?.call(context, controller),
          if (_entries.isNotEmpty) ...[
            MbGlowIconButton(
              icon: Icons.delete_sweep,
              onPressed: _confirmClearAll,
            ),
            MbGlowIconButton(
              key: widget.deleteButtonKey,
              icon: _isDeleteMode ? Icons.check_circle : Icons.delete_outline,
              iconColor: _isDeleteMode ? Colors.green : cs.onSurface,
              onPressed: _toggleDeleteMode,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: widget.addButtonKey,
        onPressed: _addEntry,
        backgroundColor: cs.primary,
        child: Icon(Icons.add, color: cs.onPrimary),
      ),
      body: MbFloatingHintOverlay(
        hintKey: widget.floatingHintKey,
        text: widget.floatingHintText,
        iconText: widget.floatingHintIconText,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      key: widget.canvasContainerKey,
                      child: InteractiveViewer(
                        transformationController: _canvasController,
                        minScale: 0.7,
                        maxScale: 2.0,
                        panEnabled: true,
                        scaleEnabled: true,
                        constrained: false,
                        boundaryMargin: EdgeInsets.zero,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: canvasSize.width,
                          height: canvasSize.height,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                ),
                              ),
                              Center(
                                child: Text(
                                  widget.centerPromptText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cs.onSurface.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              ..._entries.map((entry) {
                                final bubbleSize = _getBubbleSize(
                                  entry.text,
                                  scale: crowdScale,
                                );
                                return Positioned(
                                  left: entry.offset.dx + worldOffset.dx,
                                  top: entry.offset.dy + worldOffset.dy,
                                  child: RepaintBoundary(
                                    child: _DraggableBubbleEntry(
                                      key: ValueKey<String>(entry.id),
                                      entry: entry,
                                      transformationController:
                                          _canvasController,
                                      onLongPress: () => _popEntry(entry),
                                      onTap: () {
                                        if (_isDeleteMode) {
                                          _deleteEntry(entry);
                                          return;
                                        }
                                        if (widget.onBubbleTap != null) {
                                          widget.onBubbleTap!(
                                            context,
                                            entry,
                                            controller,
                                          );
                                          return;
                                        }
                                        _showEditSheet(entry);
                                      },
                                      onCommit: (nextOffset) {
                                        setState(() {
                                          entry.offset = nextOffset;
                                        });
                                        _upsertEntry(entry);
                                      },
                                      child: _buildBubble(
                                        context,
                                        entry,
                                        bubbleSize: bubbleSize,
                                        controller: controller,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.topOverlayBuilder != null)
                    Positioned(
                      top: 10,
                      left: 16,
                      right: 16,
                      child: widget.topOverlayBuilder!(context, controller),
                    ),
                  if (_entries.length >= 9)
                    Positioned(
                      top: widget.topOverlayBuilder == null ? 24 : 80,
                      left: 24,
                      right: 24,
                      child: Text(
                        widget.crowdedHintText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  if (widget.bottomOverlayBuilder != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 28,
                      child: widget.bottomOverlayBuilder!(context, controller),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    BubbleEntry entry, {
    required double bubbleSize,
    required BubbleBoardController controller,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isPopping = _poppingIds.contains(entry.id);
    final visual = _bubbleVisualSpec(context, entry, controller);
    final hasSolution = entry.solutionText.trim().isNotEmpty;
    final solutionBubbleSize = bubbleSize * 0.46;
    final totalWidth = hasSolution
        ? bubbleSize + (solutionBubbleSize * 0.82)
        : bubbleSize;
    final totalHeight = hasSolution
        ? math.max(bubbleSize, bubbleSize * 0.86 + solutionBubbleSize * 0.42)
        : bubbleSize;
    final solutionLineColor = cs.primary.withValues(alpha: 0.22);

    return AnimatedScale(
      scale: isPopping ? 0.2 : 1,
      duration: widget.popAnimationDuration,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: isPopping ? 0 : visual.opacity,
        duration: widget.popAnimationDuration,
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) => Transform.rotate(
            angle: _isDeleteMode ? (0.05 * _shakeController.value) - 0.025 : 0,
            child: child,
          ),
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: bubbleSize,
                    height: bubbleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: visual.color,
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(visual.glowStrength),
                          blurRadius: 18,
                          blurStyle: BlurStyle.outer,
                        ),
                      ],
                      border: Border.all(
                        color: _isDeleteMode
                            ? Colors.red
                            : cs.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                entry.text.isEmpty
                                    ? widget.bubblePlaceholderText
                                    : entry.text,
                                textAlign: TextAlign.center,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_isDeleteMode)
                          const Positioned(
                            top: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.remove,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (visual.badgeText != null)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    visual.badgeBackgroundColor ??
                                    cs.primary.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                visual.badgeText!,
                                style: TextStyle(
                                  color: visual.badgeTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (hasSolution) ...[
                  Positioned(
                    left: bubbleSize * 0.68,
                    top: bubbleSize * 0.62,
                    child: Transform.rotate(
                      angle: -0.28,
                      child: Container(
                        width: bubbleSize * 0.28,
                        height: 2,
                        decoration: BoxDecoration(
                          color: solutionLineColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: bubbleSize * 0.82,
                    top: bubbleSize * 0.52,
                    child: Container(
                      width: solutionBubbleSize,
                      height: solutionBubbleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surface.withValues(alpha: 0.94),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.14),
                            blurRadius: 10,
                            spreadRadius: 0.4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Text(
                            entry.solutionText,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.solutionBubblePromptText != null &&
                    entry.text.trim().isNotEmpty) ...[
                  Positioned(
                    left: bubbleSize * 0.78,
                    top: bubbleSize * 0.52,
                    child: IgnorePointer(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: bubbleSize * 0.7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          widget.solutionBubblePromptText!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (isPopping && widget.popEffect != BubblePopEffect.none)
                  Positioned(
                    left: -bubbleSize * 0.36,
                    top: -bubbleSize * 0.36,
                    right: -bubbleSize * 0.36,
                    bottom: -bubbleSize * 0.36,
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: widget.popAnimationDuration,
                        curve: Curves.easeOutCubic,
                        builder: (context, progress, _) {
                          switch (widget.popEffect) {
                            case BubblePopEffect.waterDroplets:
                              return CustomPaint(
                                painter: _DropletBurstPainter(
                                  progress: progress,
                                  accent: cs.primary,
                                ),
                              );
                            case BubblePopEffect.none:
                              return const SizedBox.shrink();
                          }
                        },
                      ),
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

class _DropletBurstPainter extends CustomPainter {
  const _DropletBurstPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final fade = Curves.easeOut.transform((1 - progress).clamp(0.0, 1.0));
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(progress);
    final travel = size.width * 0.38 * eased;
    final droplets =
        <
          ({double angle, double radius, double scale, Color color, double arc})
        >[
          (
            angle: -1.82,
            radius: travel * 1.18,
            scale: 1.26,
            color: Color.lerp(
              accent,
              Colors.white,
              0.48,
            )!.withValues(alpha: 0.96 * fade),
            arc: 0.12,
          ),
          (
            angle: -0.96,
            radius: travel * 1.34,
            scale: 1.06,
            color: Color.lerp(
              accent,
              const Color(0xFFAEE7FF),
              0.32,
            )!.withValues(alpha: 0.88 * fade),
            arc: 0.08,
          ),
          (
            angle: -0.16,
            radius: travel * 1.46,
            scale: 1.0,
            color: Color.lerp(
              accent,
              const Color(0xFFFFE2F4),
              0.4,
            )!.withValues(alpha: 0.84 * fade),
            arc: 0.05,
          ),
          (
            angle: 0.68,
            radius: travel * 1.28,
            scale: 1.18,
            color: Color.lerp(
              accent,
              Colors.white,
              0.3,
            )!.withValues(alpha: 0.92 * fade),
            arc: -0.03,
          ),
          (
            angle: 1.42,
            radius: travel * 1.18,
            scale: 0.9,
            color: Color.lerp(
              accent,
              const Color(0xFFBFEFFF),
              0.26,
            )!.withValues(alpha: 0.82 * fade),
            arc: -0.08,
          ),
          (
            angle: 2.28,
            radius: travel * 1.36,
            scale: 1.04,
            color: Color.lerp(
              accent,
              Colors.white,
              0.54,
            )!.withValues(alpha: 0.88 * fade),
            arc: -0.1,
          ),
          (
            angle: -2.6,
            radius: travel * 1.24,
            scale: 0.86,
            color: Color.lerp(
              accent,
              const Color(0xFFD8F3FF),
              0.34,
            )!.withValues(alpha: 0.8 * fade),
            arc: 0.12,
          ),
          (
            angle: -1.36,
            radius: travel * 1.42,
            scale: 0.74,
            color: Color.lerp(
              accent,
              Colors.white,
              0.6,
            )!.withValues(alpha: 0.86 * fade),
            arc: 0.14,
          ),
          (
            angle: 0.12,
            radius: travel * 1.54,
            scale: 0.8,
            color: Color.lerp(
              accent,
              const Color(0xFFFFE7F6),
              0.45,
            )!.withValues(alpha: 0.84 * fade),
            arc: 0.02,
          ),
          (
            angle: 1.96,
            radius: travel * 1.28,
            scale: 0.88,
            color: Color.lerp(
              accent,
              const Color(0xFFA8E6FF),
              0.28,
            )!.withValues(alpha: 0.82 * fade),
            arc: -0.12,
          ),
          (
            angle: 2.9,
            radius: travel * 1.18,
            scale: 0.72,
            color: Color.lerp(
              accent,
              Colors.white,
              0.5,
            )!.withValues(alpha: 0.78 * fade),
            arc: -0.02,
          ),
        ];

    for (final droplet in droplets) {
      final offset = Offset(
        math.cos(droplet.angle) * droplet.radius,
        (math.sin(droplet.angle) * droplet.radius) -
            (size.width * droplet.arc * eased) +
            (size.width * 0.06 * progress * progress),
      );
      _drawDroplet(
        canvas,
        center + offset,
        size.width * 0.062 * droplet.scale * (1 - (progress * 0.16)),
        droplet.color,
        droplet.angle,
      );
    }
  }

  void _drawDroplet(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double angle,
  ) {
    final dropletPath = Path();
    dropletPath.moveTo(center.dx, center.dy - radius * 1.25);
    dropletPath.cubicTo(
      center.dx + radius * 0.86,
      center.dy - radius * 0.38,
      center.dx + radius * 0.9,
      center.dy + radius * 0.64,
      center.dx,
      center.dy + radius,
    );
    dropletPath.cubicTo(
      center.dx - radius * 0.9,
      center.dy + radius * 0.64,
      center.dx - radius * 0.86,
      center.dy - radius * 0.38,
      center.dx,
      center.dy - radius * 1.25,
    );
    dropletPath.close();

    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..rotateZ(angle + math.pi / 2)
      ..translate(-center.dx, -center.dy);
    final transformed = dropletPath.transform(matrix.storage);

    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader =
          LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.78), color],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: radius * 2.2,
              height: radius * 2.8,
            ),
          );
    canvas.drawPath(transformed, glow);
    canvas.drawPath(transformed, fill);
  }

  @override
  bool shouldRepaint(covariant _DropletBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

class _BubbleEditResult {
  const _BubbleEditResult({required this.text, required this.solutionText});

  final String text;
  final String solutionText;
}

class _SecondaryFieldResult {
  const _SecondaryFieldResult.save(this.solutionText) : remove = false;
  const _SecondaryFieldResult.remove() : solutionText = '', remove = true;

  final String solutionText;
  final bool remove;
}

class _BubbleEditSheet extends StatefulWidget {
  const _BubbleEditSheet({
    required this.hintText,
    required this.saveButtonText,
    required this.initialText,
    required this.initialSolutionText,
    this.secondaryFieldPromptText,
    this.secondaryFieldHintText,
  });

  final String hintText;
  final String saveButtonText;
  final String initialText;
  final String initialSolutionText;
  final String? secondaryFieldPromptText;
  final String? secondaryFieldHintText;

  @override
  State<_BubbleEditSheet> createState() => _BubbleEditSheetState();
}

class _BubbleEditSheetState extends State<_BubbleEditSheet> {
  late final TextEditingController _textController;
  late final TextEditingController _solutionController;

  bool get _hasSecondaryField =>
      widget.secondaryFieldPromptText != null &&
      widget.secondaryFieldHintText != null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _solutionController = TextEditingController(
      text: widget.initialSolutionText,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _solutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              autofocus: true,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
              ),
              maxLines: 3,
            ),
            if (_hasSecondaryField) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.secondaryFieldPromptText!,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (_solutionController.text.trim().isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(_solutionController.clear);
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _solutionController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: widget.secondaryFieldHintText,
                        border: InputBorder.none,
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _BubbleEditResult(
                    text: _textController.text,
                    solutionText: _hasSecondaryField
                        ? _solutionController.text.trim()
                        : widget.initialSolutionText,
                  ),
                );
              },
              child: Text(widget.saveButtonText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryFieldSheet extends StatefulWidget {
  const _SecondaryFieldSheet({
    required this.promptText,
    required this.hintText,
    required this.saveButtonText,
    required this.entryText,
    required this.initialSolutionText,
  });

  final String promptText;
  final String hintText;
  final String saveButtonText;
  final String entryText;
  final String initialSolutionText;

  @override
  State<_SecondaryFieldSheet> createState() => _SecondaryFieldSheetState();
}

class _SecondaryFieldSheetState extends State<_SecondaryFieldSheet> {
  late final TextEditingController _solutionController;

  @override
  void initState() {
    super.initState();
    _solutionController = TextEditingController(
      text: widget.initialSolutionText,
    );
  }

  @override
  void dispose() {
    _solutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.promptText,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (widget.entryText.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  widget.entryText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.84),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _solutionController,
              autofocus: true,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.initialSolutionText.trim().isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        const _SecondaryFieldResult.remove(),
                      );
                    },
                    child: const Text('Remove'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _SecondaryFieldResult.save(
                        _solutionController.text.trim(),
                      ),
                    );
                  },
                  child: Text(widget.saveButtonText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableBubbleEntry extends StatefulWidget {
  const _DraggableBubbleEntry({
    super.key,
    required this.entry,
    required this.transformationController,
    required this.onTap,
    required this.onLongPress,
    required this.onCommit,
    required this.child,
  });

  final BubbleEntry entry;
  final TransformationController transformationController;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onCommit;
  final Widget child;

  @override
  State<_DraggableBubbleEntry> createState() => _DraggableBubbleEntryState();
}

class _DraggableBubbleEntryState extends State<_DraggableBubbleEntry> {
  Offset? _draggedOffset;

  Offset get _activeOffset => _draggedOffset ?? widget.entry.offset;

  @override
  Widget build(BuildContext context) {
    final delta = _activeOffset - widget.entry.offset;
    return Transform.translate(
      offset: delta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onPanUpdate: (details) {
          final scale = widget.transformationController.value
              .getMaxScaleOnAxis();
          final sceneDelta = details.delta / (scale <= 0 ? 1 : scale);
          final base = _draggedOffset ?? widget.entry.offset;
          setState(() {
            _draggedOffset = base + sceneDelta;
          });
        },
        onPanEnd: (_) {
          final committed = _draggedOffset;
          if (committed != null) {
            widget.onCommit(committed);
          }
          setState(() {
            _draggedOffset = null;
          });
        },
        onPanCancel: () {
          setState(() {
            _draggedOffset = null;
          });
        },
        child: widget.child,
      ),
    );
  }
}
