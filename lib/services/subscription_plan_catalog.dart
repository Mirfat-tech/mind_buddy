import 'package:flutter/foundation.dart';

enum MbPlanTier { pending, free, lightSupport, plusSupport, fullSupport }

@immutable
class PlanBenefits {
  const PlanBenefits({
    required this.tier,
    required this.emoji,
    required this.name,
    required this.price,
    required this.normalizedAliases,
    required this.dailyChats,
    required this.replyStyle,
    required this.voiceChatsPerDay,
    required this.longTermMemory,
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

  final int dailyChats;
  final String replyStyle;
  final int voiceChatsPerDay;
  final bool longTermMemory;
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

  bool get hasAi => dailyChats > 0;
  bool get hasVoice => voiceChatsPerDay > 0;

  String get titleWithPrice => '$name ($price)';
  String get heading => '$emoji $name ($price)';
}

class SubscriptionPlanCatalog {
  static const String title = '🟣 MB - Subscriptions';

  static const List<String> comparisonSectionOrder = <String>[
    'AI',
    'Devices',
    'Templates',
    'Journaling',
    'Tools Included',
  ];

  static const String previewModeHelpText =
      '24-hour preview mode: You can try and edit templates, but preview data disappears after 24 hours unless your plan supports permanent saves.';

  static String sharesPerDayHelpText(PlanBenefits plan) {
    if (!plan.canShareEntries) {
      return '${plan.name} cannot share entries yet.';
    }
    if (plan.sharesPerDay < 0) {
      return '${plan.name} includes unlimited shares per day.';
    }
    return '${plan.name} includes ${plan.sharesPerDay} ${plan.sharesPerDay == 1 ? 'share' : 'shares'} per day.';
  }

  static String voiceChatsHelpText(PlanBenefits plan) {
    if (plan.voiceChatsPerDay <= 0) {
      return 'Voice chats are available in FULL SUPPORT MODE (20 voice chats per day).';
    }
    return '${plan.name} includes ${plan.voiceChatsPerDay} voice chats per day.';
  }

  static String deviceLimitHelpText(PlanBenefits plan) {
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
    normalizedAliases: <String>[
      'free',
      'free_mode',
      'free mode',
      'basic',
    ],
    dailyChats: 0,
    replyStyle: 'No AI replies',
    voiceChatsPerDay: 0,
    longTermMemory: false,
    insights: false,
    devices: 1,
    canCreateCustomTemplates: false,
    templatesPreviewMode: true,
    coreTemplatesSaveForever: false,
    canJournal: true,
    canShareEntries: false,
    sharesPerDay: 0,
    canReceiveUnlimitedShares: true,
    tools: <String>[
      'Brain Fog Bubble ✅',
      'Pomodoro Timer ✅',
      'Habit Tracker ✅',
      'Manual Logging ✅',
      'Unlimited journal entries ✅',
    ],
    notes: <String>[
      'Core templates: preview only (data not saved permanently)',
      'Data disappears after 24 hours ("24-hour preview mode")',
    ],
  );

  static const PlanBenefits light = PlanBenefits(
    tier: MbPlanTier.lightSupport,
    emoji: '🔵',
    name: 'LIGHT SUPPORT MODE',
    price: '£4.99',
    normalizedAliases: <String>[
      'light',
      'light_support',
      'light support',
      'light_support_mode',
      'light support mode',
    ],
    dailyChats: 10,
    replyStyle: 'Short-medium replies',
    voiceChatsPerDay: 0,
    longTermMemory: false,
    insights: false,
    devices: 1,
    canCreateCustomTemplates: false,
    templatesPreviewMode: true,
    coreTemplatesSaveForever: true,
    canJournal: true,
    canShareEntries: true,
    sharesPerDay: 1,
    canReceiveUnlimitedShares: true,
    tools: <String>[
      'Brain Fog Bubble ✅',
      'Pomodoro Timer ✅',
      'Habit Tracker ✅',
      'Manual Logging ✅',
      'Unlimited journal entries ✅',
    ],
    notes: <String>[
      'Data disappears after 24 hours ("24-hour preview mode")',
      'Core templates save forever and show in calendar',
    ],
  );

  static const PlanBenefits plus = PlanBenefits(
    tier: MbPlanTier.plusSupport,
    emoji: '🟣',
    name: 'PLUS SUPPORT MODE',
    price: '£9.99',
    normalizedAliases: <String>[
      'plus',
      'plus_support',
      'plus support',
      'plus_support_mode',
      'plus support mode',
      'pro',
      'premium',
    ],
    dailyChats: 25,
    replyStyle: 'Slightly longer replies',
    voiceChatsPerDay: 0,
    longTermMemory: true,
    insights: false,
    devices: 3,
    canCreateCustomTemplates: true,
    templatesPreviewMode: false,
    coreTemplatesSaveForever: true,
    canJournal: true,
    canShareEntries: true,
    sharesPerDay: 5,
    canReceiveUnlimitedShares: true,
    tools: <String>[
      'Brain Fog Bubble ✅',
      'Pomodoro Timer ✅',
      'Habit Tracker ✅',
      'Manual Logging ✅',
      'Unlimited journal entries ✅',
    ],
    notes: <String>[
      'Can create and save custom templates',
      'Core templates save forever and show in calendar',
    ],
  );

  static const PlanBenefits full = PlanBenefits(
    tier: MbPlanTier.fullSupport,
    emoji: '🟡',
    name: 'FULL SUPPORT MODE',
    price: '£19.99',
    normalizedAliases: <String>[
      'full',
      'full_support',
      'full support',
      'full_support_mode',
      'full support mode',
    ],
    dailyChats: 50,
    replyStyle: 'Longer, more thoughtful replies',
    voiceChatsPerDay: 20,
    longTermMemory: true,
    insights: true,
    devices: 10,
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
    ],
    notes: <String>[
      'Can create and save custom templates',
      'Core templates save forever and show in calendar',
    ],
  );

  static const List<PlanBenefits> allPaidPlans = <PlanBenefits>[
    light,
    plus,
    full,
  ];

  static const List<PlanBenefits> allPlans = <PlanBenefits>[
    free,
    light,
    plus,
    full,
  ];

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
      case MbPlanTier.lightSupport:
        return light;
      case MbPlanTier.plusSupport:
        return plus;
      case MbPlanTier.fullSupport:
        return full;
      case MbPlanTier.pending:
        return free;
    }
  }

  static PlanBenefits fromRaw(dynamic rawTier) {
    return forTier(resolveTier(rawTier));
  }
}
