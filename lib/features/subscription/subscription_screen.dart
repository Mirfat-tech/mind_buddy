import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/subscription_purchase_service.dart';

enum BillingPeriod { monthly, yearly }

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionPurchaseController _controller =
      SubscriptionPurchaseController();
  BillingPeriod _billingPeriod = BillingPeriod.monthly;
  String? _friendlyStoreError;

  static const Map<MbPlanTier, double> _fallbackMonthlyPrice = {
    MbPlanTier.plusSupport: 2.99,
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final rawError = _controller.error;
    if (rawError != null && rawError.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('Subscription store error: $rawError');
      }
      _friendlyStoreError =
          'Couldn\'t reach the store right now. Please try again.';
    } else {
      _friendlyStoreError = null;
    }
    setState(() {});
  }

  Future<void> _retryStore() async {
    setState(() => _friendlyStoreError = null);
    await _controller.loadProducts();
    await _controller.refreshEntitlement();
  }

  String _statusLabel() {
    final ent = _controller.entitlement;
    if (ent == null) return 'Loading';
    if (ent.isActive) return 'Active';
    if (ent.status == 'canceled' || ent.status == 'cancelled') {
      return 'Canceled';
    }
    if (ent.tier == 'pending') return 'No active mode';
    return ent.status;
  }

  String _dateLabel(DateTime? date, {required String fallback}) {
    if (date == null) return fallback;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  SubscriptionOffer? _offerForPlan(PlanBenefits plan, BillingPeriod period) {
    if (plan.tier == MbPlanTier.free) return null;
    final tierSlug = switch (plan.tier) {
      MbPlanTier.plusSupport => 'plus',
      MbPlanTier.free || MbPlanTier.pending => '',
    };
    final periodSlug = period == BillingPeriod.monthly ? 'monthly' : 'yearly';
    for (final offer in SubscriptionPurchaseController.catalog) {
      if (offer.tier == tierSlug && offer.period == periodSlug) {
        return offer;
      }
    }
    return null;
  }

  String _formatPrice(double amount) {
    return '£${amount.toStringAsFixed(2)}';
  }

  String _displayPrice(PlanBenefits plan, BillingPeriod period) {
    if (plan.tier == MbPlanTier.free) return '£0';

    final offer = _offerForPlan(plan, period);
    if (offer != null) {
      final product = _controller.productForId(offer.productId);
      if (product != null) return product.price;
    }

    final monthly = _fallbackMonthlyPrice[plan.tier];
    if (monthly == null) return plan.price;
    if (period == BillingPeriod.monthly) return _formatPrice(monthly);
    return _formatPrice(monthly * 10);
  }

  double _yearlySavings(PlanBenefits plan) {
    if (plan.tier == MbPlanTier.free) return 0;

    final monthlyOffer = _offerForPlan(plan, BillingPeriod.monthly);
    final yearlyOffer = _offerForPlan(plan, BillingPeriod.yearly);

    final monthlyProduct = monthlyOffer == null
        ? null
        : _controller.productForId(monthlyOffer.productId);
    final yearlyProduct = yearlyOffer == null
        ? null
        : _controller.productForId(yearlyOffer.productId);

    if (monthlyProduct != null && yearlyProduct != null) {
      final yearlySavings =
          (monthlyProduct.rawPrice * 12) - yearlyProduct.rawPrice;
      return yearlySavings > 0 ? yearlySavings : 0;
    }

    final monthly = _fallbackMonthlyPrice[plan.tier];
    if (monthly == null) return 0;
    return monthly * 2;
  }

  List<String> _headlineBenefits(PlanBenefits plan) {
    return <String>[
      plan.insights ? 'Insights included' : 'Core tracking tools included',
      plan.devices < 0
          ? 'Unlimited devices'
          : '${plan.devices} ${plan.devices == 1 ? 'device' : 'devices'}',
      'Unlimited journaling',
      'Unlimited journal sharing',
      'Custom templates included',
    ];
  }

  List<String> _accessDetails(PlanBenefits plan) {
    return <String>[
      'Brain Fog, habits, journals, templates, and pomodoro included',
      plan.insights
          ? 'Insights for templates and habits are enabled'
          : 'Insights are not included on this plan',
    ];
  }

  List<String> _templateDetails(PlanBenefits plan) {
    return <String>[
      'Can create and save custom templates',
      'Built-in templates save forever and show in calendar',
    ];
  }

  List<String> _journalDetails(PlanBenefits plan) {
    return <String>[
      'Unlimited journal entries',
      'Unlimited shares per day',
      'Can receive unlimited shares',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ent = _controller.entitlement;
    final currentPlan = SubscriptionPlanCatalog.fromRaw(ent?.tier ?? 'free');

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('🟣 MB - Subscriptions'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    BillingToggle(
                      value: _billingPeriod,
                      onChanged: (next) =>
                          setState(() => _billingPeriod = next),
                    ),
                    const SizedBox(height: 12),
                    CurrentPlanCard(
                      plan: currentPlan,
                      status: _statusLabel(),
                      renewsAt: _dateLabel(ent?.renewsAt, fallback: 'Unknown'),
                      expiresAt: _dateLabel(
                        ent?.expiresAt,
                        fallback: 'Unknown',
                      ),
                    ),
                    if (_friendlyStoreError != null) ...[
                      const SizedBox(height: 12),
                      _StoreErrorCard(
                        message: _friendlyStoreError!,
                        onRetry: _controller.busy ? null : _retryStore,
                      ),
                    ],
                    const SizedBox(height: 12),
                    ...SubscriptionPlanCatalog.allPlans.map((plan) {
                      final selectedPrice = _displayPrice(plan, _billingPeriod);
                      final yearlySavings = _yearlySavings(plan);
                      final offer = _offerForPlan(plan, _billingPeriod);
                      final canPurchase =
                          offer != null &&
                          _controller.productForId(offer.productId) != null;

                      final cta = _billingPeriod == BillingPeriod.monthly
                          ? 'Upgrade monthly'
                          : 'Upgrade yearly (2 months free)';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TierPlanCard(
                          plan: plan,
                          price: selectedPrice,
                          isCurrentTier: currentPlan.tier == plan.tier,
                          isMostPopular: plan.tier == MbPlanTier.plusSupport,
                          headlineBenefits: _headlineBenefits(plan),
                          yearlySubtitle:
                              (_billingPeriod == BillingPeriod.yearly &&
                                  plan.tier != MbPlanTier.free)
                              ? '2 months free${yearlySavings > 0 ? ' • Save ${_formatPrice(yearlySavings)}' : ''}'
                              : null,
                          ctaLabel: plan.tier == MbPlanTier.free ? null : cta,
                          ctaEnabled: !_controller.busy && canPurchase,
                          onCtaTap:
                              (plan.tier == MbPlanTier.free || !canPurchase)
                              ? null
                              : () => _controller.purchaseProduct(
                                  offer.productId,
                                ),
                          aiDetails: _accessDetails(plan),
                          deviceDetails: <String>[
                            plan.devices < 0
                                ? 'Unlimited devices'
                                : '${plan.devices} ${plan.devices == 1 ? 'device' : 'devices'}',
                          ],
                          templateDetails: _templateDetails(plan),
                          journalDetails: _journalDetails(plan),
                          toolsDetails: plan.tools,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _controller.busy
                      ? null
                      : _controller.restorePurchases,
                  child: const Text('Restore purchases'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _controller.openManageSubscriptionPage,
                  child: const Text('Manage subscription'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BillingToggle extends StatelessWidget {
  const BillingToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BillingPeriod value;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _BillingOption(
              label: 'Monthly',
              selected: value == BillingPeriod.monthly,
              onTap: () => onChanged(BillingPeriod.monthly),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _BillingOption(
              label: 'Yearly • 2 months free',
              selected: value == BillingPeriod.yearly,
              onTap: () => onChanged(BillingPeriod.yearly),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingOption extends StatelessWidget {
  const _BillingOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? scheme.primary.withValues(alpha: 0.16) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class CurrentPlanCard extends StatelessWidget {
  const CurrentPlanCard({
    super.key,
    required this.plan,
    required this.status,
    required this.renewsAt,
    required this.expiresAt,
  });

  final PlanBenefits plan;
  final String status;
  final String renewsAt;
  final String expiresAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surface,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your plan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Current tier: ${plan.titleWithPrice}'),
          Text('Status: $status'),
          Text('Renews: $renewsAt'),
          Text('Expires: $expiresAt'),
        ],
      ),
    );
  }
}

class TierPlanCard extends StatelessWidget {
  const TierPlanCard({
    super.key,
    required this.plan,
    required this.price,
    required this.isCurrentTier,
    required this.isMostPopular,
    required this.headlineBenefits,
    required this.aiDetails,
    required this.deviceDetails,
    required this.templateDetails,
    required this.journalDetails,
    required this.toolsDetails,
    this.yearlySubtitle,
    this.ctaLabel,
    this.ctaEnabled = false,
    this.onCtaTap,
  });

  final PlanBenefits plan;
  final String price;
  final bool isCurrentTier;
  final bool isMostPopular;
  final List<String> headlineBenefits;
  final List<String> aiDetails;
  final List<String> deviceDetails;
  final List<String> templateDetails;
  final List<String> journalDetails;
  final List<String> toolsDetails;
  final String? yearlySubtitle;
  final String? ctaLabel;
  final bool ctaEnabled;
  final VoidCallback? onCtaTap;

  Color _dotColor(MbPlanTier tier, ColorScheme scheme) {
    switch (tier) {
      case MbPlanTier.free:
        return const Color(0xFF34C759);
      case MbPlanTier.plusSupport:
        return const Color(0xFF8E44AD);
      case MbPlanTier.pending:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentTier
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: (isMostPopular ? scheme.primary : scheme.shadow).withValues(
              alpha: isMostPopular ? 0.14 : 0.08,
            ),
            blurRadius: isMostPopular ? 22 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dotColor(plan.tier, scheme),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '($price)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (yearlySubtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          yearlySubtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              if (isMostPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text('Most popular'),
                ),
              if (isCurrentTier)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text('Current tier'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...headlineBenefits.take(6).map((text) => BenefitRow(text: text)),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('See full breakdown'),
              children: [
                _Section(title: 'Access', items: aiDetails),
                _Section(title: 'Devices', items: deviceDetails),
                _Section(title: 'Templates', items: templateDetails),
                _Section(title: 'Journaling', items: journalDetails),
                _Section(title: 'Tools Included', items: toolsDetails),
              ],
            ),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: ctaEnabled ? onCtaTap : null,
                child: Text(ctaLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BenefitRow extends StatelessWidget {
  const BenefitRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          ...items.map((item) => BenefitRow(text: item)),
        ],
      ),
    );
  }
}

class _StoreErrorCard extends StatelessWidget {
  const _StoreErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_outlined, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
