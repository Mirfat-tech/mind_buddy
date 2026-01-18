// lib/features/insights/habit_streaks_summary.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitStreaksSummary extends StatefulWidget {
  const HabitStreaksSummary({
    super.key,
    required this.month,
    this.onManageTap,
  });

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

  // ----------------------------
  // ✅ Helpers: stable formatting
  // ----------------------------

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
  // ^^^ Ensures date comparison is consistent and timezone-safe.

  String _habitKey(String name) => name.trim().toLowerCase();
  // ^^^ Normalizes habit names so "Change background" == "change background".

  bool _readDone(Map<String, dynamic> data) {
    final done = data['done'];
    if (done is bool) return done;

    final status =
        (data['status'] ?? data['state'] ?? '').toString().toLowerCase().trim();

    return status == 'done' ||
        status == 'completed' ||
        status == 'true' ||
        status == 'yes';
  }
  // ^^^ Handles multiple possible schemas: done=true, status=done, etc.

  String _readHabit(Map<String, dynamic> data) {
    final h = data['habit'] ?? data['habit_name'] ?? data['name'] ?? '';
    return h.toString().trim();
  }
  // ^^^ Supports different field names stored in your log data.

  // ------------------------------------------------------
  // ✅ Get the templateId for template_key = 'habits'
  // ------------------------------------------------------
  Future<String?> _getHabitsTemplateId(String userId) async {
    final tpl = await supabase
        .from('log_templates_v2')
        .select('id')
        .eq('user_id', userId)
        .eq('template_key', 'habits')
        .maybeSingle();

    if (tpl == null) return null;
    return tpl['id']?.toString();
  }
  // ^^^ Without this templateId, we can't query log_entries for the habits template.

  // ----------------------------
  // ✅ Main loader: counts + ticks
  // ----------------------------
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

      // If user not logged in, just stop loading gracefully.
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // 1) Load active habits (these define the denominator of "X / Y")
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

      // ✅ Normalized set for matching log entries
      final activeKeys = activeHabits.map(_habitKey).toSet();

      // If no active habits, show the "No habits yet" UI.
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

      // 2) Get habits templateId so we can pull month log_entries.
      final templateId = await _getHabitsTemplateId(user.id);

      // If template missing, still show active habit count but 0 done/ticks.
      if (templateId == null) {
        if (!mounted) return;
        setState(() {
          _activeHabitsCount = activeCount;
          _doneTodayCount = 0;
          _monthTicks = 0;
          _loading = false;
        });
        return;
      }

      // 3) Define month range [start, end)
      final base = DateTime(widget.month.year, widget.month.month, 1);
      final start = base;
      final end = DateTime(base.year, base.month + 1, 1);

      // 4) Load all habit log entries within that month
      final rows = await supabase
          .from('log_entries')
          .select('day, data')
          .eq('template_id', templateId)
          .gte('day', _ymd(start))
          .lt('day', _ymd(end));

      // ✅ Today as a stable key
      final todayKey = _ymd(DateTime.now());

      // We count:
      // - monthTickKeys: every (day, habit) that is "done" in the month
      // - doneTodayHabits: unique habits done today (for numerator)
      final Set<String> monthTickKeys = <String>{};
      final Set<String> doneTodayHabits = <String>{};

      // 5) Parse rows and build sets
      for (final r in (rows as List)) {
        final row = Map<String, dynamic>.from(r as Map);

        // ✅ Convert day to YYYY-MM-DD string safely
        final dayVal = row['day'];
        final dayKey = (dayVal is DateTime)
            ? _ymd(dayVal.toLocal())
            : dayVal.toString().substring(0, 10);

        final dataRaw = row['data'];
        final data = (dataRaw is Map)
            ? Map<String, dynamic>.from(dataRaw as Map)
            : <String, dynamic>{};

        // Read habit name and normalize it for matching
        final habit = _readHabit(data);
        if (habit.isEmpty) continue;

        final habitKey = _habitKey(habit);

        // Only consider habits that are currently active
        if (!activeKeys.contains(habitKey)) continue;

        // Only consider "done" entries
        final done = _readDone(data);
        if (!done) continue;

        // Month ticks count each unique (day, habit)
        monthTickKeys.add('$dayKey::$habitKey');

        // Today count counts each unique habit completed today
        if (dayKey == todayKey) {
          doneTodayHabits.add(habitKey);
        }
      }

      // 6) Update UI state
      if (!mounted) return;
      setState(() {
        _activeHabitsCount = activeCount;
        _doneTodayCount = doneTodayHabits.length;
        _monthTicks = monthTickKeys.length;
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
  // ^^^ This loader now matches habits reliably using normalized keys and stable day strings.

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
  // ^^^ Reload if user switches month.

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Checking your tracker…',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: cs.onSurface.withOpacity(0.65)),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Couldn’t load habit summary: $_error',
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
        ),
      );
    }

    // If there are no active habits, show your friendly “add your first habit” card.
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

    // Main summary text (matches screenshot layout)
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_doneTodayCount / $_activeHabitsCount habits done today',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Month ticks: $_monthTicks',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurface.withOpacity(0.75)),
          ),
        ],
      ),
    );
  }
}
