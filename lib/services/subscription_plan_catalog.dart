import 'package:flutter/foundation.dart';

enum MbPlanTier { pending, free, plusSupport }

@immutable
class PlanBenefits {
  const PlanBenefits({
    required this.tier,
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
    required this.toolsHeading,
    required this.tools,
    this.plusExtras = const <String>[],
    this.summary = '',
    this.caption = '',
  });

  final MbPlanTier tier;
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

  final String toolsHeading;
  final List<String> tools;
  final List<String> plusExtras;
  final String summary;
  final String caption;

  bool get includesEverythingInFreeMode => tier == MbPlanTier.plusSupport;

  String get titleWithPrice => price.isEmpty ? name : '$name ($price)';
}

class SubscriptionPlanCatalog {
  static const String title = 'Subscriptions';

  static const String previewModeHelpText =
      'Choose the mode that fits you best. Everything is kept simple, clear, and easy to come back to.';

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
    name: 'Free Mode',
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
    toolsHeading: 'Tools included',
    tools: <String>[
      'Brainfog Bubble',
      'Pomodoro Bubble',
      'Habit Bubble',
      'Logs / Templates',
      'Unlimited journal entries',
      'Unlimited journal sharings',
      'Custom templates',
      'Does not include Insights',
      'Does not include Make Your Own Quotes',
      'Does not include Gratitude Bubble',
      'Up to 2 themes in Theme Selector',
      '1 device only',
      'Does not include Study Buddy feature',
    ],
    summary:
        'A calm starting point with the core bubbles, journaling, and templates.',
    caption: 'Simple, gentle, and easy to scan.',
  );

  static const PlanBenefits plus = PlanBenefits(
    tier: MbPlanTier.plusSupport,
    name: 'Plus Support Mode',
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
    toolsHeading: 'Everything in Free Mode, plus',
    tools: <String>[
      'Includes Insights',
      'Includes Make Your Own Quotes',
      'Includes Gratitude Bubble',
      'Study Buddy feature',
      'Unlimited themes',
      'Create your own theme',
      'Unlimited devices',
    ],
    plusExtras: <String>[
      'Includes Insights',
      'Includes Make Your Own Quotes',
      'Includes Gratitude Bubble',
      'Study Buddy feature',
      'Unlimited themes',
      'Create your own theme',
      'Unlimited devices',
    ],
    summary:
        'Everything in Free Mode with more room to personalise, reflect, and use across devices.',
    caption: 'Best for a fuller MyBrainBubble setup.',
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
