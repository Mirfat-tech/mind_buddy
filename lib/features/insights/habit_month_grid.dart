// lib/features/insights/habit_month_grid.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitMonthGrid extends StatefulWidget {
  const HabitMonthGrid({
    super.key,
    required this.month,
    this.onManageTap,
    this.onPrevMonth,
    this.onNextMonth,
    this.onChanged, // call this after toggles so summary refreshes
  });

  // The month currently being displayed (always use the 1st of the month)
  final DateTime month;

  // Manage button tap
  final VoidCallback? onManageTap;

  // Month chevrons (handled by parent; parent updates month)
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;

  // Notifies parent that the grid changed (so HabitStreaksSummary can refresh)
  final VoidCallback? onChanged;

  @override
  State<HabitMonthGrid> createState() => _HabitMonthGridState();
}

class _HabitMonthGridState extends State<HabitMonthGrid> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Active habit names (left-side labels)
  final List<String> _activeHabits = [];

  // doneByHabitKey[habitKey] = set of YYYY-MM-DD strings that are DONE
  final Map<String, Set<String>> _doneByHabitKey = {};

  // Option B: auto-sized label width based on longest habit name
  double _labelWidth = 110;

  // Cached template_id for habits log template
  String? _templateId;

  // For the “pop” animation: store last tapped cell key + timestamp
  String? _lastTappedCellKey; // "YYYY-MM-DD::habitKey"
  DateTime? _lastTapAt;

  // Day cell sizing (keeps numbers readable + dots aligned)
  static const double _dayCellWidth = 26; // ⬅️ more room for the dot
  static const double _dayCellGap = 4;
  static const double _habitRowHeight = 28;

  // Number row height (so labels column aligns vertically with grid)
  static const double _numbersRowHeight = 22;

  // ----------------------------
  // Helpers: formatting & reading
  // ----------------------------

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _habitKey(String name) => name.trim().toLowerCase();

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

  String _readHabit(Map<String, dynamic> data) {
    final h = data['habit'] ?? data['habit_name'] ?? data['name'] ?? '';
    return h.toString().trim();
  }

  int _daysInMonth(DateTime m) {
    final start = DateTime(m.year, m.month, 1);
    final next = DateTime(m.year, m.month + 1, 1);
    return next.difference(start).inDays;
  }

  String _monthName(int m) {
    const names = [
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
    ];
    if (m < 1 || m > 12) return 'Month';
    return names[m - 1];
  }

  // ---------------------------------------------------------
  // OPTION B: measure widest habit name for auto labelWidth
  // ---------------------------------------------------------
  double _computeLabelWidth(BuildContext context, List<String> habitNames) {
    final style = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    double maxW = 0;

    for (final h in habitNames) {
      final tp = TextPainter(
        text: TextSpan(text: h, style: style),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 9999);

      if (tp.width > maxW) maxW = tp.width;
    }

    // Add padding + clamp so label column stays reasonable
    return (maxW + 18).clamp(90, 170).toDouble();
  }

  // -----------------------------------
  // Supabase: get templateId for habits
  // -----------------------------------
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

  // ----------------------------------------
  // LOAD: habits + month entries into memory
  // ----------------------------------------
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
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // 1) Load active habits for label column
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

      _activeHabits.addAll(activeHabits);

      // 2) Compute label width after we know habit names (Option B)
      _labelWidth = _computeLabelWidth(context, _activeHabits);

      // If no habits, nothing else to load
      if (_activeHabits.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // 3) Cache template id for habits template
      _templateId ??= await _getHabitsTemplateId(user.id);
      if (_templateId == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      // 4) Month range [start, end)
      final base = DateTime(widget.month.year, widget.month.month, 1);
      final start = base;
      final end = DateTime(base.year, base.month + 1, 1);

      // 5) Load log entries for this month
      final rows = await supabase
          .from('log_entries')
          .select('day, data')
          .eq('template_id', _templateId!)
          .gte('day', _ymd(start))
          .lt('day', _ymd(end));

      // 6) Normalize active habit keys for matching
      final activeKeys = _activeHabits.map(_habitKey).toSet();

      final Map<String, Set<String>> doneByHabitKey = {};

      for (final r in (rows as List)) {
        final row = Map<String, dynamic>.from(r as Map);

        // Convert day to stable YYYY-MM-DD
        final dayVal = row['day'];
        final dayKey = (dayVal is DateTime)
            ? _ymd(dayVal.toLocal())
            : dayVal.toString().substring(0, 10);

        final dataRaw = row['data'];
        final data = (dataRaw is Map)
            ? Map<String, dynamic>.from(dataRaw as Map)
            : <String, dynamic>{};

        final habit = _readHabit(data);
        if (habit.isEmpty) continue;

        final hk = _habitKey(habit);
        if (!activeKeys.contains(hk)) continue;

        if (!_readDone(data)) continue;

        doneByHabitKey.putIfAbsent(hk, () => <String>{});
        doneByHabitKey[hk]!.add(dayKey);
      }

      if (!mounted) return;
      setState(() {
        _doneByHabitKey
          ..clear()
          ..addAll(doneByHabitKey);
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
  void didUpdateWidget(covariant HabitMonthGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _load();
    }
  }

  // ----------------------------
  // Tap behavior: toggle in DB
  // ----------------------------
  Future<void> _toggleDone({
    required String habitName,
    required DateTime day,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Ensure template id
    _templateId ??= await _getHabitsTemplateId(user.id);
    if (_templateId == null) return;

    final dayKey = _ymd(day);
    final hk = _habitKey(habitName);

    // 1) Optimistic UI update + animation trigger
    setState(() {
      final set = _doneByHabitKey.putIfAbsent(hk, () => <String>{});
      if (set.contains(dayKey)) {
        set.remove(dayKey);
      } else {
        set.add(dayKey);
      }

      _lastTappedCellKey = '$dayKey::$hk';
      _lastTapAt = DateTime.now();
    });

    // Let parent refresh HabitStreaksSummary
    widget.onChanged?.call();

    try {
      // 2) Find existing row for the same day, then match habit inside JSON
      final dayRows = await supabase
          .from('log_entries')
          .select('id, data')
          .eq('template_id', _templateId!)
          .eq('day', dayKey);

      Map<String, dynamic>? found;
      for (final r in (dayRows as List)) {
        final row = Map<String, dynamic>.from(r as Map);
        final dataRaw = row['data'];
        final data = (dataRaw is Map)
            ? Map<String, dynamic>.from(dataRaw as Map)
            : <String, dynamic>{};

        final habit = _readHabit(data);
        if (_habitKey(habit) == hk) {
          found = row;
          break;
        }
      }

      // Determine new done state from UI
      final nowDone = _doneByHabitKey[hk]?.contains(dayKey) == true;

      if (found != null) {
        // 3a) Update existing row
        final id = found['id'];
        final existingDataRaw = found['data'];
        final existingData = (existingDataRaw is Map)
            ? Map<String, dynamic>.from(existingDataRaw as Map)
            : <String, dynamic>{};

        existingData['habit'] = habitName.trim();
        existingData['done'] = nowDone;
        existingData['status'] = nowDone ? 'done' : 'todo';

        await supabase
            .from('log_entries')
            .update({'data': existingData}).eq('id', id);
      } else {
        // 3b) Insert new row
        await supabase.from('log_entries').insert({
          'template_id': _templateId,
          'day': dayKey,
          'data': {
            'habit': habitName.trim(),
            'done': nowDone,
            'status': nowDone ? 'done' : 'todo',
          },
        });
      }
    } catch (e) {
      // If DB write fails, reload from source of truth
      await _load();
    }
  }

  // ----------------------------
  // UI: dot with subtle “pop”
  // ----------------------------
  Widget _dot({
    required bool filled,
    required bool isPopping,
    required ColorScheme cs,
  }) {
    return AnimatedScale(
      scale: isPopping ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 12, // ⬅️ bigger dot
        height: 12, // ⬅️ bigger dot
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? cs.primary : Colors.transparent,
          border: Border.all(
            color: cs.outlineVariant,
            width: 1.2, // ⬅️ slightly thicker outline
          ),
        ),
      ),
    );
  }

  // ----------------------------
  // UI: top header (month + chevrons + manage)
  // ----------------------------
  Widget _buildMonthHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = '${_monthName(widget.month.month)} ${widget.month.year}';

    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: widget.onPrevMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: widget.onNextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: widget.onManageTap,
          child: Text(
            'Manage',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  // ----------------------------
  // UI: the scrolled grid (numbers + dot rows)
  // ✅ This is the key: ONE horizontal scroll wraps everything
  // ----------------------------
  Widget _buildScrolledGrid(BuildContext context, int days) {
    final cs = Theme.of(context).colorScheme;
    final base = DateTime(widget.month.year, widget.month.month, 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: labels column (fixed; does NOT scroll horizontally)
        SizedBox(
          width: _labelWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spacer to align label column with the numbers row
              const SizedBox(height: _numbersRowHeight),

              // Labels (wrap to 2 lines if too long)
              for (final habitName in _activeHabits) ...[
                SizedBox(
                  height: _habitRowHeight, // forces same height as dot row
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      habitName,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // RIGHT: day grid column (scrolls horizontally as ONE unit)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NUMBERS ROW (scrolls together with dots)
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
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    height: 1.0,
                                    color: cs.onSurface.withOpacity(0.75),
                                  ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // HABIT DOT ROWS (scroll with the numbers row)
                for (final habitName in _activeHabits) ...[
                  SizedBox(
                    height: _habitRowHeight, // exact same height as label row
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: List.generate(days, (i) {
                          final day = DateTime(base.year, base.month, i + 1);
                          final dayKey = _ymd(day);

                          final hk = _habitKey(habitName);
                          final doneSet = _doneByHabitKey[hk] ?? <String>{};
                          final filled = doneSet.contains(dayKey);

                          // Pop animation trigger for last tapped cell
                          final cellKey = '$dayKey::$hk';
                          final isRecentTap = _lastTappedCellKey == cellKey &&
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
                                  onTap: () => _toggleDone(
                                    habitName: habitName,
                                    day: day,
                                  ),
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
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Loading your month…',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurface.withOpacity(0.65)),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Couldn’t load month grid: $_error',
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
        ),
      );
    }

    if (_activeHabits.isEmpty) return const SizedBox.shrink();

    final days = _daysInMonth(widget.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthHeader(context),
        const SizedBox(height: 8),
        _buildScrolledGrid(context, days),
      ],
    );
  }
}
