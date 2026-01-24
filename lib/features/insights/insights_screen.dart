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

  // --- GLOWING UI HELPERS ---

  Widget _glowingIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15), // Softer opacity
            blurRadius: 20, // High blur for soft glow
            spreadRadius: 0, // Fixed the "lines" issue
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          icon: Icon(icon, color: scheme.primary, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _sectionWrapper(ColorScheme scheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: scheme.primary.withOpacity(0.05), blurRadius: 10),
        ],
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Insights'),
        leading: _glowingIconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          scheme: scheme,
        ),
        actions: [
          _glowingIconButton(
            icon: Icons.refresh,
            onPressed: loading ? () {} : _refresh,
            scheme: scheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                if (error != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(error!, style: TextStyle(color: scheme.error)),
                  ),
                  const SizedBox(height: 12),
                ],

                // --- HABIT TRACKER SECTION ---
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    'Habit tracker',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                _sectionWrapper(
                  scheme,
                  child: Column(
                    children: [
                      HabitStreaksSummary(
                        key: ValueKey(
                          'summary_${_refreshSeed}_${_month.year}-${_month.month}',
                        ),
                        month: _month,
                        onManageTap: () => context.push('/habits/manage'),
                      ),
                      // The Grid itself
                      HabitMonthGrid(
                        month: _month,
                        onManageTap: () => context.push('/habits/manage'),
                        onPrevMonth: _prevMonth,
                        onNextMonth: _nextMonth,
                        onChanged: _onGridChanged,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // --- SLEEP SECTION ---
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    'Sleep',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                _sectionWrapper(scheme, child: const SleepInsights()),

                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
