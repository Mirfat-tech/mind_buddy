import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/features/coming_soon/coming_soon_page.dart';

const bool bubblePoolEnabledForLaunch = false;
const bool bubbleCoinsEnabledForLaunch = bubblePoolEnabledForLaunch;

class BubbleComingSoonContent {
  const BubbleComingSoonContent({
    required this.featureKey,
    required this.appBarTitle,
    required this.title,
    required this.bodyText,
    required this.bottomCardText,
  });

  final String featureKey;
  final String appBarTitle;
  final String title;
  final String bodyText;
  final String bottomCardText;
}

BubbleComingSoonContent resolveBubbleComingSoonContent(String featureKey) {
  switch (featureKey) {
    case 'bubble_coins':
      return const BubbleComingSoonContent(
        featureKey: 'bubble_coins',
        appBarTitle: 'Bubble Coins',
        title: 'Coming soon',
        bodyText:
            'We’re creating something special for your bubbles.\nIt’s in the making!',
        bottomCardText:
            'Thanks for your patience.\nMore ways to grow, collect and enjoy are on the way. 💗',
      );
    case 'habit_bubble':
      return const BubbleComingSoonContent(
        featureKey: 'habit_bubble',
        appBarTitle: 'Habit Bubble',
        title: 'Coming soon',
        bodyText:
            'Good things take time.\nMore mindful features are blooming soon. 🌱',
        bottomCardText:
            'Thanks for your patience.\nMore ways to grow, collect and enjoy are on the way. 💗',
      );
    case 'pomodoro_bubble':
      return const BubbleComingSoonContent(
        featureKey: 'pomodoro_bubble',
        appBarTitle: 'Pomodoro Bubble',
        title: 'Coming soon',
        bodyText: 'Great focus deserves gentle tools.\nMore is on the way. 💜',
        bottomCardText:
            'Thanks for your patience.\nMore ways to grow, collect and enjoy are on the way. 💗',
      );
    case 'bubble_pool':
    default:
      return const BubbleComingSoonContent(
        featureKey: 'bubble_pool',
        appBarTitle: 'Bubble Pool',
        title: 'Coming soon',
        bodyText:
            'We’re creating something special for your bubbles.\nIt’s in the making!',
        bottomCardText:
            'Thanks for your patience.\nMore ways to grow, collect and enjoy are on the way. 💗',
      );
  }
}

ComingSoonPage buildBubbleComingSoonPage(String featureKey) {
  final content = resolveBubbleComingSoonContent(featureKey);
  return ComingSoonPage(
    featureKey: content.featureKey,
    appBarTitle: content.appBarTitle,
    title: content.title,
    bodyText: content.bodyText,
    bottomCardText: content.bottomCardText,
  );
}

void openBubblePoolLaunchAware(
  BuildContext context, {
  String featureKey = 'bubble_pool',
}) {
  if (bubblePoolEnabledForLaunch) {
    context.go('/bubble-pool');
    return;
  }
  debugPrint('BUBBLE_POOL_DISABLED_FOR_LAUNCH_SHOW_COMING_SOON');
  context.go('/coming-soon/$featureKey');
}

void openBubbleCoinsLaunchAware(
  BuildContext context, {
  String featureKey = 'bubble_coins',
}) {
  debugPrint('BUBBLE_COIN_DISABLED_FOR_LAUNCH');
  context.go('/coming-soon/$featureKey');
}
