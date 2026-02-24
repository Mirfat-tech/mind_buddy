import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class HabitMonthGrid extends StatefulWidget {
  const HabitMonthGrid({
    super.key,
    required this.month,
    this.onManageTap,
    this.onPrevMonth,
    this.onNextMonth,
    this.onChanged,
    this.prevMonthKey,
    this.nextMonthKey,
    this.gridKey,
  });

  final DateTime month;
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
  final Map<String, Set<String>> _doneByHabitKey = {};

  double _labelWidth = 110;
  String? _lastTappedCellKey;
  DateTime? _lastTapAt;

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
        oldWidget.month.year != widget.month.year) {
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

  String _habitKey(String name) => name.trim().toLowerCase();

  DateTime? _parseLocalDay(dynamic raw) {
    if (raw == null) return null;
    final parsed = raw is DateTime
        ? raw.toLocal()
        : DateTime.tryParse(raw.toString())?.toLocal();
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
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

  double _computeLabelWidth(BuildContext context, List<String> habitNames) {
    final style = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _habitsWithMetadata.clear();
      _doneByHabitKey.clear();
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // FIX: Changed 'categories' to 'habit_categories' to match your SQL
      final habitsResponse = await supabase
          .from('user_habits')
          .select('*, habit_categories(name)')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('sort_order');

      final List habits = habitsResponse as List;
      _habitsWithMetadata.addAll(habits.cast<Map<String, dynamic>>());

      final habitNames = _habitsWithMetadata
          .map((h) => h['name'].toString())
          .toList();
      _labelWidth = _computeLabelWidth(context, habitNames);

      if (_habitsWithMetadata.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // Load Logs
      final start = DateTime(widget.month.year, widget.month.month, 1);
      final end = DateTime(widget.month.year, widget.month.month + 1, 1);

      final rows = await supabase
          .from('habit_logs')
          .select('habit_name, day, is_completed')
          .eq('user_id', user.id)
          .gte('day', _ymd(start))
          .lt('day', _ymd(end));

      for (final r in rows as List) {
        if (r['is_completed'] != true) continue;
        final hk = _habitKey(r['habit_name'] ?? '');
        final dayDt = _parseLocalDay(r['day']);
        if (dayDt == null) continue;
        if (dayDt.year != widget.month.year ||
            dayDt.month != widget.month.month) {
          continue;
        }
        final dayKey = _ymd(dayDt);
        _doneByHabitKey.putIfAbsent(hk, () => <String>{}).add(dayKey);
      }
      if (kDebugMode) {
        final grouped = _doneByHabitKey.values.expand((v) => v).toSet().toList()
          ..sort();
        debugPrint(
          '📅 [HabitMonthGrid] month=${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')} '
          'start=${_ymd(start)} end(exclusive)=${_ymd(end)} tzOffset=${DateTime.now().timeZoneOffset}',
        );
        debugPrint('📅 [HabitMonthGrid] rows=${(rows as List).length}');
        debugPrint('📅 [HabitMonthGrid] groupedDays=${grouped.join(', ')}');
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleDone({
    required String habitName,
    required DateTime day,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dayKey = _ymd(day);
    final hk = _habitKey(habitName);

    setState(() {
      final set = _doneByHabitKey.putIfAbsent(hk, () => <String>{});
      set.contains(dayKey) ? set.remove(dayKey) : set.add(dayKey);
      _lastTappedCellKey = '$dayKey::$hk';
      _lastTapAt = DateTime.now();
    });

    final nowDone = _doneByHabitKey[hk]!.contains(dayKey);

    try {
      final info = await SubscriptionLimits.fetchForCurrentUser();
      if (info.isPending && mounted) {
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => Navigator.of(context).pushNamed('/subscription'),
        );
        // Revert optimistic toggle if trial blocks saving.
        _load();
        return;
      }

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
    final cs = Theme.of(context).colorScheme;
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
      final catName = habit['habit_categories']?['name'] ?? 'Uncategorized';
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
                  _buildCategoryLabel(entry.key),
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
                      _buildDotsRow(habit['name'], days, base, cs),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLabel(String name) {
    return Container(
      height: _categoryHeaderHeight,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
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
    String habitName,
    int days,
    DateTime base,
    ColorScheme cs,
  ) {
    return SizedBox(
      height: _habitRowHeight,
      child: Row(
        children: List.generate(days, (i) {
          final day = DateTime(base.year, base.month, i + 1);
          final dayKey = _ymd(day);
          final hk = _habitKey(habitName);
          final filled = _doneByHabitKey[hk]?.contains(dayKey) == true;

          final cellKey = '$dayKey::$hk';
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
                onTap: () => _toggleDone(habitName: habitName, day: day),
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
