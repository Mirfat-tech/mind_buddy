import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.rawTier,
    required this.isFull,
    required this.isPending,
  });

  final String rawTier;
  final bool isFull;
  final bool isPending;

  int get messageLimit => isPending ? 0 : (isFull ? 100 : 10);
  int get chatLimit => isPending ? 0 : (isFull ? -1 : 1);
  int get journalLimit => isPending ? 0 : (isFull ? 10 : 3);
  int get deviceLimit => isFull ? 5 : 1;
}

class SubscriptionLimits {
  static const String trialUpgradeMessage =
      'Ready to use? Upgrade your subscription to start today ✨';

  static Future<void> showTrialUpgradeDialog(
    BuildContext context, {
    VoidCallback? onUpgrade,
  }) async {
    final shouldForcePlan = await TrialTracker.recordTrialAction();
    if (shouldForcePlan && context.mounted) {
      GoRouter.of(context).go('/onboarding/plan');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a plan'),
        content: const Text(trialUpgradeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onUpgrade != null) {
                onUpgrade();
              } else {
                GoRouter.of(context).go('/subscription');
              }
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
  static String normalizeTier(dynamic tier) {
    return (tier ?? '').toString().trim().toLowerCase();
  }

  static bool isFullTier(dynamic tier) {
    final normalized = normalizeTier(tier);
    return normalized == 'full' ||
        normalized == 'full_support' ||
        normalized == 'full support' ||
        normalized == 'full_support_mode' ||
        normalized == 'full support mode';
  }

  static bool isPendingTier(dynamic tier) {
    final normalized = normalizeTier(tier);
    return normalized.isEmpty || normalized == 'pending';
  }

  static Future<SubscriptionInfo> fetchForCurrentUser() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return const SubscriptionInfo(rawTier: '', isFull: false, isPending: true);
    }

    final profile = await client
        .from('profiles')
        .select('subscription_tier')
        .eq('id', user.id)
        .maybeSingle();

    final rawTier = profile?['subscription_tier'] ?? '';
    return SubscriptionInfo(
      rawTier: rawTier.toString(),
      isFull: isFullTier(rawTier),
      isPending: isPendingTier(rawTier),
    );
  }
}

class TrialTracker {
  static const String _countKey = 'trial_action_count';
  static const int threshold = 5;

  static Future<int> _getCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_countKey) ?? 0;
  }

  static Future<bool> recordTrialAction() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _getCount();
    final next = current + 1;
    await prefs.setInt(_countKey, next);
    return next >= threshold;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey);
  }
}
