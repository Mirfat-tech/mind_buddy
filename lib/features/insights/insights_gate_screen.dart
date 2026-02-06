import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/insights/insights_screen.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class InsightsGateScreen extends StatelessWidget {
  const InsightsGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionInfo>(
      future: SubscriptionLimits.fetchForCurrentUser(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MbScaffold(
            applyBackground: true,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final info = snap.data;
        if (info != null && info.isFull) {
          return const InsightsScreen();
        }

        return MbScaffold(
          applyBackground: true,
          appBar: AppBar(
            title: const Text('Insights'),
            centerTitle: true,
            leading: MbGlowBackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Insights are available on Full Support',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upgrade to unlock insights, trends, and summaries.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/subscription'),
                    child: const Text('Upgrade'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
