import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/services/mind_buddy_api.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';

class UsageSettingsScreen extends StatefulWidget {
  const UsageSettingsScreen({super.key});

  @override
  State<UsageSettingsScreen> createState() => _UsageSettingsScreenState();
}

class _UsageSettingsScreenState extends State<UsageSettingsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = MindBuddyEnhancedApi().getChatUsageSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = MindBuddyEnhancedApi().getChatUsageSummary();
    });
    await _future;
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
        child: FutureBuilder<Map<String, dynamic>>(
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
            final planName = (usage['planName'] ?? 'FREE MODE').toString();
            final plan = SubscriptionPlanCatalog.fromRaw(
              usage['normalizedTier'],
            );
            final messageCount = usage['messageCount'] as int? ?? 0;
            final messageLimit = usage['messageLimit'] as int? ?? 0;
            final chatCount = usage['chatCount'] as int? ?? 0;
            final chatLimit = usage['chatLimit'] as int? ?? plan.dailyChats;
            final journalCount = usage['journalCount'] as int? ?? 0;
            final journalLimit = usage['journalLimit'] as int? ?? 0;
            final deviceCount = usage['deviceCount'] as int? ?? 0;
            final deviceLimit = usage['deviceLimit'] as int? ?? 0;
            final dayId = usage['dayId'] as String? ?? '';

            final isPending = usage['isPending'] == true;
            final tierLabel = isPending ? 'FREE MODE' : planName;
            final chatLimitLabel = chatLimit.toString();

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
                  subtitle: dayId.isEmpty ? null : 'Today: $dayId',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'AI Chats Today',
                  value: '$messageCount / $messageLimit',
                  subtitle: isPending
                      ? 'FREE MODE includes no AI chats.'
                      : '${plan.name} includes $messageLimit AI chats per day.',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Conversations Started',
                  value: '$chatCount / $chatLimitLabel',
                  subtitle: isPending
                      ? 'FREE MODE includes no AI chats.'
                      : '${plan.name} allows $chatLimitLabel chats per day.',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Journal Entries Today',
                  value: journalLimit < 0
                      ? '$journalCount / Unlimited'
                      : '$journalCount / $journalLimit',
                  subtitle: 'Unlimited journal entries are included.',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Devices',
                  value: '$deviceCount / $deviceLimit',
                  subtitle: '${plan.name} allows up to $deviceLimit devices.',
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

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.title,
    required this.value,
    this.subtitle,
  });

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
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
