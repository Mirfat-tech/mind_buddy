import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_buddy/features/insights/brainbubble_insights.dart';
import 'package:mind_buddy/features/sleep/sleep_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// DATA MODEL
// ============================================================================

class SleepDayAgg {
  SleepDayAgg({required this.day});

  final String day; // Expected format: "YYYY-MM-DD"
  int entriesCount = 0;
  double hoursTotal = 0;
  String? qualityRaw;
  String? notes;

  void add(double hours, {String? quality, String? note}) {
    entriesCount += 1;
    hoursTotal += hours;
    final trimmedQuality = quality?.trim();
    final trimmedNote = note?.trim();
    if (trimmedQuality != null && trimmedQuality.isNotEmpty) {
      qualityRaw = trimmedQuality;
    }
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      notes = trimmedNote;
    }
  }

  double get averageHours => entriesCount > 0 ? hoursTotal / entriesCount : 0;
}

enum SleepHeatMapMode { hours, quality, consistency }

class _SleepLegendItem {
  const _SleepLegendItem({required this.label, required this.color});

  final String label;
  final Color color;
}

class _SleepMetricCardData {
  const _SleepMetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
}

class _SleepPastelPalette {
  static const Color card = Color(0xFFFFF8F8);
  static const Color cardInner = Color(0xFFFFFBFB);
  static const Color tileBase = Color(0xFFF8EEF1);
  static const Color blush = Color(0xFFF0BFD0);
  static const Color peach = Color(0xFFF2C9A8);
  static const Color butter = Color(0xFFF1DC8A);
  static const Color mint = Color(0xFFBFE6D2);
  static const Color aqua = Color(0xFFB9E2E9);
  static const Color teal = Color(0xFFA1D7E1);
  static const Color aquaDeep = Color(0xFF88C7D5);
  static const Color selectionPink = Color(0xFFE4B3C4);
  static const Color selectionMint = Color(0xFF9FD6C2);
  static const Color selectionAqua = Color(0xFF97CDD8);
  static const Color textSoft = Color(0xFF7D7077);
  static Color tint(Color accent, {double strength = 0.22}) {
    return Color.alphaBlend(accent.withOpacity(strength), tileBase);
  }

  static Color neutralTile({double strength = 1.0}) {
    return Color.lerp(Colors.white, tileBase, strength) ?? tileBase;
  }
}

// ============================================================================
// MAIN CONTAINER
// ============================================================================

class SleepInsightsContainer extends StatefulWidget {
  const SleepInsightsContainer({super.key});

  @override
  State<SleepInsightsContainer> createState() => _SleepInsightsContainerState();
}

