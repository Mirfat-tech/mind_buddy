import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';

/// Subscription Upgrade Screen
/// Beautiful bubble aesthetic matching Brain Fog design
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentTier = 'standard';
  bool _loading = true;
  bool _upgrading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTier();
  }

  Future<void> _loadCurrentTier() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _currentTier = profile?['subscription_tier'] ?? 'standard';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tier: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upgradeTier(String newTier) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _upgrading = true);

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'subscription_tier': newTier,
            'subscription_start_date': newTier == 'full'
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          _currentTier = newTier;
          _upgrading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newTier == 'full'
                  ? '🏆 Welcome to Full Support! Unlimited chats, 100 messages/day, 10 journals/day, templates + insights.'
                  : 'Switched to Light Support: 1 chat/day, 10 messages/day.',
            ),
            backgroundColor: newTier == 'full'
                ? Colors.amber.shade700
                : Colors.grey.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error upgrading: $e');
      if (mounted) {
        setState(() => _upgrading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFull = _currentTier == 'full';
    final isLight = _currentTier == 'light';
    final isPending = _currentTier == 'pending' || _currentTier.isEmpty;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                children: [
                  _buildStatusBubble(cs, isFull, isPending),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 520,
                    child: PageView(
                      controller: PageController(viewportFraction: 0.88),
                      padEnds: true,
                      children: [
                        _buildPlanBubble(
                          cs: cs,
                          title: 'Light Support',
                          price: '\$3.99/mo',
                          features: [
                            '1 chat/day',
                            '10 msg/day',
                            '3 journal entries/day',
                            'Built-in templates only',
                            '1 device',
                            'No insights',
                            'No data saved on trial',
                          ],
                          isGold: false,
                          isCurrent: isLight,
                          onTap: isFull ? () => _showDowngradeDialog() : null,
                        ),
                        _buildPlanBubble(
                          cs: cs,
                          title: 'Full Support',
                          price: '\$9.99/mo',
                          features: [
                            'Unlimited chats',
                            '100 msg/day',
                            '10 journal entries/day',
                            'Create templates',
                            'Up to 5 devices',
                            'Insights access',
                            'Data is saved',
                          ],
                          isGold: true,
                          isCurrent: isFull,
                          onTap: !isFull ? () => _upgradeTier('full') : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBubble(ColorScheme cs, bool isGold, bool isPending) {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface.withOpacity(0.7),
        boxShadow: [
          BoxShadow(
            color: isGold
                ? Colors.amber.withOpacity(0.4)
                : cs.primary.withOpacity(0.3),
            blurRadius: 20,
            blurStyle: BlurStyle.outer,
          ),
        ],
        border: Border.all(
          color: isPending
              ? cs.outline.withOpacity(0.3)
              : isGold
                  ? Colors.amber.withOpacity(0.3)
                  : cs.primary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPending
                ? Icons.lock_outline
                : isGold
                    ? Icons.workspace_premium
                    : Icons.person_outline,
            color: isPending
                ? cs.onSurface.withOpacity(0.6)
                : isGold
                    ? Colors.amber.shade700
                    : cs.primary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            isPending ? 'Choose a Plan' : (isGold ? 'Full Support 🏆' : 'Light Support'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
            maxLines: 2,
          ),
          Text(
            'Current',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8, color: cs.onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBubble({
    required ColorScheme cs,
    required String title,
    required String price,
    required List<String> features,
    required bool isGold,
    required bool isCurrent,
    required VoidCallback? onTap,
  }) {
    final bubbleColor = isGold ? Colors.amber.shade50 : cs.surface;
    final glowColor = isGold ? Colors.amber : cs.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 340.0);
        return Center(
          child: GestureDetector(
            onTap: isCurrent || _upgrading ? null : onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bubbleColor.withOpacity(0.6),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.4),
                      blurRadius: 25,
                      blurStyle: BlurStyle.outer,
                    ),
                  ],
                  border: Border.all(
                    color: isCurrent
                        ? glowColor.withOpacity(0.6)
                        : glowColor.withOpacity(0.2),
                    width: isCurrent ? 3 : 2,
                  ),
                ),
                child: ClipOval(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isGold ? Icons.workspace_premium : Icons.star_outline,
                          color: isGold ? Colors.amber.shade700 : cs.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          price,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isGold ? Colors.amber.shade800 : cs.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...features.map(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              feature,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isGold ? Colors.amber.shade700 : cs.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: _upgrading
                                ? const SizedBox(
                                    height: 12,
                                    width: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isGold ? 'Upgrade 🏆' : 'Downgrade',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Current',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDowngradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Downgrade to Light Support?'),
        content: const Text(
          'You\'ll go from 100 messages per day down to just 10. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _upgradeTier('standard');
            },
            child: const Text('Downgrade', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
