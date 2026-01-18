// lib/features/insights/insights_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'habit_month_grid.dart';
import 'sleep_insights.dart';
import 'habit_streaks_summary.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _refreshSeed = 0;

  bool loading = false;
  String? error;

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _refreshSeed++);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
      _refreshSeed++;
    });
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
      _refreshSeed++;
    });
  }

  void _onGridChanged() {
    setState(() {
      _refreshSeed++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loading ? null : _refresh,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) ...[
                  Text(
                    error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Habit tracker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        backgroundColor: Colors.transparent,
                      ),
                ),
                const SizedBox(height: 10),
                HabitStreaksSummary(
                  key: ValueKey(
                      'summary_${_refreshSeed}_${_month.year}-${_month.month}'),
                  month: _month,
                  onManageTap: () => context.push('/habits/manage'),
                ),
                HabitMonthGrid(
                  month: _month,
                  onManageTap: () => context.push('/habits/manage'),
                  onPrevMonth: _prevMonth,
                  onNextMonth: _nextMonth,
                  onChanged: _onGridChanged,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sleep',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const SleepInsights(),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
