import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitMonthGrid extends StatefulWidget {
  const HabitMonthGrid({
    super.key,
    required this.month,
    this.onManageTap,
    this.onPrevMonth,
    this.onNextMonth,
    this.onChanged,
  });

  final DateTime month;
  final VoidCallback? onManageTap;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onChanged;

  @override
  State<HabitMonthGrid> createState() => _HabitMonthGridState();
}

class _HabitMonthGridState extends State<HabitMonthGrid> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  final List<String> _activeHabits = [];
  final Map<String, Set<String>> _doneByHabitKey = {};

  double _labelWidth = 110;

  String? _lastTappedCellKey;
  DateTime? _lastTapAt;

  static const double _dayCellWidth = 26;
  static const double _dayCellGap = 4;
  static const double _habitRowHeight = 28;
  static const double _numbersRowHeight = 22;

  // ----------------------------
  // Helpers
  // ----------------------------

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _habitKey(String name) => name.trim().toLowerCase();

  int _daysInMonth(DateTime m) => DateTime(
    m.year,
    m.month + 1,
    1,
  ).difference(DateTime(m.year, m.month, 1)).inDays;

  String _monthName(int m) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];

  double _computeLabelWidth(BuildContext context, List<String> habits) {
    final style = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    double maxW = 0;

    for (final h in habits) {
      final tp = TextPainter(
        text: TextSpan(text: h, style: style),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 9999);
      maxW = maxW < tp.width ? tp.width : maxW;
    }

    return (maxW + 18).clamp(90, 170).toDouble();
  }

  // ----------------------------
  // LOAD MONTH DATA
  // ----------------------------

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _activeHabits.clear();
      _doneByHabitKey.clear();
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1) Load active habits
      final habitsRows = await supabase
          .from('user_habits')
          .select('name')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('sort_order');

      _activeHabits.addAll(
        (habitsRows as List)
            .map((r) => r['name'].toString().trim())
            .where((s) => s.isNotEmpty),
      );

      _labelWidth = _computeLabelWidth(context, _activeHabits);

      if (_activeHabits.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // 2) Load habit logs for month
      final start = DateTime(widget.month.year, widget.month.month, 1);
      final end = DateTime(widget.month.year, widget.month.month + 1, 1);

      final rows = await supabase
          .from('habit_logs')
          .select('habit_name, day, is_completed')
          .eq('user_id', user.id)
          .gte('day', _ymd(start))
          .lt('day', _ymd(end));

      final activeKeys = _activeHabits.map(_habitKey).toSet();

      for (final r in rows as List) {
        if (r['is_completed'] != true) continue;

        final habit = (r['habit_name'] ?? '').toString().trim();
        final hk = _habitKey(habit);
        if (!activeKeys.contains(hk)) continue;

        final dayVal = r['day'];
        final DateTime dayDt = dayVal is DateTime
            ? dayVal
            : DateTime.parse(dayVal.toString()); // handles "YYYY-MM-DD"

        final dayKey = _ymd(dayDt.toLocal());

        _doneByHabitKey.putIfAbsent(hk, () => <String>{}).add(dayKey);
      }

      setState(() => _loading = false);
    } catch (e) {
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
  void didUpdateWidget(covariant HabitMonthGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.month != widget.month.month ||
        oldWidget.month.year != widget.month.year) {
      _load();
    }
  }

  // ----------------------------
  // TOGGLE DOT
  // ----------------------------

  Future<void> _toggleDone({
    required String habitName,
    required DateTime day,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dayKey = _ymd(day);
    final hk = _habitKey(habitName);

    // optimistic UI
    setState(() {
      final set = _doneByHabitKey.putIfAbsent(hk, () => <String>{});
      set.contains(dayKey) ? set.remove(dayKey) : set.add(dayKey);
      _lastTappedCellKey = '$dayKey::$hk';
      _lastTapAt = DateTime.now();
    });

    final nowDone = _doneByHabitKey[hk]!.contains(dayKey);
    widget.onChanged?.call();

    try {
      final existing = await supabase
          .from('habit_logs')
          .select('id')
          .eq('user_id', user.id)
          .eq('habit_name', habitName)
          .eq('day', dayKey)
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('habit_logs')
            .update({'is_completed': nowDone})
            .eq('id', existing['id']);
      } else {
        await supabase.from('habit_logs').insert({
          'user_id': user.id,
          'habit_name': habitName,
          'day': dayKey,
          'is_completed': nowDone,
        });
      }
    } catch (e) {
      await _load(); // rollback on failure
    }
  }

  // ----------------------------
  // UI (unchanged)
  // ----------------------------

  Widget _dot({
    required bool filled,
    required bool isPopping,
    required ColorScheme cs,
  }) {
    return AnimatedScale(
      scale: isPopping ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? cs.primary : Colors.transparent,
          border: Border.all(color: cs.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: widget.onPrevMonth,
        ),
        Expanded(
          child: Text(
            '${_monthName(widget.month.month)} ${widget.month.year}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: widget.onNextMonth,
        ),
        GestureDetector(
          onTap: widget.onManageTap,
          child: Text(
            'Manage',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Padding(padding: EdgeInsets.all(8), child: Text('Loading…'));
    if (_error != null) return Text('Error: $_error');
    if (_activeHabits.isEmpty) return const SizedBox.shrink();

    final days = _daysInMonth(widget.month);
    final cs = Theme.of(context).colorScheme;
    final base = DateTime(widget.month.year, widget.month.month, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthHeader(context),
        const SizedBox(height: 8),
        _buildScrolledGrid(context, days, cs),
      ],
    );
  }

  Widget _buildScrolledGrid(BuildContext context, int days, ColorScheme cs) {
    final base = DateTime(widget.month.year, widget.month.month, 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: habit labels (does NOT scroll)
        SizedBox(
          width: _labelWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: _numbersRowHeight),
              for (final habit in _activeHabits)
                SizedBox(
                  height: _habitRowHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      habit,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // RIGHT: grid (scrolls horizontally)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: (days * _dayCellWidth) + ((days - 1) * _dayCellGap),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NUMBERS ROW
                  SizedBox(
                    height: _numbersRowHeight,
                    child: Row(
                      children: List.generate(days, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: _dayCellGap),
                          child: SizedBox(
                            width: _dayCellWidth,
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // DOT ROWS
                  for (final habit in _activeHabits)
                    SizedBox(
                      height: _habitRowHeight,
                      child: Row(
                        children: List.generate(days, (i) {
                          final day = DateTime(base.year, base.month, i + 1);
                          final dayKey = _ymd(day);
                          final hk = _habitKey(habit);

                          final filled =
                              _doneByHabitKey[hk]?.contains(dayKey) == true;

                          final cellKey = '$dayKey::$hk';
                          final isRecentTap =
                              _lastTappedCellKey == cellKey &&
                              _lastTapAt != null &&
                              DateTime.now()
                                      .difference(_lastTapAt!)
                                      .inMilliseconds <
                                  220;

                          return Padding(
                            padding: const EdgeInsets.only(right: _dayCellGap),
                            child: SizedBox(
                              width: _dayCellWidth,
                              child: Center(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () =>
                                      _toggleDone(habitName: habit, day: day),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: _dot(
                                      filled: filled,
                                      isPopping: isRecentTap,
                                      cs: cs,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
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
