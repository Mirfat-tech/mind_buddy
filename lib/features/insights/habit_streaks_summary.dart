// lib/features/insights/habit_streaks_summary.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_buddy/features/insights/habit_completion_stats.dart';

class HabitStreaksSummary extends StatefulWidget {
  const HabitStreaksSummary({
    super.key,
    required this.month,
    required this.refreshTick,
    this.onManageTap,
  });

  final DateTime month;
  final int refreshTick;
  final VoidCallback? onManageTap;

  @override
  State<HabitStreaksSummary> createState() => _HabitStreaksSummaryState();
}

class _HabitStreaksSummaryState extends State<HabitStreaksSummary> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  int _activeHabitsCount = 0;
  int _doneTodayCount = 0;
  int _monthTicks = 0;

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _load({bool preserveVisibleState = false}) async {
    if (!mounted) return;

    if (preserveVisibleState && !_loading) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _refreshing = false;
        _error = null;
        _activeHabitsCount = 0;
        _doneTodayCount = 0;
        _monthTicks = 0;
      });
    }

    try {
      final stats = await fetchHabitMonthlyCompletionStats(
        selectedMonth: widget.month,
      );

      if (stats.activeHabitsCount == 0) {
        if (!mounted) return;
        setState(() {
          _activeHabitsCount = 0;
          _doneTodayCount = 0;
          _monthTicks = 0;
          _loading = false;
          _refreshing = false;
        });
        return;
      }

      if (!mounted) return;
      if (kDebugMode) {
        debugPrint(
          '📅 [HabitStreaksSummary] month=${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')} '
          'start=${_ymd(stats.monthStart)} end(exclusive)=${_ymd(stats.monthEndExclusive)} tzOffset=${DateTime.now().timeZoneOffset}',
        );
        debugPrint(
          '📅 [HabitStreaksSummary] totals completions=${stats.totalCompletedInstances} '
          'uniqueDays=${stats.uniqueDaysWithCompletion} activeHabits=${stats.activeHabitsCount} '
          'doneToday=${stats.doneTodayCount}',
        );
      }
      setState(() {
        _activeHabitsCount = stats.activeHabitsCount;
        _doneTodayCount = stats.doneTodayCount;
        _monthTicks = stats.totalCompletedInstances;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _refreshing = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HabitStreaksSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month ||
        oldWidget.refreshTick != widget.refreshTick) {
      _load(preserveVisibleState: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Checking your tracker…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withOpacity(0.65),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Couldn’t load habit summary: $_error',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.error),
        ),
      );
    }

    if (_activeHabitsCount == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'No habits yet 🌸 Add your first habit to start your gentle tracker.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: widget.onManageTap,
                child: const Text('Manage'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Column(
          key: ValueKey(
            '$_doneTodayCount-$_activeHabitsCount-$_monthTicks-${widget.month.year}-${widget.month.month}',
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$_doneTodayCount / $_activeHabitsCount habits done today',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: _refreshing ? 1 : 0,
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Month ticks: $_monthTicks',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
