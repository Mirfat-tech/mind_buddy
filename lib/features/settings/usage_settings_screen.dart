import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class UsageSettingsScreen extends StatefulWidget {
  const UsageSettingsScreen({super.key});

  @override
  State<UsageSettingsScreen> createState() => _UsageSettingsScreenState();
}

class _UsageSettingsScreenState extends State<UsageSettingsScreen> {
  late Future<_UsageSummary> _future;

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

  Future<_UsageSummary> _loadUsageSummary() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User is not signed in.');
    }

    final info = await SubscriptionLimits.fetchForCurrentUser();
    final deviceCountResponse = await client
        .from('user_devices')
        .select()
        .eq('user_id', user.id)
        .count();
    final journalCountResponse = await client
        .from('journals')
        .select()
        .eq('user_id', user.id)
        .count();

    return _UsageSummary(
      plan: info,
      deviceCount: deviceCountResponse.count,
      journalCount: journalCountResponse.count,
    );
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_UsageSummary>(
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

            final usage = snapshot.data!;
            final planInfo = usage.plan;
            final plan = planInfo.plan;
            final tierLabel = planInfo.isPending ? 'FREE MODE' : plan.name;
            final deviceLimit = planInfo.deviceLimit;
            final deviceCount = usage.deviceCount;
            final journalCount = usage.journalCount;
            final deviceValue = deviceLimit < 0
                ? '$deviceCount / Unlimited'
                : '$deviceCount / $deviceLimit';
            final deviceSubtitle = deviceLimit < 0
                ? '${plan.name} allows unlimited devices.'
                : '${plan.name} allows up to $deviceLimit devices.';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Usage & Plan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Current Plan',
                  value: '$tierLabel (${plan.price})',
                  subtitle: plan.insights
                      ? 'Insights are enabled on this plan.'
                      : 'Upgrade to Plus Support Mode for insights.',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Journal Entries',
                  value: '$journalCount / Unlimited',
                  subtitle: 'Unlimited journaling is included.',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Journal Sharing',
                  value: 'Unlimited',
                  subtitle: 'Unlimited journal sharing is included.',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Devices',
                  value: deviceValue,
                  subtitle: deviceSubtitle,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
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

class _UsageSummary {
  const _UsageSummary({
    required this.plan,
    required this.deviceCount,
    required this.journalCount,
  });

  final SubscriptionInfo plan;
  final int deviceCount;
  final int journalCount;
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.title, required this.value, this.subtitle});

  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
