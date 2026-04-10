import 'package:flutter/material.dart';

enum BrainBubbleTrend { up, down, steady, unknown }

class BrainBubbleInsightData {
  const BrainBubbleInsightData({
    required this.summary,
    this.details = const <String>[],
  });

  final String summary;
  final List<String> details;
}

class BrainBubbleInsightCallout extends StatelessWidget {
  const BrainBubbleInsightCallout({
    super.key,
    required this.data,
    required this.scheme,
    this.accentColor,
  });

  final BrainBubbleInsightData data;
  final ColorScheme scheme;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? scheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withOpacity(0.08),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.summary,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          for (final detail in data.details) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BrainBubbleInsights {
  BrainBubbleInsights._();

  static BrainBubbleTrend compareValues(
    double current,
    double previous, {
    double relativeThreshold = 0.08,
    double absoluteThreshold = 0.0,
  }) {
    if (current <= 0 && previous <= 0) return BrainBubbleTrend.unknown;
    final delta = current - previous;
    if (delta.abs() <= absoluteThreshold) return BrainBubbleTrend.steady;
    if (previous.abs() < 0.001) {
      return delta.abs() <= absoluteThreshold
          ? BrainBubbleTrend.steady
          : BrainBubbleTrend.up;
    }
    final relativeDelta = delta.abs() / previous.abs();
    if (relativeDelta < relativeThreshold) return BrainBubbleTrend.steady;
    return delta > 0 ? BrainBubbleTrend.up : BrainBubbleTrend.down;
  }

  static String formatDate(DateTime date) {
    const months = <String>[
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
    return '${months[date.month - 1]} ${date.day}';
  }

  static BrainBubbleInsightData sleep({
    required double currentHours,
    required double previousHours,
    DateTime? calmestNight,
    DateTime? shortestNight,
    required int daysLogged,
  }) {
    final trend = compareValues(
      currentHours,
      previousHours,
      relativeThreshold: 0.1,
      absoluteThreshold: 1.0,
    );
    final summary = switch (trend) {
      BrainBubbleTrend.up =>
        'You seemed to get a little more rest this month 🌙',
      BrainBubbleTrend.down => 'Your sleep felt a little lighter this month 🌙',
      BrainBubbleTrend.steady =>
        'Your sleep rhythm stayed fairly steady this month 🌙',
      BrainBubbleTrend.unknown =>
        'You’re still building your rest rhythm, gently',
    };
    final details = <String>[];
    if (calmestNight != null) {
      details.add('Your calmest night was on ${formatDate(calmestNight)} 🌙');
    } else if (shortestNight != null) {
      details.add('One night looked a little shorter than the rest 💭');
    }
    if (daysLogged < 3) {
      details.add('You’re still building your rest rhythm, gently');
    }
    return BrainBubbleInsightData(
      summary: summary,
      details: details.take(2).toList(),
    );
  }

  static BrainBubbleInsightData mood({
    required int currentLightDays,
    required int currentHeavyDays,
    required int currentNeutralDays,
    required int previousLightDays,
    required int previousHeavyDays,
    required int entriesCount,
    String? dominantMood,
    String? dominantMoodEmoji,
  }) {
    final lightLead = currentLightDays - currentHeavyDays;
    final heavyLead = currentHeavyDays - currentLightDays;
    final lightDominantMood =
        dominantMood != null &&
        <String>{
          'happy',
          'excited',
          'confident',
          'calm',
        }.contains(dominantMood.toLowerCase());

    String summary;
    if (entriesCount <= 2) {
      summary = 'You’ve started checking in with yourself this month 💭';
    } else if (currentNeutralDays >= currentLightDays &&
        currentNeutralDays >= currentHeavyDays) {
      summary = 'This month held a mix of different feelings';
    } else if (lightLead >= 2) {
      summary = 'There were more lighter moments this month ✨';
    } else if (heavyLead >= 2) {
      summary = 'Some days felt a bit heavier this month 💭';
    } else if ((currentLightDays - currentHeavyDays).abs() <= 1 ||
        (previousLightDays - previousHeavyDays).abs() <= 1) {
      summary = 'Your feelings moved around a bit this month 💭';
    } else {
      summary = 'Emotionally, things felt a little varied this month';
    }

    if (summary.contains('heavier') && lightDominantMood) {
      summary = lightLead >= 1
          ? 'This month felt a little softer emotionally ✨'
          : 'Your feelings moved around a bit this month 💭';
    }

    final details = <String>[];
    if (dominantMood != null && dominantMood.isNotEmpty) {
      final emoji = (dominantMoodEmoji ?? '').trim();
      final label = dominantMood[0].toUpperCase() + dominantMood.substring(1);
      details.add(
        '$label showed up most often this month${emoji.isEmpty ? '' : ' $emoji'}',
      );
    }
    return BrainBubbleInsightData(summary: summary, details: details);
  }

  static BrainBubbleInsightData water({
    required int currentGoalDays,
    required int previousGoalDays,
    required int daysLogged,
    DateTime? strongestDay,
  }) {
    final trend = compareValues(
      currentGoalDays.toDouble(),
      previousGoalDays.toDouble(),
      absoluteThreshold: 1,
    );
    final summary = switch (trend) {
      BrainBubbleTrend.up =>
        'You seemed to find a gentler rhythm with hydration this month 💧',
      BrainBubbleTrend.down =>
        'Hydration looked a little quieter this month 💧',
      BrainBubbleTrend.steady =>
        'Your hydration rhythm stayed fairly similar this month 💧',
      BrainBubbleTrend.unknown =>
        'You’re still finding your rhythm with water, gently',
    };
    final details = <String>[
      'You reached your water goal on $currentGoalDays days 💧',
      if (strongestDay != null)
        'Your strongest hydration day was ${formatDate(strongestDay)}',
    ];
    if (daysLogged == 0) {
      details.add('A gentle reminder to take a sip when you can');
    }
    return BrainBubbleInsightData(
      summary: summary,
      details: details.take(2).toList(),
    );
  }

  static BrainBubbleInsightData finance({
    required double currentExpenses,
    required double previousExpenses,
    required double currentNet,
    DateTime? spikeDate,
  }) {
    final trend = compareValues(
      currentExpenses,
      previousExpenses,
      relativeThreshold: 0.08,
      absoluteThreshold: 20,
    );
    late final String summary;
    if (currentNet < 0) {
      summary = switch (trend) {
        BrainBubbleTrend.down =>
          'Spending softened a little, but it still ran ahead this month 💭',
        BrainBubbleTrend.up =>
          'Spending was a little heavier this month and ran ahead of income 💭',
        BrainBubbleTrend.steady =>
          'This month ended a little above your income overall 💭',
        BrainBubbleTrend.unknown =>
          'This month ran a little ahead of what came in 💭',
      };
    } else {
      summary = switch (trend) {
        BrainBubbleTrend.down =>
          'Your spending felt a little softer this month, and you still kept some aside ✨',
        BrainBubbleTrend.up =>
          'Spending was a little heavier this month, but you still finished with money left over ✨',
        BrainBubbleTrend.steady =>
          'Your money rhythm looked fairly similar this month, with some left over ✨',
        BrainBubbleTrend.unknown =>
          'You still finished the month with money left over ✨',
      };
    }
    final details = <String>[
      if (currentNet >= 0) 'You still had some money left over this month',
      if (currentNet < 0) 'Spending ended a little above your income overall',
      if (spikeDate != null)
        'There was a spending spike around ${formatDate(spikeDate)}',
    ];
    return BrainBubbleInsightData(
      summary: summary,
      details: details.take(2).toList(),
    );
  }

  static BrainBubbleInsightData cycle({
    DateTime? predictedDate,
    int? avgCycleLength,
    DateTime? lastStartDate,
    required bool hasEnoughHistory,
  }) {
    if (!hasEnoughHistory) {
      return const BrainBubbleInsightData(
        summary: 'Your cycle moved in its own rhythm this month 🩸',
        details: <String>['Still learning your rhythm'],
      );
    }
    final details = <String>[
      if (predictedDate != null)
        'Your next period may begin around ${formatDate(predictedDate)} 🩸',
      if (avgCycleLength != null)
        'Your cycle has been averaging about $avgCycleLength days',
      if (lastStartDate != null)
        'Your last period began on ${formatDate(lastStartDate)}',
    ];
    return BrainBubbleInsightData(
      summary: 'Your body’s rhythm shifted a little this month 💭',
      details: details.take(2).toList(),
    );
  }

  static BrainBubbleInsightData workout({
    required int currentDays,
    required int previousDays,
    DateTime? strongestDay,
  }) {
    final trend = compareValues(
      currentDays.toDouble(),
      previousDays.toDouble(),
      absoluteThreshold: 1,
    );
    final summary = switch (trend) {
      BrainBubbleTrend.up => 'Movement showed up a little more this month 💪',
      BrainBubbleTrend.down => 'Movement felt a little quieter this month 💭',
      BrainBubbleTrend.steady =>
        'Your movement rhythm stayed fairly steady this month',
      BrainBubbleTrend.unknown => 'Your routine is taking shape gently',
    };
    final details = <String>[
      'You moved through $currentDays workout days this month',
      if (strongestDay != null)
        'Your strongest workout day was ${formatDate(strongestDay)} 💪',
    ];
    return BrainBubbleInsightData(
      summary: summary,
      details: details.take(2).toList(),
    );
  }

  static BrainBubbleInsightData fasting({
    required int currentDays,
    required int previousDays,
    double? longestFastHours,
  }) {
    final trend = compareValues(
      currentDays.toDouble(),
      previousDays.toDouble(),
      absoluteThreshold: 1,
    );
    final summary = switch (trend) {
      BrainBubbleTrend.up =>
        'Your fasting rhythm felt a little steadier this month ⏳',
      BrainBubbleTrend.down =>
        'Your fasting rhythm looked a little lighter this month 💭',
      BrainBubbleTrend.steady =>
        'Your fasting rhythm stayed fairly similar this month ⏳',
      BrainBubbleTrend.unknown => 'Your rhythm is still forming gently',
    };
    final details = <String>[
      'You fasted on $currentDays days this month',
      if (longestFastHours != null)
        'Your longest fast was ${longestFastHours.toStringAsFixed(1)}h',
    ];
    return BrainBubbleInsightData(
      summary: summary,
      details: details.take(2).toList(),
    );
  }

  static BrainBubbleInsightData meditation({
    required int currentDays,
    required int previousDays,
    required double totalMinutes,
    DateTime? calmestDate,
  }) {
    final trend = compareValues(
      currentDays.toDouble(),
      previousDays.toDouble(),
      absoluteThreshold: 1,
    );
    final summary = switch (trend) {
      BrainBubbleTrend.up =>
        'You created a little more quiet for yourself this month 🧘',
      BrainBubbleTrend.down =>
        'Quiet moments felt a little lighter this month 💭',
      BrainBubbleTrend.steady =>
        'Your quiet rhythm stayed fairly steady this month 🧘',
      BrainBubbleTrend.unknown => 'Stillness showed up a bit more this month',
    };
    final details = <String>[
      'You paused for ${totalMinutes.toStringAsFixed(0)} minutes this month',
      'You made space for stillness on $currentDays days',
      if (calmestDate != null)
        'Your calmest stretch was around ${formatDate(calmestDate)}',
    ];
    return BrainBubbleInsightData(
      summary: summary,
      details: details.take(2).toList(),
    );
  }
}
