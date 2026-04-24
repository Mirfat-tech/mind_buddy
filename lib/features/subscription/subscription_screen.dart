import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/subscription/subscription_plan_section.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/subscription_purchase_service.dart';

enum BillingPeriod { monthly, yearly }

enum SubscriptionTierTab { freeMode, plusSupportMode }

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionPurchaseController _controller =
      SubscriptionPurchaseController();
  BillingPeriod _billingPeriod = BillingPeriod.monthly;
  SubscriptionTierTab _selectedTierTab = SubscriptionTierTab.plusSupportMode;
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
    final visiblePlan = _selectedTierTab == SubscriptionTierTab.freeMode
        ? SubscriptionPlanCatalog.allPlans.firstWhere(
            (plan) => plan.tier == MbPlanTier.free,
          )
        : SubscriptionPlanCatalog.allPlans.firstWhere(
            (plan) => plan.tier == MbPlanTier.plusSupport,
          );

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
                    TierToggle(
                      value: _selectedTierTab,
                      onChanged: (next) =>
                          setState(() => _selectedTierTab = next),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VisiblePlanCard(
                        plan: visiblePlan,
                        currentPlan: currentPlan,
                        billingPeriod: _billingPeriod,
                        onBillingChanged: (next) =>
                            setState(() => _billingPeriod = next),
                        displayPrice: _displayPrice,
                        yearlySavings: _yearlySavings,
                        captionForPlan: _captionForPlan,
                        yearlySubtitle: yearlySubtitle,
                        offerForPlan: _offerForPlan,
                        productForId: _controller.productForId,
                        controllerBusy: _controller.busy,
                        purchaseProduct: _controller.purchaseProduct,
                      ),
                    ),
                    const SizedBox(height: 8),
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

class TierToggle extends StatelessWidget {
  const TierToggle({super.key, required this.value, required this.onChanged});

  final SubscriptionTierTab value;
  final ValueChanged<SubscriptionTierTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surface.withValues(alpha: 0.8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentOption(
              label: 'Free Mode',
              selected: value == SubscriptionTierTab.freeMode,
              onTap: () => onChanged(SubscriptionTierTab.freeMode),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentOption(
              label: 'Plus Support Mode',
              selected: value == SubscriptionTierTab.plusSupportMode,
              onTap: () => onChanged(SubscriptionTierTab.plusSupportMode),
            ),
          ),
        ],
      ),
    );
  }
}

class PlusBillingToggle extends StatelessWidget {
  const PlusBillingToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BillingPeriod value;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surface.withValues(alpha: 0.72),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentOption(
              label: 'Monthly',
              selected: value == BillingPeriod.monthly,
              onTap: () => onChanged(BillingPeriod.monthly),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentOption(
              label: 'Yearly',
              selected: value == BillingPeriod.yearly,
              onTap: () => onChanged(BillingPeriod.yearly),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
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
          color: selected
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.surface.withValues(alpha: 0.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? scheme.primary : scheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _VisiblePlanCard extends StatelessWidget {
  const _VisiblePlanCard({
    required this.plan,
    required this.currentPlan,
    required this.billingPeriod,
    required this.onBillingChanged,
    required this.displayPrice,
    required this.yearlySavings,
    required this.captionForPlan,
    required this.yearlySubtitle,
    required this.offerForPlan,
    required this.productForId,
    required this.controllerBusy,
    required this.purchaseProduct,
  });

  final PlanBenefits plan;
  final PlanBenefits currentPlan;
  final BillingPeriod billingPeriod;
  final ValueChanged<BillingPeriod> onBillingChanged;
  final String Function(PlanBenefits, BillingPeriod) displayPrice;
  final double Function(PlanBenefits) yearlySavings;
  final String Function(PlanBenefits, {required BillingPeriod billingPeriod})
  captionForPlan;
  final String Function({
    required String base,
    required BillingPeriod billingPeriod,
    required double yearlySavings,
    required MbPlanTier tier,
  })
  yearlySubtitle;
  final SubscriptionOffer? Function(PlanBenefits, BillingPeriod) offerForPlan;
  final dynamic Function(String) productForId;
  final bool controllerBusy;
  final Future<void> Function(String) purchaseProduct;

  @override
  Widget build(BuildContext context) {
    final selectedPrice = displayPrice(plan, billingPeriod);
    final savings = yearlySavings(plan);
    final offer = offerForPlan(plan, billingPeriod);
    final canPurchase = offer != null && productForId(offer.productId) != null;
    final cta = billingPeriod == BillingPeriod.monthly
        ? 'Upgrade monthly'
        : 'Upgrade yearly (2 months free)';

    final normalizedPlan = PlanBenefits(
      tier: plan.tier,
      name: plan.name,
      price: plan.tier == MbPlanTier.free ? plan.price : selectedPrice,
      normalizedAliases: plan.normalizedAliases,
      insights: plan.insights,
      devices: plan.devices,
      canCreateCustomTemplates: plan.canCreateCustomTemplates,
      templatesPreviewMode: plan.templatesPreviewMode,
      coreTemplatesSaveForever: plan.coreTemplatesSaveForever,
      canJournal: plan.canJournal,
      canShareEntries: plan.canShareEntries,
      sharesPerDay: plan.sharesPerDay,
      canReceiveUnlimitedShares: plan.canReceiveUnlimitedShares,
      toolsHeading: plan.toolsHeading,
      tools: plan.tools,
      plusExtras: plan.plusExtras,
      summary: yearlySubtitle(
        base: plan.summary,
        billingPeriod: billingPeriod,
        yearlySavings: savings,
        tier: plan.tier,
      ),
      caption: captionForPlan(plan, billingPeriod: billingPeriod),
    );

    if (plan.tier == MbPlanTier.free) {
      return SubscriptionPlanCard(
        plan: normalizedPlan,
        isCurrentTier: currentPlan.tier == plan.tier,
        ctaLabel: null,
        ctaEnabled: false,
        onTap: null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubscriptionPlanCard(
          plan: normalizedPlan,
          isCurrentTier: currentPlan.tier == plan.tier,
          ctaLabel: cta,
          ctaEnabled: !controllerBusy && canPurchase,
          onTap: !canPurchase ? null : () => purchaseProduct(offer.productId),
          headerFooter: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: PlusBillingToggle(
              value: billingPeriod,
              onChanged: onBillingChanged,
            ),
          ),
        ),
      ],
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
