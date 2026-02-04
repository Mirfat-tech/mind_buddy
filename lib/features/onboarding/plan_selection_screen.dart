import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  bool _busy = false;

  Future<void> _setPlan(String tier) async {
    if (_busy) return;
    setState(() => _busy = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/signin');
      return;
    }

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'subscription_tier': tier,
      });
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save plan: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Choose your plan'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick a plan to continue',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You can upgrade anytime from Settings.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _PlanCard(
              title: 'Light Support',
              subtitle:
                  '1 chat/day • 10 msgs/day • 3 journals/day • 1 device',
              onTap: _busy ? null : () => _setPlan('light'),
            ),
            const SizedBox(height: 12),
            _PlanCard(
              title: 'Full Support',
              subtitle:
                  'Unlimited chats • 100 msgs/day • 10 journals/day • 5 devices • Insights',
              highlight: true,
              onTap: _busy ? null : () => _setPlan('full'),
            ),
            const Spacer(),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                'By continuing you agree to our Terms.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/signin'),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight
                ? scheme.primary.withOpacity(0.5)
                : scheme.outline.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(highlight ? 0.18 : 0.08),
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
