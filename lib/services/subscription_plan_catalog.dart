import 'package:flutter/foundation.dart';

enum MbPlanTier { pending, free, plusSupport }

@immutable
class PlanBenefits {
  const PlanBenefits({
    required this.tier,
    required this.emoji,
    required this.name,
    required this.price,
    required this.normalizedAliases,
    required this.insights,
    required this.devices,
    required this.canCreateCustomTemplates,
    required this.templatesPreviewMode,
    required this.coreTemplatesSaveForever,
    required this.canJournal,
    required this.canShareEntries,
    required this.sharesPerDay,
    required this.canReceiveUnlimitedShares,
    required this.tools,
    this.notes = const <String>[],
  });

  final MbPlanTier tier;
  final String emoji;
  final String name;
  final String price;
  final List<String> normalizedAliases;

  final bool insights;

  final int devices;
  final bool canCreateCustomTemplates;
  final bool templatesPreviewMode;
  final bool coreTemplatesSaveForever;

  final bool canJournal;
  final bool canShareEntries;
  final int sharesPerDay; // -1 means unlimited
  final bool canReceiveUnlimitedShares;

  final List<String> tools;
  final List<String> notes;
  String get titleWithPrice => '$name ($price)';
  String get heading => '$emoji $name ($price)';
}

class SubscriptionPlanCatalog {
  static const String title = '🟣 MB - Subscriptions';

  static const List<String> comparisonSectionOrder = <String>[
    'Access',
    'Insights',
    'Devices',
    'Templates',
    'Journaling',
    'Tools Included',
  ];

  static const String previewModeHelpText =
      'Free Mode includes journaling, journal sharing, and custom templates with normal saving.';

  static const String freeModeJournalHelpText =
      'Write freely, as much as you need 💭\nYour journal entries stay saved in Free mode';

  static String sharesPerDayHelpText(PlanBenefits plan) {
    if (!plan.canShareEntries) {
      return '${plan.name} cannot share entries yet.';
    }
    if (plan.sharesPerDay < 0) {
      return '${plan.name} includes unlimited shares per day.';
    }
    return '${plan.name} includes ${plan.sharesPerDay} ${plan.sharesPerDay == 1 ? 'share' : 'shares'} per day.';
  }

  static String deviceLimitHelpText(PlanBenefits plan) {
    if (plan.devices < 0) {
      return '${plan.name} allows unlimited devices.';
    }
    return '${plan.name} allows ${plan.devices} ${plan.devices == 1 ? 'device' : 'devices'}.';
  }

  static String deviceLimitReachedText(PlanBenefits plan) {
    return 'Device limit reached. ${deviceLimitHelpText(plan)}';
  }

  static const PlanBenefits free = PlanBenefits(
    tier: MbPlanTier.free,
    emoji: '🟢',
    name: 'FREE MODE',
    price: '£0',
    normalizedAliases: <String>['free', 'free_mode', 'free mode', 'basic'],
    insights: false,
    devices: 1,
    canCreateCustomTemplates: true,
    templatesPreviewMode: false,
    coreTemplatesSaveForever: true,
    canJournal: true,
    canShareEntries: true,
    sharesPerDay: -1,
    canReceiveUnlimitedShares: true,
    tools: <String>[
      'Brain Fog Bubble ✅',
      'Pomodoro Timer ✅',
      'Habit Tracker ✅',
      'Manual Logging ✅',
      'Unlimited journal entries ✅',
      'Journal sharing ✅',
      'Custom templates ✅',
    ],
    notes: <String>[
      'Custom templates save normally',
      'Unlimited journal sharing',
    ],
  );

  static const PlanBenefits plus = PlanBenefits(
    tier: MbPlanTier.plusSupport,
    emoji: '🟣',
    name: 'PLUS SUPPORT MODE',
    price: '£2.99',
    normalizedAliases: <String>[
      'plus',
      'plus_support',
      'plus support',
      'plus_support_mode',
      'plus support mode',
      'pro',
      'premium',
    ],
    insights: true,
    devices: -1,
    canCreateCustomTemplates: true,
    templatesPreviewMode: false,
    coreTemplatesSaveForever: true,
    canJournal: true,
    canShareEntries: true,
    sharesPerDay: -1,
    canReceiveUnlimitedShares: true,
    tools: <String>[
      'Brain Fog Bubble ✅',
      'Pomodoro Timer ✅',
      'Habit Tracker ✅',
      'Manual Logging ✅',
      'Unlimited journal entries ✅',
      'Journal sharing ✅',
      'Custom templates ✅',
      'Insights ✅',
    ],
    notes: <String>[
      'Custom templates save normally',
      'Unlimited journal sharing',
    ],
  );

  static const List<PlanBenefits> allPaidPlans = <PlanBenefits>[plus];

  static const List<PlanBenefits> allPlans = <PlanBenefits>[free, plus];

  static String normalize(dynamic tier) {
    return (tier ?? '').toString().trim().toLowerCase();
  }

  static MbPlanTier resolveTier(dynamic rawTier) {
    final normalized = normalize(rawTier);
    if (normalized.isEmpty || normalized == 'pending') {
      return MbPlanTier.pending;
    }

    for (final plan in allPlans) {
      if (plan.normalizedAliases.contains(normalized)) {
        return plan.tier;
      }
    }
    return MbPlanTier.free;
  }

  static PlanBenefits forTier(MbPlanTier tier) {
    switch (tier) {
      case MbPlanTier.free:
        return free;
      case MbPlanTier.plusSupport:
        return plus;
      case MbPlanTier.pending:
        return free;
    }
  }

  static PlanBenefits fromRaw(dynamic rawTier) {
    return forTier(resolveTier(rawTier));
  }

  static String databaseTierFor(MbPlanTier tier) {
    switch (tier) {
      case MbPlanTier.pending:
        return 'pending';
      case MbPlanTier.free:
        return 'free';
      case MbPlanTier.plusSupport:
        return 'plus';
    }
  }
}
