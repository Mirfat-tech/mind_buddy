import 'package:flutter/material.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/onboarding/plan_required_screen.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class PlusFeatureGateScreen extends StatelessWidget {
  const PlusFeatureGateScreen({
    super.key,
    required this.title,
    required this.message,
    required this.child,
  });

  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionInfo>(
      future: SubscriptionLimits.fetchForCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MbScaffold(
            applyBackground: true,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final info = snapshot.data;
        if (info != null && info.isPlus) {
          return child;
        }

        return PlanRequiredScreen(title: title, message: message);
      },
    );
  }
}
