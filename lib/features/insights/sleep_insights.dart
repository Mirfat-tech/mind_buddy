import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

// ============================================================================
// DATA MODEL
// ============================================================================

/// Aggregates sleep data for a single day
class SleepDayAgg {
  SleepDayAgg({required this.day});

  final String day; // Expected format: "YYYY-MM-DD"
  int entriesCount = 0;
  double hoursTotal = 0;

  void add(double hours) {
    entriesCount += 1;
    hoursTotal += hours;
  }

  double get averageHours => entriesCount > 0 ? hoursTotal / entriesCount : 0;
}

// ============================================================================
// MAIN CONTAINER (Swipeable Month View)
// ============================================================================

/// Top-level widget wrapping the swipeable month-based sleep insights.
/// Use this wherever you want the full sleep insights experience.
class SleepInsightsContainer extends StatefulWidget {
  const SleepInsightsContainer({super.key});

  @override
  State<SleepInsightsContainer> createState() => _SleepInsightsContainerState();
}

class _SleepInsightsContainerState extends State<SleepInsightsContainer> {
  late final PageController _pageController;
  DateTime _focusedMonth = DateTime.now();
  static const int _initialPage = 1200; // Buffer for back/forward swipes

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Month Selector Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: scheme.onSurface),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
              Text(
                "${_monthName(_focusedMonth.month)} ${_focusedMonth.year}",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: scheme.onSurface),
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ],
          ),
        ),
        // Swipeable Month Area
        SizedBox(
          height: 690,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                final monthOffset = index - _initialPage;
                _focusedMonth = DateTime(
                  DateTime.now().year,
                  DateTime.now().month + monthOffset,
                  1,
                );
              });
            },
            itemBuilder: (context, index) {
              final monthOffset = index - _initialPage;
              final selectedMonth = DateTime(
                DateTime.now().year,
                DateTime.now().month + monthOffset,
                1,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SleepInsights(selectedMonth: selectedMonth),
              );
            },
          ),
        ),
      ],
    );
  }

  String _monthName(int month) => const [
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
  ][month - 1];
}

// ============================================================================
// MONTH VIEW (Chart + Latest Entries)
// ============================================================================

/// The actual month view displaying chart + last 3 entries for that month.
class SleepInsights extends StatelessWidget {
  const SleepInsights({super.key, required this.selectedMonth});

  final DateTime selectedMonth;

  /// Converts DateTime to date-only ISO string (YYYY-MM-DD)
  String _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;

  /// Safely converts dynamic value to double
  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0;
  }

  /// Formats date string for display (e.g., "Today", "Yesterday", "Mon, Jan 15")
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) return 'Today';
      if (dateOnly == yesterday) return 'Yesterday';

      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
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
      return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final firstDayStr = _dateOnly(firstDay);
    final lastDayStr = _dateOnly(lastDay);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('sleep_logs')
          .select('day, hours_slept')
          .gte('day', firstDayStr)
          .lte('day', lastDayStr)
          .order('day', ascending: true)
          .limit(500),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.error.withOpacity(0.3)),
            ),
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: scheme.error),
            ),
          );
        }

        final rows = snapshot.data ?? [];

        // Empty state
        if (rows.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bed_outlined,
                  size: 42,
                  color: scheme.primary.withOpacity(0.35),
                ),
                const SizedBox(height: 10),
                Text(
                  'No sleep data for this month',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          );
        }

        // Group data by day
        final Map<String, SleepDayAgg> byDay = {};
        for (final r in rows) {
          final day = (r['day'] ?? '').toString(); // YYYY-MM-DD
          final hours = _toDouble(r['hours_slept']);
          byDay.putIfAbsent(day, () => SleepDayAgg(day: day)).add(hours);
        }

        // Chart data: oldest -> newest
        final chartData = byDay.values.toList()
          ..sort((a, b) => a.day.compareTo(b.day));

        // Display list: newest -> oldest (only last 3)
        final fullList = chartData.reversed.toList();
        final displayList = fullList.take(3).toList();

        // Calculate statistics
        final totalHours = fullList.fold<double>(
          0,
          (sum, s) => sum + s.hoursTotal,
        );
        final avgHours = fullList.isNotEmpty ? totalHours / fullList.length : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Title: Sleep Trends
            Text(
              'Sleep Trends',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // Chart Container
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.surfaceContainer,
                border: Border.all(color: scheme.outline.withOpacity(0.2)),
              ),
              child: _SleepChart(data: chartData, scheme: scheme),
            ),
            const SizedBox(height: 14),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Avg Sleep',
                    value: '${avgHours.toStringAsFixed(1)}h',
                    icon: Icons.nights_stay_outlined,
                    scheme: scheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Days Logged',
                    value: '${fullList.length}',
                    icon: Icons.calendar_today_outlined,
                    scheme: scheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Section Title: Latest entries
            Text(
              'Latest entries',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // Latest entries list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final s = displayList[index];
                return _SleepEntryCard(
                  day: _formatDate(s.day),
                  hours: s.averageHours,
                  entries: s.entriesCount,
                  scheme: scheme,
                );
              },
            ),

            // "Showing X of Y" indicator
            if (fullList.length > 3) ...[
              const SizedBox(height: 6),
              Text(
                'Showing 3 of ${fullList.length} days logged this month',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.55),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================================
// CHART COMPONENT (Line chart with goal line)
// ============================================================================

/// Displays a line chart of sleep hours with an 8-hour goal line.
class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.data, required this.scheme});

  final List<SleepDayAgg> data;
  final ColorScheme scheme;

  /// Formats date to short readable form (e.g., "15 Jan")
  String _prettyShortDay(String isoDay) {
    try {
      final d = DateTime.parse(isoDay);
      const months = [
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
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return isoDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.averageHours))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            tooltipBgColor: scheme.surfaceVariant,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final i = spot.x.toInt();
                final day = (i >= 0 && i < data.length) ? data[i].day : '';
                return LineTooltipItem(
                  '${_prettyShortDay(day)}\n${spot.y.toStringAsFixed(1)}h',
                  TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                );
              }).toList();
            },
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 8,
              color: scheme.primary.withOpacity(0.35),
              strokeWidth: 2,
              dashArray: [6, 6],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                style: TextStyle(
                  color: scheme.primary.withOpacity(0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                labelResolver: (_) => 'Goal 8h',
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: scheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: scheme.surface,
                    strokeWidth: 2,
                    strokeColor: scheme.primary,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withOpacity(0.35),
                  scheme.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STAT CARD COMPONENT
// ============================================================================

/// Displays a single sleep metric (e.g., "Avg Sleep: 7.2h")
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.scheme,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outline.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SLEEP ENTRY CARD COMPONENT
// ============================================================================

/// Displays a single sleep entry with date, hours, and quality indicator.
class _SleepEntryCard extends StatelessWidget {
  const _SleepEntryCard({
    required this.day,
    required this.hours,
    required this.entries,
    required this.scheme,
  });

  final String day;
  final double hours;
  final int entries;
  final ColorScheme scheme;

  /// Returns a quality label based on hours slept
  String _getQualityLabel(double hours) {
    if (hours >= 8) return '😴 Great!';
    if (hours >= 7) return '😊 Good';
    if (hours >= 6) return '😐 Fair';
    return '😴 Short';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surface,
        border: Border.all(color: scheme.outline.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hours.toStringAsFixed(1)}h • $entries ${entries == 1 ? 'entry' : 'entries'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: scheme.primary.withOpacity(0.1),
            ),
            child: Text(
              _getQualityLabel(hours),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
