// lib/features/insights/insights_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/insights/brainbubble_insights.dart';
import 'package:mind_buddy/features/insights/habit_completion_stats.dart';
import 'package:mind_buddy/features/mood/mood_catalog.dart' as mood_catalog;
import 'package:mind_buddy/guides/guide_manager.dart';

import 'sleep_insights.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const List<String> _allInsightSections = [
    'Habits',
    'Sleep',
    'Mood',
    'Meditation',
    'Finance',
    'Cycle',
    'Workout',
    'Social',
    'Fasting',
    'Water',
    'Activities',
  ];
  static const String _insightsVisibilityPrefsKey =
      'insights_visible_sections_v1';

  final ScrollController _mainScrollController = ScrollController();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _refreshSeed = 0;
  bool _loading = false;
  String? _error;
  Set<String> _visibleSections = {..._allInsightSections};
  final GlobalKey _insightsBackButtonKey = GlobalKey();
  final GlobalKey _insightsMonthPrevChevronKey = GlobalKey();
  final GlobalKey _insightsMonthNextChevronKey = GlobalKey();
  final GlobalKey _insightsCategoryChipsRowKey = GlobalKey();
  final GlobalKey _insightsRefreshButtonKey = GlobalKey();
  final GlobalKey _insightsFirstCardKey = GlobalKey();
  bool _guideScheduledThisOpen = false;

  final Map<String, GlobalKey> _sectionKeys = {
    'Habits': GlobalKey(),
    'Sleep': GlobalKey(),
    'Mood': GlobalKey(),
    'Meditation': GlobalKey(),
    'Finance': GlobalKey(),
    'Cycle': GlobalKey(),
    'Workout': GlobalKey(),
    'Social': GlobalKey(),
    'Fasting': GlobalKey(),
    'Water': GlobalKey(),
    'Activities': GlobalKey(),
  };

  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    _loadVisibleSections();
  }

  Future<void> _loadVisibleSections() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_insightsVisibilityPrefsKey);
    if (stored == null || stored.isEmpty) return;
    final visible = stored.where(_allInsightSections.contains).toSet();
    if (!mounted || visible.isEmpty) return;
    setState(() => _visibleSections = visible);
  }

  Future<void> _persistVisibleSections(Set<String> visibleSections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _insightsVisibilityPrefsKey,
      _allInsightSections.where(visibleSections.contains).toList(),
    );
  }

  Future<void> _showSectionFilters() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        var tempVisible = <String>{..._visibleSections};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: scheme.primary.withOpacity(0.16)),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.10),
                        blurRadius: 26,
                        spreadRadius: 1,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Choose insights',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Show only the sections you want to keep in view.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => setModalState(() {
                                tempVisible = {..._allInsightSections};
                              }),
                              child: const Text('Show all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _allInsightSections.map((section) {
                                final isSelected = tempVisible.contains(
                                  section,
                                );
                                return FilterChip(
                                  selected: isSelected,
                                  showCheckmark: true,
                                  label: Text(section),
                                  selectedColor: scheme.primary.withOpacity(
                                    0.16,
                                  ),
                                  backgroundColor: scheme.surfaceContainerHigh,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onSelected: (selected) => setModalState(() {
                                    if (selected) {
                                      tempVisible.add(section);
                                    } else {
                                      tempVisible.remove(section);
                                    }
                                  }),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(tempVisible),
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    final visible = result.where(_allInsightSections.contains).toSet();
    if (!mounted) return;
    setState(() => _visibleSections = visible);
    await _persistVisibleSections(visible);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _refreshSeed++);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

  String _monthName(int m) => _monthNames[m - 1];

  Future<void> _showGuideIfNeeded({bool force = false}) async {
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'insights',
      force: force,
      requireAllTargetsVisible: true,
      steps: [
        GuideStep(
          key: _insightsMonthPrevChevronKey,
          title: 'Your monthly reflection',
          body:
              'Use the arrows to move between months and see your patterns over time.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _insightsCategoryChipsRowKey,
          title: 'Choose your bubble',
          body:
              'Tap a category (Habits, Sleep, Mood + more) to switch what you’re viewing.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _insightsFirstCardKey,
          title: 'Your stats, at a glance',
          body:
              'Each card shows your totals, trends, and consistency for this month.',
          align: GuideAlign.top,
        ),
        GuideStep(
          key: _insightsRefreshButtonKey,
          title: 'Need a fresh view?',
          body: 'Tap refresh to reload your latest data.',
          align: GuideAlign.bottom,
        ),
      ],
    );
  }

  void _scheduleGuideAutoStart() {
    if (!mounted || _guideScheduledThisOpen) return;
    _guideScheduledThisOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 24), () {
        if (!mounted) return;
        _showGuideIfNeeded();
      });
    });
  }

  Widget _buildMonthPicker() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: _insightsMonthPrevChevronKey,
            onPressed: _prevMonth,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_monthName(_month.month)} ${_month.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Monthly Report',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.primary),
                ),
              ],
            ),
          ),
          IconButton(
            key: _insightsMonthNextChevronKey,
            onPressed: _nextMonth,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    GuideManager.dismissActiveGuideForPage('insights');
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _scheduleGuideAutoStart();
    final sections = _buildInsightSections(scheme);
    final visibleSections = sections
        .where((section) => _visibleSections.contains(section.id))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Insights'),
        leading: MbGlowBackButton(
          key: _insightsBackButtonKey,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.tune_rounded,
            onPressed: _showSectionFilters,
          ),
          MbGlowIconButton(
            key: _insightsRefreshButtonKey,
            icon: Icons.refresh_outlined,
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: MbFloatingHintOverlay(
          hintKey: 'hint_insights',
          text: 'You can scroll gently — insights unfold at your pace.',
          iconText: '✨',
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _ErrorBox(message: _error!),
                      ),
                    _buildMonthPicker(),
                    _buildCategoryNavigator(
                      key: _insightsCategoryChipsRowKey,
                      controller: _mainScrollController,
                      scheme: scheme,
                      categories: visibleSections
                          .map((section) => section.id)
                          .toList(),
                      sectionKeys: _sectionKeys,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _mainScrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (visibleSections.isEmpty)
                              _GlowingCard(
                                scheme: scheme,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No insight sections are showing right now.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Use the filter in the top corner whenever you want to bring everything back.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      FilledButton.tonal(
                                        onPressed: _showSectionFilters,
                                        child: const Text('Show sections'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...visibleSections.asMap().entries.expand((
                                entry,
                              ) {
                                final index = entry.key;
                                final section = entry.value;
                                final card = _GlowingCard(
                                  scheme: scheme,
                                  child: section.child,
                                );
                                return [
                                  Container(
                                    key: _sectionKeys[section.id],
                                    child: _sectionTitle(
                                      section.title,
                                      section.icon,
                                    ),
                                  ),
                                  if (index == 0)
                                    KeyedSubtree(
                                      key: _insightsFirstCardKey,
                                      child: card,
                                    )
                                  else
                                    card,
                                  const SizedBox(height: 32),
                                ];
                              }),
                            const SizedBox(height: 100),

                            // const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

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
            color: scheme.primary.withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          icon: Icon(icon, color: scheme.primary),
          onPressed: onPressed,
        ),
      ),
    );
  }

  List<_InsightSectionDefinition> _buildInsightSections(ColorScheme scheme) {
    return [
      _InsightSectionDefinition(
        id: 'Habits',
        title: 'Habit Tracker',
        icon: Icons.check_circle_outline,
        child: HabitStepLineChartContainer(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Sleep',
        title: 'Sleep Insights',
        icon: Icons.bedtime_outlined,
        child: SleepInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Mood',
        title: 'Mood Tracker',
        icon: Icons.sentiment_satisfied,
        child: MoodInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Meditation',
        title: 'Meditation',
        icon: Icons.spa_outlined,
        child: MeditationInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Finance',
        title: 'Finance Insights',
        icon: Icons.payments_outlined,
        child: FinanceInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Cycle',
        title: 'Cycle Insights',
        icon: Icons.water_drop_outlined,
        child: CycleInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Workout',
        title: 'Workout Calendar',
        icon: Icons.fitness_center,
        child: WorkoutInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Social',
        title: 'Social Outings',
        icon: Icons.people,
        child: SocialOutingsInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Fasting',
        title: 'Fasting Tracker',
        icon: Icons.access_time,
        child: FastingInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Water',
        title: 'Water Intake',
        icon: Icons.local_drink,
        child: WaterInsights(selectedMonth: _month),
      ),
      _InsightSectionDefinition(
        id: 'Activities',
        title: 'Activity Trends',
        icon: Icons.auto_graph,
        child: GenericActivityTrends(
          selectedMonth: _month,
          refreshSeed: _refreshSeed,
        ),
      ),
    ];
  }
}

// CATEGORY NAVIGATOR
Widget _buildCategoryNavigator({
  GlobalKey? key,
  required ScrollController controller,
  required ColorScheme scheme,
  required List<String> categories,
  required Map<String, GlobalKey> sectionKeys,
}) {
  return SizedBox(
    key: key,
    height: 50,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, i) {
        final category = categories[i];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(category),
            backgroundColor: scheme.surfaceContainerHigh,
            labelStyle: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
            onPressed: () {
              final key = sectionKeys[category];
              final ctx = key?.currentContext;
              if (ctx == null) return;

              final renderBox = ctx.findRenderObject() as RenderBox?;
              if (renderBox == null) return;

              final position = renderBox.localToGlobal(Offset.zero);
              final targetOffset = controller.offset + position.dy - 140;

              controller.animateTo(
                targetOffset.clamp(
                  controller.position.minScrollExtent,
                  controller.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
          ),
        );
      },
    ),
  );
}

class _InsightSectionDefinition {
  const _InsightSectionDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String id;
  final String title;
  final IconData icon;
  final Widget child;
}

// SHARED HELPERS
DateTime _startOfMonth(DateTime month) => DateTime(month.year, month.month, 1);
DateTime _startOfNextMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 1);
DateTime _startOfPreviousMonth(DateTime month) =>
    DateTime(month.year, month.month - 1, 1);

int _daysInMonth(DateTime month) {
  final startNext = DateTime(month.year, month.month + 1, 1);
  return startNext.subtract(const Duration(days: 1)).day;
}

