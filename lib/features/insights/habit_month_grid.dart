import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitMonthGrid extends StatefulWidget {
  const HabitMonthGrid({
    super.key,
    required this.month,
    required this.refreshTick,
    this.onManageTap,
    this.onPrevMonth,
    this.onNextMonth,
    this.onChanged,
    this.prevMonthKey,
    this.nextMonthKey,
    this.gridKey,
  });

  final DateTime month;
  final int refreshTick;
  final VoidCallback? onManageTap;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onChanged;
  final GlobalKey? prevMonthKey;
  final GlobalKey? nextMonthKey;
  final GlobalKey? gridKey;

  @override
  State<HabitMonthGrid> createState() => _HabitMonthGridState();
}

class _HabitMonthGridState extends State<HabitMonthGrid> {
  final supabase = Supabase.instance.client;

  // State Variables
  bool _loading = true;
  String? _error;
  final List<Map<String, dynamic>> _habitsWithMetadata = [];
  final Map<String, Set<String>> _doneByHabitId = {};

  double _labelWidth = 110;
  String? _lastTappedCellKey;
  DateTime? _lastTapAt;
  int _loadRequestId = 0;

  // Constants for UI alignment
  static const double _dayCellWidth = 26;
  static const double _dayCellGap = 4;
  static const double _habitRowHeight = 28;
  static const double _categoryHeaderHeight = 40;
  static const double _numbersRowHeight = 22;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HabitMonthGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.month != widget.month.month ||
        oldWidget.month.year != widget.month.year ||
        oldWidget.refreshTick != widget.refreshTick) {
      _load();
    }
  }

  // ----------------------------
  // HELPERS
  // ----------------------------

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseLocalDay(dynamic raw) {
    if (raw == null) return null;
    final parsed = raw is DateTime
        ? raw.toLocal()
        : DateTime.tryParse(raw.toString())?.toLocal();
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime? _habitActiveFrom(
    Map<String, dynamic> habit, {
    DateTime? earliestLoggedDay,
  }) {
    return _parseLocalDay(
          habit['start_date'] ?? habit['active_from'] ?? habit['created_at'],
        ) ??
        earliestLoggedDay;
  }

  DateTime? _habitActiveUntil(Map<String, dynamic> habit) {
    return _parseLocalDay(
      habit['end_date'] ??
          habit['ended_at'] ??
          habit['deleted_at'] ??
          habit['archived_at'] ??
          habit['inactive_at'] ??
          ((habit['is_active'] == false) ? habit['updated_at'] : null),
    );
  }

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

  double _computeLabelWidth(List<String> habitNames) {
    const style = TextStyle(fontSize: 12);
    double maxW = 0;
    for (final h in habitNames) {
      final tp = TextPainter(
        text: TextSpan(text: h, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 9999);
      maxW = maxW < tp.width ? tp.width : maxW;
    }
    return (maxW + 18).clamp(110, 180).toDouble();
  }

  // ----------------------------
  // DATA LOADING & ACTIONS
  // ----------------------------

  Future<void> _load() async {
    final requestId = ++_loadRequestId;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final habitsResponse = await supabase
          .from('user_habits')
          .select('*, habit_categories(name)')
          .eq('user_id', user.id)
          .order('sort_order');

      if (!mounted || requestId != _loadRequestId) return;

      final monthEndExclusive = DateTime(
        widget.month.year,
        widget.month.month + 1,
        1,
      );
      final historyRows = await supabase
          .from('habit_logs')
          .select('habit_id, day')
          .eq('user_id', user.id)
          .lt('day', _ymd(monthEndExclusive));

      if (!mounted || requestId != _loadRequestId) return;

      final earliestLoggedDayByHabit = <String, DateTime>{};
      for (final raw in historyRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final hid = (row['habit_id'] ?? '').toString().trim();
        if (hid.isEmpty) continue;
        final loggedDay = _parseLocalDay(row['day']);
        if (loggedDay == null) continue;
        final existing = earliestLoggedDayByHabit[hid];
        if (existing == null || loggedDay.isBefore(existing)) {
          earliestLoggedDayByHabit[hid] = loggedDay;
        }
      }

      final localHabits = <Map<String, dynamic>>[];
      final seenHabitIds = <String>{};
      for (final raw in habitsResponse as List) {
        final habit = Map<String, dynamic>.from(raw as Map);
        final id = (habit['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          if (!seenHabitIds.add(id)) continue;
        }
        final activeFrom = _habitActiveFrom(
          habit,
          earliestLoggedDay: id.isEmpty ? null : earliestLoggedDayByHabit[id],
        );
        final activeUntil = _habitActiveUntil(habit);
        if (activeFrom != null && !activeFrom.isBefore(monthEndExclusive)) {
          continue;
        }
        if (activeUntil != null && activeUntil.isBefore(DateTime(widget.month.year, widget.month.month, 1))) {
          continue;
        }
        if (activeFrom != null) {
          habit['_active_from'] = _ymd(activeFrom);
        }
        if (activeUntil != null) {
          habit['_active_until'] = _ymd(activeUntil);
        }
        localHabits.add(habit);
      }

      final habitNames = localHabits.map((h) => h['name'].toString()).toList();
      final labelWidth = _computeLabelWidth(habitNames);

      if (localHabits.isEmpty) {
        setState(() {
          _habitsWithMetadata
            ..clear()
            ..addAll(localHabits);
          _doneByHabitId.clear();
          _labelWidth = labelWidth;
          _loading = false;
        });
        return;
      }

      // Load Logs
      final start = DateTime(widget.month.year, widget.month.month, 1);
      final end = DateTime(widget.month.year, widget.month.month + 1, 1);

      final rows = await supabase
          .from('habit_logs')
          .select('habit_id, habit_name, day, is_completed')
          .eq('user_id', user.id)
          .gte('day', _ymd(start))
          .lt('day', _ymd(end));

      if (!mounted || requestId != _loadRequestId) return;

      final activeIds = localHabits
          .map((h) => (h['id'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final stateByHabitDay = <String, bool>{};
      final localDoneByHabitId = <String, Set<String>>{};
      for (final r in rows as List) {
        final hid = (r['habit_id'] ?? '').toString().trim();
        if (hid.isEmpty || !activeIds.contains(hid)) continue;
        final dayDt = _parseLocalDay(r['day']);
        if (dayDt == null) continue;
        if (dayDt.year != widget.month.year ||
            dayDt.month != widget.month.month) {
          continue;
        }
        final dayKey = _ymd(dayDt);
        final k = '$hid|$dayKey';
        stateByHabitDay[k] = r['is_completed'] == true;
      }
      for (final entry in stateByHabitDay.entries) {
        if (entry.value != true) continue;
        final parts = entry.key.split('|');
        if (parts.length != 2) continue;
        final resolvedId = parts[0];
        final dayKey = parts[1];
        localDoneByHabitId
            .putIfAbsent(resolvedId, () => <String>{})
            .add(dayKey);
      }
      if (kDebugMode) {
        final grouped =
            localDoneByHabitId.values.expand((v) => v).toSet().toList()..sort();
        debugPrint(
          '📅 [HabitMonthGrid] month=${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')} '
          'start=${_ymd(start)} end(exclusive)=${_ymd(end)} tzOffset=${DateTime.now().timeZoneOffset}',
        );
        debugPrint('📅 [HabitMonthGrid] rows=${(rows as List).length}');
        debugPrint('📅 [HabitMonthGrid] groupedDays=${grouped.join(', ')}');
      }

      if (!mounted) return;
      if (requestId != _loadRequestId) return;
      setState(() {
        _habitsWithMetadata
          ..clear()
          ..addAll(localHabits);
        _doneByHabitId
          ..clear()
          ..addAll(localDoneByHabitId);
        _labelWidth = labelWidth;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (requestId != _loadRequestId) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleDone({
    required String habitId,
    required String habitName,
    required DateTime day,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dayKey = _ymd(day);
    final hid = habitId.trim();
    if (hid.isEmpty) return;

    setState(() {
      final set = _doneByHabitId.putIfAbsent(hid, () => <String>{});
      set.contains(dayKey) ? set.remove(dayKey) : set.add(dayKey);
      _lastTappedCellKey = '$dayKey::$hid';
      _lastTapAt = DateTime.now();
    });

    final nowDone = _doneByHabitId[hid]!.contains(dayKey);

    try {
      final payload = <String, dynamic>{
        'user_id': user.id,
        'habit_id': hid,
        'habit_name': habitName,
        'day': dayKey,
        'is_completed': nowDone,
      };
      try {
        await supabase
            .from('habit_logs')
            .upsert(payload, onConflict: 'user_id,habit_id,day');
      } catch (_) {
        final existing = await supabase
            .from('habit_logs')
            .select('id')
            .eq('user_id', user.id)
            .eq('habit_id', hid)
            .eq('day', dayKey)
            .maybeSingle();
        if (existing != null) {
          await supabase
              .from('habit_logs')
              .update({'is_completed': nowDone})
              .eq('user_id', user.id)
              .eq('habit_id', hid)
              .eq('day', dayKey);
        } else {
          await supabase.from('habit_logs').insert(payload);
        }
      }

      // Refresh summary after the write completes so it reflects new data.
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      _load(); // Rollback on error
    }
  }

  // ----------------------------
  // UI BUILDERS
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_habitsWithMetadata.isEmpty) {
      return const Center(child: Text('No active habits.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthHeader(context),
        const SizedBox(height: 8),
        _buildScrolledGrid(context),
      ],
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: widget.prevMonthKey,
          icon: const Icon(Icons.chevron_left),
          onPressed: widget.onPrevMonth,
        ),
        Expanded(
          child: Text(
            '${_monthName(widget.month.month)} ${widget.month.year}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          key: widget.nextMonthKey,
          icon: const Icon(Icons.chevron_right),
          onPressed: widget.onNextMonth,
        ),
      ],
    );
  }

  Widget _buildScrolledGrid(BuildContext context) {
    final days = _daysInMonth(widget.month);
    final cs = Theme.of(context).colorScheme;
    final base = DateTime(widget.month.year, widget.month.month, 1);

    // Grouping habits by their category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var habit in _habitsWithMetadata) {
      // Matches the 'habit_categories' join name
      final catName = habit['habit_categories']?['name'] ?? 'Uncategorised';
      grouped.putIfAbsent(catName, () => []).add(habit);
    }

    return Container(
      key: widget.gridKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN: Labels
          SizedBox(
            width: _labelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: _numbersRowHeight),
                for (var entry in grouped.entries) ...[
                  _buildCategoryLabel(context, entry.key),
                  for (var habit in entry.value)
                    _buildHabitLabel(habit['name']),
                ],
              ],
            ),
          ),
          // RIGHT COLUMN: Scrollable Grid
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDaysRow(days),
                  for (var entry in grouped.entries) ...[
                    const SizedBox(
                      height: _categoryHeaderHeight,
                    ), // Spacer for category header
                    for (var habit in entry.value)
                      _buildDotsRow(habit, days, base, cs),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLabel(BuildContext context, String name) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: _categoryHeaderHeight,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: scheme.primary.withValues(alpha: 0.88),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildHabitLabel(String name) {
    return SizedBox(
      height: _habitRowHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDaysRow(int days) {
    return SizedBox(
      height: _numbersRowHeight,
      child: Row(
        children: List.generate(
          days,
          (i) => SizedBox(
            width: _dayCellWidth + _dayCellGap,
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotsRow(
    Map<String, dynamic> habit,
    int days,
    DateTime base,
    ColorScheme cs,
  ) {
    final habitId = (habit['id'] ?? '').toString();
    final habitName = (habit['name'] ?? '').toString();
    return SizedBox(
      height: _habitRowHeight,
      child: Row(
        children: List.generate(days, (i) {
          final day = DateTime(base.year, base.month, i + 1);
          final dayKey = _ymd(day);
          final hid = habitId.trim();
          final filled = _doneByHabitId[hid]?.contains(dayKey) == true;

          final cellKey = '$dayKey::$hid';
          final isRecentTap =
              _lastTappedCellKey == cellKey &&
              _lastTapAt != null &&
              DateTime.now().difference(_lastTapAt!).inMilliseconds < 200;

          return Padding(
            padding: const EdgeInsets.only(right: _dayCellGap),
            child: SizedBox(
              width: _dayCellWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _toggleDone(
                  habitId: habitId,
                  habitName: habitName,
                  day: day,
                ),
                child: Center(
                  child: _dot(filled: filled, isPopping: isRecentTap, cs: cs),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _dot({
    required bool filled,
    required bool isPopping,
    required ColorScheme cs,
  }) {
    return AnimatedScale(
      scale: isPopping ? 1.3 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? cs.primary : Colors.transparent,
          border: Border.all(
            color: filled ? cs.primary : cs.outlineVariant,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
