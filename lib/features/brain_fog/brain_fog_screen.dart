import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/brain_fog/brain_fog_repository.dart';
import 'package:mind_buddy/features/brain_fog/data/local/brain_fog_local_data_source.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrainFogScreen extends ConsumerStatefulWidget {
  const BrainFogScreen({
    super.key,
    this.guidesEnabled = true,
    this.onBackPressed,
    this.onFigureOutRoute,
  });

  final bool guidesEnabled;
  final VoidCallback? onBackPressed;
  final void Function(String route)? onFigureOutRoute;

  @override
  ConsumerState<BrainFogScreen> createState() => _BrainFogScreenState();
}

class _Thought {
  _Thought({required this.id, this.text = '', required this.offset});
  final String id;
  String text;
  Offset offset;
}

class _BrainFogScreenState extends ConsumerState<BrainFogScreen>
    with TickerProviderStateMixin {
  final List<_Thought> _thoughts = [];
  final Set<String> _poppingIds = {};
  bool _isDeleteMode = false;
  bool _isLoading = true;
  late AnimationController _shakeController;
  final TransformationController _canvasController = TransformationController();
  Size? _lastCanvasSize;
  bool _figureOutMode = false;
  int _figureStep =
      0; // 0 = off, 1 = controllable, 2 = focus order, 3 = let go, 4 = next step
  final Set<String> _controllableIds = <String>{};
  final List<String> _focusOrder = <String>[];
  final GlobalKey _addBubbleButtonKey = GlobalKey();
  final GlobalKey _brainFogCanvasContainerKey = GlobalKey();
  final GlobalKey _modeToggleKey = GlobalKey();
  final GlobalKey _deleteButtonKey = GlobalKey();
  bool _guideStartedThisOpen = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _loadThoughtsFromLocal();
  }

  @override
  void dispose() {
    GuideManager.dismissActiveGuideForPage('brainFog');
    _shakeController.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  Future<void> _showGuideIfNeeded({bool force = false}) async {
    if (!widget.guidesEnabled) return;
    if (!force && _guideStartedThisOpen) return;
    if (!force) {
      _guideStartedThisOpen = true;
    }
    final prefs = await SharedPreferences.getInstance();
    const seenKey = 'pageGuideShown_brainFog';
    final keepVisible = prefs.getBool('keepInstructionsVisible') ?? false;
    final shown = prefs.getBool(seenKey) ?? false;

    final fullSteps = _brainFogGuideSteps(includeDelete: true);
    final reducedSteps = _brainFogGuideSteps(includeDelete: false);

    for (var attempt = 1; attempt <= 10; attempt++) {
      if (!mounted) return;
      final addReady = _isTargetReady(_addBubbleButtonKey);
      final canvasReady = _isTargetReady(_brainFogCanvasContainerKey);
      final modeReady = _isTargetReady(_modeToggleKey);
      final deleteReady = _isTargetReady(_deleteButtonKey);
      final canRunFull = addReady && canvasReady && modeReady && deleteReady;

      debugPrint(
        '[Guide][brainFog] pageId=brainFog keepInstructionsVisible=$keepVisible '
        'pageGuideShown_brainFog=$shown attempt=$attempt/10 steps.length=${fullSteps.length}',
      );
      for (final step in fullSteps) {
        final hasContext = step.key.currentContext != null;
        debugPrint(
          '[Guide][brainFog] step="${step.title}" hasContext=$hasContext '
          'targetReady=${_isTargetReady(step.key)}',
        );
      }

      if (canRunFull) {
        await GuideManager.showGuideIfNeeded(
          context: context,
          pageId: 'brainFog',
          force: force,
          steps: fullSteps,
          requireAllTargetsVisible: true,
          debugLogs: true,
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    debugPrint(
      '[Guide][brainFog] full target set not ready after retries. '
      'Starting reduced guide with stable targets only.',
    );
    debugPrint(
      '[Guide][brainFog] reduced steps.length=${reducedSteps.length} '
      'targetsReady=${reducedSteps.map((e) => _isTargetReady(e.key)).toList()}',
    );
    final steps = <GuideStep>[
      for (final step in reducedSteps)
        if (_isTargetReady(step.key)) step,
    ];
    if (!mounted) return;
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'brainFog',
      force: force,
      steps: steps,
      requireAllTargetsVisible: true,
      debugLogs: true,
    );
  }

  List<GuideStep> _brainFogGuideSteps({required bool includeDelete}) {
    return <GuideStep>[
      GuideStep(
        key: _addBubbleButtonKey,
        title: 'Got a thought floating?',
        body: 'Tap + to release a new fog bubble.',
        align: GuideAlign.top,
      ),
      GuideStep(
        key: _brainFogCanvasContainerKey,
        title: 'Let your mind wander',
        body: 'Drag bubbles anywhere. No right place.',
        align: GuideAlign.bottom,
      ),
      GuideStep(
        key: _modeToggleKey,
        title: '🫧 Ready to bring things into focus?',
        body: 'Turn on Figure-Out Mode to organise your foggy thoughts.',
        align: GuideAlign.bottom,
      ),
      if (includeDelete)
        GuideStep(
          key: _deleteButtonKey,
          title: 'Ready to let it go?',
          body: 'Hold a bubble to dissolve it.',
          align: GuideAlign.bottom,
        ),
      GuideStep(
        key: _brainFogCanvasContainerKey,
        title: 'Need perspective?',
        body: 'Pinch to zoom out.',
        align: GuideAlign.top,
      ),
    ];
  }

  bool _isTargetReady(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return false;
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return false;
    final size = render.size;
    return size.width > 0 && size.height > 0;
  }

  void _scheduleGuideAutoStart() {
    if (!widget.guidesEnabled) return;
    if (!mounted || _guideStartedThisOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading) return;
      Future<void>.delayed(const Duration(milliseconds: 24), () {
        if (!mounted || _isLoading || _guideStartedThisOpen) return;
        _showGuideIfNeeded();
      });
    });
  }

  // --- LOCAL-FIRST LOGIC ---
  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';

  List<BrainFogThoughtRecord> _thoughtSnapshot() {
    return _thoughts
        .map(
          (thought) => BrainFogThoughtRecord(
            id: thought.id,
            text: thought.text,
            dx: thought.offset.dx,
            dy: thought.offset.dy,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _persistCurrentState({required String reason}) {
    return ref
        .read(brainFogRepositoryProvider)
        .saveState(
          userId: _currentUserId,
          thoughts: _thoughtSnapshot(),
          isDeleteMode: _isDeleteMode,
          figureOutMode: _figureOutMode,
          figureStep: _figureStep,
          controllableIds: _controllableIds,
          focusOrder: _focusOrder,
          reason: reason,
        );
  }

  Future<void> _loadThoughtsFromLocal() async {
    try {
      final data = await ref
          .read(brainFogRepositoryProvider)
          .loadState(userId: _currentUserId);
      setState(() {
        _thoughts.clear();
        if (data != null) {
          for (final item in data.thoughts) {
            _thoughts.add(
              _Thought(
                id: item.id,
                text: item.text,
                offset: Offset(item.dx, item.dy),
              ),
            );
          }
          _isDeleteMode = data.isDeleteMode;
          _figureOutMode = data.figureOutMode;
          _figureStep = data.figureStep;
          _controllableIds
            ..clear()
            ..addAll(data.controllableIds);
          _focusOrder
            ..clear()
            ..addAll(data.focusOrder);
        } else {
          _isDeleteMode = false;
          _figureOutMode = false;
          _figureStep = 0;
          _controllableIds.clear();
          _focusOrder.clear();
        }
        _thoughts.removeWhere((thought) => thought.id.trim().isEmpty);
        _isLoading = false;
      });
      if (_isDeleteMode) {
        _shakeController.repeat(reverse: true);
      } else {
        _shakeController.stop();
      }
      _scheduleGuideAutoStart();
    } catch (e) {
      debugPrint('Fetch error: $e');
      setState(() => _isLoading = false);
      _scheduleGuideAutoStart();
    }
  }

  Future<void> _upsertThought(_Thought thought) async {
    try {
      await _persistCurrentState(
        reason: thought.text.trim().isEmpty
            ? 'position_update'
            : 'save_thought',
      );
    } catch (e) {
      debugPrint('BRAINFOG_SAVE_LOCAL_ERROR: $e');
      setState(() => _isLoading = false); // Safety net
    }
  }

  Future<void> _popThought(_Thought thought) async {
    if (_poppingIds.contains(thought.id)) return;
    setState(() => _poppingIds.add(thought.id));
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await _deleteThought(thought);
    if (!mounted) return;
    setState(() => _poppingIds.remove(thought.id));
  }

  // ... inside _BrainFogScreenState ...

  Future<void> _deleteThought(_Thought thought) async {
    final deletedThought = thought;
    final originalIndex = _thoughts.indexOf(thought);

    setState(() {
      _thoughts.remove(thought);
    });
    await _persistCurrentState(reason: 'delete_thought');
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Thought cleared...'),
        backgroundColor: Colors.teal.shade900,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.fixed,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () async {
            setState(() {
              _thoughts.insert(originalIndex, deletedThought);
            });
            await _persistCurrentState(reason: 'undo_delete_thought');
          },
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      controller.close();
    });
  }

  // ... inside your build method AppBar ...

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear all thoughts?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _thoughts.clear();
                _isDeleteMode = false;
                _figureOutMode = false;
                _figureStep = 0;
                _controllableIds.clear();
                _focusOrder.clear();
              });
              await _persistCurrentState(reason: 'clear_all');
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- UI LOGIC ---

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      _isDeleteMode
          ? _shakeController.repeat(reverse: true)
          : _shakeController.stop();
    });
    _persistCurrentState(reason: 'toggle_delete_mode');
  }

  void _toggleFigureOutMode() {
    setState(() {
      _figureOutMode = !_figureOutMode;
      _figureStep = _figureOutMode ? 1 : 0;
      _controllableIds.clear();
      _focusOrder.clear();
    });
    _persistCurrentState(reason: 'toggle_figure_out_mode');
  }

  void _advanceFigureStep() {
    if (!_figureOutMode) return;
    setState(() {
      if (_figureStep < 4) {
        _figureStep += 1;
      } else {
        _figureOutMode = false;
        _figureStep = 0;
        _controllableIds.clear();
        _focusOrder.clear();
      }
    });
    _persistCurrentState(reason: 'advance_figure_step');
  }

  void _handleFigureTap(_Thought thought) {
    if (!_figureOutMode) return;
    if (_figureStep == 1) {
      setState(() {
        if (_controllableIds.contains(thought.id)) {
          _controllableIds.remove(thought.id);
          _focusOrder.remove(thought.id);
        } else {
          _controllableIds.add(thought.id);
        }
      });
      _persistCurrentState(reason: 'select_controllable');
      return;
    }
    if (_figureStep == 2) {
      if (!_controllableIds.contains(thought.id)) return;
      setState(() {
        if (_focusOrder.contains(thought.id)) {
          _focusOrder.remove(thought.id);
        } else {
          _focusOrder.add(thought.id);
        }
      });
      _persistCurrentState(reason: 'update_focus_order');
      return;
    }
  }

  void _goFigureAction(String route) {
    setState(() {
      _figureOutMode = false;
      _figureStep = 0;
      _controllableIds.clear();
      _focusOrder.clear();
    });
    _persistCurrentState(reason: 'leave_figure_out_mode');
    if (widget.onFigureOutRoute != null) {
      widget.onFigureOutRoute!(route);
      return;
    }
    context.go(route);
  }

  void _addThought() {
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
    final newThought = _Thought(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      offset: center,
    );
    setState(() => _thoughts.add(newThought));
    _showEditSheet(newThought);
  }

  void _showEditSheet(_Thought thought) {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: thought.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
                maxLines: 3,
              ),
              FilledButton(
                onPressed: () {
                  setState(() => thought.text = controller.text);
                  _upsertThought(thought);
                  Navigator.pop(context);
                },
                child: const Text("Keep Thought"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getBubbleSize(String text, {double scale = 1}) {
    final size = (110.0 + (text.length / 10) * 15).clamp(110.0, 220.0);
    return size * scale;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final crowdFactor = ((_thoughts.length - 8).clamp(0, 6)) / 6;
    final crowdScale = (1 - (0.15 * crowdFactor)).clamp(0.75, 1.0);
    final canvasSize = Size(size.width * 3, size.height * 3);
    final worldOffset = Offset(
      (canvasSize.width - size.width) / 2,
      (canvasSize.height - size.height) / 2,
    );

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
        title: const Text('Brain Fog'),
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
          MbGlowIconButton(
            icon: Icons.help_outline,
            onPressed: () {
              if (!widget.guidesEnabled) return;
              _showGuideIfNeeded(force: true);
            },
          ),
          MbGlowIconButton(
            icon: Icons.notifications_outlined,
            onPressed: () => context.push('/settings/notifications'),
          ),
          if (_thoughts.isNotEmpty) ...[
            MbGlowIconButton(
              icon: Icons.delete_sweep,
              onPressed: _confirmClearAll,
            ),
            MbGlowIconButton(
              key: _deleteButtonKey,
              icon: _isDeleteMode ? Icons.check_circle : Icons.delete_outline,
              iconColor: _isDeleteMode ? Colors.green : cs.onSurface,
              onPressed: _toggleDeleteMode,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _addBubbleButtonKey,
        onPressed: _addThought,
        backgroundColor: cs.primary,
        child: Icon(Icons.add, color: cs.onPrimary),
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_brain_fog',
        text: 'Long press to pop. Tap to edit. Drag to move.',
        iconText: '🫧',
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      key: _brainFogCanvasContainerKey,
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
                                  "Let it out 💨 \nWhat's overwhelming you today?",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cs.onSurface.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              ..._thoughts.map((t) {
                                final bubbleSize = _getBubbleSize(
                                  t.text,
                                  scale: crowdScale,
                                );
                                return Positioned(
                                  left: t.offset.dx + worldOffset.dx,
                                  top: t.offset.dy + worldOffset.dy,
                                  child: RepaintBoundary(
                                    child: _DraggableThoughtBubble(
                                      key: ValueKey<String>(t.id),
                                      thought: t,
                                      transformationController:
                                          _canvasController,
                                      onLongPress: () => _popThought(t),
                                      onTap: () => _isDeleteMode
                                          ? _deleteThought(t)
                                          : (_figureOutMode
                                                ? _handleFigureTap(t)
                                                : _showEditSheet(t)),
                                      onCommit: (nextOffset) {
                                        setState(() {
                                          t.offset = nextOffset;
                                        });
                                        _upsertThought(t);
                                      },
                                      child: _buildBubble(
                                        t,
                                        bubbleSize: bubbleSize,
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
                  Positioned(
                    top: 10,
                    left: 16,
                    right: 16,
                    child: KeyedSubtree(
                      key: _modeToggleKey,
                      child: _FigureOutCard(
                        enabled: _figureOutMode,
                        step: _figureStep,
                        canAdvance: _figureStep == 1
                            ? _controllableIds.isNotEmpty
                            : (_figureStep == 2
                                  ? _focusOrder.isNotEmpty
                                  : true),
                        onToggle: _toggleFigureOutMode,
                        onNext: _advanceFigureStep,
                      ),
                    ),
                  ),
                  if (_thoughts.length >= 9)
                    Positioned(
                      top: 80,
                      left: 24,
                      right: 24,
                      child: Text(
                        'Too crowded? Pinch to zoom.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  if (_figureOutMode && _figureStep == 4)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 28,
                      child: _FigureOutActions(
                        onJournal: () => _goFigureAction('/journals'),
                        onHabit: () => _goFigureAction('/habits'),
                        onPomodoro: () => _goFigureAction('/pomodoro'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildBubble(_Thought t, {required double bubbleSize}) {
    final cs = Theme.of(context).colorScheme;
    double bSize = bubbleSize;
    final isPopping = _poppingIds.contains(t.id);
    final isControllable = _controllableIds.contains(t.id);
    final focusIndex = _focusOrder.indexOf(t.id);
    final isFocused = focusIndex >= 0;
    final isDimmed =
        _figureOutMode &&
        ((_figureStep == 1 && !isControllable) ||
            (_figureStep >= 2 && !isFocused));
    final baseColor = cs.surface.withOpacity(0.6);
    final highlightColor = cs.primary.withOpacity(0.35);
    final bubbleColor = _figureOutMode && (isControllable || isFocused)
        ? highlightColor
        : baseColor;
    final glowStrength = _figureOutMode && (isControllable || isFocused)
        ? 0.65
        : 0.4;

    return AnimatedScale(
      scale: isPopping ? 0.2 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: isPopping ? 0 : (isDimmed ? 0.55 : 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) => Transform.rotate(
            angle: _isDeleteMode ? (0.05 * _shakeController.value) - 0.025 : 0,
            child: child,
          ),
          child: Container(
            width: bSize,
            height: bSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bubbleColor,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(glowStrength),
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
                        t.text.isEmpty ? "Tap..." : t.text,
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
                      child: Icon(Icons.remove, size: 16, color: Colors.white),
                    ),
                  ),
                if (_figureOutMode && isFocused)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${focusIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
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
      ),
    );
  }
}

class _DraggableThoughtBubble extends StatefulWidget {
  const _DraggableThoughtBubble({
    super.key,
    required this.thought,
    required this.transformationController,
    required this.onTap,
    required this.onLongPress,
    required this.onCommit,
    required this.child,
  });

  final _Thought thought;
  final TransformationController transformationController;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onCommit;
  final Widget child;

  @override
  State<_DraggableThoughtBubble> createState() =>
      _DraggableThoughtBubbleState();
}

class _DraggableThoughtBubbleState extends State<_DraggableThoughtBubble> {
  Offset? _draggedOffset;

  Offset get _activeOffset => _draggedOffset ?? widget.thought.offset;

  @override
  Widget build(BuildContext context) {
    final delta = _activeOffset - widget.thought.offset;
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
          final base = _draggedOffset ?? widget.thought.offset;
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

class _FigureOutCard extends StatelessWidget {
  const _FigureOutCard({
    required this.enabled,
    required this.step,
    required this.canAdvance,
    required this.onToggle,
    required this.onNext,
  });

  final bool enabled;
  final int step;
  final bool canAdvance;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  String _prompt() {
    if (!enabled) {
      return 'Figure-Out Mode';
    }
    switch (step) {
      case 1:
        return 'Out of all of this… what can you actually control?';
      case 2:
        return 'Okay… what do you want to work on first?';
      case 3:
        return 'What can we let go of for now? (hold to pop)';
      case 4:
        return 'Do you want to talk it out… plan it out… focus on it… or just let it out?';
      default:
        return 'Figure-Out Mode';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🧠'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _prompt(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(value: enabled, onChanged: (_) => onToggle()),
          if (enabled && step > 0)
            TextButton(
              onPressed: canAdvance ? onNext : null,
              child: Text(step < 4 ? 'Next' : 'Done'),
            ),
        ],
      ),
    );
  }
}

class _FigureOutActions extends StatelessWidget {
  const _FigureOutActions({
    required this.onJournal,
    required this.onHabit,
    required this.onPomodoro,
  });

  final VoidCallback onJournal;
  final VoidCallback onHabit;
  final VoidCallback onPomodoro;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How do you want to handle this?',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Choose one gentle next step.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionBubble(
                icon: '📖',
                title: 'Write it through',
                subtitle: 'Slow down and untangle it.',
                onTap: onJournal,
              ),
              _ActionBubble(
                icon: '✅',
                title: 'Build something small',
                subtitle: 'Make it easier for future you.',
                onTap: onHabit,
              ),
              _ActionBubble(
                icon: '⏱',
                title: 'Focus for 10',
                subtitle: 'Start small. Just begin.',
                onTap: onPomodoro,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBubble extends StatefulWidget {
  const _ActionBubble({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ActionBubble> createState() => _ActionBubbleState();
}

class _ActionBubbleState extends State<_ActionBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(_pressed ? 0.3 : 0.18),
                blurRadius: _pressed ? 16 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