String _ymd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _monthLabel(DateTime month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

DateTime? _parseAsLocalDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();
  final parsed = DateTime.tryParse(raw.toString());
  return parsed?.toLocal();
}

DateTime _toLocalDay(DateTime d) => DateTime(d.year, d.month, d.day);

int? _dayInSelectedMonth(dynamic raw, DateTime selectedMonth) {
  final parsed = _parseAsLocalDate(raw);
  if (parsed == null) return null;
  final day = _toLocalDay(parsed);
  if (day.year != selectedMonth.year || day.month != selectedMonth.month) {
    return null;
  }
  return day.day;
}

String? _dayKeyInSelectedMonth(dynamic raw, DateTime selectedMonth) {
  final parsed = _parseAsLocalDate(raw);
  if (parsed == null) return null;
  final day = _toLocalDay(parsed);
  if (day.year != selectedMonth.year || day.month != selectedMonth.month) {
    return null;
  }
  return _ymd(day);
}

void _debugMonthQuery({
  required String label,
  required DateTime selectedMonth,
  required DateTime start,
  required DateTime endExclusive,
  required List<Map<String, dynamic>> rows,
  required dynamic Function(Map<String, dynamic>) rawTimestamp,
  required Iterable<String> groupedDayKeys,
}) {
  if (!kDebugMode) return;
  final sample = rows.take(3).map((row) {
    final raw = rawTimestamp(row);
    final local = _parseAsLocalDate(raw);
    return 'raw=$raw local=$local';
  }).toList();
  final grouped = groupedDayKeys.toList()..sort();
  debugPrint(
    '📅 [$label] month=${_monthLabel(selectedMonth)} '
    'start=${start.toIso8601String()} end(exclusive)=${endExclusive.toIso8601String()} '
    'tzOffset=${DateTime.now().timeZoneOffset}',
  );
  debugPrint('📅 [$label] rows=${rows.length}');
  debugPrint('📅 [$label] sample=${sample.join(' | ')}');
  debugPrint('📅 [$label] groupedDays=${grouped.join(', ')}');
}

String _currency(num v) {
  final sign = v < 0 ? '-' : '';
  final abs = v.abs();
  if (abs >= 1000) return '$sign\$${abs.toStringAsFixed(0)}';
  return '$sign\$${abs.toStringAsFixed(2)}';
}

String _compactMoney(double v) {
  final abs = v.abs();
  final sign = v < 0 ? '-' : '';
  if (abs >= 1000000) return '$sign\$${(abs / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '$sign\$${(abs / 1000).toStringAsFixed(1)}K';
  return '$sign\$${abs.toStringAsFixed(0)}';
}

double _niceInterval(double maxY) {
  if (maxY <= 0) return 1;
  final raw = maxY / 4;
  if (raw <= 10) return 10;
  if (raw <= 25) return 25;
  if (raw <= 50) return 50;
  if (raw <= 100) return 100;
  if (raw <= 250) return 250;
  if (raw <= 500) return 500;
  if (raw <= 1000) return 1000;
  return (raw / 1000).roundToDouble() * 1000;
}

// CALENDAR GRID HELPER
class _DayCellVisual {
  final String? iconText;
  final IconData? iconData;
  final Color bgColor;
  final Color? iconColor;

  const _DayCellVisual({
    required this.bgColor,
    this.iconText,
    this.iconData,
    this.iconColor,
  }) : assert(iconText != null || iconData != null);

  Widget buildIcon(double size, Color fallbackTextColor) {
    if (iconData != null) {
      return Icon(iconData, size: size, color: iconColor);
    }
    return Text(
      iconText!,
      style: TextStyle(fontSize: size, color: iconColor ?? fallbackTextColor),
    );
  }
}

