import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/legal/legal_document_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/subscription/subscription_plan_section.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  static const _termsVersion = '2026-03-02';
  static const _privacyVersion = '2026-03-02';
  static const _termsVersionKey = 'terms_version';
  static const _privacyVersionKey = 'privacy_version';
  static const _termsAcceptedAtKey = 'terms_accepted_at';
  static const _privacyAcceptedAtKey = 'privacy_accepted_at';

  bool _busy = false;
  bool _loadingAcceptance = true;
  bool _acceptedLegal = false;

  @override
  void initState() {
    super.initState();
    OnboardingController.markFeaturesSeen();
    _loadAcceptance();
  }

  Future<void> _loadAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final localAccepted =
        prefs.getString(_termsVersionKey) == _termsVersion &&
        prefs.getString(_privacyVersionKey) == _privacyVersion &&
        (prefs.getString(_termsAcceptedAtKey)?.isNotEmpty ?? false) &&
        (prefs.getString(_privacyAcceptedAtKey)?.isNotEmpty ?? false);

    var accepted = localAccepted;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select(
              'terms_version,terms_accepted_at,privacy_version,privacy_accepted_at',
            )
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          final termsVersion = (profile['terms_version'] ?? '').toString();
          final privacyVersion = (profile['privacy_version'] ?? '').toString();
          final termsAcceptedAt = (profile['terms_accepted_at'] ?? '')
              .toString();
          final privacyAcceptedAt = (profile['privacy_accepted_at'] ?? '')
              .toString();
          final profileAccepted =
              termsVersion == _termsVersion &&
              privacyVersion == _privacyVersion &&
              termsAcceptedAt.isNotEmpty &&
              privacyAcceptedAt.isNotEmpty;
          accepted = accepted || profileAccepted;
        }
      } catch (_) {
        // Keep local fallback only.
      }
    }

    if (!mounted) return;
    setState(() {
      _acceptedLegal = accepted;
      _loadingAcceptance = false;
    });
  }

  Future<void> _persistLegalAcceptance() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_termsVersionKey, _termsVersion);
    await prefs.setString(_privacyVersionKey, _privacyVersion);
    await prefs.setString(_termsAcceptedAtKey, nowIso);
    await prefs.setString(_privacyAcceptedAtKey, nowIso);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'terms_version': _termsVersion,
        'terms_accepted_at': nowIso,
        'privacy_version': _privacyVersion,
        'privacy_accepted_at': nowIso,
      });
    } catch (_) {
      // Local backup already persisted.
    }
  }

  void _showTermsRequiredSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please accept the Terms & Conditions at the bottom to continue.',
        ),
      ),
    );
  }

  Future<void> _trySelectPlan(PlanBenefits plan) async {
    if (_busy) return;
    if (!_acceptedLegal) {
      _showTermsRequiredSnack();
      return;
    }
    await _setPlan(plan);
  }

  Future<void> _setPlan(PlanBenefits plan) async {
    if (_busy) return;
    setState(() => _busy = true);

    final user = Supabase.instance.client.auth.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await _persistLegalAcceptance();
      if (user != null) {
        await _ensureProfileRowExists();
        final dbTier = SubscriptionPlanCatalog.databaseTierFor(plan.tier);
        debugPrint(
          '[PlanSelection] save start userId=${user.id} uiTier=${plan.tier.name} dbTier=$dbTier',
        );
        try {
          await Supabase.instance.client.rpc(
            'set_my_subscription_plan',
            params: {
              'p_tier': dbTier,
              'p_terms_version': _termsVersion,
              'p_terms_accepted_at': nowIso,
              'p_privacy_version': _privacyVersion,
              'p_privacy_accepted_at': nowIso,
            },
          );
        } on PostgrestException catch (e) {
          final lowered = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
          final rpcMissing =
              e.code == 'PGRST202' ||
              lowered.contains('set_my_subscription_plan');
          if (!rpcMissing && !_isMissingLegalColumnsError(e)) rethrow;
          await _savePlanWithLegacyFallback(
            user.id,
            user.email,
            dbTier,
            nowIso,
          );
        }
        final refreshedProfile = await Supabase.instance.client
            .from('profiles')
            .select('subscription_tier,subscription_completed,completed_at')
            .eq('id', user.id)
            .maybeSingle();
        final persistedTier = SubscriptionPlanCatalog.normalize(
          refreshedProfile?['subscription_tier'],
        );
        final persistedCompleted =
            refreshedProfile?['subscription_completed'] == true;
        if (kDebugMode) {
          debugPrint(
            '[PlanSelection] post-save userId=${user.id} subscription_tier=$persistedTier subscription_completed=$persistedCompleted completed_at=${refreshedProfile?['completed_at']}',
          );
        }
        if (persistedTier != dbTier) {
          throw const FormatException('subscription_tier_not_persisted');
        }
        if (!persistedCompleted) {
          if (kDebugMode) {
            debugPrint(
              '[PlanSelection] repairing missing subscription_completed for userId=${user.id}',
            );
          }
          await Supabase.instance.client
              .from('profiles')
              .update({'subscription_completed': true, 'completed_at': nowIso})
              .eq('id', user.id);
        }
      }
      await OnboardingController.setPlanCompleted(true);
      await CompletionGateRepository.markSubscriptionCompleted();
      if (user != null) {
        StartupUserDataService.instance.invalidateUser(user.id);
        await StartupUserDataService.instance.fetchCombinedForUser(user.id);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('trial_banner_dismissed', true);
      if (!mounted) return;
      context.go('/bootstrap');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final message = e.code == '23514'
          ? 'That plan could not be saved right now. Please try again in a moment.'
          : 'Could not save your plan right now. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      final message =
          e is FormatException && e.message == 'subscription_tier_not_persisted'
          ? 'That plan did not save correctly. Please try again.'
          : 'Could not save your plan right now. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isMissingLegalColumnsError(PostgrestException e) {
    final msg = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
    if (e.code == 'PGRST204') return true;
    return msg.contains('privacy_accepted_at') ||
        msg.contains('privacy_version') ||
        msg.contains('subscription_completed') ||
        msg.contains('completed_at') ||
        msg.contains('terms_accepted_at') ||
        msg.contains('terms_version');
  }

  Future<void> _ensureProfileRowExists() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.rpc('ensure_my_profile');
      return;
    } catch (_) {
      // Fall through to a direct existence check for older environments.
    }

    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    await client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'subscription_tier': 'free',
      'subscription_status': 'inactive',
    }, onConflict: 'id');
  }

  Future<void> _savePlanWithLegacyFallback(
    String userId,
    String? email,
    String dbTier,
    String nowIso,
  ) async {
    final client = Supabase.instance.client;
    final fullPayload = <String, dynamic>{
      'id': userId,
      'email': email,
      'subscription_tier': dbTier,
      'subscription_status': dbTier == 'free' ? 'inactive' : 'active',
      'subscription_completed': true,
      'terms_version': _termsVersion,
      'terms_accepted_at': nowIso,
      'privacy_version': _privacyVersion,
      'privacy_accepted_at': nowIso,
    };

    try {
      final updated = await client
          .from('profiles')
          .update(fullPayload)
          .eq('id', userId)
          .select('id')
          .maybeSingle();
      if (updated != null) {
        return;
      }
    } on PostgrestException catch (e) {
      if (!_isMissingLegalColumnsError(e)) {
        rethrow;
      }
    }

    try {
      await client.from('profiles').upsert(fullPayload, onConflict: 'id');
      return;
    } on PostgrestException catch (e) {
      if (!_isMissingLegalColumnsError(e)) {
        rethrow;
      }
    }

    final compatibilityPayload = <String, dynamic>{
      'id': userId,
      'email': email,
      'subscription_tier': dbTier,
      'subscription_status': dbTier == 'free' ? 'inactive' : 'active',
    };
    await client
        .from('profiles')
        .upsert(compatibilityPayload, onConflict: 'id');
  }

  Future<void> _openLegalDoc(String title, String path) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, assetPath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canChoosePlan = _acceptedLegal && !_busy && !_loadingAcceptance;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text(SubscriptionPlanCatalog.title),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SubscriptionPlanSection(
            title: 'Choose your mode',
            subtitle:
                'A softer, simpler comparison to help you finish setup. You can update this later in Subscriptions.',
            plans: SubscriptionPlanCatalog.allPlans,
            ctaLabelBuilder: (plan) => plan.tier == MbPlanTier.free
                ? 'Choose Free Mode'
                : 'Choose Plus Support Mode',
            onPlanTap: (plan) =>
                () => _trySelectPlan(plan),
            isPlanEnabled: (_) => canChoosePlan,
            footer: _loadingAcceptance
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.88),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      'Plus Support Mode includes everything in Free Mode, plus Insights, Make Your Own Quotes, Gratitude Bubble, Study Buddy, unlimited themes, custom theme creation, and unlimited devices.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedLegal,
                onChanged: _loadingAcceptance
                    ? null
                    : (checked) =>
                          setState(() => _acceptedLegal = checked ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        const TextSpan(
                          text: 'By continuing, you agree to the ',
                        ),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openLegalDoc(
                              'Terms & Conditions',
                              'assets/legal/terms.md',
                            ),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openLegalDoc(
                              'Privacy Policy',
                              'assets/legal/privacy.md',
                            ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
