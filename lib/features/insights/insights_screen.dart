// lib/features/insights/insights_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sleep_insights.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final ScrollController _mainScrollController = ScrollController();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _refreshSeed = 0;
  bool _loading = false;
  String? _error;

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _prevMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          Column(
            children: [
              Text(
                '${_monthName(_month.month)} ${_month.year}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Monthly Report',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          IconButton(
            onPressed: _nextMonth,
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
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
                  controller: _mainScrollController,
                  scheme: scheme,
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
                        Container(
                          key: _sectionKeys['Habits'],
                          child: _sectionTitle(
                            'Habit Tracker',
                            Icons.check_circle_outline,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: HabitStepLineChartContainer(
                            selectedMonth: _month,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Sleep'],
                          child: _sectionTitle(
                            'Sleep Insights',
                            Icons.bedtime_outlined,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: const SleepInsightsContainer(),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Mood'],
                          child: _sectionTitle(
                            'Mood Tracker',
                            Icons.sentiment_satisfied,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: MoodInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Meditation'],
                          child: _sectionTitle(
                            'Meditation',
                            Icons.spa_outlined,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: MeditationInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Finance'],
                          child: _sectionTitle(
                            'Finance Insights',
                            Icons.payments_outlined,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: FinanceInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Cycle'],
                          child: _sectionTitle(
                            'Cycle Insights',
                            Icons.water_drop_outlined,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: CycleInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Workout'],
                          child: _sectionTitle(
                            'Workout Calendar',
                            Icons.fitness_center,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: WorkoutInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Social'],
                          child: _sectionTitle('Social Outings', Icons.people),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: SocialOutingsInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          key: _sectionKeys['Fasting'],
                          child: _sectionTitle(
                            'Fasting Tracker',
                            Icons.access_time,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: FastingInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),

                        Container(
                          key: _sectionKeys['Water'],
                          child: _sectionTitle(
                            'Water Intake',
                            Icons.local_drink,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: WaterInsights(selectedMonth: _month),
                        ),
                        const SizedBox(height: 32),

                        Container(
                          key: _sectionKeys['Activities'],
                          child: _sectionTitle(
                            'Activity Trends',
                            Icons.auto_graph,
                          ),
                        ),
                        _GlowingCard(
                          scheme: scheme,
                          child: GenericActivityTrends(
                            selectedMonth: _month,
                            refreshSeed: _refreshSeed,
                          ),
                        ),
                        const SizedBox(height: 100),

                        // const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// CATEGORY NAVIGATOR
Widget _buildCategoryNavigator({
  required ScrollController controller,
  required ColorScheme scheme,
  required Map<String, GlobalKey> sectionKeys,
}) {
  const categories = [
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

  return SizedBox(
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

// SHARED HELPERS
DateTime _startOfMonth(DateTime month) => DateTime(month.year, month.month, 1);

DateTime _endOfMonthInclusive(DateTime month) {
  final startNext = DateTime(month.year, month.month + 1, 1);
  return startNext.subtract(const Duration(days: 1));
}

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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      v.buildIcon(iconSize, scheme.onSurface),
                      const SizedBox(height: 2),
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

    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client
          .from('user_habits')
          .select('created_at')
          .eq('is_active', true)
          .gte('created_at', _startOfMonth(selectedMonth).toIso8601String())
          .lte(
            'created_at',
            _endOfMonthInclusive(selectedMonth).toIso8601String(),
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

        final rows = (snapshot.data ?? const <dynamic>[])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final Map<int, int> counts = {};
        for (final r in rows) {
          final raw = r['created_at'];
          final parsed = raw is DateTime
              ? raw
              : DateTime.tryParse(raw.toString());
          if (parsed == null) continue;
          final day = parsed.day;
          counts[day] = (counts[day] ?? 0) + 1;
        }

        final days = _daysInMonth(selectedMonth);
        final daysWithHabits = counts.isEmpty ? 0 : counts.length;
        final totalHabits = rows.length;
        final avgPerDay = daysWithHabits > 0
            ? (totalHabits / daysWithHabits).toStringAsFixed(1)
            : '0';

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Habits Tracked',
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
                  Column(
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
    final end = _endOfMonthInclusive(selectedMonth);
    final startDate = _ymd(start);
    final endDate = _ymd(end);

    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _fetchAllFinanceData(startDate, endDate),
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

        for (final r in incomeRows) {
          final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
          final dayKey = _parseDayKey(r['day']);
          if (dayKey != null && byDay.containsKey(dayKey)) {
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
          if (dayKey != null && byDay.containsKey(dayKey)) {
            byDay[dayKey]!.expenses += amount;
            totalExpenses += amount;
          }
        }

        for (final r in billRows) {
          final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
          final dayKey = _parseDayKey(r['day']);
          if (dayKey != null && byDay.containsKey(dayKey)) {
            byDay[dayKey]!.expenses += amount;
            totalExpenses += amount;
          }
        }

        final chartData = byDay.values.toList()
          ..sort((a, b) => a.period.compareTo(b.period));
        final burnRate = totalIncome > 0
            ? (totalExpenses / totalIncome) * 100
            : 0.0;
        final netSavings = totalIncome - totalExpenses;

        if (totalIncome == 0 && totalExpenses == 0) {
          return const _ErrorBox(
            message: 'No finance data found for this month',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeaderRow(
              title: 'Income vs Expenses',
              subtitle: _monthLabel(selectedMonth),
              trailing: _Legend(
                items: [
                  _LegendItem(label: 'Income', color: scheme.primary),
                  _LegendItem(label: 'Expenses', color: scheme.error),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: FinanceComparisonLineChart(
                data: chartData,
                scheme: scheme,
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
                    label: 'Burn Rate',
                    value: '${burnRate.toStringAsFixed(0)}%',
                    icon: Icons.local_fire_department,
                    scheme: scheme,
                    valueColor: burnRate > 100 ? scheme.error : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Net Savings',
                    value: _currency(netSavings),
                    icon: Icons.account_balance_wallet,
                    scheme: scheme,
                    valueColor: netSavings < 0
                        ? scheme.error
                        : scheme.onSurface,
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
    String endDate,
  ) async {
    final results = await Future.wait([
      Supabase.instance.client
          .from('income_logs')
          .select('day, amount')
          .gte('day', startDate)
          .lte('day', endDate)
          .catchError((_) => []),
      Supabase.instance.client
          .from('expense_logs')
          .select('day, cost')
          .gte('day', startDate)
          .lte('day', endDate)
          .catchError((_) => []),
      Supabase.instance.client
          .from('bill_logs')
          .select('day, amount')
          .gte('day', startDate)
          .lte('day', endDate)
          .catchError((_) => []),
    ], eagerError: false);

    return {
      'income': List<Map<String, dynamic>>.from(results[0] as List? ?? []),
      'expenses': List<Map<String, dynamic>>.from(results[1] as List? ?? []),
      'bills': List<Map<String, dynamic>>.from(results[2] as List? ?? []),
    };
  }

  String? _parseDayKey(dynamic rawDay) {
    if (rawDay is DateTime) return _ymd(rawDay);
    if (rawDay is String) {
      final parsed = DateTime.tryParse(rawDay);
      return parsed != null ? _ymd(parsed) : rawDay.split('T').first;
    }
    return null;
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
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
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
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
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

// CYCLE INSIGHTS
class CycleInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const CycleInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final start = _startOfMonth(selectedMonth);
    final end = _endOfMonthInclusive(selectedMonth);
    final startIso = start.toIso8601String();
    final endIso = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
    ).toIso8601String();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('menstrual_logs')
          .select('day, flow')
          .gte('day', startIso)
          .lte('day', endIso),
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

        final Map<int, String> cycleMap = {};
        for (final r in rows) {
          final day = DateTime.parse(r['day'].toString()).day;
          final rawFlow = (r['flow'] ?? '').toString().toLowerCase().trim();

          if (rawFlow.contains('heavy')) {
            cycleMap[day] = 'heavy';
          } else if (rawFlow.contains('medium')) {
            cycleMap[day] = 'medium';
          } else if (rawFlow.contains('light')) {
            cycleMap[day] = 'light';
          }
        }

        int light = 0, medium = 0, heavy = 0;
        for (final v in cycleMap.values) {
          if (v == 'light') light++;
          if (v == 'medium') medium++;
          if (v == 'heavy') heavy++;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              ],
            ),
          ],
        );
      },
    );
  }
}

// MOOD INSIGHTS
class MoodInsights extends StatelessWidget {
  final DateTime selectedMonth;
  const MoodInsights({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('mood_logs')
          .select('day, intensity')
          .gte('day', _ymd(_startOfMonth(selectedMonth)))
          .lte('day', _ymd(_endOfMonthInclusive(selectedMonth))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];

        final Map<int, double> moodMap = {};
        for (final r in rows) {
          final day = DateTime.parse(r['day'].toString()).day;
          moodMap[day] = (r['intensity'] as num?)?.toDouble() ?? 0.0;
        }

        final double avgMood = moodMap.isNotEmpty
            ? moodMap.values.reduce((a, b) => a + b) / moodMap.length
            : 0.0;
        final int daysLogged = moodMap.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    '${avgMood.toStringAsFixed(1)}/10',
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
            _buildMoodCalendarGrid(moodMap, scheme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.orange.withOpacity(0.08),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Text(
                '$daysLogged days logged • Average: ${avgMood.toStringAsFixed(1)}/10',
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

  Widget _buildMoodCalendarGrid(Map<int, double> moodMap, ColorScheme scheme) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final daysInMonth = _daysInMonth(selectedMonth);
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

                final mood = moodMap[dayNumber] ?? 0.0;
                String moodLabel = '😐';
                Color moodColor = scheme.outline.withOpacity(0.1);

                if (mood == 0) {
                  moodLabel = '-';
                  moodColor = scheme.outline.withOpacity(0.05);
                } else if (mood <= 1.5) {
                  moodLabel = '😢';
                  moodColor = Colors.red.withOpacity(0.2);
                } else if (mood <= 2.5) {
                  moodLabel = '😕';
                  moodColor = Colors.orange.withOpacity(0.2);
                } else if (mood <= 3.5) {
                  moodLabel = '😐';
                  moodColor = Colors.yellow.withOpacity(0.2);
                } else if (mood <= 4.5) {
                  moodLabel = '🙂';
                  moodColor = Colors.lightGreen.withOpacity(0.2);
                } else {
                  moodLabel = '😄';
                  moodColor = Colors.green.withOpacity(0.2);
                }

                return Expanded(
                  child: Tooltip(
                    message: mood == 0
                        ? 'Day $dayNumber: No entry'
                        : 'Day $dayNumber: ${mood.toStringAsFixed(1)}/5',
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
                          Text(moodLabel, style: const TextStyle(fontSize: 18)),
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
          .gte('day', _ymd(_startOfMonth(selectedMonth)))
          .lte('day', _ymd(_endOfMonthInclusive(selectedMonth))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];

        final Map<int, double> medMap = {};
        int meditationDays = 0;
        double totalMeditationMins = 0;

        for (final r in rows) {
          final day = DateTime.parse(r['day'].toString()).day;
          final mins = (r['duration_minutes'] as num?)?.toDouble() ?? 0.0;
          if (mins > 0) {
            meditationDays++;
            totalMeditationMins += mins;
          }
          medMap[day] = mins;
        }

        final avgMeditationMins = meditationDays > 0
            ? totalMeditationMins / meditationDays
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                '$meditationDays days • Total: ${totalMeditationMins.toStringAsFixed(0)}m • Average: ${avgMeditationMins.toStringAsFixed(0)}m/day',
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
          .gte('day', _startOfMonth(selectedMonth).toIso8601String())
          .lte('day', _endOfMonthInclusive(selectedMonth).toIso8601String()),
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
          final day = DateTime.parse(r['day'].toString()).day;

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
      if (day <= 7)
        weekTotals[0] += value;
      else if (day <= 14)
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
    'bike': '🚴',
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
    final end = _endOfMonthInclusive(selectedMonth);
    final startIso = start.toIso8601String();
    final endIso = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
    ).toIso8601String();

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchWorkoutData(startIso, endIso),
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
        for (final r in rows) {
          final day = DateTime.parse(r['day'].toString()).day;
          final exercise = (r['exercise'] ?? '').toString().toLowerCase();
          workoutMap[day] = exercise;
        }

        final int daysLogged = workoutMap.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                '$daysLogged days with workouts • Keep pushing!',
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

  Future<Map<String, dynamic>> _fetchWorkoutData(
    String startIso,
    String endIso,
  ) async {
    try {
      // Fetch all workouts for the month
      final workoutRows = await Supabase.instance.client
          .from('workout_logs')
          .select('day, exercise')
          .gte('day', startIso)
          .lte('day', endIso);

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
    final end = _endOfMonthInclusive(selectedMonth);
    final startIso = start.toIso8601String();
    final endIso = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
    ).toIso8601String();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('social_logs')
          .select('day')
          .gte('day', startIso)
          .lte('day', endIso),
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
          final day = DateTime.parse(r['day'].toString()).day;
          socialMap[day] = true;
        }

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
                style: TextStyle(
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
    final end = _endOfMonthInclusive(selectedMonth);
    final startIso = start.toIso8601String();
    final endIso = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
    ).toIso8601String();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('fast_logs')
          .select('day, duration_hours')
          .gte('day', startIso)
          .lte('day', endIso),
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
        for (final r in rows) {
          final day = DateTime.parse(r['day'].toString()).day;
          final hours = (r['duration_hours'] as num?)?.toDouble() ?? 0.0;
          fastingMap[day] = hours;
          totalHours += hours;
        }

        final int daysLogged = fastingMap.length;
        final double avgHours = daysLogged > 0 ? totalHours / daysLogged : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                '$daysLogged days fasted • Total: ${totalHours.toStringAsFixed(0)} hrs',
                style: TextStyle(
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
    final start = _startOfMonth(selectedMonth);
    final end = _endOfMonthInclusive(selectedMonth);
    final startIso = start.toIso8601String();
    final endIso = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
    ).toIso8601String();

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchWaterData(startIso, endIso),
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
        final dailyWater = (data['daily'] as Map<int, double>) ?? {};
        final dailyGoalStatus = (data['goalStatus'] as Map<int, bool>) ?? {};
        final goalsReached = (data['goalsReached'] as int) ?? 0;
        final totalLiters = (data['totalLiters'] as double) ?? 0.0;

        final daysLogged = dailyWater.length;
        final avgDaily = daysLogged > 0 ? totalLiters / daysLogged : 0.0;
        final maxDay = dailyWater.values.isEmpty
            ? 1.0
            : dailyWater.values.reduce((a, b) => a > b ? a : b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    label: 'Days Goal Reached',
                    value: '$goalsReached',
                    icon: Icons.local_drink,
                    scheme: scheme,
                    valueColor: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _buildWaterChart(
                dailyWater,
                dailyGoalStatus,
                maxDay,
                scheme,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.blue.withOpacity(0.08),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Success Rate',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        daysLogged > 0
                            ? '${((goalsReached / daysLogged) * 100).toStringAsFixed(0)}%'
                            : '0%',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Days Logged',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$daysLogged',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Intake',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${totalLiters.toStringAsFixed(1)}L',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchWaterData(
    String startIso,
    String endIso,
  ) async {
    try {
      final rows = await Supabase.instance.client
          .from('water_logs')
          .select('day, amount, unit, goal_reached')
          .gte('day', startIso)
          .lte('day', endIso)
          .order('day', ascending: true);

      final Map<int, double> dailyWater = {};
      final Map<int, bool> dailyGoalStatus = {};
      double totalLiters = 0.0;
      int goalsReached = 0;

      for (final row in rows) {
        final day = DateTime.parse(row['day'].toString()).day;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final unit = (row['unit'] as String?)?.toLowerCase() ?? 'ml';
        final goalReached = (row['goal_reached'] as bool?) ?? false;

        final liters = _convertToLiters(amount, unit);

        dailyWater[day] = (dailyWater[day] ?? 0.0) + liters;
        totalLiters += liters;

        if (goalReached) {
          dailyGoalStatus[day] = true;
          goalsReached++;
        }
      }

      return {
        'daily': dailyWater,
        'goalStatus': dailyGoalStatus,
        'totalLiters': totalLiters,
        'goalsReached': goalsReached,
      };
    } catch (e) {
      debugPrint('Error fetching water data: $e');
      return {
        'daily': <int, double>{},
        'goalStatus': <int, bool>{},
        'totalLiters': 0.0,
        'goalsReached': 0,
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
    final daysInMonth = _daysInMonth(selectedMonth);
    final scaledMax = (maxDay * 1.2).ceilToDouble();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(daysInMonth, (index) {
            final day = index + 1;
            final liters = dailyWater[day] ?? 0.0;
            final percentage = scaledMax > 0 ? (liters / scaledMax) : 0.0;
            final height = percentage * 180;
            final reachedGoal = dailyGoalStatus[day] ?? false;

            return Expanded(
              child: Tooltip(
                message:
                    '$day: ${liters.toStringAsFixed(1)}L${reachedGoal ? ' ✓ Goal' : ''}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (reachedGoal)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '✓',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Container(
                      height: height.toDouble(),
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.blue.shade600, Colors.blue.shade400],
                        ),
                        border: Border.all(
                          color: reachedGoal
                              ? Colors.green.shade600
                              : Colors.blue.withOpacity(0.3),
                          width: reachedGoal ? 2 : 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      day == 1 ||
                              day == 15 ||
                              day == _daysInMonth(selectedMonth)
                          ? '$day'
                          : '',

                      style: TextStyle(
                        fontSize: 8,
                        color: scheme.onSurfaceVariant.withOpacity(0.5),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: Text(
            'Days',
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        ),
      ],
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
          .gte('day', _startOfMonth(selectedMonth).toIso8601String())
          .lte('day', _endOfMonthInclusive(selectedMonth).toIso8601String()),
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
          final day = DateTime.parse(r['day'].toString()).day;
          final val = (r[valueColumn] as num?)?.toDouble() ?? 0.0;
          dailyValues[day] = (dailyValues[day] ?? 0) + val;
          total += val;
        }

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
