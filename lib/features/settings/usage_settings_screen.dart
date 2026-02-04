import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/mind_buddy_api.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
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
            final isFull = usage['isFull'] == true;
            final messageCount = usage['messageCount'] as int? ?? 0;
            final messageLimit = usage['messageLimit'] as int? ?? 0;
            final chatCount = usage['chatCount'] as int? ?? 0;
            final chatLimit = usage['chatLimit'] as int?;
            final journalCount = usage['journalCount'] as int? ?? 0;
            final journalLimit = usage['journalLimit'] as int? ?? 0;
            final deviceCount = usage['deviceCount'] as int? ?? 0;
            final deviceLimit = usage['deviceLimit'] as int? ?? 0;
            final dayId = usage['dayId'] as String? ?? '';

            final isPending = usage['isPending'] == true;
            final tierLabel = isPending
                ? 'Choose a plan'
                : (isFull ? 'Full Support' : 'Light Support');
            final chatLimitLabel =
                isFull ? 'Unlimited' : (chatLimit ?? 1).toString();

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
                  value: tierLabel,
                  subtitle: dayId.isEmpty ? null : 'Today: $dayId',
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Messages Today',
                  value: '$messageCount / $messageLimit',
                  subtitle: isPending
                      ? 'Pick a plan to start messaging.'
                      : (isFull
                          ? 'Full Support includes 100 total messages per day.'
                          : 'Light Support includes 10 total messages per day.'),
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Chats Today',
                  value: '$chatCount / $chatLimitLabel',
                  subtitle: isPending
                      ? 'Pick a plan to start chats.'
                      : (isFull
                          ? 'Full Support has no daily chat limit.'
                          : 'Light Support allows 1 chat per day.'),
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Journal Entries Today',
                  value: '$journalCount / $journalLimit',
                  subtitle: isPending
                      ? 'Pick a plan to start journaling.'
                      : (isFull
                          ? 'Full Support includes 10 journal entries per day.'
                          : 'Light Support includes 3 journal entries per day.'),
                ),
                const SizedBox(height: 12),
                _UsageCard(
                  title: 'Devices',
                  value: '$deviceCount / $deviceLimit',
                  subtitle: isFull
                      ? 'Full Support allows up to 5 devices.'
                      : 'Light Support allows 1 device.',
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => context.go('/subscription'),
                  child: const Text('Manage Subscription'),
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
