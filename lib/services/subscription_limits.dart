import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.rawTier,
    required this.tier,
    required this.plan,
    required this.isPending,
  });

  final String rawTier;
  final MbPlanTier tier;
  final PlanBenefits plan;
  final bool isPending;

  bool get isFree => tier == MbPlanTier.free;
  bool get isPlus => tier == MbPlanTier.plusSupport;
  bool get supportsInsights => plan.insights;
  bool get supportsCustomTemplates => plan.canCreateCustomTemplates;
  int get journalLimit =>
      -1; // Unlimited journal entries for every active plan.
  int get deviceLimit => isPending ? 0 : plan.devices;
  int get sharesPerDay => isPending ? 0 : plan.sharesPerDay;

  String get planName => plan.name;
  String get planNameWithPrice => plan.titleWithPrice;
}

class SubscriptionLimits {
  static const String trialUpgradeMessage =
      'Pick a BrainBubble mode to continue.';

  static Future<void> showTrialUpgradeDialog(
    BuildContext context, {
    VoidCallback? onUpgrade,
  }) async {
    final shouldForcePlan = await TrialTracker.recordTrialAction();
    if (shouldForcePlan && context.mounted) {
      GoRouter.of(context).go('/onboarding/plan');
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🟣 MB - Subscriptions'),
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
            child: const Text('View modes'),
          ),
        ],
      ),
    );
  }

  static String normalizeTier(dynamic tier) {
    return SubscriptionPlanCatalog.normalize(tier);
  }

  static bool isFullTier(dynamic tier) {
    return SubscriptionPlanCatalog.resolveTier(tier) == MbPlanTier.plusSupport;
  }

  static bool isPendingTier(dynamic tier) {
    return SubscriptionPlanCatalog.resolveTier(tier) == MbPlanTier.pending;
  }

  static SubscriptionInfo fromRawTier(dynamic rawTier) {
    final normalized = normalizeTier(rawTier);
    final tier = SubscriptionPlanCatalog.resolveTier(normalized);
    final plan = SubscriptionPlanCatalog.forTier(tier);
    return SubscriptionInfo(
      rawTier: SubscriptionPlanCatalog.databaseTierFor(tier),
      tier: tier,
      plan: plan,
      isPending: tier == MbPlanTier.pending,
    );
  }

  static Future<SubscriptionInfo> fetchForCurrentUser() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return fromRawTier('pending');
    }

    try {
      final res = await client.rpc('get_my_entitlement');
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      return fromRawTier(map?['subscription_tier'] ?? 'free');
    } on PostgrestException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'get_my_entitlement failed code=${e.code} message=${e.message} details=${e.details}',
        );
        debugPrint('$st');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('get_my_entitlement unexpected error: $e');
        debugPrint('$st');
      }
    }

    // Backward-compatible fallback while RPC rollout completes.
    try {
      final profile = await client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .maybeSingle();
      return fromRawTier(profile?['subscription_tier'] ?? 'free');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('profiles fallback entitlement read failed: $e');
        debugPrint('$st');
      }
      return fromRawTier('free');
    }
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

class VoiceUsageTracker {
  static const String _dayKey = 'voice_usage_day';
  static const String _countKey = 'voice_usage_count';

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<int> todayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final day = prefs.getString(_dayKey);
    if (day != today) {
      await prefs.setString(_dayKey, today);
      await prefs.setInt(_countKey, 0);
      return 0;
    }
    return prefs.getInt(_countKey) ?? 0;
  }

  static Future<int> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final day = prefs.getString(_dayKey);
    int next;
    if (day != today) {
      next = 1;
      await prefs.setString(_dayKey, today);
      await prefs.setInt(_countKey, next);
      return next;
    }
    next = (prefs.getInt(_countKey) ?? 0) + 1;
    await prefs.setInt(_countKey, next);
    return next;
  }
}

class JournalShareUsageTracker {
  static const String _dayKey = 'journal_share_day';
  static const String _countKey = 'journal_share_count';

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<int> todayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final day = prefs.getString(_dayKey);
    if (day != today) {
      await prefs.setString(_dayKey, today);
      await prefs.setInt(_countKey, 0);
      return 0;
    }
    return prefs.getInt(_countKey) ?? 0;
  }

  static Future<int> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final day = prefs.getString(_dayKey);
    int next;
    if (day != today) {
      next = 1;
      await prefs.setString(_dayKey, today);
      await prefs.setInt(_countKey, next);
      return next;
    }
    next = (prefs.getInt(_countKey) ?? 0) + 1;
    await prefs.setInt(_countKey, next);
    return next;
  }
}
