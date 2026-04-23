import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/subscription/subscription_plan_section.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class UsageSettingsScreen extends StatefulWidget {
  const UsageSettingsScreen({super.key});

  @override
  State<UsageSettingsScreen> createState() => _UsageSettingsScreenState();
}

class _UsageSettingsScreenState extends State<UsageSettingsScreen> {
  static const List<String> _freeModeIncluded = <String>[
    'Brainfog Bubble',
    'Pomodoro Bubble',
    'Habit Bubble',
    'Logs / Templates',
    'Unlimited journal entries',
    'Unlimited journal sharing',
    'Custom templates',
    'Up to 2 themes in Theme Selector',
    '1 device only',
  ];

  static const List<String> _plusModeIncluded = <String>[
    'Brainfog Bubble',
    'Pomodoro Bubble',
    'Habit Bubble',
    'Logs / Templates',
    'Unlimited journal entries',
    'Unlimited journal sharing',
    'Custom templates',
    'Study Buddy',
    'Insights',
    'Gratitude Bubble',
    'Make Your Own Quotes',
    'Unlimited themes',
    'Create your own theme',
    'Unlimited devices',
  ];

  static const List<String> _plusOnlyFeatures = <String>[
    'Study Buddy',
    'Insights',
    'Gratitude Bubble',
    'Make Your Own Quotes',
    'Unlimited themes',
    'Create your own theme',
    'Unlimited devices',
  ];

  late Future<SubscriptionInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadUsageSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadUsageSummary();
    });
    await _future;
  }

  Future<SubscriptionInfo> _loadUsageSummary() async {
    return SubscriptionLimits.fetchForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Usage & Plan'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<SubscriptionInfo>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Could not load usage right now.',
                    style: TextStyle(color: scheme.error),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              );
            }

            final planInfo = snapshot.data!;
            final isPlus = planInfo.isPlus;
            final planTitle = isPlus
                ? 'Plus Support Mode (£2.99)'
                : 'Free Mode';
            final planSubtitle = isPlus
                ? 'You have full access to Plus features'
                : 'You’re currently using the free version';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PlanOverviewCard(title: planTitle, subtitle: planSubtitle),
                const SizedBox(height: 16),
                _FeatureSectionCard(
                  title: 'What you have ✨',
                  items: isPlus ? _plusModeIncluded : _freeModeIncluded,
                  accent: const Color(0xFFF2FBF8),
                ),
                const SizedBox(height: 16),
                if (isPlus)
                  _FeatureSectionCard(
                    title: 'Free mode doesn’t include',
                    items: _plusOnlyFeatures,
                    accent: scheme.surface.withValues(alpha: 0.82),
                    highlighted: false,
                    locked: true,
                  )
                else
                  const _FeatureSectionCard(
                    title: 'Unlock with Plus ✨',
                    items: _plusOnlyFeatures,
                    locked: true,
                    subtitle:
                        'A softer upgrade path with more support, more expression, and more room to grow.',
                    accent: Color(0xFFF1EAFF),
                    highlighted: true,
                  ),
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.primary,
                    side: BorderSide(color: scheme.primary),
                  ),
                  onPressed: () => context.go('/subscription'),
                  child: const Text('Manage subscription'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanOverviewCard extends StatelessWidget {
  const _PlanOverviewCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFF2FFF8),
            Color(0xFFF1EAFF),
            Color(0xFFFFF1F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Plan', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _FeatureSectionCard extends StatelessWidget {
  const _FeatureSectionCard({
    required this.title,
    required this.items,
    this.subtitle,
    this.highlighted = false,
    this.accent,
    this.locked = false,
  });

  final String title;
  final List<String> items;
  final String? subtitle;
  final bool highlighted;
  final Color? accent;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        accent ??
        (highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.70)
            : scheme.surface);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.20)
              : scheme.outline.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: (highlighted ? scheme.primary : scheme.shadow).withValues(
              alpha: highlighted ? 0.10 : 0.06,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          SubscriptionFeatureList(
            items: items,
            featured: highlighted,
            forceLocked: locked,
            compact: true,
          ),
        ],
      ),
    );
  }
}
