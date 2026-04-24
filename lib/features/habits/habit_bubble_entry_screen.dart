import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/features/bubble_coins/widgets/bubble_coin_reward_burst.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_launch_config.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/habits/habit_models.dart';
import 'package:mind_buddy/features/habits/habit_today_repository.dart';

class HabitBubbleEntryScreen extends StatefulWidget {
  const HabitBubbleEntryScreen({super.key});

  @override
  State<HabitBubbleEntryScreen> createState() => _HabitBubbleEntryScreenState();
}

class _HabitBubbleEntryScreenState extends State<HabitBubbleEntryScreen> {
  final HabitTodayRepository _repository = HabitTodayRepository();
  final PageController _pageController = PageController(viewportFraction: 0.94);
  final GlobalKey _resetButtonKey = GlobalKey();
  bool _loading = true;
  String? _error;
  List<TodayHabitItem> _habits = const <TodayHabitItem>[];
  final Map<String, int> _requestVersionByHabitId = <String, int>{};
  int _currentPage = 0;
  int _rewardBurstCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final habits = await _repository.fetchTodayHabits();
      if (!mounted) return;
      setState(() {
        _habits = habits;
        _loading = false;
      });
      final maxPage = math.max(0, _pages.length - 1);
      if (_currentPage > maxPage) {
        _currentPage = maxPage;
      }
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn’t load today’s habits right now.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleHabit(TodayHabitItem item) async {
    final nextCompleted = !item.isCompleted;
    final requestVersion = (_requestVersionByHabitId[item.id] ?? 0) + 1;
    setState(() {
      _requestVersionByHabitId[item.id] = requestVersion;
      _habits = _habits.map((habit) {
        return habit.id == item.id
            ? habit.copyWith(isCompleted: nextCompleted)
            : habit;
      }).toList();
    });

    if (nextCompleted) {
      unawaited(HapticFeedback.lightImpact());
      unawaited(SystemSound.play(SystemSoundType.click));
    } else {
      unawaited(HapticFeedback.selectionClick());
    }

    try {
      final rewardAwarded = await _repository.setHabitCompletion(
        habitId: item.id,
        habitName: item.name,
        isCompleted: nextCompleted,
      );
      if (!mounted) return;
      if (rewardAwarded) {
        if (bubbleCoinsEnabledForLaunch) {
          setState(() {
            _rewardBurstCount++;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      final latestVersion = _requestVersionByHabitId[item.id];
      TodayHabitItem? currentHabit;
      for (final habit in _habits) {
        if (habit.id == item.id) {
          currentHabit = habit;
          break;
        }
      }
      if (latestVersion == requestVersion &&
          currentHabit != null &&
          currentHabit.isCompleted == nextCompleted) {
        setState(() {
          _habits = _habits.map((habit) {
            return habit.id == item.id
                ? habit.copyWith(isCompleted: item.isCompleted)
                : habit;
          }).toList();
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update that bubble yet.')),
      );
    }
  }

  List<_CategoryPageData> get _pages {
    final grouped = <String, List<TodayHabitItem>>{};
    for (final habit in _habits) {
      final categoryName = _normalizedCategoryName(habit.categoryName);
      grouped
          .putIfAbsent(categoryName, () => <TodayHabitItem>[])
          .add(habit.copyWith(categoryName: categoryName));
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aStartedAt = _oldestStartedAt(a.value);
        final bStartedAt = _oldestStartedAt(b.value);
        final byStart = _compareNullableDate(aStartedAt, bStartedAt);
        if (byStart != 0) return byStart;
        final aSort = a.value
            .map((habit) => habit.categorySortOrder)
            .reduce(math.min);
        final bSort = b.value
            .map((habit) => habit.categorySortOrder)
            .reduce(math.min);
        final byOrder = aSort.compareTo(bSort);
        if (byOrder != 0) return byOrder;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    return [
      for (var i = 0; i < entries.length; i++)
        _CategoryPageData(
          name: entries[i].key,
          habits: entries[i].value,
          palette: _themePalette(context),
          shape: _shapeForCategory(entries[i].key, i),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = _pages;
    final currentPage = pages.isEmpty
        ? null
        : pages[_currentPage.clamp(0, pages.length - 1)];
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MbGlowBackButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today’s habit-bubbles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      currentPage == null
                          ? 'Pop the ones you’ve done'
                          : '${currentPage.name} bubble-wrap',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.82,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.push('/habits/tracker'),
                child: const Text('Open full tracker'),
              ),
            ],
          ),
        ),
        actions: [
          MbGlowIconButton(
            tooltip: 'Bubble Pool',
            icon: Icons.bubble_chart_outlined,
            onPressed: () =>
                openBubblePoolLaunchAware(context, featureKey: 'habit_bubble'),
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_habit_bubble_entry',
        text:
            'Pop the bubbles you finished today. When you’re ready, slide to the next category or open the full tracker.',
        iconText: '🫧',
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _loading
                    ? const _BubbleWrapLoadingState()
                    : _error != null
                    ? _BubbleWrapErrorState(error: _error!, onRetry: _load)
                    : _habits.isEmpty
                    ? const _BubbleWrapEmptyState()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroSummary(
                            currentIndex: _currentPage,
                            pageCount: pages.length,
                            page: currentPage!,
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: pages.length,
                              onPageChanged: (page) {
                                setState(() => _currentPage = page);
                              },
                              itemBuilder: (context, index) {
                                final page = pages[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _CategoryBubblePage(
                                    page: page,
                                    onHabitTap: _toggleHabit,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          SafeArea(
                            top: false,
                            child: Center(
                              child: TextButton(
                                key: _resetButtonKey,
                                onPressed: _load,
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  minimumSize: const Size(88, 44),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Reset'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
              ),
            ),
            if (bubbleCoinsEnabledForLaunch)
              BubbleCoinRewardBurst(
                playCount: _rewardBurstCount,
                padding: const EdgeInsets.only(top: 72),
              ),
          ],
        ),
      ),
    );
  }

  static bool _isUncategorizedCategory(String categoryName) {
    final normalized = categoryName.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'other' ||
        normalized == 'uncategorized' ||
        normalized == 'uncategorised' ||
        normalized == 'unsorted';
  }

  static String _normalizedCategoryName(String categoryName) {
    return _isUncategorizedCategory(categoryName)
        ? 'Uncategorised'
        : categoryName.trim();
  }

  static DateTime? _oldestStartedAt(List<TodayHabitItem> habits) {
    DateTime? oldest;
    for (final habit in habits) {
      final startedAt = habit.startedAt;
      if (startedAt == null) continue;
      if (oldest == null || startedAt.isBefore(oldest)) {
        oldest = startedAt;
      }
    }
    return oldest;
  }

  static int _compareNullableDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

class _CategoryPageData {
  const _CategoryPageData({
    required this.name,
    required this.habits,
    required this.palette,
    required this.shape,
  });

  final String name;
  final List<TodayHabitItem> habits;
  final _HabitSectionPalette palette;
  final _BubbleShape shape;

  int get completedCount => habits.where((habit) => habit.isCompleted).length;
}

enum _BubbleShape { circle, heart, star, diamond }

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({
    required this.currentIndex,
    required this.pageCount,
    required this.page,
  });

  final int currentIndex;
  final int pageCount;
  final _CategoryPageData page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = scheme.primary;
    final accentSoft = Color.lerp(accent, Colors.white, 0.72)!;
    final accentDeep = Color.lerp(accent, Colors.black, 0.2)!;
    final pageProgress = page.habits.isEmpty
        ? 0.0
        : page.completedCount / page.habits.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentSoft.withValues(alpha: 0.94),
            Color.lerp(accentSoft, Colors.white, 0.24)!,
            Color.lerp(accentSoft, accent, 0.12)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PillBadge(
                  text: 'Category ${currentIndex + 1} of $pageCount',
                  color: accent.withValues(alpha: 0.16),
                  textColor: accentDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PageDots(
                    count: pageCount,
                    activeIndex: currentIndex,
                    activeColor: accentDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              page.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: accentDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pageProgress,
                minHeight: 8,
                backgroundColor: accent.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pop what you’ve done, then glide to the next sheet when you’re ready.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: accentDeep.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBubblePage extends StatelessWidget {
  const _CategoryBubblePage({required this.page, required this.onHabitTap});

  final _CategoryPageData page;
  final ValueChanged<TodayHabitItem> onHabitTap;

  @override
  Widget build(BuildContext context) {
    return _BubbleWrapSheet(
      palette: page.palette,
      shape: page.shape,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 760
              ? 5
              : width >= 560
              ? 4
              : 3;
          const spacing = 14.0;
          final bubbleSize =
              ((width - 42 - (spacing * (columns - 1))) / columns).clamp(
                90.0,
                128.0,
              );
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: spacing,
              childAspectRatio: 0.94,
            ),
            itemCount: page.habits.length,
            itemBuilder: (context, index) {
              final habit = page.habits[index];
              final isStar = page.shape == _BubbleShape.star;
              final labelLength = habit.name.trim().length;
              final starBoost = isStar
                  ? (labelLength > 18
                        ? 16.0
                        : labelLength > 12
                        ? 10.0
                        : 6.0)
                  : 0.0;
              return _HabitBubbleNode(
                key: ValueKey(habit.id),
                habit: habit,
                palette: page.palette,
                shape: page.shape,
                size: bubbleSize + starBoost,
                onTap: () => onHabitTap(habit),
              );
            },
          );
        },
      ),
    );
  }
}

class _HabitBubbleNode extends StatefulWidget {
  const _HabitBubbleNode({
    super.key,
    required this.habit,
    required this.palette,
    required this.shape,
    required this.size,
    required this.onTap,
  });

  final TodayHabitItem habit;
  final _HabitSectionPalette palette;
  final _BubbleShape shape;
  final double size;
  final VoidCallback onTap;

  @override
  State<_HabitBubbleNode> createState() => _HabitBubbleNodeState();
}

class _HabitBubbleNodeState extends State<_HabitBubbleNode>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _sparkleController;
  late final Animation<double> _pressScale;
  late final Animation<double> _shineShift;
  late final Animation<double> _sparkleProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pressScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.91,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.91,
          end: 1.03,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.03,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 46,
      ),
    ]).animate(_controller);
    _shineShift = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _sparkleProgress = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _HabitBubbleNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.habit.isCompleted && widget.habit.isCompleted) {
      _controller.forward(from: 0);
      _sparkleController.forward(from: 0);
    }
    if (oldWidget.habit.isCompleted && !widget.habit.isCompleted) {
      _controller.value = 0;
      _sparkleController.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  String _shortLabel(String text) {
    const maxLength = 20;
    final trimmed = text.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 1).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.habit.isCompleted;
    final size = widget.size;
    final accentColor = Theme.of(context).colorScheme.primary;
    final horizontalPadding = switch (widget.shape) {
      _BubbleShape.star => size * 0.2,
      _BubbleShape.diamond => size * 0.2,
      _ => size * 0.18,
    };
    final topPadding = switch (widget.shape) {
      _BubbleShape.star => size * 0.27,
      _BubbleShape.diamond => size * 0.24,
      _ => size * 0.26,
    };
    final bottomPadding = switch (widget.shape) {
      _BubbleShape.star => size * 0.18,
      _BubbleShape.diamond => size * 0.15,
      _ => size * 0.14,
    };
    return Semantics(
      button: true,
      selected: isCompleted,
      label: widget.habit.name,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _sparkleController]),
        builder: (context, child) {
          final pressScale = isCompleted ? 1.0 : _pressScale.value;
          final sparkleVisible =
              _sparkleController.isAnimating || _sparkleController.value > 0.0;
          return Transform.scale(
            scale: pressScale,
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: size,
                    height: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _HabitBubblePainter(
                              shape: widget.shape,
                              isCompleted: isCompleted,
                              shineShift: _shineShift.value,
                              palette: widget.palette,
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              topPadding,
                              horizontalPadding,
                              bottomPadding,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isCompleted)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: size * 0.04,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: size * 0.16,
                                      color: widget.palette.headingColor
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                Text(
                                  _shortLabel(widget.habit.name),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: widget.palette.headingColor
                                            .withValues(
                                              alpha: isCompleted ? 0.72 : 0.84,
                                            ),
                                        fontWeight: FontWeight.w600,
                                        height: 1.08,
                                        fontSize: switch (widget.shape) {
                                          _BubbleShape.star => size * 0.086,
                                          _BubbleShape.diamond => size * 0.092,
                                          _ => size * 0.105,
                                        },
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (sparkleVisible)
                          Positioned(
                            left: -size * 0.32,
                            top: -size * 0.32,
                            right: -size * 0.32,
                            bottom: -size * 0.32,
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _BubbleSparklePainter(
                                  progress: _sparkleProgress.value,
                                  accent: accentColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BubbleWrapSheet extends StatelessWidget {
  const _BubbleWrapSheet({
    required this.palette,
    required this.shape,
    required this.child,
  });

  final _HabitSectionPalette palette;
  final _BubbleShape shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            Color.lerp(palette.panelColor, Colors.white, 0.08)!,
            Color.lerp(palette.panelColor, Colors.white, 0.02)!,
            Color.lerp(palette.panelColor, Colors.black, 0.02)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: palette.borderColor.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _BubbleSheetPainter(palette: palette, shape: shape),
            ),
            child,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleSparklePainter extends CustomPainter {
  const _BubbleSparklePainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final fade = Curves.easeOut.transform((1 - progress).clamp(0.0, 1.0));
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(progress);
    final travel = size.width * 0.38 * eased;
    final sparkleConfigs =
        <({double angle, double radius, double scale, Color color})>[
          (
            angle: -1.75,
            radius: travel * 1.14,
            scale: 1.28,
            color: Color.lerp(
              accent,
              Colors.white,
              0.52,
            )!.withValues(alpha: 0.98 * fade),
          ),
          (
            angle: -0.9,
            radius: travel * 1.3,
            scale: 1.08,
            color: accent.withValues(alpha: 0.9 * fade),
          ),
          (
            angle: -0.2,
            radius: travel * 1.42,
            scale: 0.98,
            color: Color.lerp(
              accent,
              Colors.white,
              0.68,
            )!.withValues(alpha: 0.92 * fade),
          ),
          (
            angle: 0.75,
            radius: travel * 1.24,
            scale: 1.18,
            color: Color.lerp(
              accent,
              Colors.white,
              0.36,
            )!.withValues(alpha: 0.96 * fade),
          ),
          (
            angle: 1.55,
            radius: travel * 1.26,
            scale: 0.9,
            color: accent.withValues(alpha: 0.84 * fade),
          ),
          (
            angle: 2.4,
            radius: travel * 1.38,
            scale: 1.02,
            color: Color.lerp(
              accent,
              Colors.white,
              0.62,
            )!.withValues(alpha: 0.9 * fade),
          ),
          (
            angle: -2.52,
            radius: travel * 1.22,
            scale: 0.86,
            color: Color.lerp(
              accent,
              Colors.white,
              0.5,
            )!.withValues(alpha: 0.86 * fade),
          ),
          (
            angle: -1.34,
            radius: travel * 1.46,
            scale: 0.8,
            color: accent.withValues(alpha: 0.82 * fade),
          ),
          (
            angle: 0.14,
            radius: travel * 1.52,
            scale: 0.88,
            color: Color.lerp(
              accent,
              Colors.white,
              0.58,
            )!.withValues(alpha: 0.88 * fade),
          ),
          (
            angle: 2.88,
            radius: travel * 1.18,
            scale: 0.76,
            color: Color.lerp(
              accent,
              Colors.white,
              0.44,
            )!.withValues(alpha: 0.8 * fade),
          ),
        ];

    for (final sparkle in sparkleConfigs) {
      final offset = Offset(
        math.cos(sparkle.angle) * sparkle.radius,
        math.sin(sparkle.angle) * sparkle.radius,
      );
      _drawSparkle(
        canvas,
        center + offset,
        size.width * 0.07 * sparkle.scale * (0.86 - (progress * 0.14)),
        sparkle.color,
      );
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.28
      ..color = color.withValues(alpha: 0.46)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = (-math.pi / 2) + (i * math.pi / 4);
      final pointRadius = i.isEven ? radius : radius * 0.42;
      final point = Offset(
        center.dx + (math.cos(angle) * pointRadius),
        center.dy + (math.sin(angle) * pointRadius),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _BubbleSparklePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

class _HabitBubblePainter extends CustomPainter {
  const _HabitBubblePainter({
    required this.shape,
    required this.isCompleted,
    required this.shineShift,
    required this.palette,
  });

  final _BubbleShape shape;
  final bool isCompleted;
  final double shineShift;
  final _HabitSectionPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _bubbleShapePath(shape, rect);
    final accentBase = isCompleted
        ? palette.completedBubble
        : palette.bubbleColor;
    final stroke = isCompleted
        ? palette.completedOutline
        : palette.bubbleOutline;
    final shortestSide = size.shortestSide;

    canvas.drawShadow(
      path,
      (isCompleted ? palette.completedShadow : palette.bubbleShadow).withValues(
        alpha: isCompleted ? 0.14 : 0.26,
      ),
      isCompleted ? 4 : 12,
      false,
    );

    final fill = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.24 + (shineShift * 0.12), -0.3),
        radius: isCompleted ? 0.9 : 1.06,
        colors: isCompleted
            ? [
                Colors.white.withValues(alpha: 0.1),
                Color.lerp(accentBase, Colors.white, 0.04)!,
                Color.lerp(accentBase, Colors.black, 0.12)!,
              ]
            : [
                Colors.white.withValues(alpha: 0.92),
                Color.lerp(accentBase, Colors.white, 0.34)!,
                Color.lerp(accentBase, Colors.black, 0.04)!,
              ],
      ).createShader(rect);
    canvas.drawPath(path, fill);

    final domeInner = _bubbleShapePath(
      shape,
      rect.deflate(shortestSide * 0.08),
    );
    final domePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.1, -0.18),
        radius: 0.92,
        colors: isCompleted
            ? [
                Colors.white.withValues(alpha: 0.04),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.06),
              ]
            : [
                Colors.white.withValues(alpha: 0.24),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.02),
              ],
      ).createShader(rect);
    canvas.drawPath(domeInner, domePaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCompleted ? 1.0 : 1.4
      ..color = stroke.withValues(alpha: isCompleted ? 0.34 : 0.56);
    canvas.drawPath(path, strokePaint);

    final rimHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: isCompleted ? 0.08 : 0.34);
    canvas.drawPath(
      _bubbleShapePath(
        shape,
        rect.deflate(shortestSide * 0.03),
      ).shift(Offset(-shortestSide * 0.012, -shortestSide * 0.016)),
      rimHighlight,
    );

    final innerPath = _bubbleShapePath(
      shape,
      rect.deflate(shortestSide * 0.16),
    );
    final innerHighlight = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: isCompleted ? 0.03 : 0.1);
    canvas.drawPath(innerPath, innerHighlight);

    final glossPath = _bubbleShapePath(
      shape,
      rect
          .deflate(shortestSide * 0.26)
          .shift(Offset(-shortestSide * 0.06, -shortestSide * 0.07)),
    );
    final glossPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: isCompleted ? 0.05 : 0.34);
    canvas.drawPath(glossPath, glossPaint);

    if (isCompleted) {
      final insetShadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shortestSide * 0.045
        ..color = Colors.black.withValues(alpha: 0.05);
      canvas.drawPath(
        _bubbleShapePath(
          shape,
          rect.deflate(shortestSide * 0.18),
        ).shift(Offset(0, shortestSide * 0.03)),
        insetShadow,
      );
    } else {
      final bottomOcclusion = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black.withValues(alpha: 0.04);
      canvas.drawPath(
        _bubbleShapePath(
          shape,
          rect
              .deflate(shortestSide * 0.14)
              .shift(Offset(0, shortestSide * 0.05)),
        ),
        bottomOcclusion,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HabitBubblePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.shineShift != shineShift ||
        oldDelegate.palette != palette;
  }
}

Path _bubbleShapePath(_BubbleShape shape, Rect rect) {
  switch (shape) {
    case _BubbleShape.circle:
      return Path()..addOval(rect);
    case _BubbleShape.heart:
      final path = Path();
      final topDip = Offset(rect.center.dx, rect.top + (rect.height * 0.24));
      final bottomPoint = Offset(
        rect.center.dx,
        rect.bottom - (rect.height * 0.02),
      );
      path.moveTo(bottomPoint.dx, bottomPoint.dy);
      path.cubicTo(
        rect.left + (rect.width * 0.1),
        rect.bottom - (rect.height * 0.18),
        rect.left + (rect.width * 0.02),
        rect.top + (rect.height * 0.5),
        rect.left + (rect.width * 0.04),
        rect.top + (rect.height * 0.27),
      );
      path.cubicTo(
        rect.left + (rect.width * 0.06),
        rect.top + (rect.height * 0.06),
        rect.left + (rect.width * 0.28),
        rect.top + (rect.height * 0.02),
        topDip.dx,
        topDip.dy,
      );
      path.cubicTo(
        rect.right - (rect.width * 0.28),
        rect.top + (rect.height * 0.02),
        rect.right - (rect.width * 0.06),
        rect.top + (rect.height * 0.06),
        rect.right - (rect.width * 0.04),
        rect.top + (rect.height * 0.27),
      );
      path.cubicTo(
        rect.right - (rect.width * 0.02),
        rect.top + (rect.height * 0.5),
        rect.right - (rect.width * 0.1),
        rect.bottom - (rect.height * 0.18),
        bottomPoint.dx,
        bottomPoint.dy,
      );
      path.close();
      return path;
    case _BubbleShape.star:
      final center = rect.center;
      final outerRadius = rect.width * 0.49;
      final innerRadius = rect.width * 0.28;
      final points = <Offset>[];
      for (var i = 0; i < 10; i++) {
        final angle = (-math.pi / 2) + (i * math.pi / 5);
        final radius = i.isEven ? outerRadius : innerRadius;
        points.add(
          Offset(
            center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius,
          ),
        );
      }
      return _roundedPolygonPath(points, cornerRadius: rect.width * 0.032);
    case _BubbleShape.diamond:
      return _roundedPolygonPath(<Offset>[
        Offset(rect.center.dx, rect.top + rect.height * 0.01),
        Offset(rect.right - rect.width * 0.02, rect.center.dy),
        Offset(rect.center.dx, rect.bottom - rect.height * 0.01),
        Offset(rect.left + rect.width * 0.02, rect.center.dy),
      ], cornerRadius: rect.width * 0.028);
  }
}

Path _roundedPolygonPath(List<Offset> points, {required double cornerRadius}) {
  if (points.length < 3) return Path();
  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final previous = points[(i - 1 + points.length) % points.length];
    final current = points[i];
    final next = points[(i + 1) % points.length];

    final toPrevious = previous - current;
    final toNext = next - current;
    final prevDistance = toPrevious.distance;
    final nextDistance = toNext.distance;
    final safeRadius = math.min(
      cornerRadius,
      math.min(prevDistance, nextDistance) * 0.28,
    );

    final start = Offset(
      current.dx + (toPrevious.dx / prevDistance) * safeRadius,
      current.dy + (toPrevious.dy / prevDistance) * safeRadius,
    );
    final end = Offset(
      current.dx + (toNext.dx / nextDistance) * safeRadius,
      current.dy + (toNext.dy / nextDistance) * safeRadius,
    );

    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
  }
  path.close();
  return path;
}

_BubbleShape _shapeForCategory(String categoryName, int index) {
  if (_HabitBubbleEntryScreenState._isUncategorizedCategory(categoryName)) {
    return _BubbleShape.star;
  }
  const shapes = <_BubbleShape>[
    _BubbleShape.circle,
    _BubbleShape.heart,
    _BubbleShape.diamond,
  ];
  return shapes[index % shapes.length];
}

_HabitSectionPalette _themePalette(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final accent = scheme.primary;
  final surfaceTint = Color.lerp(accent, Colors.white, 0.8)!;
  return _HabitSectionPalette(
    panelColor: Color.lerp(surfaceTint, scheme.surface, 0.42)!,
    badgeColor: accent.withValues(alpha: 0.14),
    headingColor: Color.lerp(accent, Colors.black, 0.18)!,
    borderColor: accent.withValues(alpha: 0.32),
    shadowColor: accent.withValues(alpha: 0.2),
    bubbleColor: Color.lerp(accent, Colors.white, 0.62)!,
    bubbleOutline: accent.withValues(alpha: 0.42),
    bubbleShadow: accent.withValues(alpha: 0.24),
    completedBubble: Color.lerp(accent, Colors.white, 0.74)!,
    completedOutline: accent.withValues(alpha: 0.34),
    completedShadow: accent.withValues(alpha: 0.2),
  );
}

class _BubbleSheetPainter extends CustomPainter {
  const _BubbleSheetPainter({required this.palette, required this.shape});

  final _HabitSectionPalette palette;
  final _BubbleShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final sheetBase = Paint()
      ..shader = LinearGradient(
        colors: [
          Color.lerp(palette.panelColor, Colors.white, 0.08)!,
          Color.lerp(palette.panelColor, Colors.white, 0.03)!,
          Color.lerp(palette.panelColor, Colors.black, 0.02)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sheetBase);

    final bubbleFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.045);

    final rimLight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.26);
    final rimDark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..color = palette.borderColor.withValues(alpha: 0.14);
    final innerShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black.withValues(alpha: 0.03);
    final gloss = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = Colors.white.withValues(alpha: 0.22);

    final spacing = switch (shape) {
      _BubbleShape.circle => 58.0,
      _BubbleShape.heart => 62.0,
      _BubbleShape.star => 64.0,
      _BubbleShape.diamond => 60.0,
    };
    final radius = switch (shape) {
      _BubbleShape.circle => 23.0,
      _BubbleShape.heart => 25.0,
      _BubbleShape.star => 28.0,
      _BubbleShape.diamond => 25.0,
    };
    for (double y = radius + 10; y < size.height + spacing; y += spacing) {
      final isOffsetRow = ((y / spacing).floor()).isOdd;
      for (
        double x = isOffsetRow ? radius + 14 : radius - 2;
        x < size.width + spacing;
        x += spacing
      ) {
        final center = Offset(x, y);
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 2.02,
          height: radius * 2.02,
        );
        final path = _bubbleShapePath(shape, rect);
        final glossPath = _bubbleShapePath(
          shape,
          rect
              .deflate(radius * 0.26)
              .shift(Offset(-radius * 0.1, -radius * 0.12)),
        );
        final innerPath = _bubbleShapePath(shape, rect.deflate(radius * 0.14));
        final bubbleInnerFill = Paint()
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
            center: const Alignment(-0.18, -0.24),
            radius: 0.98,
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.03),
              palette.panelColor.withValues(alpha: 0.01),
            ],
          ).createShader(rect);
        canvas.drawShadow(
          path,
          Colors.black.withValues(alpha: 0.1),
          2.1,
          false,
        );
        canvas.drawPath(path, bubbleFill);
        canvas.drawPath(path, bubbleInnerFill);
        canvas.drawPath(
          innerPath,
          Paint()..color = Colors.white.withValues(alpha: 0.03),
        );
        canvas.drawPath(path, rimDark);
        canvas.drawPath(path.shift(Offset(0, radius * 0.03)), innerShadow);
        canvas.drawPath(path, rimLight);
        canvas.drawPath(glossPath, gloss);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleSheetPainter oldDelegate) {
    return oldDelegate.palette != palette || oldDelegate.shape != shape;
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.activeIndex,
    required this.activeColor,
  });

  final int count;
  final int activeIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == activeIndex ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i == activeIndex
                  ? activeColor
                  : activeColor.withValues(alpha: 0.2),
            ),
          ),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BubbleWrapLoadingState extends StatelessWidget {
  const _BubbleWrapLoadingState();

  @override
  Widget build(BuildContext context) {
    final palette = _themePalette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroSummary(
          currentIndex: 0,
          pageCount: 1,
          page: _CategoryPageData(
            name: 'Loading',
            habits: const <TodayHabitItem>[],
            palette: palette,
            shape: _BubbleShape.circle,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _BubbleWrapSheet(
            palette: palette,
            shape: _BubbleShape.circle,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _BubbleWrapErrorState extends StatelessWidget {
  const _BubbleWrapErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = _themePalette(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _BubbleWrapSheet(
          palette: palette,
          shape: _BubbleShape.circle,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your saved habits should appear here once the page reconnects.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleWrapEmptyState extends StatelessWidget {
  const _BubbleWrapEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = _themePalette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroSummary(
          currentIndex: 0,
          pageCount: 1,
          page: _CategoryPageData(
            name: 'A quiet bubble day',
            habits: const <TodayHabitItem>[],
            palette: palette,
            shape: _BubbleShape.circle,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _BubbleWrapSheet(
            palette: palette,
            shape: _BubbleShape.circle,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No habits yet ✨',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.headingColor,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  _EmptyStateAddHabitAction(
                    color: palette.headingColor,
                    onTap: () => context.push('/habits/manage'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyStateAddHabitAction extends StatefulWidget {
  const _EmptyStateAddHabitAction({required this.color, required this.onTap});

  final Color color;
  final Future<void> Function() onTap;

  @override
  State<_EmptyStateAddHabitAction> createState() =>
      _EmptyStateAddHabitActionState();
}

class _EmptyStateAddHabitActionState extends State<_EmptyStateAddHabitAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _navigating = false;

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_navigating) return;
    _navigating = true;
    unawaited(_burstController.forward(from: 0));
    await Future<void>.delayed(const Duration(milliseconds: 170));
    if (!mounted) return;
    await widget.onTap();
    _navigating = false;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: widget.color,
    );

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _burstController,
        builder: (context, child) {
          final progress = Curves.easeOut.transform(_burstController.value);
          final fade = (1 - Curves.easeIn.transform(_burstController.value))
              .clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              child!,
              if (_burstController.value > 0)
                IgnorePointer(
                  child: SizedBox(
                    width: 180,
                    height: 64,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        for (final star in _starBursts)
                          Transform.translate(
                            offset: Offset(
                              math.cos(star.angle) * star.distance * progress,
                              (math.sin(star.angle) *
                                      star.distance *
                                      progress) -
                                  (6 * progress),
                            ),
                            child: Opacity(
                              opacity: fade,
                              child: Transform.scale(
                                scale: 0.8 + (0.4 * (1 - progress)),
                                child: Text(
                                  star.glyph,
                                  style: TextStyle(
                                    fontSize: star.size,
                                    fontWeight: FontWeight.w700,
                                    color: widget.color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: widget.color.withValues(alpha: 0.18)),
          ),
          child: Text('Want to add one?', style: textStyle),
        ),
      ),
    );
  }
}

const List<({double angle, double distance, double size, String glyph})>
_starBursts = <({double angle, double distance, double size, String glyph})>[
  (angle: -2.2, distance: 18, size: 13, glyph: '✦'),
  (angle: -1.4, distance: 24, size: 11, glyph: '✦'),
  (angle: -0.45, distance: 20, size: 12, glyph: '✦'),
  (angle: 0.35, distance: 22, size: 11, glyph: '✦'),
  (angle: 1.1, distance: 18, size: 12, glyph: '✦'),
  (angle: 2.05, distance: 16, size: 10, glyph: '✦'),
];

class _HabitSectionPalette {
  const _HabitSectionPalette({
    required this.panelColor,
    required this.badgeColor,
    required this.headingColor,
    required this.borderColor,
    required this.shadowColor,
    required this.bubbleColor,
    required this.bubbleOutline,
    required this.bubbleShadow,
    required this.completedBubble,
    required this.completedOutline,
    required this.completedShadow,
  });

  final Color panelColor;
  final Color badgeColor;
  final Color headingColor;
  final Color borderColor;
  final Color shadowColor;
  final Color bubbleColor;
  final Color bubbleOutline;
  final Color bubbleShadow;
  final Color completedBubble;
  final Color completedOutline;
  final Color completedShadow;
}
