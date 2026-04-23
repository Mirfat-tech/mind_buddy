import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mind_buddy/features/gratitude/gratitude_carousel_models.dart';
import 'package:mind_buddy/features/gratitude/gratitude_carousel_storage.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/features/settings/theme_picker_panel.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class HomeSpherePreviewScreen extends ConsumerStatefulWidget {
  const HomeSpherePreviewScreen({super.key});

  @override
  ConsumerState<HomeSpherePreviewScreen> createState() =>
      _HomeSpherePreviewScreenState();
}

class _HomeSpherePreviewScreenState
    extends ConsumerState<HomeSpherePreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _openThemePicker(
    BuildContext context,
    String? selectedId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Material(
                color: Theme.of(sheetContext).scaffoldBackgroundColor,
                child: ThemePickerPanel(
                  selectedId: selectedId,
                  onThemeSelected: (_) => Navigator.of(sheetContext).pop(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openHomeRoute(BuildContext context, String route) {
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).settings;
    final style = styleById(settings.themeId);

    return Scaffold(
      backgroundColor: style.paper,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 430 ? 28.0 : 20.0;
            final screenHeight = constraints.maxHeight;
            final topGap = screenHeight < 720 ? 14.0 : 20.0;
            final sphereZoneTopGap = screenHeight < 720 ? 12.0 : 18.0;
            final bottomGap = screenHeight < 720 ? 8.0 : 12.0;
            final recommendedHeight = screenHeight < 720 ? 188.0 : 208.0;
            final bottomSafePad = math.max(
              16.0,
              MediaQuery.of(context).padding.bottom,
            );
            return AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glowValue =
                    (math.sin(_glowController.value * math.pi * 2) + 1) / 2;
                final swayValue = math.sin(_glowController.value * math.pi * 2);
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    bottomSafePad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewTopBar(
                        style: style,
                        onBack: () => context.go('/settings'),
                        onThemePressed: () =>
                            _openThemePicker(context, settings.themeId),
                      ),
                      SizedBox(height: topGap),
                      _PreviewDivider(style: style),
                      SizedBox(height: sphereZoneTopGap),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, heroConstraints) {
                            final halftoneWidth = math.min(
                              constraints.maxWidth * 0.9,
                              440.0,
                            );
                            final halftoneHeight = math.min(
                              heroConstraints.maxHeight * 0.9,
                              440.0,
                            );
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                IgnorePointer(
                                  child: SizedBox(
                                    width: halftoneWidth,
                                    height: halftoneHeight,
                                    child: CustomPaint(
                                      painter: _SphereBackdropHalftonePainter(
                                        style: style,
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    const Spacer(flex: 4),
                                    Center(
                                      child: _AnimatedWelcomeSphere(
                                        style: style,
                                        glowValue: glowValue,
                                        swayValue: swayValue,
                                        maxWidth: constraints.maxWidth,
                                        maxHeight:
                                            heroConstraints.maxHeight * 0.92,
                                      ),
                                    ),
                                    const Spacer(flex: 5),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      _RecommendedPreviewSection(
                        style: style,
                        height: recommendedHeight,
                        onOpenRoute: (route) => _openHomeRoute(context, route),
                        onSeeMore: () => context.push('/overall-features'),
                      ),
                      SizedBox(height: bottomGap),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PreviewTopBar extends StatelessWidget {
  const _PreviewTopBar({
    required this.style,
    required this.onBack,
    required this.onThemePressed,
  });

  final PaperStyle style;
  final VoidCallback onBack;
  final VoidCallback onThemePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TopIconButton(
          icon: Icons.menu_rounded,
          style: style,
          onPressed: onBack,
        ),
        const Spacer(),
        _ThemeGlowButton(style: style, onPressed: onThemePressed),
      ],
    );
  }
}

class _PreviewDivider extends StatelessWidget {
  const _PreviewDivider({required this.style});

  final PaperStyle style;

  @override
  Widget build(BuildContext context) {
    final lineColor = Color.lerp(
      style.accent,
      style.border,
      0.4,
    )!.withValues(alpha: 0.9);

    return Container(
      height: 1,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            style.accent.withValues(alpha: 0.5),
            lineColor,
            style.accent.withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }
}

class _AnimatedWelcomeSphere extends StatefulWidget {
  const _AnimatedWelcomeSphere({
    required this.style,
    required this.glowValue,
    required this.swayValue,
    required this.maxWidth,
    required this.maxHeight,
  });

  final PaperStyle style;
  final double glowValue;
  final double swayValue;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_AnimatedWelcomeSphere> createState() => _AnimatedWelcomeSphereState();
}

class _AnimatedWelcomeSphereState extends State<_AnimatedWelcomeSphere>
    with TickerProviderStateMixin {
  static const double _swipeThreshold = 0.2;
  static const double _swipeStartThreshold = 18.0;

  late final AnimationController _swipeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final AnimationController _popController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  Animation<double>? _swipeAnimation;
  int _currentIndex = 0;
  int _swipeDirection = 0;
  int _targetIndex = 0;
  double _dragExtent = 0;
  double _transitionProgress = 0;
  bool _isSwipeAnimating = false;
  bool _isNavigating = false;
  bool _isPointerTracking = false;
  bool _isSwipeTrackingActive = false;
  bool _isCtaPressActive = false;
  double _lastPointerX = 0;
  double _pointerDownX = 0;
  final ImagePicker _imagePicker = ImagePicker();
  _GratitudeMemoryPreview? _gratitudeMemory;
  bool _gratitudeLoaded = false;

  @override
  void dispose() {
    _swipeController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadGratitudeMemory();
  }

  List<_SpherePreviewState> get _states => <_SpherePreviewState>[
    const _SpherePreviewState(
      title: 'Welcome ✨',
      subtitle: 'Where do you want to start today?',
    ),
    _SpherePreviewState.memoryPrompt(
      memory: _gratitudeMemory,
      isLoaded: _gratitudeLoaded,
    ),
    const _SpherePreviewState(
      title: 'Fancy a little focus session?',
      route: '/pomodoro',
      icon: Icons.timer_outlined,
      titleTapEnabled: true,
      titleItalic: false,
    ),
    _SpherePreviewState.gratitudeMemory(
      route: '/gratitude-bubble',
      memory: _gratitudeMemory,
      isLoaded: _gratitudeLoaded,
    ),
  ];

  Future<void> _loadGratitudeMemory() async {
    final entries = await GratitudeCarouselStorage.fetchEntries();
    _GratitudeMemoryPreview? match;
    for (final entry in entries) {
      final item = entry.items.cast<GratitudeCarouselItem?>().firstWhere(
        (candidate) =>
            candidate != null &&
            candidate.type == GratitudeCarouselItemType.photo &&
            (candidate.filePath ?? '').trim().isNotEmpty &&
            File(candidate.filePath!).existsSync(),
        orElse: () => null,
      );
      if (item == null) continue;
      match = _GratitudeMemoryPreview(
        filePath: item.filePath!,
        date: entry.date,
        caption: item.caption.trim(),
      );
      break;
    }
    if (!mounted) return;
    setState(() {
      _gratitudeMemory = match;
      _gratitudeLoaded = true;
    });
  }

  int _wrapIndex(int index) => (index + _states.length) % _states.length;

  void _handlePointerDown(PointerDownEvent event) {
    if (_isNavigating || _isSwipeAnimating) return;
    _isPointerTracking = true;
    _isSwipeTrackingActive = false;
    _pointerDownX = event.position.dx;
    _lastPointerX = event.position.dx;
    _dragExtent = 0;
    debugPrint(
      '[HomeSphere] listener down slide=$_currentIndex x=${event.position.dx.toStringAsFixed(1)} ctaPress=$_isCtaPressActive',
    );
  }

  void _handlePointerMove(PointerMoveEvent event, double sphereSize) {
    if (!_isPointerTracking || _isNavigating || _isSwipeAnimating) return;
    final deltaFromDown = event.position.dx - _pointerDownX;
    final deltaFromLast = event.position.dx - _lastPointerX;
    _lastPointerX = event.position.dx;
    if (_isCtaPressActive) {
      debugPrint(
        '[HomeSphere] listener move ignored slide=$_currentIndex deltaFromDown=${deltaFromDown.toStringAsFixed(2)} because ctaPress=true',
      );
      return;
    }
    if (!_isSwipeTrackingActive) {
      if (deltaFromDown.abs() < _swipeStartThreshold) {
        return;
      }
      _isSwipeTrackingActive = true;
      debugPrint(
        '[HomeSphere] swipe tracking started slide=$_currentIndex deltaFromDown=${deltaFromDown.toStringAsFixed(2)}',
      );
    }
    _dragExtent += deltaFromLast;
    final normalized = (_dragExtent / (sphereSize * 0.42))
        .clamp(-1.0, 1.0)
        .toDouble();
    if (normalized == 0) {
      if (_transitionProgress != 0) {
        setState(() {
          _transitionProgress = 0;
          _swipeDirection = 0;
          _targetIndex = _currentIndex;
        });
      }
      return;
    }

    setState(() {
      _swipeDirection = normalized < 0 ? 1 : -1;
      _targetIndex = _wrapIndex(_currentIndex + _swipeDirection);
      _transitionProgress = normalized.abs();
    });
    debugPrint(
      '[HomeSphere] listener move slide=$_currentIndex deltaFromDown=${deltaFromDown.toStringAsFixed(2)} dragExtent=${_dragExtent.toStringAsFixed(2)} progress=${_transitionProgress.toStringAsFixed(3)}',
    );
  }

  void _handlePointerEnd() {
    if (!_isPointerTracking || _isNavigating || _isSwipeAnimating) return;
    _isPointerTracking = false;
    debugPrint(
      '[HomeSphere] listener end slide=$_currentIndex swipeActive=$_isSwipeTrackingActive ctaPress=$_isCtaPressActive progress=${_transitionProgress.toStringAsFixed(3)}',
    );
    if (_isCtaPressActive) {
      _isSwipeTrackingActive = false;
      _dragExtent = 0;
      return;
    }
    if (!_isSwipeTrackingActive) {
      _dragExtent = 0;
      return;
    }
    _isSwipeTrackingActive = false;
    final shouldCommit = _transitionProgress >= _swipeThreshold;
    if (shouldCommit && _swipeDirection != 0) {
      _animateSwipeTo(
        direction: _swipeDirection,
        targetProgress: 1,
        onCompleted: () {
          setState(() {
            _currentIndex = _targetIndex;
            _transitionProgress = 0;
            _swipeDirection = 0;
            _dragExtent = 0;
            _isSwipeAnimating = false;
          });
        },
      );
      return;
    }

    _animateSwipeTo(
      direction: _swipeDirection,
      targetProgress: 0,
      onCompleted: () {
        setState(() {
          _transitionProgress = 0;
          _swipeDirection = 0;
          _targetIndex = _currentIndex;
          _dragExtent = 0;
          _isSwipeAnimating = false;
        });
      },
    );
  }

  void _setCtaPressState(
    bool value, {
    required String source,
    required _SpherePreviewState state,
    required int slideIndex,
  }) {
    _isCtaPressActive = value;
    debugPrint(
      '[HomeSphere] ctaPress=$value source=$source activeSlide=$_currentIndex targetSlide=$slideIndex title="${state.title}" route=${state.route} action=${state.action.name} swipeActive=$_isSwipeTrackingActive progress=${_transitionProgress.toStringAsFixed(3)}',
    );
    if (value) {
      _isSwipeTrackingActive = false;
      _dragExtent = 0;
      if (_transitionProgress != 0 && mounted) {
        setState(() {
          _transitionProgress = 0;
          _swipeDirection = 0;
          _targetIndex = _currentIndex;
        });
      }
    }
  }

  Future<void> _pickMemoryPhoto() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final now = DateTime.now();
    final entry = GratitudeCarouselEntry(
      id: 'memory_${now.microsecondsSinceEpoch}',
      date: DateTime(now.year, now.month, now.day),
      title: 'A little memory to keep close',
      createdAt: now,
      updatedAt: now,
      items: <GratitudeCarouselItem>[
        GratitudeCarouselItem(
          id: 'memory_item_${now.microsecondsSinceEpoch}',
          type: GratitudeCarouselItemType.photo,
          filePath: picked.path,
        ),
      ],
    );
    await GratitudeCarouselStorage.saveEntry(entry);
    await _loadGratitudeMemory();
  }

  void _animateSwipeTo({
    required int direction,
    required double targetProgress,
    required VoidCallback onCompleted,
  }) {
    if (direction == 0 && targetProgress == 1) return;
    _swipeController.stop();
    _swipeAnimation =
        Tween<double>(begin: _transitionProgress, end: targetProgress).animate(
          CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (!mounted) return;
          setState(() {
            _transitionProgress = _swipeAnimation!.value;
            if (direction != 0) {
              _swipeDirection = direction;
              _targetIndex = _wrapIndex(_currentIndex + direction);
            }
          });
        });
    _isSwipeAnimating = true;
    _swipeController
      ..duration = Duration(
        milliseconds: math.max(
          160,
          (320 * (_transitionProgress - targetProgress).abs()).round(),
        ),
      )
      ..forward(from: 0).whenComplete(() {
        if (!mounted) return;
        onCompleted();
      });
  }

  Future<void> _handleCtaTap(_SpherePreviewState state) async {
    if (_isNavigating || _isSwipeAnimating) return;
    debugPrint(
      '[HomeSphere] onTap start title="${state.title}" route=${state.route} action=${state.action.name}',
    );
    setState(() => _isNavigating = true);
    try {
      await _popController.forward(from: 0);
      if (!mounted) return;
      if (state.action == _SphereAction.pickMemoryPhoto) {
        debugPrint('[HomeSphere] opening gallery picker');
        await _pickMemoryPhoto();
        return;
      }
      final route = state.route;
      if (route == null) return;
      debugPrint('[HomeSphere] navigating to $route');
      GoRouter.of(context).go(route);
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final widthBasedSize = math.min(
      widget.maxWidth - 40,
      widget.maxWidth * 0.78,
    );
    final size = math.min(widthBasedSize, widget.maxHeight).clamp(250.0, 520.0);
    final accentGlow = widget.style.accent.withValues(
      alpha: 0.18 + (widget.glowValue * 0.11),
    );
    final paperGlow = Color.lerp(
      widget.style.paper,
      widget.style.accent,
      0.14,
    )!.withValues(alpha: 0.12 + (widget.glowValue * 0.07));
    final sphereFill = Color.lerp(
      widget.style.paper,
      widget.style.boxFill,
      0.14,
    )!;
    final innerHighlight = Color.lerp(
      widget.style.paper,
      widget.style.boxFill,
      0.72,
    )!;
    final baseShadow = widget.style.text.withValues(alpha: 0.07);
    final rimColor = Color.lerp(
      widget.style.border,
      Color.lerp(widget.style.paper, widget.style.boxFill, 0.55)!,
      0.72,
    )!.withValues(alpha: 0.9);
    final liftShadow = Color.lerp(
      widget.style.text,
      widget.style.border,
      0.45,
    )!.withValues(alpha: 0.1);
    final swayOffset = widget.swayValue * 2.8;
    final popPulse = Curves.easeOut.transform(
      math.min(_popController.value / 0.35, 1),
    );
    final settleValue = Curves.easeOut.transform(
      math.max((_popController.value - 0.32) / 0.68, 0),
    );
    final popScale = 1 + (0.035 * popPulse) - (0.014 * settleValue);
    final activeState = _states[_currentIndex];
    final incomingState = _states[_targetIndex];

    return SizedBox(
      width: double.infinity,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: (1.06 + (widget.glowValue * 0.055)) * popScale,
                child: Container(
                  width: size * (1.14 + (widget.glowValue * 0.075)),
                  height: size * (1.14 + (widget.glowValue * 0.075)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentGlow,
                        blurRadius: 140 + (widget.glowValue * 46),
                        spreadRadius: 22 + (widget.glowValue * 14),
                      ),
                      BoxShadow(
                        color: paperGlow,
                        blurRadius: 176 + (widget.glowValue * 40),
                        spreadRadius: 34 + (widget.glowValue * 16),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: size * 0.08,
                child: Container(
                  width: size * 0.62,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    boxShadow: [
                      BoxShadow(
                        color: baseShadow,
                        blurRadius: 48,
                        spreadRadius: 2,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(swayOffset, 0),
                child: Transform.scale(
                  scale: (1 + (widget.glowValue * 0.015)) * popScale,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: (event) => _handlePointerMove(event, size),
                    onPointerUp: (_) => _handlePointerEnd(),
                    onPointerCancel: (_) => _handlePointerEnd(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.16, -0.22),
                          radius: 1.0,
                          colors: [
                            innerHighlight.withValues(alpha: 0.96),
                            Color.lerp(
                              widget.style.paper,
                              widget.style.boxFill,
                              0.18,
                            )!,
                            sphereFill,
                            Color.lerp(
                              widget.style.paper,
                              widget.style.border,
                              0.08,
                            )!,
                          ],
                          stops: const [0.0, 0.42, 0.82, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: liftShadow,
                            blurRadius: 26,
                            spreadRadius: 1,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: widget.style.border.withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: 0.5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          children: [
                            Positioned(
                              left: size * 0.14,
                              top: size * 0.12,
                              child: IgnorePointer(
                                child: Container(
                                  width: size * 0.28,
                                  height: size * 0.19,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(size),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color.lerp(
                                          widget.style.boxFill,
                                          Colors.white,
                                          0.55,
                                        )!.withValues(alpha: 0.48),
                                        Colors.white.withValues(alpha: 0.04),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: ClipOval(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) {
                                        return const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.transparent,
                                            Colors.white,
                                            Colors.white,
                                            Colors.transparent,
                                          ],
                                          stops: [0.03, 0.24, 0.76, 0.97],
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          _SphereFaceContent(
                                            state: activeState,
                                            style: widget.style,
                                            size: size,
                                            phase: _transitionProgress,
                                            direction: _swipeDirection,
                                            isIncoming: false,
                                          ),
                                          if (_transitionProgress > 0 &&
                                              _swipeDirection != 0)
                                            _SphereFaceContent(
                                              state: incomingState,
                                              style: widget.style,
                                              size: size,
                                              phase: _transitionProgress,
                                              direction: _swipeDirection,
                                              isIncoming: true,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              center: const Alignment(
                                                -0.12,
                                                -0.18,
                                              ),
                                              radius: 0.9,
                                              colors: [
                                                Colors.transparent,
                                                Colors.transparent,
                                                widget.style.border.withValues(
                                                  alpha: 0.06,
                                                ),
                                              ],
                                              stops: const [0.0, 0.7, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _SpherePopPainter(
                                    progress: _popController.value,
                                    accent: widget.style.accent,
                                    border: widget.style.border,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: rimColor,
                                      width: 1.25,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      center: const Alignment(0.56, 0.76),
                                      radius: 0.94,
                                      colors: [
                                        Colors.transparent,
                                        widget.style.border.withValues(
                                          alpha: 0.05,
                                        ),
                                        widget.style.text.withValues(
                                          alpha: 0.12,
                                        ),
                                      ],
                                      stops: const [0.58, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      center: const Alignment(-0.34, -0.42),
                                      radius: 0.76,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.12),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_transitionProgress < 0.02)
                              Positioned.fill(
                                child: _SphereInteractionLayer(
                                  state: activeState,
                                  size: size,
                                  slideIndex: _currentIndex,
                                  onPressStateChanged: (value, source) =>
                                      _setCtaPressState(
                                        value,
                                        source: source,
                                        state: activeState,
                                        slideIndex: _currentIndex,
                                      ),
                                  onTap: () => _handleCtaTap(activeState),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpherePreviewState {
  const _SpherePreviewState({
    required this.title,
    this.subtitle,
    this.route,
    this.icon,
    this.titleTapEnabled = false,
    this.titleItalic = true,
  }) : gratitudeMemory = null,
       cta = null,
       action = _SphereAction.navigate,
       ctaTone = _SphereTextTone.subtitle,
       ctaItalic = true,
       showGratitudeLoading = false;

  const _SpherePreviewState.gratitudeMemory({
    required this.route,
    required _GratitudeMemoryPreview? memory,
    required bool isLoaded,
  }) : title = '',
       subtitle = null,
       cta = memory == null ? 'Open Gratitude Bubble' : 'Open Gratitude Bubble',
       icon = null,
       action = _SphereAction.navigate,
       titleTapEnabled = false,
       ctaTone = _SphereTextTone.welcomeAccent,
       titleItalic = true,
       ctaItalic = false,
       gratitudeMemory = memory,
       showGratitudeLoading = !isLoaded;

  const _SpherePreviewState.memoryPrompt({
    required _GratitudeMemoryPreview? memory,
    required bool isLoaded,
  }) : title = 'Add a little memory your mind wants to keep',
       subtitle = null,
       cta = 'Choose a photo to hold close',
       route = null,
       icon = Icons.photo_library_outlined,
       action = _SphereAction.pickMemoryPhoto,
       titleTapEnabled = false,
       ctaTone = _SphereTextTone.welcomeAccent,
       titleItalic = true,
       ctaItalic = false,
       gratitudeMemory = memory,
       showGratitudeLoading = !isLoaded;

  final String title;
  final String? subtitle;
  final String? cta;
  final String? route;
  final IconData? icon;
  final _SphereAction action;
  final bool titleTapEnabled;
  final _SphereTextTone ctaTone;
  final bool titleItalic;
  final bool ctaItalic;
  final _GratitudeMemoryPreview? gratitudeMemory;
  final bool showGratitudeLoading;

  bool get isWelcome => subtitle != null;
  bool get isGratitudeMemory => route == '/gratitude-bubble';
  bool get isMemoryPrompt => action == _SphereAction.pickMemoryPhoto;
}

enum _SphereTextTone { subtitle, welcomeAccent }

enum _SphereAction { navigate, pickMemoryPhoto }

class _SphereFaceContent extends StatelessWidget {
  const _SphereFaceContent({
    required this.state,
    required this.style,
    required this.size,
    required this.phase,
    required this.direction,
    required this.isIncoming,
  });

  final _SpherePreviewState state;
  final PaperStyle style;
  final double size;
  final double phase;
  final int direction;
  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    final progress = phase.clamp(0.0, 1.0);
    final signedDirection = direction == 0 ? 1.0 : direction.toDouble();
    final curved = Curves.easeInOutCubic.transform(progress);
    final edgeDepth = math.sin(curved * math.pi / 2);
    final startRotation = 1.02 * signedDirection;
    final rotation = isIncoming
        ? startRotation * (1 - curved)
        : -startRotation * curved;
    final xShift = isIncoming
        ? signedDirection * size * 0.26 * (1 - curved)
        : -signedDirection * size * 0.22 * curved;
    final scaleX = isIncoming ? 0.86 + (0.14 * curved) : 1 - (0.18 * edgeDepth);
    final scaleY = isIncoming ? 0.96 + (0.04 * curved) : 1 - (0.05 * edgeDepth);
    final opacity = isIncoming ? 0.22 + (0.78 * curved) : 1 - (0.62 * curved);
    final welcomeColor = Color.lerp(style.text, style.accent, 0.72)!;
    final subtitleColor = Color.lerp(
      style.mutedText,
      style.accent,
      0.16,
    )!.withValues(alpha: 0.9);
    final nonWelcomeTitleColor = subtitleColor;
    final ctaColor = switch (state.ctaTone) {
      _SphereTextTone.welcomeAccent => welcomeColor,
      _SphereTextTone.subtitle => subtitleColor,
    };
    final titleColor = state.isWelcome ? welcomeColor : nonWelcomeTitleColor;
    final supportingColor = state.isWelcome ? subtitleColor : ctaColor;
    final subtitleBaseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: subtitleColor,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.3,
      letterSpacing: 0.1,
    );
    final nonWelcomeTitleStyle = subtitleBaseStyle?.copyWith(
      color: titleColor,
      fontStyle: state.titleItalic ? FontStyle.italic : FontStyle.normal,
      fontSize: subtitleBaseStyle.fontSize != null
          ? subtitleBaseStyle.fontSize! * 1.02
          : null,
      height: 1.28,
    );
    final subtitleActionStyle = subtitleBaseStyle?.copyWith(
      color: supportingColor,
      fontStyle: state.ctaItalic ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.none,
    );
    if (state.isMemoryPrompt) {
      return _MemoryPromptSphereFaceContent(
        state: state,
        style: style,
        size: size,
        rotation: rotation,
        xShift: xShift,
        scaleX: scaleX,
        scaleY: scaleY,
        opacity: opacity,
      );
    }
    if (state.isGratitudeMemory) {
      return _GratitudeSphereFaceContent(
        state: state,
        style: style,
        size: size,
        progress: progress,
        signedDirection: signedDirection,
        curved: curved,
        edgeDepth: edgeDepth,
        rotation: rotation,
        xShift: xShift,
        scaleX: scaleX,
        scaleY: scaleY,
        opacity: opacity,
      );
    }
    final titleWidget = Text(
      state.title,
      textAlign: TextAlign.center,
      style: state.isWelcome
          ? Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: style.accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : nonWelcomeTitleStyle,
    );

    return IgnorePointer(
      ignoring: isIncoming || opacity < 0.85,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0013)
            ..translateByDouble(xShift, 0, 0, 1)
            ..rotateY(rotation)
            ..scaleByDouble(scaleX, scaleY, 1, 1),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.17),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.icon != null) ...[
                      Padding(
                        padding: EdgeInsets.all(size * 0.014),
                        child: Icon(
                          state.icon,
                          size: size * 0.095,
                          color: style.accent.withValues(alpha: 0.9),
                        ),
                      ),
                      SizedBox(height: size * 0.036),
                    ],
                    titleWidget,
                    if (state.isWelcome || state.cta != null)
                      SizedBox(height: size * 0.038),
                    if (state.isWelcome)
                      Text(
                        state.subtitle!,
                        textAlign: TextAlign.center,
                        style: subtitleBaseStyle,
                      )
                    else if (state.cta != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: size * 0.045,
                          vertical: size * 0.01,
                        ),
                        child: Text(
                          state.cta!,
                          textAlign: TextAlign.center,
                          style: subtitleActionStyle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GratitudeMemoryPreview {
  const _GratitudeMemoryPreview({
    required this.filePath,
    required this.date,
    required this.caption,
  });

  final String filePath;
  final DateTime date;
  final String caption;
}

class _MemoryPromptSphereFaceContent extends StatelessWidget {
  const _MemoryPromptSphereFaceContent({
    required this.state,
    required this.style,
    required this.size,
    required this.rotation,
    required this.xShift,
    required this.scaleX,
    required this.scaleY,
    required this.opacity,
  });

  final _SpherePreviewState state;
  final PaperStyle style;
  final double size;
  final double rotation;
  final double xShift;
  final double scaleX;
  final double scaleY;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final memory = state.gratitudeMemory;
    final subtitleColor = Color.lerp(
      style.mutedText,
      style.accent,
      0.16,
    )!.withValues(alpha: 0.9);
    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: subtitleColor,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.32,
    );
    final ctaStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Color.lerp(style.text, style.accent, 0.72),
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w500,
      height: 1.28,
    );
    final imageSize = size * 0.34;

    return IgnorePointer(
      ignoring: opacity < 0.85,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0013)
            ..translateByDouble(xShift, 0, 0, 1)
            ..rotateY(rotation)
            ..scaleByDouble(scaleX, scaleY, 1, 1),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.showGratitudeLoading)
                      SizedBox(
                        width: imageSize * 0.42,
                        height: imageSize * 0.42,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: style.accent.withValues(alpha: 0.7),
                        ),
                      )
                    else if (memory != null) ...[
                      _SphereWrappedPhoto(
                        filePath: memory.filePath,
                        size: imageSize,
                        style: style,
                        edgeDepth: 0.38,
                      ),
                    ] else ...[
                      Padding(
                        padding: EdgeInsets.all(size * 0.014),
                        child: Icon(
                          state.icon,
                          size: size * 0.11,
                          color: style.accent.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    SizedBox(height: size * 0.05),
                    Text(
                      memory != null
                          ? 'A little photo memory, held softly close.'
                          : state.title,
                      textAlign: TextAlign.center,
                      style: titleStyle,
                    ),
                    SizedBox(height: size * 0.032),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: size * 0.045,
                        vertical: size * 0.01,
                      ),
                      child: Text(
                        memory != null
                            ? 'Choose another little moment'
                            : state.cta!,
                        textAlign: TextAlign.center,
                        style: ctaStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GratitudeSphereFaceContent extends StatelessWidget {
  const _GratitudeSphereFaceContent({
    required this.state,
    required this.style,
    required this.size,
    required this.progress,
    required this.signedDirection,
    required this.curved,
    required this.edgeDepth,
    required this.rotation,
    required this.xShift,
    required this.scaleX,
    required this.scaleY,
    required this.opacity,
  });

  final _SpherePreviewState state;
  final PaperStyle style;
  final double size;
  final double progress;
  final double signedDirection;
  final double curved;
  final double edgeDepth;
  final double rotation;
  final double xShift;
  final double scaleX;
  final double scaleY;
  final double opacity;

  String _dateLabel(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final memory = state.gratitudeMemory;
    final subtitleColor = Color.lerp(
      style.mutedText,
      style.accent,
      0.16,
    )!.withValues(alpha: 0.9);
    final ctaStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Color.lerp(style.text, style.accent, 0.72),
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w500,
      height: 1.28,
    );
    final detailStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: subtitleColor,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.32,
    );
    final imageSize = size * 0.37;

    return IgnorePointer(
      ignoring: opacity < 0.85,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0013)
            ..translateByDouble(xShift, 0, 0, 1)
            ..rotateY(rotation)
            ..scaleByDouble(scaleX, scaleY, 1, 1),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.showGratitudeLoading)
                      SizedBox(
                        width: imageSize * 0.42,
                        height: imageSize * 0.42,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: style.accent.withValues(alpha: 0.7),
                        ),
                      )
                    else if (memory != null)
                      _SphereWrappedPhoto(
                        filePath: memory.filePath,
                        size: imageSize,
                        style: style,
                        edgeDepth: edgeDepth,
                      )
                    else
                      _GratitudeEmptyOrb(style: style, size: imageSize),
                    SizedBox(height: size * 0.05),
                    Text(
                      memory != null
                          ? 'Gratitude Bubble held this little memory on ${_dateLabel(memory.date)}'
                          : 'Your little gratitude moments can glow here. Add one in Gratitude Bubble and it will softly appear.',
                      textAlign: TextAlign.center,
                      style: detailStyle,
                    ),
                    SizedBox(height: size * 0.032),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: size * 0.045,
                        vertical: size * 0.01,
                      ),
                      child: Text(
                        state.cta!,
                        textAlign: TextAlign.center,
                        style: ctaStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SphereInteractionLayer extends StatelessWidget {
  const _SphereInteractionLayer({
    required this.state,
    required this.size,
    required this.slideIndex,
    required this.onPressStateChanged,
    required this.onTap,
  });

  final _SpherePreviewState state;
  final double size;
  final int slideIndex;
  final void Function(bool value, String source) onPressStateChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (state.isWelcome) {
      return const SizedBox.shrink();
    }

    final left = size * 0.16;
    final right = size * 0.16;
    final top = state.isMemoryPrompt ? size * 0.18 : size * 0.22;
    final bottom = state.isMemoryPrompt ? size * 0.14 : size * 0.2;

    return Padding(
      padding: EdgeInsets.fromLTRB(left, top, right, bottom),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) {
            onPressStateChanged(true, 'tapDown');
            debugPrint(
              '[HomeSphere] pointer down slide=$slideIndex title="${state.title}" route=${state.route} action=${state.action.name}',
            );
          },
          onTapUp: (_) {
            onPressStateChanged(false, 'tapUp');
            debugPrint(
              '[HomeSphere] pointer up slide=$slideIndex title="${state.title}" route=${state.route} action=${state.action.name}',
            );
          },
          onTapCancel: () {
            onPressStateChanged(false, 'tapCancel');
            debugPrint(
              '[HomeSphere] tap cancel slide=$slideIndex title="${state.title}" route=${state.route} action=${state.action.name}',
            );
          },
          onTap: () {
            debugPrint(
              '[HomeSphere] onTap fired slide=$slideIndex title="${state.title}" route=${state.route} action=${state.action.name}',
            );
            onTap();
          },
          borderRadius: BorderRadius.circular(size * 0.18),
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SphereWrappedPhoto extends StatelessWidget {
  const _SphereWrappedPhoto({
    required this.filePath,
    required this.size,
    required this.style,
    required this.edgeDepth,
  });

  final String filePath;
  final double size;
  final PaperStyle style;
  final double edgeDepth;

  @override
  Widget build(BuildContext context) {
    final edgeCompression = 1 - (edgeDepth * 0.06);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..scaleByDouble(edgeCompression, 1.0, 1.0, 1.0),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: style.accent.withValues(alpha: 0.12),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(filePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _GratitudeEmptyOrb(style: style, size: size);
                },
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.18, -0.24),
                    radius: 1.0,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.transparent,
                      style.border.withValues(alpha: 0.08),
                    ],
                    stops: const [0.0, 0.66, 1.0],
                  ),
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.white,
                      Colors.white,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    stops: const [0.0, 0.18, 0.82, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Container(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GratitudeEmptyOrb extends StatelessWidget {
  const _GratitudeEmptyOrb({required this.style, required this.size});

  final PaperStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = Color.lerp(style.boxFill, style.paper, 0.18)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.16, -0.2),
          radius: 1,
          colors: [
            Color.lerp(fill, Colors.white, 0.36)!.withValues(alpha: 0.92),
            fill,
            Color.lerp(style.paper, style.border, 0.08)!,
          ],
          stops: const [0.0, 0.72, 1.0],
        ),
        border: Border.all(color: style.border.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_outlined,
          size: size * 0.24,
          color: style.accent.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _SpherePopPainter extends CustomPainter {
  const _SpherePopPainter({
    required this.progress,
    required this.accent,
    required this.border,
  });

  final double progress;
  final Color accent;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width * (0.14 + (0.3 * progress));
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(3.8, 0.6, progress)!
      ..color = Color.lerp(
        accent,
        border,
        0.35,
      )!.withValues(alpha: (1 - progress) * 0.32);
    canvas.drawCircle(center, ringRadius, ringPaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: (1 - progress) * 0.14),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius * 1.2));
    canvas.drawCircle(center, ringRadius * 1.08, glowPaint);

    final dropletPaint = Paint()..style = PaintingStyle.fill;
    final droplets = <Offset>[
      Offset(size.width * 0.22, -size.height * 0.03),
      Offset(size.width * 0.18, size.height * 0.16),
      Offset(-size.width * 0.2, size.height * 0.12),
      Offset(-size.width * 0.14, -size.height * 0.18),
    ];

    for (var i = 0; i < droplets.length; i++) {
      final offset = droplets[i] * Curves.easeOut.transform(progress);
      final radius = lerpDouble(
        size.width * 0.016,
        size.width * 0.004,
        progress,
      )!;
      dropletPaint.color = Color.lerp(
        accent,
        border,
        i.isEven ? 0.3 : 0.55,
      )!.withValues(alpha: (1 - progress) * 0.42);
      canvas.drawCircle(center + offset, radius, dropletPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpherePopPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.border != border;
  }
}

class _SphereBackdropHalftonePainter extends CustomPainter {
  const _SphereBackdropHalftonePainter({required this.style});

  final PaperStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;

    final anchor = Offset(size.width * 0.5, size.height * 0.5);
    final maxDistance = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final dotColor = Color.lerp(style.border, style.accent, 0.58)!;
    final paint = Paint()..style = PaintingStyle.fill;
    final shortestSide = math.max(size.shortestSide, 1);
    final auraRadius = shortestSide * 0.34;
    const spacing = 15.0;

    for (double y = 0; y <= size.height + spacing; y += spacing) {
      for (double x = 0; x <= size.width + spacing; x += spacing) {
        final point = Offset(x, y);
        final dx = point.dx - anchor.dx;
        final dy = point.dy - anchor.dy;
        final distance = math.sqrt((dx * dx) + (dy * dy));
        final normalizedRadius = distance / auraRadius;
        final normalizedDistance = distance / math.max(maxDistance, 1);
        final nearSphere = (1 - ((normalizedRadius - 0.9).abs() / 0.72)).clamp(
          0.0,
          1.0,
        );
        final outerFade = (1 - ((normalizedRadius - 1.25) / 0.7)).clamp(
          0.0,
          1.0,
        );
        final haloFalloff = math.max(nearSphere, outerFade * 0.7);
        if (haloFalloff <= 0.01) continue;

        final eased = Curves.easeOutCubic.transform(haloFalloff);
        final opacity = (0.045 + (eased * 0.11) - (normalizedDistance * 0.018))
            .clamp(0.02, 0.14);
        final radius = (0.65 + (eased * 2.6) - (normalizedDistance * 0.22))
            .clamp(0.5, 3.1);
        if (opacity <= 0 || radius <= 0) continue;

        paint.color = dotColor.withValues(alpha: opacity);
        canvas.drawCircle(point, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SphereBackdropHalftonePainter oldDelegate) {
    return oldDelegate.style != style;
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.style,
    required this.onPressed,
  });

  final IconData icon;
  final PaperStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Menu',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      iconSize: 34,
      icon: Icon(icon, color: style.accent),
    );
  }
}

class _ThemeGlowButton extends StatelessWidget {
  const _ThemeGlowButton({required this.style, required this.onPressed});

  final PaperStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Theme',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      iconSize: 24,
      icon: Icon(Icons.palette_outlined, color: style.accent),
    );
  }
}

class _RecommendedPreviewSection extends StatelessWidget {
  const _RecommendedPreviewSection({
    required this.style,
    required this.height,
    required this.onOpenRoute,
    required this.onSeeMore,
  });

  final PaperStyle style;
  final double height;
  final ValueChanged<String> onOpenRoute;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Color.lerp(style.mutedText, style.text, 0.2),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final labelGap = height < 196 ? 10.0 : 12.0;
    final rowGap = height < 196 ? 10.0 : 12.0;
    final linkGap = height < 196 ? 8.0 : 10.0;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewDivider(style: style),
          SizedBox(height: labelGap),
          Text('Recommended', style: titleStyle),
          SizedBox(height: rowGap),
          Row(
            children: [
              Expanded(
                child: _RecommendationPill(
                  label: 'Brain fog',
                  icon: Icons.palette_outlined,
                  style: style,
                  onTap: () => onOpenRoute('/brain-fog'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _RecommendationPill(
                  label: 'Gratitude',
                  icon: Icons.auto_awesome_outlined,
                  style: style,
                  onTap: () => onOpenRoute('/gratitude-bubble'),
                ),
              ),
            ],
          ),
          SizedBox(height: rowGap),
          Center(
            child: _RecommendationPill(
              label: 'Journal',
              icon: Icons.menu_book_outlined,
              style: style,
              onTap: () => onOpenRoute('/journals'),
            ),
          ),
          SizedBox(height: linkGap),
          Center(
            child: InkWell(
              onTap: onSeeMore,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'See more →',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: style.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPill extends StatelessWidget {
  const _RecommendationPill({
    required this.label,
    required this.icon,
    required this.style,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final PaperStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = Color.lerp(style.boxFill, style.paper, 0.16)!;
    final rim = Color.lerp(
      style.border,
      Color.lerp(style.paper, style.boxFill, 0.62)!,
      0.78,
    )!.withValues(alpha: 0.88);
    final shadow = Color.lerp(
      style.text,
      style.border,
      0.5,
    )!.withValues(alpha: 0.07);
    final accentGlow = style.accent.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(fill, style.boxFill, 0.24)!, fill],
            ),
            border: Border.all(color: rim, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: accentGlow,
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: shadow,
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: style.border.withValues(alpha: 0.06),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkResponse(
                onTap: onTap,
                radius: 22,
                containedInkWell: false,
                splashColor: style.accent.withValues(alpha: 0.1),
                highlightColor: style.accent.withValues(alpha: 0.05),
                child: Icon(icon, color: style.accent, size: 24),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(18),
                    splashColor: style.accent.withValues(alpha: 0.1),
                    highlightColor: style.accent.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: style.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
