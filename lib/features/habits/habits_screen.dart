import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'package:mind_buddy/features/insights/habit_streaks_summary.dart';

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
    return Scaffold(
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
          const SizedBox(height: 8),

          // ✅ Key forces rebuild when refreshTick changes
          HabitStreaksSummary(
            key: ValueKey(
              'summary_${refreshTick}_${month.year}-${month.month}',
            ),
            month: month,
            onManageTap: () => context.go('/habits/manage'),
          ),

          const SizedBox(height: 6),

          HabitMonthGrid(
            month: month,
            onPrevMonth: _prevMonth,
            onNextMonth: _nextMonth,
            onManageTap: () => context.go('/habits/manage'),

            // ✅ when user taps dots, refresh summary
            onChanged: _refreshSummary,
          ),
        ],
      ),
    );
  }
}