class _SleepInsightsContainerState extends State<SleepInsightsContainer> {
  late final PageController _pageController;
  DateTime _focusedMonth = DateTime.now();
  static const int _initialPage = 1200;

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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: scheme.onSurface),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                ),
              ),
              Text(
                '${monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: scheme.onSurface),
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 760,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SleepInsights(selectedMonth: selectedMonth),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String monthName(int month) => const [
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

// ============================================================================
// MONTH VIEW
// ============================================================================

class SleepInsights extends StatefulWidget {
  const SleepInsights({super.key, required this.selectedMonth});

  final DateTime selectedMonth;

  @override
  State<SleepInsights> createState() => _SleepInsightsState();
}

class _SleepInsightsState extends State<SleepInsights> {
  SleepHeatMapMode _selectedMode = SleepHeatMapMode.hours;
  DateTime? _selectedDay;

  Future<List<Map<String, dynamic>>> _loadSleepRows({
    required String startDay,
    required String endExclusiveDay,
  }) async {
    debugPrint('INSIGHTS_LOAD_LOCAL source=sleep');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const <Map<String, dynamic>>[];
    final rows = await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(sleepRepositoryProvider).loadEntries(userId: userId);
    return rows
        .where((row) {
          final day = (row['day'] ?? '').toString();
          return day.compareTo(startDay) >= 0 &&
              day.compareTo(endExclusiveDay) < 0;
        })
        .toList(growable: false)
      ..sort(
        (a, b) =>
            (a['day'] ?? '').toString().compareTo((b['day'] ?? '').toString()),
      );
  }

  String _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;

  DateTime? _parseLocalDay(dynamic raw) {
    if (raw == null) return null;
    final parsed = raw is DateTime
        ? raw.toLocal()
        : DateTime.tryParse(raw.toString())?.toLocal();
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

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
      return '${days[date.weekday - 1]}, ${monthName(date.month)} ${date.day}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatFullDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _modeTitle(SleepHeatMapMode mode) {
    switch (mode) {
      case SleepHeatMapMode.hours:
        return 'Hours';
      case SleepHeatMapMode.quality:
        return 'Quality';
      case SleepHeatMapMode.consistency:
        return 'Consistency';
    }
  }

  String _qualityLabel(String? raw, {double? fallbackHours}) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized != null && normalized.isNotEmpty) {
      final numeric = int.tryParse(normalized);
      if (numeric != null) {
        if (numeric <= 2) return 'Restless';
        if (numeric <= 4) return 'Short';
        if (numeric <= 6) return 'Okay';
        if (numeric <= 8) return 'Good';
        return 'Great';
      }
      if (normalized.contains('restless') ||
          normalized.contains('poor') ||
          normalized.contains('bad')) {
        return 'Restless';
      }
      if (normalized.contains('short') || normalized.contains('little')) {
        return 'Short';
      }
      if (normalized.contains('okay') ||
          normalized.contains('ok') ||
          normalized.contains('fair')) {
        return 'Okay';
      }
      if (normalized.contains('good')) return 'Good';
      if (normalized.contains('great') ||
          normalized.contains('excellent') ||
          normalized.contains('amazing')) {
        return 'Great';
      }
    }
    if (fallbackHours == null) return 'No data';
    if (fallbackHours < 5) return 'Restless';
    if (fallbackHours < 7) return 'Short';
    if (fallbackHours < 9) return 'Okay';
    if (fallbackHours < 11) return 'Good';
    return 'Great';
  }

  String _consistencyLabel(double? hours, double? monthlyAverage) {
    if (hours == null || monthlyAverage == null) return 'No data';
    final diff = (hours - monthlyAverage).abs();
    if (diff <= 0.4) return 'Very consistent';
    if (diff <= 1.0) return 'Typical';
    if (diff <= 1.8) return 'Slightly off';
    return 'Very inconsistent';
  }

  _SleepLegendItem _hoursLegend(double? hours, ColorScheme scheme) {
    if (hours == null) {
      return _SleepLegendItem(
        label: 'No data',
        color: _SleepPastelPalette.neutralTile(strength: 0.72),
      );
    }
    if (hours < 5) {
      return _SleepLegendItem(
        label: 'Under 5h',
        color: _SleepPastelPalette.tint(
          _SleepPastelPalette.blush,
          strength: 0.28,
        ),
      );
    }
    if (hours < 7) {
      return _SleepLegendItem(
        label: '5–6.9h',
        color: _SleepPastelPalette.tint(
          _SleepPastelPalette.peach,
          strength: 0.27,
        ),
      );
    }
    if (hours < 9) {
      return _SleepLegendItem(
        label: '7–8.9h',
        color: _SleepPastelPalette.tint(
          _SleepPastelPalette.mint,
          strength: 0.25,
        ),
      );
    }
    if (hours < 11) {
      return _SleepLegendItem(
        label: '9–10.9h',
        color: _SleepPastelPalette.tint(
          _SleepPastelPalette.aqua,
          strength: 0.28,
        ),
      );
    }
    return _SleepLegendItem(
      label: '11h+',
      color: _SleepPastelPalette.tint(
        _SleepPastelPalette.aquaDeep,
        strength: 0.34,
      ),
    );
  }

  _SleepLegendItem _qualityLegend(
    String? raw,
    double? hours,
    ColorScheme scheme,
  ) {
    switch (_qualityLabel(raw, fallbackHours: hours)) {
      case 'Restless':
        return _SleepLegendItem(
          label: 'Restless',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.blush,
            strength: 0.28,
          ),
        );
      case 'Short':
        return _SleepLegendItem(
          label: 'Short',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.peach,
            strength: 0.27,
          ),
        );
      case 'Okay':
        return _SleepLegendItem(
          label: 'Okay',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.butter,
            strength: 0.24,
          ),
        );
      case 'Good':
        return _SleepLegendItem(
          label: 'Good',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.mint,
            strength: 0.26,
          ),
        );
      case 'Great':
        return _SleepLegendItem(
          label: 'Great',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.aqua,
            strength: 0.30,
          ),
        );
      default:
        return _SleepLegendItem(
          label: 'No data',
          color: _SleepPastelPalette.neutralTile(strength: 0.72),
        );
    }
  }

  _SleepLegendItem _consistencyLegend(
    double? hours,
    double? monthlyAverage,
    ColorScheme scheme,
  ) {
    switch (_consistencyLabel(hours, monthlyAverage)) {
      case 'Very inconsistent':
        return _SleepLegendItem(
          label: 'Very inconsistent',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.blush,
            strength: 0.28,
          ),
        );
      case 'Slightly off':
        return _SleepLegendItem(
          label: 'Slightly off',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.peach,
            strength: 0.26,
          ),
        );
      case 'Typical':
        return _SleepLegendItem(
          label: 'Typical',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.butter,
            strength: 0.24,
          ),
        );
      case 'Very consistent':
        return _SleepLegendItem(
          label: 'Very consistent',
          color: _SleepPastelPalette.tint(
            _SleepPastelPalette.teal,
            strength: 0.30,
          ),
        );
      default:
        return _SleepLegendItem(
          label: 'No data',
          color: _SleepPastelPalette.neutralTile(strength: 0.72),
        );
    }
  }

  List<_SleepLegendItem> _legendItemsForMode(
    SleepHeatMapMode mode,
    ColorScheme scheme,
  ) {
    switch (mode) {
      case SleepHeatMapMode.hours:
        return [
          _hoursLegend(null, scheme),
          _hoursLegend(4.0, scheme),
          _hoursLegend(6.0, scheme),
          _hoursLegend(8.0, scheme),
          _hoursLegend(10.0, scheme),
          _hoursLegend(11.5, scheme),
        ];
      case SleepHeatMapMode.quality:
        return [
          _qualityLegend(null, null, scheme),
          _qualityLegend('restless', null, scheme),
          _qualityLegend('short', null, scheme),
          _qualityLegend('okay', null, scheme),
          _qualityLegend('good', null, scheme),
          _qualityLegend('great', null, scheme),
        ];
      case SleepHeatMapMode.consistency:
        return [
          _consistencyLegend(null, null, scheme),
          _consistencyLegend(10, 7, scheme),
          _consistencyLegend(8.4, 7, scheme),
          _consistencyLegend(7.7, 7, scheme),
          _consistencyLegend(7.1, 7, scheme),
        ];
    }
  }

  String _selectedDaySummary(
    SleepHeatMapMode mode,
    SleepDayAgg? day,
    double? monthlyAverage,
  ) {
    switch (mode) {
      case SleepHeatMapMode.hours:
        return day == null
            ? 'No entry logged'
            : '${day.averageHours.toStringAsFixed(1)} hours';
      case SleepHeatMapMode.quality:
        return _qualityLabel(day?.qualityRaw, fallbackHours: day?.averageHours);
      case SleepHeatMapMode.consistency:
        return _consistencyLabel(day?.averageHours, monthlyAverage);
    }
  }

  String _modeInsightText(
    SleepHeatMapMode mode,
    List<SleepDayAgg> monthData,
    double? monthlyAverage,
  ) {
    if (monthData.isEmpty) {
      return 'This month is still open and gentle. Sleep days will start to fill in here as you log them.';
    }

    switch (mode) {
      case SleepHeatMapMode.hours:
        final average = monthlyAverage ?? 0;
        if (average >= 7 && average <= 9) {
          return 'Most of your sleep sat in a calm, restorative range this month.';
        }
        if (average < 7) {
          return 'Your month leaned a little lighter on rest, with several shorter nights showing up in the calendar.';
        }
        return 'You had a few longer sleep stretches this month, which gave the calendar a slower, softer feel.';
      case SleepHeatMapMode.quality:
        final counts = <String, int>{};
        for (final day in monthData) {
          final label = _qualityLabel(
            day.qualityRaw,
            fallbackHours: day.averageHours,
          );
          if (label == 'No data') continue;
          counts[label] = (counts[label] ?? 0) + 1;
        }
        if (counts.isEmpty) {
          return 'You logged sleep this month, though quality tags were a little quiet.';
        }
        final dominant = counts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
        return 'Your sleep quality most often felt $dominant this month, with a few softer variations around it.';
      case SleepHeatMapMode.consistency:
        final steadyDays = monthData.where((day) {
          final label = _consistencyLabel(day.averageHours, monthlyAverage);
          return label == 'Typical' || label == 'Very consistent';
        }).length;
        if (steadyDays >= math.max(3, monthData.length ~/ 2)) {
          return 'Your sleep rhythm looked fairly steady this month, especially in your usual range.';
        }
        return 'Your sleep rhythm shifted a bit this month, which is okay. The calmer tiles show where things felt more familiar.';
    }
  }

  void _showDayDetails(
    BuildContext context,
    DateTime date,
    SleepDayAgg? day,
    double? monthlyAverage,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final content = _SleepDayDetailsCard(
      dateLabel: _formatFullDate(date),
      day: day,
      monthlyAverage: monthlyAverage,
      selectedMode: _selectedMode,
      qualityLabel: _qualityLabel(
        day?.qualityRaw,
        fallbackHours: day?.averageHours,
      ),
      consistencyLabel: _consistencyLabel(day?.averageHours, monthlyAverage),
      scheme: scheme,
    );

    if (MediaQuery.of(context).size.width >= 700) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(padding: const EdgeInsets.all(16), child: content),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: scheme.surface,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: content,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedMonth = widget.selectedMonth;
    final previousMonthStart = DateTime(
      selectedMonth.year,
      selectedMonth.month - 1,
      1,
    );
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endExclusive = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadSleepRows(
        startDay: _dateOnly(previousMonthStart),
        endExclusiveDay: _dateOnly(endExclusive),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.error.withOpacity(0.24)),
            ),
            child: Text(
              'Error loading sleep insights: ${snapshot.error}',
              style: TextStyle(color: scheme.error),
            ),
          );
        }

        final rows = snapshot.data ?? [];
        final byDay = <String, SleepDayAgg>{};
        final previousByDay = <String, SleepDayAgg>{};

        for (final row in rows) {
          final localDay = _parseLocalDay(row['day']);
          if (localDay == null) continue;
          final targetMap =
              (localDay.year == selectedMonth.year &&
                  localDay.month == selectedMonth.month)
              ? byDay
              : (localDay.year == previousMonthStart.year &&
                    localDay.month == previousMonthStart.month)
              ? previousByDay
              : null;
          if (targetMap == null) continue;
          final dayKey = _dateOnly(localDay);
          targetMap
              .putIfAbsent(dayKey, () => SleepDayAgg(day: dayKey))
              .add(
                _toDouble(row['hours_slept']),
                quality: row['quality']?.toString(),
                note: row['notes']?.toString(),
              );
        }

        if (kDebugMode) {
          debugPrint(
            'SleepInsights month=${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')} rows=${rows.length} days=${byDay.length}',
          );
        }

        final monthData = byDay.values.toList()
          ..sort((a, b) => a.day.compareTo(b.day));
        final totalHours = monthData.fold<double>(
          0,
          (sum, day) => sum + day.hoursTotal,
        );
        final monthlyAverage = monthData.isEmpty
            ? null
            : monthData.fold<double>(0, (sum, day) => sum + day.averageHours) /
                  monthData.length;
        final previousTotalHours = previousByDay.values.fold<double>(
          0,
          (sum, day) => sum + day.hoursTotal,
        );
        final bestSleepDay = monthData.isEmpty
            ? null
            : monthData.reduce(
                (a, b) => a.averageHours >= b.averageHours ? a : b,
              );
        final shortestSleepDay = monthData.isEmpty
            ? null
            : monthData.reduce(
                (a, b) => a.averageHours <= b.averageHours ? a : b,
              );
        final selectedDay =
            _selectedDay != null &&
                _selectedDay!.year == selectedMonth.year &&
                _selectedDay!.month == selectedMonth.month
            ? _selectedDay!
            : monthStart;
        final selectedAgg = byDay[_dateOnly(selectedDay)];

        final qualityCounts = <String, int>{};
        final hoursCounts = <String, int>{};
        int steadyDays = 0;
        for (final day in monthData) {
          final quality = _qualityLabel(
            day.qualityRaw,
            fallbackHours: day.averageHours,
          );
          if (quality != 'No data') {
            qualityCounts[quality] = (qualityCounts[quality] ?? 0) + 1;
          }
          final range = _hoursLegend(day.averageHours, scheme).label;
          hoursCounts[range] = (hoursCounts[range] ?? 0) + 1;
          final consistency = _consistencyLabel(
            day.averageHours,
            monthlyAverage,
          );
          if (consistency == 'Typical' || consistency == 'Very consistent') {
            steadyDays += 1;
          }
        }

        final metricCards = <_SleepMetricCardData>[
          _SleepMetricCardData(
            label: 'Average sleep',
            value: monthlyAverage == null
                ? '—'
                : '${monthlyAverage.toStringAsFixed(1)}h',
            icon: Icons.nights_stay_outlined,
          ),
          _SleepMetricCardData(
            label: 'Days logged',
            value: '${monthData.length}',
            icon: Icons.calendar_today_outlined,
          ),
          _SleepMetricCardData(
            label: 'Total sleep this month',
            value: monthData.isEmpty
                ? '—'
                : '${totalHours.toStringAsFixed(1)}h',
            icon: Icons.stacked_line_chart_rounded,
          ),
          _SleepMetricCardData(
            label: 'Best sleep day',
            value: bestSleepDay == null
                ? '—'
                : '${bestSleepDay.averageHours.toStringAsFixed(1)}h',
            icon: Icons.wb_twilight_outlined,
            subtitle: bestSleepDay == null
                ? null
                : _formatDate(bestSleepDay.day),
          ),
          _SleepMetricCardData(
            label: 'Shortest sleep day',
            value: shortestSleepDay == null
                ? '—'
                : '${shortestSleepDay.averageHours.toStringAsFixed(1)}h',
            icon: Icons.bedtime_off_outlined,
            subtitle: shortestSleepDay == null
                ? null
                : _formatDate(shortestSleepDay.day),
          ),
          if (hoursCounts.isNotEmpty)
            _SleepMetricCardData(
              label: 'Most common range',
              value: hoursCounts.entries
                  .reduce((a, b) => a.value >= b.value ? a : b)
                  .key,
              icon: Icons.blur_on_rounded,
            ),
          if (qualityCounts.isNotEmpty)
            _SleepMetricCardData(
              label: 'Most common quality',
              value: qualityCounts.entries
                  .reduce((a, b) => a.value >= b.value ? a : b)
                  .key,
              icon: Icons.self_improvement_outlined,
            ),
          if (monthData.isNotEmpty)
            _SleepMetricCardData(
              label: 'Consistency score',
              value: '${((steadyDays / monthData.length) * 100).round()}%',
              icon: Icons.track_changes_outlined,
            ),
        ];

        final legacyInsight = BrainBubbleInsights.sleep(
          currentHours: totalHours,
          previousHours: previousTotalHours,
          calmestNight: bestSleepDay == null
              ? null
              : DateTime.tryParse(bestSleepDay.day),
          shortestNight: shortestSleepDay == null
              ? null
              : DateTime.tryParse(shortestSleepDay.day),
          daysLogged: monthData.length,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SleepModeInsightCard(
              title: legacyInsight.summary,
              body: _modeInsightText(_selectedMode, monthData, monthlyAverage),
              modeLabel: _modeTitle(_selectedMode),
              scheme: scheme,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: _SleepPastelPalette.card,
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep Calendar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedMode == SleepHeatMapMode.hours
                          ? '${monthData.length} nights logged this month'
                          : '${_modeTitle(_selectedMode)} view for this month',
                      style: TextStyle(
                        color: _SleepPastelPalette.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SleepHeatMapToggle(
                      selectedMode: _selectedMode,
                      scheme: scheme,
                      onChanged: (mode) {
                        if (mode == _selectedMode) return;
                        setState(() => _selectedMode = mode);
                      },
                    ),
                    const SizedBox(height: 16),
                    _SleepHeatMap(
                      month: selectedMonth,
                      dataByDay: byDay,
                      selectedMode: _selectedMode,
                      selectedDay: selectedDay,
                      monthlyAverage: monthlyAverage,
                      onTapDay: (date) {
                        setState(() => _selectedDay = date);
                        _showDayDetails(
                          context,
                          date,
                          byDay[_dateOnly(date)],
                          monthlyAverage,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _SleepHeatMapLegend(
                        key: ValueKey('legend-${_selectedMode.name}'),
                        items: _legendItemsForMode(_selectedMode, scheme),
                        scheme: scheme,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _SleepCalendarFooterBar(
                        key: ValueKey(
                          'footer-${_selectedMode.name}-${selectedDay.toIso8601String()}',
                        ),
                        text: selectedAgg == null
                            ? 'Tap a day to gently explore your sleep details'
                            : '${_formatFullDate(selectedDay)} • ${_selectedDaySummary(_selectedMode, selectedAgg, monthlyAverage)}',
                        scheme: scheme,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Monthly summary',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _SleepMetricGrid(cards: metricCards, scheme: scheme),
            const SizedBox(height: 16),
            Text(
              'Recent nights',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (monthData.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.surfaceContainer,
                ),
                child: Text(
                  'No sleep entries logged for this month yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.68),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(3, monthData.length),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = monthData.reversed.toList()[index];
                  return _SleepEntryCard(
                    day: _formatDate(item.day),
                    hours: item.averageHours,
                    entries: item.entriesCount,
                    qualityLabel: _qualityLabel(
                      item.qualityRaw,
                      fallbackHours: item.averageHours,
                    ),
                    scheme: scheme,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// INSIGHT + TOGGLE
// ============================================================================

class _SleepModeInsightCard extends StatelessWidget {
  const _SleepModeInsightCard({
    required this.title,
    required this.body,
    required this.modeLabel,
    required this.scheme,
  });

  final String title;
  final String body;
  final String modeLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(0.08),
            scheme.surfaceContainerHighest.withOpacity(0.64),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: scheme.primary.withOpacity(0.12),
            ),
            child: Text(
              modeLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepHeatMapToggle extends StatelessWidget {
  const _SleepHeatMapToggle({
    required this.selectedMode,
    required this.onChanged,
    required this.scheme,
  });

  final SleepHeatMapMode selectedMode;
  final ValueChanged<SleepHeatMapMode> onChanged;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _SleepPastelPalette.cardInner,
      ),
      child: Row(
        children: SleepHeatMapMode.values.map((mode) {
          final selected = mode == selectedMode;
          final label = switch (mode) {
            SleepHeatMapMode.hours => 'Hours',
            SleepHeatMapMode.quality => 'Quality',
            SleepHeatMapMode.consistency => 'Consistency',
          };
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: selected
                        ? scheme.primary.withOpacity(0.10)
                        : Colors.transparent,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.primary
                          : _SleepPastelPalette.textSoft,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// HEAT MAP
// ============================================================================

class _SleepHeatMap extends StatelessWidget {
  const _SleepHeatMap({
    required this.month,
    required this.dataByDay,
    required this.selectedMode,
    required this.selectedDay,
    required this.monthlyAverage,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<String, SleepDayAgg> dataByDay;
  final SleepHeatMapMode selectedMode;
  final DateTime selectedDay;
  final double? monthlyAverage;
  final ValueChanged<DateTime> onTapDay;

  String _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;

  String _qualityLabel(String? raw, {double? fallbackHours}) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized != null && normalized.isNotEmpty) {
      final numeric = int.tryParse(normalized);
      if (numeric != null) {
        if (numeric <= 2) return 'Restless';
        if (numeric <= 4) return 'Short';
        if (numeric <= 6) return 'Okay';
        if (numeric <= 8) return 'Good';
        return 'Great';
      }
      if (normalized.contains('restless') ||
          normalized.contains('poor') ||
          normalized.contains('bad')) {
        return 'Restless';
      }
      if (normalized.contains('short')) return 'Short';
      if (normalized.contains('okay') ||
          normalized.contains('ok') ||
          normalized.contains('fair')) {
        return 'Okay';
      }
      if (normalized.contains('good')) return 'Good';
      if (normalized.contains('great') || normalized.contains('excellent')) {
        return 'Great';
      }
    }
    if (fallbackHours == null) return 'No data';
    if (fallbackHours < 5) return 'Restless';
    if (fallbackHours < 7) return 'Short';
    if (fallbackHours < 9) return 'Okay';
    if (fallbackHours < 11) return 'Good';
    return 'Great';
  }

  String _consistencyLabel(double? hours) {
    if (hours == null || monthlyAverage == null) return 'No data';
    final diff = (hours - monthlyAverage!).abs();
    if (diff <= 0.4) return 'Very consistent';
    if (diff <= 1.0) return 'Typical';
    if (diff <= 1.8) return 'Slightly off';
    return 'Very inconsistent';
  }

  Color _selectionBorderColor() {
    switch (selectedMode) {
      case SleepHeatMapMode.hours:
        return _SleepPastelPalette.selectionAqua;
      case SleepHeatMapMode.quality:
        return _SleepPastelPalette.selectionPink;
      case SleepHeatMapMode.consistency:
        return _SleepPastelPalette.selectionMint;
    }
  }

  Color _tileColor(SleepDayAgg? day) {
    if (day == null) return Colors.black.withOpacity(0.04);
    switch (selectedMode) {
      case SleepHeatMapMode.hours:
        final hours = day.averageHours;
        if (hours < 5) return const Color(0xFFE88AA8).withOpacity(0.18);
        if (hours < 7) return const Color(0xFFEFB08D).withOpacity(0.18);
        if (hours < 9) return const Color(0xFF9CC9A6).withOpacity(0.18);
        if (hours < 11) return const Color(0xFF89C9D8).withOpacity(0.18);
        return const Color(0xFF6EB7CB).withOpacity(0.22);
      case SleepHeatMapMode.quality:
        return switch (_qualityLabel(
          day.qualityRaw,
          fallbackHours: day.averageHours,
        )) {
          'Restless' => const Color(0xFFE88AA8).withOpacity(0.18),
          'Short' => const Color(0xFFEFB08D).withOpacity(0.18),
          'Okay' => const Color(0xFFE5C96D).withOpacity(0.18),
          'Good' => const Color(0xFF8CC8AA).withOpacity(0.18),
          'Great' => const Color(0xFF7FC1D4).withOpacity(0.20),
          _ => Colors.black.withOpacity(0.04),
        };
      case SleepHeatMapMode.consistency:
        return switch (_consistencyLabel(day.averageHours)) {
          'Very inconsistent' => const Color(0xFFE88AA8).withOpacity(0.18),
          'Slightly off' => const Color(0xFFEFB08D).withOpacity(0.18),
          'Typical' => const Color(0xFFE5C96D).withOpacity(0.18),
          'Very consistent' => const Color(0xFF89C7B5).withOpacity(0.20),
          _ => Colors.black.withOpacity(0.04),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final scheme = Theme.of(context).colorScheme;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: [
        Row(
          children: weekdays
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
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
        ...List.generate(rowCount, (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: List.generate(7, (dayOfWeek) {
                final dayNumber =
                    (weekIndex * 7) + dayOfWeek - leadingBlanks + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox());
                }
                final date = DateTime(month.year, month.month, dayNumber);
                final data = dataByDay[_dateOnly(date)];
                final isSelected =
                    selectedDay.year == date.year &&
                    selectedDay.month == date.month &&
                    selectedDay.day == date.day;
                final today = DateTime.now();
                final isToday =
                    today.year == date.year &&
                    today.month == date.month &&
                    today.day == date.day;

                return Expanded(
                  child: Tooltip(
                    message: data == null
                        ? 'Day $dayNumber: No entry'
                        : 'Day $dayNumber: ${_qualityLabel(data.qualityRaw, fallbackHours: data.averageHours)} • ${data.averageHours.toStringAsFixed(1)}h',
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label:
                          '${weekdays[date.weekday - 1]} ${date.day}, ${monthName(date.month)}. ${data == null ? 'No data.' : 'Sleep logged.'}',
                      child: Container(
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onTapDay(date),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: _tileColor(data),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? _selectionBorderColor().withOpacity(
                                          0.28,
                                        )
                                      : isToday
                                      ? scheme.primary.withOpacity(0.18)
                                      : scheme.outline.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant.withOpacity(
                                      0.62,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
}

class _SleepHeatMapLegend extends StatelessWidget {
  const _SleepHeatMapLegend({
    super.key,
    required this.items,
    required this.scheme,
  });

  final List<_SleepLegendItem> items;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outline.withOpacity(0.1)),
          ),
          child: Text(
            item.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SleepCalendarFooterBar extends StatelessWidget {
  const _SleepCalendarFooterBar({
    super.key,
    required this.text,
    required this.scheme,
  });

  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.primary.withOpacity(0.08),
        border: Border.all(color: scheme.primary.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// DETAILS
// ============================================================================

class _SleepDayDetailsCard extends StatelessWidget {
  const _SleepDayDetailsCard({
    required this.dateLabel,
    required this.day,
    required this.monthlyAverage,
    required this.selectedMode,
    required this.qualityLabel,
    required this.consistencyLabel,
    required this.scheme,
  });

  final String dateLabel;
  final SleepDayAgg? day;
  final double? monthlyAverage;
  final SleepHeatMapMode selectedMode;
  final String qualityLabel;
  final String consistencyLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final hasData = day != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DetailPill(
              label: hasData
                  ? '${day!.averageHours.toStringAsFixed(1)}h'
                  : 'No data',
              scheme: scheme,
            ),
            _DetailPill(label: qualityLabel, scheme: scheme),
            _DetailPill(label: consistencyLabel, scheme: scheme),
          ],
        ),
        const SizedBox(height: 16),
        if (!hasData)
          Text(
            'No entry logged for this day yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.7),
            ),
          )
        else ...[
          _DetailRow(label: 'Entries', value: '${day!.entriesCount}'),
          _DetailRow(
            label: 'Mode focus',
            value: switch (selectedMode) {
              SleepHeatMapMode.hours =>
                '${day!.averageHours.toStringAsFixed(1)} hours',
              SleepHeatMapMode.quality => qualityLabel,
              SleepHeatMapMode.consistency => consistencyLabel,
            },
          ),
          if (monthlyAverage != null)
            _DetailRow(
              label: 'Monthly average',
              value: '${monthlyAverage!.toStringAsFixed(1)}h',
            ),
          if (day!.notes != null && day!.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                day!.notes!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withOpacity(0.72),
                  height: 1.35,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.primary.withOpacity(0.10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.62),
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUMMARY + ENTRIES
// ============================================================================

class _SleepMetricGrid extends StatelessWidget {
  const _SleepMetricGrid({required this.cards, required this.scheme});

  final List<_SleepMetricCardData> cards;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : 2;
        const spacing = 12.0;
        final rowExtent = constraints.maxWidth >= 700 ? 138.0 : 144.0;
        final rows = (cards.length / columns).ceil();
        return SizedBox(
          height: rows * rowExtent + ((rows - 1) * spacing),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: rowExtent,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return _StatCard(
                label: card.label,
                value: card.value,
                icon: card.icon,
                subtitle: card.subtitle,
                scheme: scheme,
              );
            },
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.scheme,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme scheme;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outline.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.62),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.62),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SleepEntryCard extends StatelessWidget {
  const _SleepEntryCard({
    required this.day,
    required this.hours,
    required this.entries,
    required this.qualityLabel,
    required this.scheme,
  });

  final String day;
  final double hours;
  final int entries;
  final String qualityLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surface,
        border: Border.all(color: scheme.outline.withOpacity(0.15)),
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
              borderRadius: BorderRadius.circular(999),
              color: scheme.primary.withOpacity(0.1),
            ),
            child: Text(
              qualityLabel,
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
