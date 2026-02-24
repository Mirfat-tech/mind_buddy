import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'package:mind_buddy/features/insights/habit_streaks_summary.dart';
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

class _HabitsScreenState extends State<HabitsScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _hideStreaks = false;
  bool _needsHideStreaksRefresh = false;
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
    _loadHideStreaks();
  }

  Future<void> _loadHideStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hideStreaks = prefs.getBool('habits_hide_streaks') ?? false;
    });
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
    setState(() => refreshTick++);
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
              context.go('/home');
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
          MbGlowIconButton(
            key: _resetButtonKey,
            tooltip: 'Refresh',
            icon: Icons.refresh,
            onPressed: _refreshSummary,
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_habits',
        text: 'Tap a habit to mark it done.',
        iconText: '✨',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Habit tracker',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
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
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
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
