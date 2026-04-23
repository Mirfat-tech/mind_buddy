import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/subscription/subscription_plan_section.dart';
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

  @override
  Widget build(BuildContext context) {
    final ent = _controller.entitlement;
    final currentPlan = SubscriptionPlanCatalog.fromRaw(ent?.tier ?? 'free');

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text(SubscriptionPlanCatalog.title),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
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
                    Text(
                      'Pick the support mode that feels right for you.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A lighter comparison, clearer spacing, and all the important details in one place.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 18),
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
                        child: SubscriptionPlanCard(
                          plan: PlanBenefits(
                            tier: plan.tier,
                            name: plan.name,
                            price: plan.tier == MbPlanTier.free
                                ? plan.price
                                : selectedPrice,
                            normalizedAliases: plan.normalizedAliases,
                            insights: plan.insights,
                            devices: plan.devices,
                            canCreateCustomTemplates:
                                plan.canCreateCustomTemplates,
                            templatesPreviewMode: plan.templatesPreviewMode,
                            coreTemplatesSaveForever:
                                plan.coreTemplatesSaveForever,
                            canJournal: plan.canJournal,
                            canShareEntries: plan.canShareEntries,
                            sharesPerDay: plan.sharesPerDay,
                            canReceiveUnlimitedShares:
                                plan.canReceiveUnlimitedShares,
                            toolsHeading: plan.toolsHeading,
                            tools: plan.tools,
                            plusExtras: plan.plusExtras,
                            summary: yearlySubtitle(
                              base: plan.summary,
                              billingPeriod: _billingPeriod,
                              yearlySavings: yearlySavings,
                              tier: plan.tier,
                            ),
                            caption: _captionForPlan(
                              plan,
                              billingPeriod: _billingPeriod,
                            ),
                          ),
                          isCurrentTier: currentPlan.tier == plan.tier,
                          ctaLabel: plan.tier == MbPlanTier.free ? null : cta,
                          ctaEnabled: !_controller.busy && canPurchase,
                          onTap: (plan.tier == MbPlanTier.free || !canPurchase)
                              ? null
                              : () => _controller.purchaseProduct(
                                  offer.productId,
                                ),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onPressed: _controller.busy
                      ? null
                      : _controller.restorePurchases,
                  child: const Text('Restore purchases'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
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

  String yearlySubtitle({
    required String base,
    required BillingPeriod billingPeriod,
    required double yearlySavings,
    required MbPlanTier tier,
  }) {
    if (tier == MbPlanTier.free || billingPeriod != BillingPeriod.yearly) {
      return base;
    }
    if (yearlySavings <= 0) {
      return '$base Yearly billing keeps things simple with 2 months free.';
    }
    return '$base Yearly billing includes 2 months free and saves ${_formatPrice(yearlySavings)}.';
  }

  String _captionForPlan(
    PlanBenefits plan, {
    required BillingPeriod billingPeriod,
  }) {
    if (plan.tier == MbPlanTier.free) {
      return plan.caption;
    }
    if (billingPeriod == BillingPeriod.yearly) {
      return 'Billed yearly with a softer value option.';
    }
    return plan.caption;
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
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFF2FFF8),
            Color(0xFFF1EAFF),
            Color(0xFFFFF1F9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D7CFF).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your plan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Current plan: ${plan.titleWithPrice}'),
          Text('Status: $status'),
          Text('Renews: $renewsAt'),
          Text('Expires: $expiresAt'),
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
