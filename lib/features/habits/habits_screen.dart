import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'package:mind_buddy/features/insights/habit_streaks_summary.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Used to force HabitStreaksSummary to rebuild after a toggle
  int refreshTick = 0;

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
    setState(() => refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Habits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSummary,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Habit tracker',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _GlowPanel(
            child: HabitStreaksSummary(
              key: ValueKey(
                'summary_${refreshTick}_${month.year}-${month.month}',
              ),
              month: month,
              onManageTap: () => context.go('/habits/manage'),
            ),
          ),
          const SizedBox(height: 12),
          _GlowPanel(
            child: HabitMonthGrid(
              month: month,
              onPrevMonth: _prevMonth,
              onNextMonth: _nextMonth,
              onManageTap: () => context.go('/habits/manage'),
              onChanged: _refreshSummary,
            ),
          ),
        ],
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
