import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/features/bubble_coins/bubble_coin_reward_service.dart';
import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'package:mind_buddy/features/insights/habit_streaks_summary.dart';
import 'package:mind_buddy/features/habits/habit_home_widget_service.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen>
    with WidgetsBindingObserver {
  static const String _widgetTipDismissedKey = 'habits_widget_tip_dismissed';
  static const String _widgetTipSeenKey = 'habits_widget_tip_seen_once';
  static const String _widgetTipLastShownAtKey =
      'habits_widget_tip_last_shown_at';
  static const String _widgetTipStateVersionKey = 'habits_widget_tip_state_v';
  static const int _widgetTipStateVersion = 1;
  static const Duration _widgetTipCooldown = Duration(days: 7);

  final BubbleCoinRewardService _bubbleCoinRewardService =
      BubbleCoinRewardService();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _hideStreaks = false;
  bool _needsHideStreaksRefresh = false;
  bool _showWidgetTip = false;
  int _bubbleCoinBalance = 0;
  Timer? _widgetTipAutoHideTimer;
  final GlobalKey _monthChevronLeftKey = GlobalKey();
  final GlobalKey _monthChevronRightKey = GlobalKey();
  final GlobalKey _habitDotsGridKey = GlobalKey();
  final GlobalKey _manageButtonKey = GlobalKey();
  final GlobalKey _resetButtonKey = GlobalKey();

  // Used to force HabitStreaksSummary to rebuild after a toggle
  int refreshTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHideStreaks();
    _loadBubbleCoinBalance();
    _prepareWidgetTip();
    Future<void>.microtask(() async {
      await HabitHomeWidgetService.flushPendingWidgetToggles();
      if (!mounted) return;
      _refreshSummary();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetTipAutoHideTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future<void>.microtask(() async {
        await HabitHomeWidgetService.flushPendingWidgetToggles();
        if (!mounted) return;
        _refreshSummary();
      });
    }
  }

  Future<void> _loadHideStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hideStreaks = prefs.getBool('habits_hide_streaks') ?? false;
    });
    await HabitHomeWidgetService.syncTodaySnapshot();
  }

  void _prevMonth() {
    setState(() {
      month = DateTime(month.year, month.month - 1, 1);
      refreshTick++;
    });
  }

  void _nextMonth() {
    setState(() {
      month = DateTime(month.year, month.month + 1, 1);
      refreshTick++;
    });
  }

  void _refreshSummary() {
    _loadHideStreaks();
    _loadBubbleCoinBalance();
    setState(() => refreshTick++);
    HabitHomeWidgetService.syncTodaySnapshot();
  }

  Future<void> _loadBubbleCoinBalance() async {
    final wallet = await _bubbleCoinRewardService.loadWallet();
    if (!mounted) return;
    setState(() {
      _bubbleCoinBalance = wallet.balance;
    });
  }

  Future<void> _showWidgetHowTo() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Home Screen Widget',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text(
                'iPhone (WidgetKit)\n'
                '1. Long-press your Home Screen.\n'
                '2. Tap + (top-left).\n'
                '3. Search for MyBrainBubble.\n'
                '4. Choose the Habits widget and tap Add Widget.',
              ),
              SizedBox(height: 12),
              Text(
                'Android (App Widget)\n'
                '1. Long-press your Home Screen.\n'
                '2. Tap Widgets.\n'
                '3. Find MyBrainBubble.\n'
                '4. Drag the Habits widget onto the Home Screen.',
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _prepareWidgetTip() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_widgetTipStateVersionKey) ?? 0;
    if (storedVersion < _widgetTipStateVersion) {
      await prefs.remove(_widgetTipDismissedKey);
      await prefs.remove(_widgetTipSeenKey);
      await prefs.remove(_widgetTipLastShownAtKey);
      await prefs.setInt(_widgetTipStateVersionKey, _widgetTipStateVersion);
    }

    final dismissed = prefs.getBool(_widgetTipDismissedKey) ?? false;
    if (!mounted || dismissed) return;

    final seen = prefs.getBool(_widgetTipSeenKey) ?? false;
    final lastShownMillis = prefs.getInt(_widgetTipLastShownAtKey);
    final lastShownAt = lastShownMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
    final shouldShowAgain =
        lastShownAt == null ||
        DateTime.now().difference(lastShownAt) >= _widgetTipCooldown;
    if (seen && !shouldShowAgain) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        setState(() => _showWidgetTip = true);
        _widgetTipAutoHideTimer?.cancel();
        _widgetTipAutoHideTimer = Timer(
          const Duration(seconds: 4),
          () => _hideWidgetTip(markSeen: true),
        );
      });
    });
  }

  Future<void> _hideWidgetTip({
    bool markDismissed = false,
    bool markSeen = false,
  }) async {
    _widgetTipAutoHideTimer?.cancel();
    if (mounted) {
      setState(() => _showWidgetTip = false);
    }
    if (markDismissed || markSeen) {
      final prefs = await SharedPreferences.getInstance();
      if (markDismissed) {
        await prefs.setBool(_widgetTipDismissedKey, true);
      }
      if (markSeen) {
        await prefs.setBool(_widgetTipSeenKey, true);
        await prefs.setInt(
          _widgetTipLastShownAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> _onWidgetTipTap() async {
    await _hideWidgetTip(markSeen: true);
    if (!mounted) return;
    await _showWidgetHowTo();
  }

  Future<void> _showGuideIfNeeded({bool force = false}) async {
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'habits',
      force: force,
      steps: [
        GuideStep(
          key: _monthChevronLeftKey,
          title: 'Drifting through time?',
          body: 'Use the arrows to float between months.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _habitDotsGridKey,
          title: 'See the tiny wins',
          body: 'Tap the dots to reveal what you completed.',
          align: GuideAlign.top,
        ),
        GuideStep(
          key: _manageButtonKey,
          title: 'Organise your rhythm',
          body: 'Tap Manage to add habits and sort categories.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _resetButtonKey,
          title: 'Need a fresh glance?',
          body: 'Tap Reset to refresh your view.',
          align: GuideAlign.bottom,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGuideIfNeeded());
    if (_needsHideStreaksRefresh &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _needsHideStreaksRefresh = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadHideStreaks();
        _refreshSummary();
      });
    }
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Habits'),
        leading: MbGlowBackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.help_outline,
            tooltip: 'Guide',
            onPressed: () => _showGuideIfNeeded(force: true),
          ),
          MbGlowIconButton(
            key: _manageButtonKey,
            tooltip: 'Manage',
            icon: Icons.tune,
            onPressed: () async {
              _needsHideStreaksRefresh = true;
              await context.push('/habits/manage');
              _loadHideStreaks();
              _refreshSummary();
            },
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_habits',
        text: 'Tap a habit to mark it done.',
        iconText: '✨',
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Habit tracker',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _BubbleCoinWalletChip(balance: _bubbleCoinBalance),
                const SizedBox(height: 12),
                if (!_hideStreaks)
                  _GlowPanel(
                    child: HabitStreaksSummary(
                      month: month,
                      refreshTick: refreshTick,
                      onManageTap: () async {
                        await context.push('/habits/manage');
                        _loadHideStreaks();
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                _GlowPanel(
                  child: HabitMonthGrid(
                    month: month,
                    refreshTick: refreshTick,
                    prevMonthKey: _monthChevronLeftKey,
                    nextMonthKey: _monthChevronRightKey,
                    gridKey: _habitDotsGridKey,
                    onPrevMonth: _prevMonth,
                    onNextMonth: _nextMonth,
                    onManageTap: () async {
                      await context.push('/habits/manage');
                      _loadHideStreaks();
                    },
                    onChanged: _refreshSummary,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: IgnorePointer(
                ignoring: !_showWidgetTip,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  offset: _showWidgetTip ? Offset.zero : const Offset(0, -0.08),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: _showWidgetTip ? 1 : 0,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _onWidgetTipTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFEAFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '✨ Also available as a little home screen widget.',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _hideWidgetTip(
                                  markDismissed: true,
                                  markSeen: true,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _GlowPanel extends StatelessWidget {
  const _GlowPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BubbleCoinWalletChip extends StatelessWidget {
  const _BubbleCoinWalletChip({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.toll_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            'Bubble Coins',
            style: textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$balance',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