Widget _buildEmojiCalendarGrid({
  required DateTime selectedMonth,
  required ColorScheme scheme,
  required _DayCellVisual Function(int dayNumber) cellForDay,
  double cellHeight = 50,
  double iconSize = 18,
}) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final daysInMonth = DateTime(
    selectedMonth.year,
    selectedMonth.month + 1,
    0,
  ).day;
  final firstDayOfWeek =
      DateTime(selectedMonth.year, selectedMonth.month, 1).weekday - 1;

  return Column(
    children: [
      Row(
        children: days
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 8),
      ...List.generate((daysInMonth + firstDayOfWeek + 6) ~/ 7, (weekIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: List.generate(7, (dayOfWeek) {
              final dayNumber =
                  (weekIndex * 7) + dayOfWeek - firstDayOfWeek + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              final v = cellForDay(dayNumber);

              return Expanded(
                child: Container(
                  height: cellHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: v.bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: scheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          v.buildIcon(iconSize, scheme.onSurface),
                          const SizedBox(height: 1),
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    ],
  );
}

// HABIT TRACKER
class HabitStepLineChartContainer extends StatelessWidget {
  final DateTime selectedMonth;
  const HabitStepLineChartContainer({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<HabitMonthlyCompletionStats>(
      future: fetchHabitMonthlyCompletionStats(
        supabase: Supabase.instance.client,
        selectedMonth: selectedMonth,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBox(message: snapshot.error.toString());
        }

        final stats =
            snapshot.data ??
            HabitMonthlyCompletionStats(
              monthStart: _startOfMonth(selectedMonth),
              monthEndExclusive: _startOfNextMonth(selectedMonth),
              totalCompletedInstances: 0,
              uniqueDaysWithCompletion: 0,
              activeHabitsCount: 0,
              doneTodayCount: 0,
              completionsByDay: const {},
            );
        final counts = stats.completionsByDay;
        final days = _daysInMonth(selectedMonth);
        final daysWithHabits = stats.uniqueDaysWithCompletion;
        final totalHabits = stats.totalCompletedInstances;
        final avgPerDay = daysWithHabits > 0
            ? (totalHabits / daysWithHabits).toStringAsFixed(1)
            : '0';
        if (kDebugMode) {
          final dayKeys =
              counts.keys
                  .map(
                    (day) => _ymd(
                      DateTime(selectedMonth.year, selectedMonth.month, day),
                    ),
                  )
                  .toList()
                ..sort();
          debugPrint(
            '📅 [HabitsInsights] start=${_ymd(stats.monthStart)} end(exclusive)=${_ymd(stats.monthEndExclusive)} '
            'completionRows=${stats.totalCompletedInstances} uniqueDays=${stats.uniqueDaysWithCompletion} '
            'totalUsed=$totalHabits avgUsed=$avgPerDay',
          );
          debugPrint('📅 [HabitsInsights] groupedDays=${dayKeys.join(', ')}');
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceContainerLow.withOpacity(0.5),
            border: Border.all(color: scheme.outline.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Habits Tracked',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalHabits.toString(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StatBubble(
                              label: 'Days Active',
                              value: daysWithHabits.toString(),
                              scheme: scheme,
                            ),
                            const SizedBox(height: 8),
                            _StatBubble(
                              label: 'Avg/Day',
                              value: avgPerDay,
                              scheme: scheme,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Text(
              // 'Activity Heatmap',
              // style: TextStyle(
              // fontSize: 12,
              // fontWeight: FontWeight.w600,
              // color: scheme.onSurfaceVariant.withOpacity(0.7),
              //),
              //),
              const SizedBox(height: 10),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: List.generate(days, (index) {
                  final day = index + 1;
                  final count = counts[day] ?? 0;
                  final intensity = count == 0
                      ? 0.1
                      : (count / 3).clamp(0.2, 1.0);

                  return Tooltip(
                    message: 'Day $day: $count habit${count == 1 ? "" : "s"}',
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(intensity),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: scheme.outline.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Less',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(
                    4,
                    (i) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.1 + (i * 0.25)),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme scheme;

  const _StatBubble({
    required this.label,
    required this.value,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: scheme.primary.withOpacity(0.08),
        border: Border.all(color: scheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// GLOWING CARD
class _GlowingCard extends StatelessWidget {
  const _GlowingCard({required this.scheme, required this.child});
  final ColorScheme scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: scheme.primary.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.surface,
          border: Border.all(
            color: scheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.surface.withOpacity(0.8), scheme.surface],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

// FINANCE
class FinanceAgg {
  final String period;
  double income = 0;
  double expenses = 0;
  FinanceAgg({required this.period});
}

class FinanceInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const FinanceInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = _startOfMonth(selectedMonth);
    final previousStart = _startOfPreviousMonth(selectedMonth);
    final endExclusive = _startOfNextMonth(selectedMonth);
    final startDate = _ymd(previousStart);
    final endExclusiveDate = _ymd(endExclusive);

    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _fetchAllFinanceData(startDate, endExclusiveDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBox(
            message: 'Error loading finance data: ${snapshot.error}',
          );
        }

        final data = snapshot.data ?? {};
        final billRows = data['bills'] ?? [];
        final expenseRows = data['expenses'] ?? [];
        final incomeRows = data['income'] ?? [];

        final countDays = _daysInMonth(selectedMonth);
        final Map<String, FinanceAgg> byDay = {
          for (int i = 1; i <= countDays; i++)
            _ymd(
              DateTime(selectedMonth.year, selectedMonth.month, i),
            ): FinanceAgg(
              period: _ymd(
                DateTime(selectedMonth.year, selectedMonth.month, i),
              ),
            ),
        };

        double totalIncome = 0;
        double totalExpenses = 0;
        double previousTotalExpenses = 0;
        DateTime? spendingSpikeDate;

        for (final r in incomeRows) {
          final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
          final dayKey = _parseDayKey(r['day']);
          final parsed = dayKey == null ? null : DateTime.tryParse(dayKey);
          if (dayKey != null &&
              parsed != null &&
              parsed.year == selectedMonth.year &&
              parsed.month == selectedMonth.month &&
              byDay.containsKey(dayKey)) {
            byDay[dayKey]!.income += amount;
            totalIncome += amount;
          }
        }

        for (final r in expenseRows) {
          final amount =
              (r['cost'] as num?)?.toDouble() ??
              (r['amount'] as num?)?.toDouble() ??
              0.0;
          final dayKey = _parseDayKey(r['day']);
          final parsed = dayKey == null ? null : DateTime.tryParse(dayKey);
          if (dayKey != null &&
              parsed != null &&
              parsed.year == selectedMonth.year &&
              parsed.month == selectedMonth.month &&
              byDay.containsKey(dayKey)) {
            byDay[dayKey]!.expenses += amount;
            totalExpenses += amount;
            final currentTotalForDay = byDay[dayKey]!.expenses;
            if (spendingSpikeDate == null ||
                currentTotalForDay >
                    (byDay[_ymd(spendingSpikeDate!)]?.expenses ?? -1)) {
              spendingSpikeDate = parsed;
            }
          } else if (parsed != null &&
              parsed.year == previousStart.year &&
              parsed.month == previousStart.month) {
            previousTotalExpenses += amount;
          }
        }

        for (final r in billRows) {
          final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
          final dayKey = _parseDayKey(r['day']);
          final parsed = dayKey == null ? null : DateTime.tryParse(dayKey);
          if (dayKey != null &&
              parsed != null &&
              parsed.year == selectedMonth.year &&
              parsed.month == selectedMonth.month &&
              byDay.containsKey(dayKey)) {
            byDay[dayKey]!.expenses += amount;
            totalExpenses += amount;
            final currentTotalForDay = byDay[dayKey]!.expenses;
            if (spendingSpikeDate == null ||
                currentTotalForDay >
                    (byDay[_ymd(spendingSpikeDate!)]?.expenses ?? -1)) {
              spendingSpikeDate = parsed;
            }
          } else if (parsed != null &&
              parsed.year == previousStart.year &&
              parsed.month == previousStart.month) {
            previousTotalExpenses += amount;
          }
        }
        _debugMonthQuery(
          label: 'FinanceInsights',
          selectedMonth: selectedMonth,
          start: start,
          endExclusive: endExclusive,
          rows: [...incomeRows, ...expenseRows, ...billRows],
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: byDay.entries
              .where(
                (entry) => entry.value.income > 0 || entry.value.expenses > 0,
              )
              .map((entry) => entry.key),
        );

        final chartData = byDay.values.toList()
          ..sort((a, b) => a.period.compareTo(b.period));
        final moneyKept = totalIncome - totalExpenses;
        final savingsRate = totalIncome > 0
            ? (moneyKept / totalIncome) * 100
            : null;
        final chartExpenses = totalIncome > 0
            ? math.min(totalExpenses, totalIncome).toDouble()
            : totalExpenses;
        final chartRemaining = totalIncome > 0
            ? math.max(moneyKept, 0).toDouble()
            : 0.0;
        final chartOverspent = totalIncome > 0
            ? math.max(totalExpenses - totalIncome, 0).toDouble()
            : 0.0;
        final insight = BrainBubbleInsights.finance(
          currentExpenses: totalExpenses,
          previousExpenses: previousTotalExpenses,
          currentNet: moneyKept,
          spikeDate: spendingSpikeDate,
        );

        if (totalIncome == 0 && totalExpenses == 0) {
          return const _ErrorBox(
            message: 'No finance data found for this month',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrainBubbleInsightCallout(
              data: insight,
              scheme: scheme,
              accentColor: scheme.primary,
            ),
            const SizedBox(height: 12),
            _SectionHeaderRow(
              title: 'Monthly money picture',
              subtitle: _monthLabel(selectedMonth),
              trailing: _Legend(
                items: [
                  _LegendItem(label: 'Expenses', color: scheme.error),
                  _LegendItem(
                    label: chartOverspent > 0 ? 'Overspent' : 'Kept',
                    color: chartOverspent > 0
                        ? scheme.errorContainer
                        : scheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(0.45),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.primary.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: FinanceBreakdownDonutChart(
                      scheme: scheme,
                      totalIncome: totalIncome,
                      expenses: chartExpenses,
                      remaining: chartRemaining,
                      overspent: chartOverspent,
                      moneyKept: moneyKept,
                    ),
                  ),
                  if (chartData.any(
                    (day) => day.income > 0 || day.expenses > 0,
                  )) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Daily trend',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          'A softer view of your spikes',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 140,
                      child: FinanceComparisonLineChart(
                        data: chartData,
                        scheme: scheme,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Income',
                    value: _currency(totalIncome),
                    icon: Icons.trending_up,
                    scheme: scheme,
                    valueColor: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Total Expenses',
                    value: _currency(totalExpenses),
                    icon: Icons.trending_down,
                    scheme: scheme,
                    valueColor: scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Money Kept',
                    value: _currency(moneyKept),
                    icon: Icons.account_balance_wallet,
                    scheme: scheme,
                    valueColor: moneyKept < 0 ? scheme.error : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Savings Rate',
                    value: savingsRate == null
                        ? '—'
                        : '${savingsRate.toStringAsFixed(1)}%',
                    icon: Icons.savings_outlined,
                    scheme: scheme,
                    valueColor: savingsRate == null
                        ? scheme.onSurfaceVariant
                        : savingsRate < 0
                        ? scheme.error
                        : scheme.primary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAllFinanceData(
    String startDate,
    String endExclusiveDate,
  ) async {
    final results = await Future.wait([
      Supabase.instance.client
          .from('income_logs')
          .select('day, amount')
          .gte('day', startDate)
          .lt('day', endExclusiveDate)
          .catchError((_) => []),
      Supabase.instance.client
          .from('expense_logs')
          .select('day, cost')
          .gte('day', startDate)
          .lt('day', endExclusiveDate)
          .catchError((_) => []),
      Supabase.instance.client
          .from('bill_logs')
          .select('day, amount')
          .gte('day', startDate)
          .lt('day', endExclusiveDate)
          .catchError((_) => []),
    ], eagerError: false);

    return {
      'income': List<Map<String, dynamic>>.from(results[0] as List? ?? []),
      'expenses': List<Map<String, dynamic>>.from(results[1] as List? ?? []),
      'bills': List<Map<String, dynamic>>.from(results[2] as List? ?? []),
    };
  }

  String? _parseDayKey(dynamic rawDay) {
    return _dayKeyInSelectedMonth(rawDay, selectedMonth);
  }
}

class FinanceComparisonLineChart extends StatelessWidget {
  final List<FinanceAgg> data;
  final ColorScheme scheme;

  const FinanceComparisonLineChart({
    super.key,
    required this.data,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = _calculateMaxY();
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      incomeSpots.add(FlSpot(i.toDouble(), d.income.toDouble()));
      expenseSpots.add(FlSpot(i.toDouble(), d.expenses.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 10,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: scheme.outline.withOpacity(0.10), strokeWidth: 1),
        ),
        titlesData: _buildTitles(maxY),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dayIndex = spot.x.toInt();
                if (dayIndex < 0 || dayIndex >= data.length) return null;

                final d = data[dayIndex];
                final isIncomeLine = spot.bar.color == scheme.primary;
                final label = isIncomeLine
                    ? 'Income\n${d.period}\n${_currency(spot.y)}'
                    : 'Expenses\n${d.period}\n${_currency(spot.y)}';

                return LineTooltipItem(
                  label,
                  TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            color: scheme.primary,
            barWidth: 2.4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: false,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 5,
                    color: scheme.primary,
                    strokeWidth: 2,
                    strokeColor: scheme.surface,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withOpacity(0.1),
            ),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            color: scheme.error,
            barWidth: 2.4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: false,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 5,
                    color: scheme.error,
                    strokeWidth: 2,
                    strokeColor: scheme.surface,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.error.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMaxY() {
    double maxVal = 0;
    for (final d in data) {
      if (d.income > maxVal) maxVal = d.income;
      if (d.expenses > maxVal) maxVal = d.expenses;
    }
    return maxVal <= 0 ? 10 : maxVal * 1.15;
  }

  FlTitlesData _buildTitles(double maxY) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          interval: _niceInterval(maxY),
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                _compactMoney(value),
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= data.length) return const SizedBox.shrink();

            final day = int.tryParse(data[i].period.split('-').last) ?? (i + 1);
            final shouldShow = day == 1 || day % 5 == 0 || day == data.length;
            if (!shouldShow) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$day',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FinanceBreakdownDonutChart extends StatelessWidget {
  const FinanceBreakdownDonutChart({
    super.key,
    required this.scheme,
    required this.totalIncome,
    required this.expenses,
    required this.remaining,
    required this.overspent,
    required this.moneyKept,
  });

  final ColorScheme scheme;
  final double totalIncome;
  final double expenses;
  final double remaining;
  final double overspent;
  final double moneyKept;

  @override
  Widget build(BuildContext context) {
    final hasIncome = totalIncome > 0;
    final sections = <PieChartSectionData>[
      if (expenses > 0)
        PieChartSectionData(
          value: expenses,
          color: scheme.error,
          radius: 28,
          showTitle: false,
        ),
      if (remaining > 0)
        PieChartSectionData(
          value: remaining,
          color: scheme.primary,
          radius: 28,
          showTitle: false,
        ),
      if (overspent > 0)
        PieChartSectionData(
          value: overspent,
          color: scheme.errorContainer,
          radius: 28,
          showTitle: false,
        ),
      if (!hasIncome && expenses > 0)
        PieChartSectionData(
          value: expenses,
          color: scheme.error,
          radius: 28,
          showTitle: false,
        ),
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 5,
            centerSpaceRadius: 62,
            startDegreeOffset: -90,
            sections: sections.isEmpty
                ? [
                    PieChartSectionData(
                      value: 1,
                      color: scheme.surfaceContainerHighest,
                      radius: 28,
                      showTitle: false,
                    ),
                  ]
                : sections,
          ),
        ),
        Container(
          width: 124,
          height: 124,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface.withOpacity(0.98),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.08),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                hasIncome
                    ? moneyKept >= 0
                          ? 'Left over'
                          : 'Overspent'
                    : 'Income',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasIncome ? _currency(moneyKept) : 'None logged',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: moneyKept < 0 ? scheme.error : scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasIncome
                    ? 'Income ${_currency(totalIncome)}'
                    : 'Add income to see a savings split',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// CYCLE INSIGHTS
class CycleInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const CycleInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final start = _startOfMonth(selectedMonth);
    final historyStart = DateTime(
      selectedMonth.year,
      selectedMonth.month - 12,
      1,
    );
    final endExclusive = _startOfNextMonth(selectedMonth);
    final startDay = _ymd(start);
    final endExclusiveDay = _ymd(endExclusive);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('menstrual_logs')
          .select('day, flow')
          .gte('day', _ymd(historyStart))
          .lt('day', endExclusiveDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBox(message: snapshot.error.toString());
        }

        final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final currentRows = rows.where((r) {
          final parsed = DateTime.tryParse((r['day'] ?? '').toString());
          return parsed != null &&
              parsed.year == selectedMonth.year &&
              parsed.month == selectedMonth.month;
        }).toList();

        final Map<int, String> cycleMap = {};
        for (final r in currentRows) {
          final day = _dayInSelectedMonth(r['day'], selectedMonth);
          if (day == null) continue;
          final rawFlow = (r['flow'] ?? '').toString().toLowerCase().trim();

          if (rawFlow.contains('heavy')) {
            cycleMap[day] = 'heavy';
          } else if (rawFlow.contains('medium')) {
            cycleMap[day] = 'medium';
          } else if (rawFlow.contains('light')) {
            cycleMap[day] = 'light';
          } else if (rawFlow.contains('spot')) {
            cycleMap[day] = 'spotting';
          }
        }
        final cyclePrediction = _buildCyclePrediction(rows);
        _debugMonthQuery(
          label: 'CycleInsights',
          selectedMonth: selectedMonth,
          start: start,
          endExclusive: endExclusive,
          rows: currentRows,
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: cycleMap.keys.map(
            (day) =>
                _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
          ),
        );

        int light = 0, medium = 0, heavy = 0, spotting = 0;
        for (final v in cycleMap.values) {
          if (v == 'light') light++;
          if (v == 'medium') medium++;
          if (v == 'heavy') heavy++;
          if (v == 'spotting') spotting++;
        }
        if (kDebugMode) {
          debugPrint(
            '📅 [CycleInsights] counts light=$light medium=$medium heavy=$heavy spotting=$spotting',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrainBubbleInsightCallout(
              data: BrainBubbleInsights.cycle(
                predictedDate: cyclePrediction.predictedStart,
                avgCycleLength: cyclePrediction.averageCycleLength,
                lastStartDate: cyclePrediction.lastStart,
                hasEnoughHistory: cyclePrediction.hasEnoughHistory,
              ),
              scheme: scheme,
              accentColor: Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            _SectionHeaderRow(
              title: 'Cycle Tracker',
              subtitle: _monthLabel(selectedMonth),
              trailing: Text(
                'Logs: ${rows.length}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildEmojiCalendarGrid(
              selectedMonth: selectedMonth,
              scheme: scheme,
              cellForDay: (dayNumber) {
                final flow = cycleMap[dayNumber] ?? '';
                final bgColor = flow.isEmpty
                    ? scheme.outline.withOpacity(0.05)
                    : Colors.red.withOpacity(0.08);

                IconData iconData = Icons.water_drop_outlined;
                Color iconColor = Colors.transparent;

                switch (flow) {
                  case 'heavy':
                    iconColor = Colors.red.shade900;
                    break;
                  case 'medium':
                    iconColor = Colors.red.shade600;
                    break;
                  case 'light':
                    iconColor = Colors.red.shade300;
                    break;
                  case 'spotting':
                    iconData = Icons.circle;
                    iconColor = Colors.orange.shade600;
                    break;
                  default:
                    iconData = Icons.remove;
                    iconColor = scheme.outline.withOpacity(0.25);
                }

                return _DayCellVisual(
                  bgColor: bgColor,
                  iconData: iconData,
                  iconColor: iconColor,
                );
              },
              iconSize: 20,
            ),
            const SizedBox(height: 12),
            _MiniSummaryRow(
              items: [
                _MiniSummaryItem(label: 'Light', value: '$light'),
                _MiniSummaryItem(label: 'Medium', value: '$medium'),
                _MiniSummaryItem(label: 'Heavy', value: '$heavy'),
                _MiniSummaryItem(label: 'Spotting', value: '$spotting'),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CyclePrediction {
  const _CyclePrediction({
    required this.hasEnoughHistory,
    this.predictedStart,
    this.averageCycleLength,
    this.lastStart,
  });

  final bool hasEnoughHistory;
  final DateTime? predictedStart;
  final int? averageCycleLength;
  final DateTime? lastStart;
}

_CyclePrediction _buildCyclePrediction(List<Map<String, dynamic>> rows) {
  final grouped = <DateTime, String>{};
  for (final row in rows) {
    final parsed = DateTime.tryParse((row['day'] ?? '').toString())?.toLocal();
    if (parsed == null) continue;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final flow = (row['flow'] ?? '').toString().toLowerCase().trim();
    grouped[day] = _strongerFlow(grouped[day], flow);
  }

  final sortedDays = grouped.keys.toList()..sort();
  final starts = <DateTime>[];
  DateTime? segmentStart;
  DateTime? firstMeaningfulBleed;
  DateTime? previousDay;

  void closeSegment() {
    if (firstMeaningfulBleed != null) {
      starts.add(firstMeaningfulBleed!);
    }
    segmentStart = null;
    firstMeaningfulBleed = null;
  }

  for (final day in sortedDays) {
    if (previousDay == null || day.difference(previousDay!).inDays > 1) {
      closeSegment();
      segmentStart = day;
    }
    final flow = grouped[day] ?? '';
    if (_isMeaningfulCycleFlow(flow)) {
      firstMeaningfulBleed ??= day;
    } else {
      segmentStart ??= day;
    }
    previousDay = day;
  }
  closeSegment();

  if (starts.length < 2) {
    return _CyclePrediction(
      hasEnoughHistory: false,
      lastStart: starts.isNotEmpty ? starts.last : null,
    );
  }

  final cycleLengths = <int>[];
  for (var i = 1; i < starts.length; i++) {
    final diff = starts[i].difference(starts[i - 1]).inDays;
    if (diff >= 15 && diff <= 45) {
      cycleLengths.add(diff);
    }
  }
  if (cycleLengths.length < 2) {
    return _CyclePrediction(hasEnoughHistory: false, lastStart: starts.last);
  }

  final recent = cycleLengths.length > 6
      ? cycleLengths.sublist(cycleLengths.length - 6)
      : cycleLengths;
  final avgLength = (recent.reduce((a, b) => a + b) / recent.length).round();
  final lastStart = starts.last;

  return _CyclePrediction(
    hasEnoughHistory: true,
    averageCycleLength: avgLength,
    lastStart: lastStart,
    predictedStart: lastStart.add(Duration(days: avgLength)),
  );
}

bool _isMeaningfulCycleFlow(String flow) {
  return flow.contains('heavy') ||
      flow.contains('medium') ||
      flow.contains('light');
}

String _strongerFlow(String? existing, String incoming) {
  const weights = <String, int>{
    'spotting': 0,
    'light': 1,
    'medium': 2,
    'heavy': 3,
  };

  String normalize(String value) {
    if (value.contains('heavy')) return 'heavy';
    if (value.contains('medium')) return 'medium';
    if (value.contains('light')) return 'light';
    if (value.contains('spot')) return 'spotting';
    return '';
  }

  final next = normalize(incoming);
  final current = normalize(existing ?? '');
  if ((weights[next] ?? -1) >= (weights[current] ?? -1)) {
    return next;
  }
  return current;
}

// MOOD INSIGHTS
class MoodInsights extends StatefulWidget {
  final DateTime selectedMonth;
  const MoodInsights({super.key, required this.selectedMonth});

  @override
  State<MoodInsights> createState() => _MoodInsightsState();
}

class _MoodInsightsState extends State<MoodInsights> {
  late Future<List<Map<String, dynamic>>> _moodFuture;

  @override
  void initState() {
    super.initState();
    _moodFuture = _fetchMoodRows();
  }

  @override
  void didUpdateWidget(covariant MoodInsights oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth.year != widget.selectedMonth.year ||
        oldWidget.selectedMonth.month != widget.selectedMonth.month) {
      setState(() {
        _moodFuture = _fetchMoodRows();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMoodRows() async {
    final start = _ymd(_startOfPreviousMonth(widget.selectedMonth));
    final endExclusive = _ymd(_startOfNextMonth(widget.selectedMonth));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (kDebugMode) {
      debugPrint(
        '📅 [MoodInsights] fetch-start userId=$userId start=$start end(exclusive)=$endExclusive',
      );
    }
    try {
      final result = await Supabase.instance.client
          .from('mood_logs')
          .select('day, feeling, intensity')
          .gte('day', start)
          .lt('day', endExclusive)
          .timeout(const Duration(seconds: 12));
      final rows = List<Map<String, dynamic>>.from(result as List? ?? []);
      if (kDebugMode) {
        final sample = rows.isEmpty ? '{}' : rows.first.toString();
        debugPrint(
          '📅 [MoodInsights] fetch-end rows=${rows.length} firstRow=$sample',
        );
      }
      return rows;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MoodInsights] fetch-error: $e');
      }
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _moodFuture = _fetchMoodRows();
    });
  }

  String _canonicalMood(dynamic rawMood) {
    return mood_catalog.canonicalMood(rawMood);
  }

  String _displayMood(String moodOption) {
    return mood_catalog.displayMood(moodOption);
  }

  String _moodEmoji(String moodOption) {
    return mood_catalog.moodEmoji(moodOption);
  }

  Color _moodColor(String moodOption, ColorScheme scheme) {
    final key = _displayMood(moodOption).toLowerCase();
    if (key.contains('happy') ||
        key.contains('excited') ||
        key.contains('confident')) {
      return Colors.green.withOpacity(0.2);
    }
    if (key.contains('sad')) return Colors.blue.withOpacity(0.2);
    if (key.contains('angry')) return Colors.red.withOpacity(0.2);
    if (key.contains('stressed') || key.contains('anxious')) {
      return Colors.orange.withOpacity(0.2);
    }
    if (key.contains('calm')) return Colors.teal.withOpacity(0.2);
    if (key.contains('tired')) return Colors.indigo.withOpacity(0.2);
    if (key.contains('sick')) return Colors.purple.withOpacity(0.2);
    if (key.contains('neutral')) return Colors.grey.withOpacity(0.2);
    return scheme.primary.withOpacity(0.15);
  }

  bool _isLightMood(String moodOption) {
    return mood_catalog.isPositiveMood(moodOption);
  }

  bool _isHeavyMood(String moodOption) {
    return mood_catalog.isNegativeMood(moodOption);
  }

  bool _isNeutralMood(String moodOption) {
    return mood_catalog.isNeutralMood(moodOption);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _moodFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: scheme.error.withOpacity(0.08),
              border: Border.all(color: scheme.error.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Couldn’t load mood insights. Tap retry.',
                    style: TextStyle(
                      color: scheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ),
          );
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: scheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border.all(color: scheme.outline.withOpacity(0.2)),
            ),
            child: Text(
              'No mood entries logged this month',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final Map<int, String> moodByDay = {};
        final Map<String, int> moodCounts = {};
        int currentLightDays = 0;
        int currentHeavyDays = 0;
        int currentNeutralDays = 0;
        int previousLightDays = 0;
        int previousHeavyDays = 0;
        for (final r in rows) {
          final moodRaw = (r['feeling'] ?? '').toString().trim();
          final mood = _canonicalMood(moodRaw);
          final parsed = r['day'] == null
              ? null
              : DateTime.tryParse(r['day'].toString())?.toLocal();
          final isCurrentMonth =
              parsed != null &&
              parsed.year == widget.selectedMonth.year &&
              parsed.month == widget.selectedMonth.month;
          final isPreviousMonth =
              parsed != null &&
              parsed.year == _startOfPreviousMonth(widget.selectedMonth).year &&
              parsed.month == _startOfPreviousMonth(widget.selectedMonth).month;
          if (mood.isNotEmpty && isCurrentMonth) {
            final day = _dayInSelectedMonth(r['day'], widget.selectedMonth);
            if (day != null) {
              moodByDay[day] = mood;
            }
            moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
          }
          if (isCurrentMonth) {
            if (_isLightMood(mood)) currentLightDays++;
            if (_isHeavyMood(mood)) currentHeavyDays++;
            if (_isNeutralMood(mood)) currentNeutralDays++;
          } else if (isPreviousMonth) {
            if (_isLightMood(mood)) previousLightDays++;
            if (_isHeavyMood(mood)) previousHeavyDays++;
          }
        }
        if (kDebugMode) {
          final distinct = moodCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          debugPrint(
            '📅 [MoodInsights] start=${_ymd(_startOfMonth(widget.selectedMonth))} '
            'end(exclusive)=${_ymd(_startOfNextMonth(widget.selectedMonth))} rows=${rows.length}',
          );
          debugPrint(
            '📅 [MoodInsights] distinct=${distinct.map((e) => '${_displayMood(e.key)}:${e.value}').join(', ')}',
          );
        }

        final int daysLogged = moodByDay.length;
        final sortedMoodCounts = moodCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final dominantMood = sortedMoodCounts.isNotEmpty
            ? _displayMood(sortedMoodCounts.first.key)
            : null;
        final dominantMoodEmoji = sortedMoodCounts.isNotEmpty
            ? _moodEmoji(sortedMoodCounts.first.key)
            : null;
        final currentEntriesCount = rows.where((r) {
          final parsed = r['day'] == null
              ? null
              : DateTime.tryParse(r['day'].toString())?.toLocal();
          return parsed != null &&
              parsed.year == widget.selectedMonth.year &&
              parsed.month == widget.selectedMonth.month;
        }).length;
        final insight = BrainBubbleInsights.mood(
          currentLightDays: currentLightDays,
          currentHeavyDays: currentHeavyDays,
          currentNeutralDays: currentNeutralDays,
          previousLightDays: previousLightDays,
          previousHeavyDays: previousHeavyDays,
          entriesCount: currentEntriesCount,
          dominantMood: dominantMood,
          dominantMoodEmoji: dominantMoodEmoji,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrainBubbleInsightCallout(
              data: insight,
              scheme: scheme,
              accentColor: Colors.orange,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Mood Tracker',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.orange.withOpacity(0.1),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Text(
                    '$daysLogged check-ins',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMoodCalendarGrid(moodByDay, scheme),
            if (sortedMoodCounts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedMoodCounts.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _moodColor(entry.key, scheme),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: scheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      '${_moodEmoji(entry.key)} ${_displayMood(entry.key)}: ${entry.value}',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.orange.withOpacity(0.08),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Text(
                '$daysLogged check-ins this month • noticing what showed up, gently',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoodCalendarGrid(
    Map<int, String> moodByDay,
    ColorScheme scheme,
  ) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final daysInMonth = _daysInMonth(widget.selectedMonth);
    final firstDayOfWeek =
        DateTime(
          widget.selectedMonth.year,
          widget.selectedMonth.month,
          1,
        ).weekday -
        1;

    return Column(
      children: [
        Row(
          children: days
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate((daysInMonth + firstDayOfWeek + 6) ~/ 7, (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: List.generate(7, (dayOfWeek) {
                final dayNumber =
                    (weekIndex * 7) + dayOfWeek - firstDayOfWeek + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }

                final mood = moodByDay[dayNumber] ?? '';
                final moodColor = _moodColor(mood, scheme);
                final moodEmoji = mood.isEmpty ? '-' : _moodEmoji(mood);

                return Expanded(
                  child: Tooltip(
                    message: mood.isEmpty
                        ? 'Day $dayNumber: No entry'
                        : 'Day $dayNumber: ${_displayMood(mood)}',
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: moodColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: scheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(moodEmoji, style: const TextStyle(fontSize: 18)),
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

// MEDITATION INSIGHTS
class MeditationInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const MeditationInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('meditation_logs')
          .select('day, duration_minutes')
          .gte('day', _ymd(_startOfPreviousMonth(selectedMonth)))
          .lt('day', _ymd(_startOfNextMonth(selectedMonth))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];

        final Map<int, double> medMap = {};
        int meditationDays = 0;
        double totalMeditationMins = 0;
        int previousMeditationDays = 0;
        DateTime? calmestDate;

        for (final r in rows) {
          final parsed = DateTime.tryParse(
            (r['day'] ?? '').toString(),
          )?.toLocal();
          if (parsed == null) continue;
          final mins = (r['duration_minutes'] as num?)?.toDouble() ?? 0.0;
          if (parsed.year == selectedMonth.year &&
              parsed.month == selectedMonth.month) {
            final day = _dayInSelectedMonth(r['day'], selectedMonth);
            if (day == null) continue;
            if (mins > 0) {
              meditationDays++;
              totalMeditationMins += mins;
              if (calmestDate == null ||
                  mins > (medMap[calmestDate!.day] ?? -1)) {
                calmestDate = parsed;
              }
            }
            medMap[day] = mins;
          } else if (parsed.year == _startOfPreviousMonth(selectedMonth).year &&
              parsed.month == _startOfPreviousMonth(selectedMonth).month &&
              mins > 0) {
            previousMeditationDays++;
          }
        }
        _debugMonthQuery(
          label: 'MeditationInsights',
          selectedMonth: selectedMonth,
          start: _startOfMonth(selectedMonth),
          endExclusive: _startOfNextMonth(selectedMonth),
          rows: rows,
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: medMap.keys.map(
            (day) =>
                _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
          ),
        );

        final avgMeditationMins = meditationDays > 0
            ? totalMeditationMins / meditationDays
            : 0.0;
        final insight = BrainBubbleInsights.meditation(
          currentDays: meditationDays,
          previousDays: previousMeditationDays,
          totalMinutes: totalMeditationMins,
          calmestDate: calmestDate,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrainBubbleInsightCallout(
              data: insight,
              scheme: scheme,
              accentColor: scheme.primary,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meditation Sessions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.primary.withOpacity(0.1),
                    border: Border.all(color: scheme.primary.withOpacity(0.2)),
                  ),
                  child: Text(
                    '${avgMeditationMins.toStringAsFixed(0)}m',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMeditationCalendarGrid(medMap, scheme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: scheme.primary.withOpacity(0.08),
                border: Border.all(color: scheme.primary.withOpacity(0.2)),
              ),
              child: Text(
                '$meditationDays days of stillness • ${totalMeditationMins.toStringAsFixed(0)} quiet minutes this month',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMeditationCalendarGrid(
    Map<int, double> medMap,
    ColorScheme scheme,
  ) {
    return _buildEmojiCalendarGrid(
      selectedMonth: selectedMonth,
      scheme: scheme,
      iconSize: 18,
      cellForDay: (dayNumber) {
        final mins = medMap[dayNumber] ?? 0.0;

        if (mins <= 0) {
          return _DayCellVisual(
            iconText: '-',
            bgColor: scheme.outline.withOpacity(0.05),
            iconColor: scheme.onSurfaceVariant.withOpacity(0.55),
          );
        }

        final bgColor = mins < 10
            ? scheme.primary.withOpacity(0.15)
            : mins < 20
            ? scheme.primary.withOpacity(0.35)
            : mins < 30
            ? scheme.primary.withOpacity(0.60)
            : scheme.primary.withOpacity(0.85);

        return _DayCellVisual(iconText: '🧘', bgColor: bgColor);
      },
    );
  }
}

// ACTIVITY TRENDS
class GenericActivityTrends extends StatelessWidget {
  final DateTime selectedMonth;
  final int refreshSeed;

  const GenericActivityTrends({
    super.key,
    required this.selectedMonth,
    required this.refreshSeed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final trackers = [
      // {
      // 'title': 'Water Intake',
      // 'unit': 'L',
      // 'table': 'water_logs',
      // 'col': 'amount',
      //},
      {
        'title': 'Study Time',
        'unit': 'hrs',
        'table': 'study_logs',
        'col': 'duration_hours',
      },
      // {
      //  'title': 'Exercise Sessions',
      //  'unit': 'sessions',
      //  'table': 'workout_logs',
      //   'col': 'id',
      //    },
      //  {
      // 'title': 'Social Outings',
      //  'unit': 'times',
      //  'table': 'social_logs',
      // 'col': 'id',
      //  },
      //  {
      //    'title': 'Fasting Duration',
      //     'unit': 'hrs',
      //   'table': 'fast_logs',
      //   'col': 'duration_hours',
      // },
    ];

    return Column(
      children: trackers
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: ActivityTrendItem(
                key: ValueKey(
                  '${t['table']}_${refreshSeed}_${selectedMonth.month}',
                ),
                title: 'Study Time',
                unit: 'hrs',
                table: 'study_logs',
                valueColumn: 'duration_hours',
                selectedMonth: selectedMonth,
                scheme: scheme,
              ),
            ),
          )
          .toList(),
    );
  }
}

class ActivityTrendItem extends StatelessWidget {
  final String title;
  final String unit;
  final String table;
  final String valueColumn;
  final DateTime selectedMonth;
  final ColorScheme scheme;

  const ActivityTrendItem({
    super.key,
    required this.title,
    required this.unit,
    required this.table,
    required this.valueColumn,
    required this.selectedMonth,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from(table)
          .select('day, $valueColumn')
          .gte('day', _ymd(_startOfMonth(selectedMonth)))
          .lt('day', _ymd(_startOfNextMonth(selectedMonth))),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return _buildEmptyState();

        final Map<int, double> dailyValues = {};
        double total = 0;

        for (final r in rows) {
          final day = _dayInSelectedMonth(r['day'], selectedMonth);
          if (day == null) continue;

          if (unit == 'sessions' || unit == 'times') {
            dailyValues[day] = (dailyValues[day] ?? 0) + 1;
            total += 1;
          } else if (unit == 'L') {
            var val = (r[valueColumn] as num?)?.toDouble() ?? 0.0;
            if (val > 100) val = val / 1000;
            dailyValues[day] = (dailyValues[day] ?? 0) + val;
            total += val;
          } else {
            final val = (r[valueColumn] as num?)?.toDouble() ?? 0.0;
            dailyValues[day] = (dailyValues[day] ?? 0) + val;
            total += val;
          }
        }
        _debugMonthQuery(
          label: 'ActivityTrendItem-$table',
          selectedMonth: selectedMonth,
          start: _startOfMonth(selectedMonth),
          endExclusive: _startOfNextMonth(selectedMonth),
          rows: rows,
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: dailyValues.keys.map(
            (day) =>
                _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
          ),
        );

        final daysLogged = dailyValues.length;
        final average = daysLogged > 0 ? total / daysLogged : 0;
        final maxValue = dailyValues.values.isEmpty
            ? 1
            : dailyValues.values.reduce((a, b) => a > b ? a : b);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceContainerLow.withOpacity(0.5),
            border: Border.all(color: scheme.outline.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$daysLogged days logged',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: total.toStringAsFixed(
                                unit == 'sessions' || unit == 'times' ? 0 : 1,
                              ),
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              text: ' $unit',
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _miniCard(
                      scheme,
                      label: 'Average',
                      value: average.toStringAsFixed(
                        unit == 'sessions' || unit == 'times' ? 0 : 1,
                      ),
                      unit: unit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniCard(
                      scheme,
                      label: 'Peak',
                      value: maxValue.toStringAsFixed(
                        unit == 'sessions' || unit == 'times' ? 0 : 1,
                      ),
                      unit: unit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniCard(
                      scheme,
                      label: 'Days Active',
                      value: '$daysLogged',
                      unit: 'days',
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: 160,
                child: _buildWeeklyLineChart(dailyValues, scheme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyLineChart(
    Map<int, double> dailyValues,
    ColorScheme scheme,
  ) {
    // Aggregate into weeks
    final weekTotals = <double>[0, 0, 0, 0];

    dailyValues.forEach((day, value) {
      if (day <= 7) {
        weekTotals[0] += value;
      } else if (day <= 14)
        weekTotals[1] += value;
      else if (day <= 21)
        weekTotals[2] += value;
      else
        weekTotals[3] += value;
    });

    final maxY = weekTotals.reduce((a, b) => a > b ? a : b);
    final spots = List.generate(4, (i) => FlSpot(i.toDouble(), weekTotals[i]));

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 3,
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.2,

        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: scheme.outline.withOpacity(0.12), strokeWidth: 1),
        ),

        borderData: FlBorderData(show: false),

        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1, // ✅ only 0,1,2,3
              getTitlesWidget: (value, meta) {
                // ✅ safety: only draw exact integers
                if (value % 1 != 0) return const SizedBox.shrink();

                final i = value.toInt();
                if (i < 0 || i > 3) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'W${i + 1}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                return LineTooltipItem(
                  'Week ${spot.x.toInt() + 1}\n${spot.y.toStringAsFixed(1)}',
                  TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList();
            },
          ),
        ),

        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: scheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,

            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 5,
                color: scheme.primary,
                strokeWidth: 2,
                strokeColor: scheme.surface,
              ),
            ),

            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCard(
    ColorScheme scheme, {
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surface.withOpacity(0.5),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withOpacity(0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyBars(
    Map<int, double> dailyValues,
    ColorScheme scheme,
  ) {
    final week1 = dailyValues.keys.where((d) => d <= 7).length;
    final week2 = dailyValues.keys.where((d) => d > 7 && d <= 14).length;
    final week3 = dailyValues.keys.where((d) => d > 14 && d <= 21).length;
    final week4 = dailyValues.keys.where((d) => d > 21 && d <= 31).length;

    final weeks = [week1, week2, week3, week4];
    final maxWeek = weeks.reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Consistency',
          style: TextStyle(
            color: scheme.onSurfaceVariant.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) {
            final barHeight = maxWeek > 0 ? (weeks[i] / maxWeek) * 80 : 0.0;
            return Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 80,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: double.infinity,
                            height: barHeight,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  scheme.primary,
                                  scheme.primary.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '${weeks[i]}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'W${i + 1}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.query_stats,
              color: scheme.primary.withOpacity(0.2),
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'No $title logged\nfor this month',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// WORKOUT INSIGHTS
// ======================= WORKOUT INSIGHTS =======================

class WorkoutInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const WorkoutInsights({super.key, required this.selectedMonth});

  static final Map<String, String> exerciseEmojis = {
    'cardio': '🏃',
    'running': '🏃',
    'jogging': '🏃',
    'walking': '🚶',
    'strength': '💪',
    'weightlifting': '💪',
    'weight': '💪',
    'plank': '💪',
    'bench': '💪',
    'squat': '🦵',
    'leg': '🦵',
    'yoga': '🧘',
    'stretching': '🧘',
    'swimming': '🏊',
    'cycling': '🚴',
    'pilates': '🤸',
    'gymnastics': '🤸',
    'hiit': '⚡',
    'boxing': '🥊',
    'martial': '🥋',
    'other': '🏋️',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = _startOfMonth(selectedMonth);
    final previousStart = _startOfPreviousMonth(selectedMonth);
    final endExclusive = _startOfNextMonth(selectedMonth);
    final startDay = _ymd(previousStart);
    final endExclusiveDay = _ymd(endExclusive);

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchWorkoutData(
        startDay: startDay,
        endExclusiveDay: endExclusiveDay,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBox(message: snapshot.error.toString());
        }

        final data = snapshot.data ?? {};
        final rows = (data['workouts'] as List?) ?? [];
        final lastWeight = data['lastWeight'] as String?;

        final Map<int, String> workoutMap = {};
        int previousWorkoutDays = 0;
        DateTime? strongestDay;
        for (final r in rows) {
          final parsed = DateTime.tryParse(
            (r['day'] ?? '').toString(),
          )?.toLocal();
          if (parsed == null) continue;
          final exercise = (r['exercise'] ?? '').toString().toLowerCase();
          if (parsed.year == selectedMonth.year &&
              parsed.month == selectedMonth.month) {
            final day = _dayInSelectedMonth(r['day'], selectedMonth);
            if (day == null) continue;
            workoutMap[day] = exercise;
            strongestDay ??= parsed;
          } else if (parsed.year == previousStart.year &&
              parsed.month == previousStart.month) {
            previousWorkoutDays++;
          }
        }
        _debugMonthQuery(
          label: 'WorkoutInsights',
          selectedMonth: selectedMonth,
          start: start,
          endExclusive: endExclusive,
          rows: List<Map<String, dynamic>>.from(rows),
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: workoutMap.keys.map(
            (day) =>
                _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
          ),
        );

        final int daysLogged = workoutMap.length;
        final insight = BrainBubbleInsights.workout(
          currentDays: daysLogged,
          previousDays: previousWorkoutDays,
          strongestDay: strongestDay,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrainBubbleInsightCallout(
              data: insight,
              scheme: scheme,
              accentColor: scheme.primary,
            ),
            const SizedBox(height: 12),
            _SectionHeaderRow(
              title: 'Workout Calendar',
              subtitle: _monthLabel(selectedMonth),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$daysLogged workouts',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lastWeight != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Last: $lastWeight',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildWorkoutCalendarGrid(workoutMap, scheme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: scheme.primary.withOpacity(0.08),
                border: Border.all(color: scheme.primary.withOpacity(0.2)),
              ),
              child: Text(
                '$daysLogged days with movement • Your routine is taking shape gently',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchWorkoutData({
    required String startDay,
    required String endExclusiveDay,
  }) async {
    try {
      // Fetch all workouts for the month
      final workoutRows = await Supabase.instance.client
          .from('workout_logs')
          .select('day, exercise')
          .gte('day', startDay)
          .lt('day', endExclusiveDay);

      // Fetch the most recent weight log from workout_logs
      final weightRows = await Supabase.instance.client
          .from('workout_logs')
          .select('weight_kg')
          .not(
            'weight_kg',
            'is',
            null,
          ) // Only get rows where weight_kg is NOT null
          .order('created_at', ascending: false)
          .limit(1);

      String? lastWeight;
      if (weightRows.isNotEmpty && weightRows[0]['weight_kg'] != null) {
        final weight = (weightRows[0]['weight_kg'] as num?)?.toDouble();
        if (weight != null) {
          lastWeight = '${weight.toStringAsFixed(1)} kg';
        }
      }

      return {
        'workouts': List<Map<String, dynamic>>.from(workoutRows ?? []),
        'lastWeight': lastWeight,
      };
    } catch (e) {
      debugPrint('Error fetching workout data: $e');
      return {'workouts': [], 'lastWeight': null};
    }
  }

  Widget _buildWorkoutCalendarGrid(
    Map<int, String> workoutMap,
    ColorScheme scheme,
  ) {
    return _buildEmojiCalendarGrid(
      selectedMonth: selectedMonth,
      scheme: scheme,
      cellForDay: (dayNumber) {
        final exercise = workoutMap[dayNumber] ?? '';
        String emoji = '-';
        Color bgColor = scheme.outline.withOpacity(0.05);

        if (exercise.isNotEmpty) {
          emoji = exerciseEmojis.entries
              .firstWhere(
                (e) => exercise.contains(e.key),
                orElse: () => const MapEntry('other', '🏋️'),
              )
              .value;
          bgColor = scheme.primary.withOpacity(0.15);
        }

        return _DayCellVisual(iconText: emoji, bgColor: bgColor);
      },
    );
  }
}

// SOCIAL OUTINGS INSIGHTS
class SocialOutingsInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const SocialOutingsInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final start = _startOfMonth(selectedMonth);
    final previousStart = _startOfPreviousMonth(selectedMonth);
    final endExclusive = _startOfNextMonth(selectedMonth);
    final startDay = _ymd(previousStart);
    final endExclusiveDay = _ymd(endExclusive);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('social_logs')
          .select('day')
          .gte('day', startDay)
          .lt('day', endExclusiveDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBox(message: snapshot.error.toString());
        }

        final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final Map<int, bool> socialMap = {};
        for (final r in rows) {
          final day = _dayInSelectedMonth(r['day'], selectedMonth);
          if (day == null) continue;
          socialMap[day] = true;
        }
        _debugMonthQuery(
          label: 'SocialOutingsInsights',
          selectedMonth: selectedMonth,
          start: start,
          endExclusive: endExclusive,
          rows: rows,
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: socialMap.keys.map(
            (day) =>
                _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
          ),
        );

        final int daysLogged = socialMap.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeaderRow(
              title: 'Social Outings',
              subtitle: _monthLabel(selectedMonth),
              trailing: Text(
                '$daysLogged outings',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSocialCalendarGrid(socialMap, scheme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.purple.withOpacity(0.08),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Text(
                '$daysLogged days with social activities • Stay connected!',
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSocialCalendarGrid(
    Map<int, bool> socialMap,
    ColorScheme scheme,
  ) {
    return _buildEmojiCalendarGrid(
      selectedMonth: selectedMonth,
      scheme: scheme,
      cellForDay: (dayNumber) {
        final hasSocial = socialMap[dayNumber] ?? false;
        final icon = hasSocial ? '👥' : '-';
        final bgColor = hasSocial
            ? Colors.purple.withOpacity(0.2)
            : scheme.outline.withOpacity(0.05);

        return _DayCellVisual(iconText: icon, bgColor: bgColor);
      },
    );
  }
}

// FASTING INSIGHTS
class FastingInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const FastingInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final start = _startOfMonth(selectedMonth);
    final previousStart = _startOfPreviousMonth(selectedMonth);
    final endExclusive = _startOfNextMonth(selectedMonth);
    final startDay = _ymd(previousStart);
    final endExclusiveDay = _ymd(endExclusive);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('fast_logs')
          .select('day, duration_hours')
          .gte('day', startDay)
          .lt('day', endExclusiveDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBox(message: snapshot.error.toString());
        }

        final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final Map<int, double> fastingMap = {};
        double totalHours = 0;
        final previousDays = <int>{};
        double? longestFast;
        for (final r in rows) {
          final parsed = DateTime.tryParse(
            (r['day'] ?? '').toString(),
          )?.toLocal();
          if (parsed == null) continue;
          final hours = (r['duration_hours'] as num?)?.toDouble() ?? 0.0;
          if (parsed.year == selectedMonth.year &&
              parsed.month == selectedMonth.month) {
            final day = _dayInSelectedMonth(r['day'], selectedMonth);
            if (day == null) continue;
            fastingMap[day] = hours;
            totalHours += hours;
            if (hours > 0 && (longestFast == null || hours > longestFast!)) {
              longestFast = hours;
            }
          } else if (parsed.year == previousStart.year &&
              parsed.month == previousStart.month &&
              hours > 0) {
            previousDays.add(parsed.day);
          }
        }
        _debugMonthQuery(
          label: 'FastingInsights',
          selectedMonth: selectedMonth,
          start: start,
          endExclusive: endExclusive,
          rows: rows,
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: fastingMap.keys.map(
            (day) =>
                _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
          ),
        );

        final int daysLogged = fastingMap.length;
        final double avgHours = daysLogged > 0 ? totalHours / daysLogged : 0;
        final insight = BrainBubbleInsights.fasting(
          currentDays: daysLogged,
          previousDays: previousDays.length,
          longestFastHours: longestFast,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrainBubbleInsightCallout(
              data: insight,
              scheme: scheme,
              accentColor: Colors.blue,
            ),
            const SizedBox(height: 12),
            _SectionHeaderRow(
              title: 'Fasting Tracker',
              subtitle: _monthLabel(selectedMonth),
              trailing: Text(
                '${avgHours.toStringAsFixed(1)} hrs avg',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildFastingCalendarGrid(fastingMap, scheme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.blue.withOpacity(0.08),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Text(
                '$daysLogged steady days • ${totalHours.toStringAsFixed(0)} hours in all',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFastingCalendarGrid(
    Map<int, double> fastingMap,
    ColorScheme scheme,
  ) {
    return _buildEmojiCalendarGrid(
      selectedMonth: selectedMonth,
      scheme: scheme,
      cellForDay: (dayNumber) {
        final hours = fastingMap[dayNumber] ?? 0.0;
        String icon = '-';
        Color bgColor = scheme.outline.withOpacity(0.05);

        if (hours > 0) {
          icon = '⏱️';
          if (hours <= 12) {
            bgColor = Colors.blue.withOpacity(0.25);
          } else if (hours <= 16) {
            bgColor = Colors.blue.withOpacity(0.5);
          } else {
            bgColor = Colors.blue.withOpacity(0.8);
          }
        }

        return _DayCellVisual(iconText: icon, bgColor: bgColor);
      },
    );
  }
}

// UI COMPONENTS
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withOpacity(0.25)),
      ),
      child: Text(
        message,
        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SectionHeaderRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  _LegendItem({required this.label, required this.color});
}

class _Legend extends StatelessWidget {
  final List<_LegendItem> items;
  const _Legend({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((it) {
        return Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: it.color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: scheme.outline.withOpacity(0.2)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                it.label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MiniSummaryItem {
  final String label;
  final String value;
  _MiniSummaryItem({required this.label, required this.value});
}

class _MiniSummaryRow extends StatelessWidget {
  final List<_MiniSummaryItem> items;
  const _MiniSummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: items.map((it) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: it == items.last ? 0 : 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: scheme.surfaceContainerHighest.withOpacity(0.28),
              border: Border.all(color: scheme.outline.withOpacity(0.16)),
            ),
            child: Column(
              children: [
                Text(
                  it.label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withOpacity(0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  it.value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme scheme;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.scheme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        border: Border.all(color: scheme.outline.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: scheme.primary.withOpacity(0.10),
              border: Border.all(color: scheme.primary.withOpacity(0.18)),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ======================= WATER INSIGHTS =======================

class WaterInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const WaterInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final start = _startOfMonth(selectedMonth);
    final previousStart = _startOfPreviousMonth(selectedMonth);
    final endExclusive = _startOfNextMonth(selectedMonth);
    final startDay = _ymd(previousStart);
    final endExclusiveDay = _ymd(endExclusive);

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchWaterData(
        selectedMonth: selectedMonth,
        startDay: startDay,
        endExclusiveDay: endExclusiveDay,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBox(message: snapshot.error.toString());
        }

        final data = snapshot.data ?? {};
        final dailyWater =
            (data['daily'] as Map<int, double>?) ?? <int, double>{};
        final dailyGoalStatus =
            (data['goalStatus'] as Map<int, bool>?) ?? <int, bool>{};
        final goalsReached = (data['goalsReached'] as int?) ?? 0;
        final previousGoalsReached =
            (data['previousGoalsReached'] as int?) ?? 0;
        final totalLiters = (data['totalLiters'] as double?) ?? 0.0;
        final strongestDay = data['strongestDay'] as DateTime?;

        final daysLogged = dailyWater.length;
        final avgDaily = daysLogged > 0 ? totalLiters / daysLogged : 0.0;
        final maxDay = dailyWater.values.isEmpty
            ? 1.0
            : dailyWater.values.reduce((a, b) => a > b ? a : b);
        final insight = BrainBubbleInsights.water(
          currentGoalDays: goalsReached,
          previousGoalDays: previousGoalsReached,
          daysLogged: daysLogged,
          strongestDay: strongestDay,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final chartSectionHeight = math
                .min(220.0, math.min(width * 0.48, screenHeight * 0.35))
                .clamp(132.0, 220.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrainBubbleInsightCallout(
                  data: insight,
                  scheme: scheme,
                  accentColor: Colors.blue.shade400,
                ),
                const SizedBox(height: 12),
                _SectionHeaderRow(
                  title: 'Water Intake',
                  subtitle: _monthLabel(selectedMonth),
                  trailing: Text(
                    '${totalLiters.toStringAsFixed(1)}L',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Goal Days',
                        value: '$goalsReached',
                        icon: Icons.local_drink,
                        scheme: scheme,
                        valueColor: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Daily Average',
                        value: '${avgDaily.toStringAsFixed(1)}L',
                        icon: Icons.trending_up,
                        scheme: scheme,
                        valueColor: Colors.blue.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: chartSectionHeight,
                  child: _buildWaterChart(
                    dailyWater,
                    dailyGoalStatus,
                    maxDay,
                    scheme,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.withOpacity(0.08),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hydration Rhythm',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant.withOpacity(
                                    0.7,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                daysLogged > 0
                                    ? '${((goalsReached / daysLogged) * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Days Logged',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant.withOpacity(
                                    0.7,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$daysLogged',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Total Intake',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant.withOpacity(
                                    0.7,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${totalLiters.toStringAsFixed(1)}L',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: bottomInset + 16),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchWaterData({
    required DateTime selectedMonth,
    required String startDay,
    required String endExclusiveDay,
  }) async {
    try {
      final rows = await Supabase.instance.client
          .from('water_logs')
          .select('day, amount, unit, goal_reached')
          .gte('day', startDay)
          .lt('day', endExclusiveDay)
          .order('day', ascending: true);

      final Map<int, double> dailyWater = {};
      final Map<int, bool> dailyGoalStatus = {};
      double totalLiters = 0.0;
      int goalsReached = 0;
      int previousGoalsReached = 0;
      DateTime? strongestDay;
      double strongestLiters = -1;

      for (final row in rows) {
        final parsed = DateTime.tryParse(
          (row['day'] ?? '').toString(),
        )?.toLocal();
        if (parsed == null) continue;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final unit = (row['unit'] as String?)?.toLowerCase() ?? 'ml';
        final goalReached = (row['goal_reached'] as bool?) ?? false;

        final liters = _convertToLiters(amount, unit);
        if (parsed.year == selectedMonth.year &&
            parsed.month == selectedMonth.month) {
          final day = _dayInSelectedMonth(row['day'], selectedMonth);
          if (day == null) continue;
          dailyWater[day] = (dailyWater[day] ?? 0.0) + liters;
          totalLiters += liters;
          if (dailyWater[day]! > strongestLiters) {
            strongestLiters = dailyWater[day]!;
            strongestDay = parsed;
          }
          if (goalReached) {
            dailyGoalStatus[day] = true;
            goalsReached++;
          }
        } else if (parsed.year == _startOfPreviousMonth(selectedMonth).year &&
            parsed.month == _startOfPreviousMonth(selectedMonth).month &&
            goalReached) {
          previousGoalsReached++;
        }
      }
      _debugMonthQuery(
        label: 'WaterInsights',
        selectedMonth: selectedMonth,
        start: _startOfMonth(selectedMonth),
        endExclusive: _startOfNextMonth(selectedMonth),
        rows: List<Map<String, dynamic>>.from(rows),
        rawTimestamp: (row) => row['day'],
        groupedDayKeys: dailyWater.keys.map(
          (day) => _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
        ),
      );
      if (kDebugMode) {
        debugPrint(
          '📅 [WaterInsights] totals rows=${rows.length} daysLogged=${dailyWater.length} '
          'totalLiters=${totalLiters.toStringAsFixed(2)} goalsReached=$goalsReached',
        );
      }

      return {
        'daily': dailyWater,
        'goalStatus': dailyGoalStatus,
        'totalLiters': totalLiters,
        'goalsReached': goalsReached,
        'previousGoalsReached': previousGoalsReached,
        'strongestDay': strongestDay,
      };
    } catch (e) {
      debugPrint('Error fetching water data: $e');
      return {
        'daily': <int, double>{},
        'goalStatus': <int, bool>{},
        'totalLiters': 0.0,
        'goalsReached': 0,
        'previousGoalsReached': 0,
        'strongestDay': null,
      };
    }
  }

  static double _convertToLiters(double amount, String unit) {
    switch (unit.toLowerCase().trim()) {
      case 'l':
      case 'liters':
      case 'litres':
        return amount;
      case 'ml':
      case 'milliliters':
      case 'millilitres':
        return amount / 1000;
      case 'oz':
      case 'ounces':
        return amount * 0.0295735;
      case 'cup':
      case 'cups':
        return amount * 0.236588;
      case 'pint':
      case 'pints':
        return amount * 0.473176;
      case 'gallon':
      case 'gallons':
        return amount * 3.78541;
      case 'glass':
      case 'glasses':
        return amount * 0.25;
      default:
        return amount / 1000;
    }
  }

  Widget _buildWaterChart(
    Map<int, double> dailyWater,
    Map<int, bool> dailyGoalStatus,
    double maxDay,
    ColorScheme scheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final daysInMonth = _daysInMonth(selectedMonth);
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 220.0;
        final footerHeight = availableHeight < 170 ? 20.0 : 28.0;
        final verticalGap = availableHeight < 170 ? 4.0 : 8.0;
        final minChartHeight = availableHeight < 170 ? 84.0 : 120.0;
        final chartHeight = (availableHeight - footerHeight - verticalGap)
            .clamp(minChartHeight, 260.0);
        final barTrackHeight = (chartHeight - 30).clamp(84.0, 220.0);
        final leftFontSize = chartHeight < 150 ? 8.0 : 9.0;
        final dayFontSize = chartHeight < 150 ? 7.0 : 8.0;
        final axisWidth = chartHeight < 150 ? 30.0 : 36.0;
        final scaledMax = (maxDay * 1.2).ceilToDouble().clamp(1.0, 20.0);
        final interval = scaledMax <= 2
            ? 0.5
            : scaledMax <= 4
            ? 1.0
            : scaledMax <= 10
            ? 2.0
            : 5.0;
        final yTicks = <double>[];
        for (double tick = scaledMax; tick >= 0; tick -= interval) {
          yTicks.add(double.parse(tick.toStringAsFixed(2)));
        }
        if (yTicks.isEmpty || yTicks.last != 0) {
          yTicks.add(0);
        }

        return Column(
          children: [
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: axisWidth,
                    height: chartHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: yTicks
                          .map(
                            (tick) => Text(
                              '${tick.toStringAsFixed(tick % 1 == 0 ? 0 : 1)}L',
                              style: TextStyle(
                                fontSize: leftFontSize,
                                color: scheme.onSurfaceVariant.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(daysInMonth, (index) {
                        final day = index + 1;
                        final liters = dailyWater[day] ?? 0.0;
                        final percentage = scaledMax > 0
                            ? (liters / scaledMax)
                            : 0.0;
                        final barHeight = (percentage * barTrackHeight).clamp(
                          0.0,
                          barTrackHeight,
                        );
                        final reachedGoal = dailyGoalStatus[day] ?? false;

                        return Expanded(
                          child: Tooltip(
                            message:
                                '$day: ${liters.toStringAsFixed(1)}L${reachedGoal ? ' ✓ Goal' : ''}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        Container(
                                          height: barHeight,
                                          width: double.infinity,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(4),
                                                ),
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.blue.shade600,
                                                Colors.blue.shade400,
                                              ],
                                            ),
                                            border: Border.all(
                                              color: reachedGoal
                                                  ? Colors.green.shade600
                                                  : Colors.blue.withOpacity(
                                                      0.3,
                                                    ),
                                              width: reachedGoal ? 2 : 0,
                                            ),
                                          ),
                                        ),
                                        if (reachedGoal)
                                          Positioned(
                                            top: -8,
                                            child: Text(
                                              '✓',
                                              style: TextStyle(
                                                color: Colors.green.shade600,
                                                fontSize: dayFontSize + 2,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  day == 1 ||
                                          day == 15 ||
                                          day == _daysInMonth(selectedMonth)
                                      ? '$day'
                                      : '',
                                  style: TextStyle(
                                    fontSize: dayFontSize,
                                    color: scheme.onSurfaceVariant.withOpacity(
                                      0.5,
                                    ),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: verticalGap),
            SizedBox(
              height: footerHeight,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  'Days',
                  style: TextStyle(
                    fontSize: leftFontSize + 1,
                    color: scheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ActivityTrendLineChart extends StatelessWidget {
  final String title;
  final String unit;
  final String table;
  final String valueColumn;
  final DateTime selectedMonth;
  final ColorScheme scheme;

  const ActivityTrendLineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.table,
    required this.valueColumn,
    required this.selectedMonth,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from(table)
          .select('day, $valueColumn')
          .gte('day', _ymd(_startOfMonth(selectedMonth)))
          .lt('day', _ymd(_startOfNextMonth(selectedMonth))),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return _buildEmptyState();

        final Map<int, double> dailyValues = {};
        double total = 0;

        for (final r in rows) {
          final day = _dayInSelectedMonth(r['day'], selectedMonth);
          if (day == null) continue;
          final val = (r[valueColumn] as num?)?.toDouble() ?? 0.0;
          dailyValues[day] = (dailyValues[day] ?? 0) + val;
          total += val;
        }
        _debugMonthQuery(
          label: 'ActivityTrendLineChart-$table',
          selectedMonth: selectedMonth,
          start: _startOfMonth(selectedMonth),
          endExclusive: _startOfNextMonth(selectedMonth),
          rows: rows,
          rawTimestamp: (row) => row['day'],
          groupedDayKeys: dailyValues.keys.map(
            (day) =>
                _ymd(DateTime(selectedMonth.year, selectedMonth.month, day)),
          ),
        );

        final daysLogged = dailyValues.length;
        final average = daysLogged > 0 ? total / daysLogged : 0;
        final maxValue = dailyValues.values.isEmpty
            ? 1
            : dailyValues.values.reduce((a, b) => a > b ? a : b);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceContainerLow.withOpacity(0.5),
            border: Border.all(color: scheme.outline.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$daysLogged days logged',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: total.toStringAsFixed(1),
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              text: ' $unit',
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: _buildLineChart(
                  dailyValues,
                  maxValue.toDouble(),
                  scheme,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _miniStatCard(
                      scheme,
                      'Average',
                      '${average.toStringAsFixed(1)}$unit',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniStatCard(
                      scheme,
                      'Peak',
                      '${maxValue.toStringAsFixed(1)}$unit',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniStatCard(scheme, 'Days Active', '$daysLogged'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineChart(
    Map<int, double> dailyValues,
    double maxValue,
    ColorScheme scheme,
  ) {
    final daysInMonth = _daysInMonth(selectedMonth);
    final scaledMax = (maxValue * 1.2).ceilToDouble();

    return CustomPaint(
      painter: LineChartPainter(
        dailyValues: dailyValues,
        daysInMonth: daysInMonth,
        maxValue: scaledMax,
        scheme: scheme,
      ),
      size: Size.infinite,
    );
  }

  Widget _miniStatCard(ColorScheme scheme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surface.withOpacity(0.5),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.query_stats,
              color: scheme.primary.withOpacity(0.2),
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'No $title logged',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final Map<int, double> dailyValues;
  final int daysInMonth;
  final double maxValue;
  final ColorScheme scheme;

  LineChartPainter({
    required this.dailyValues,
    required this.daysInMonth,
    required this.maxValue,
    required this.scheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade500
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = scheme.outline.withOpacity(0.1)
      ..strokeWidth = 0.5;

    final width = size.width / daysInMonth;
    final height = size.height;

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final y = height - (height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build path
    final path = Path();
    bool firstPoint = true;

    for (int day = 1; day <= daysInMonth; day++) {
      final value = dailyValues[day] ?? 0.0;
      final x = (day - 1) * width + width / 2;
      final y = height - (value / maxValue) * height;

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw filled area
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    for (int day = 1; day <= daysInMonth; day++) {
      final value = dailyValues[day] ?? 0.0;
      if (value > 0) {
        final x = (day - 1) * width + width / 2;
        final y = height - (value / maxValue) * height;
        canvas.drawCircle(
          Offset(x, y),
          3,
          Paint()..color = Colors.blue.shade600,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) => false;
}
