// lib/features/insights/habit_streaks_summary.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitStreaksSummary extends StatefulWidget {
  const HabitStreaksSummary({super.key, required this.month, this.onManageTap});

  final DateTime month;
  final VoidCallback? onManageTap;

  @override
  State<HabitStreaksSummary> createState() => _HabitStreaksSummaryState();
}

class _HabitStreaksSummaryState extends State<HabitStreaksSummary> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
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

  String _habitKey(String name) => name.trim().toLowerCase();

  DateTime _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    return DateTime.parse(v.toString()); // handles "YYYY-MM-DD"
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _activeHabitsCount = 0;
      _doneTodayCount = 0;
      _monthTicks = 0;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // 1) Active habits count (denominator)
      final habitsRows = await supabase
          .from('user_habits')
          .select('name')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('sort_order');

      final activeHabits = (habitsRows as List)
          .map((r) => (r as Map)['name'].toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final activeCount = activeHabits.length;
      final activeKeys = activeHabits.map(_habitKey).toSet();

      if (activeCount == 0) {
        if (!mounted) return;
        setState(() {
          _activeHabitsCount = 0;
          _doneTodayCount = 0;
          _monthTicks = 0;
          _loading = false;
        });
        return;
      }

      // 2) Date ranges
      final todayKey = _ymd(DateTime.now());
      final start = DateTime(widget.month.year, widget.month.month, 1);
      final end = DateTime(widget.month.year, widget.month.month + 1, 1);

      // 3) Pull completed logs for the month
      final monthRows = await supabase
          .from('habit_logs')
          .select('habit_name, day, is_completed')
          .eq('user_id', user.id)
          .gte('day', _ymd(start))
          .lt('day', _ymd(end))
          .eq('is_completed', true);

      // Count each row = a tick (one habit on one day)
      int monthTicks = 0;

      // Today = unique habits completed today
      final Set<String> doneTodayHabits = <String>{};

      for (final r in (monthRows as List)) {
        final row = Map<String, dynamic>.from(r as Map);

        final habit = (row['habit_name'] ?? '').toString().trim();
        if (habit.isEmpty) continue;

        final hk = _habitKey(habit);
        if (!activeKeys.contains(hk)) continue;

        final dayDt = _asDateTime(row['day']).toLocal();
        final dayKey = _ymd(dayDt);

        monthTicks++;

        if (dayKey == todayKey) {
          doneTodayHabits.add(hk);
        }
      }

      if (!mounted) return;
      setState(() {
        _activeHabitsCount = activeCount;
        _doneTodayCount = doneTodayHabits.length;
        _monthTicks = monthTicks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
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
        oldWidget.month.month != widget.month.month) {
      _load();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_doneTodayCount / $_activeHabitsCount habits done today',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
    );
  }
}
