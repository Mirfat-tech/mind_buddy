import 'package:flutter/material.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';

class _SubscriptionPalette {
  static const Color mintSolid = Color(0xFFF2FFF8);

  static const LinearGradient plusDream = LinearGradient(
    colors: <Color>[Color(0xFFF4FFF9), Color(0xFFF2ECFF), Color(0xFFFFF0FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintIcon = LinearGradient(
    colors: <Color>[Color(0xFFF8F1FF), Color(0xFFFDF7FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ombreIcon = LinearGradient(
    colors: <Color>[Color(0xFFF9F1FF), Color(0xFFFFF2FA), Color(0xFFF5EEFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glyphOmbre = LinearGradient(
    colors: <Color>[Color(0xFFFF2FA3), Color(0xFFFF56BC), Color(0xFF8B4DFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient lockIcon = LinearGradient(
    colors: <Color>[Color(0xFFF7F1FF), Color(0xFFF2ECFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color ombreBorder = Color(0xFFB69CFF);
  static const Color ombreText = Color(0xFF7B57D1);
  static const Color lockText = Color(0xFF64748B);
  static const Color plusGlow = Color(0xFF9A7BFF);
}

String subscriptionFeatureDisplayLabel(String raw) {
  final trimmed = raw.trim();
  const prefixes = <String>['Does not include ', 'Includes '];
  for (final prefix in prefixes) {
    if (trimmed.startsWith(prefix)) {
      return trimmed.substring(prefix.length).trim();
    }
  }
  return trimmed;
}

bool subscriptionFeatureIsLocked(String raw, {bool forceLocked = false}) {
  return forceLocked || raw.trim().startsWith('Does not include ');
}

IconData subscriptionFeatureIcon(String raw, {bool forceLocked = false}) {
  if (subscriptionFeatureIsLocked(raw, forceLocked: forceLocked)) {
    return Icons.lock_rounded;
  }

  switch (subscriptionFeatureDisplayLabel(raw).toLowerCase()) {
    case 'brainfog bubble':
      return Icons.psychology_rounded;
    case 'pomodoro bubble':
      return Icons.timer_rounded;
    case 'habit bubble':
      return Icons.check_circle_rounded;
    case 'logs / templates':
      return Icons.library_books_rounded;
    case 'unlimited journal entries':
      return Icons.menu_book_rounded;
    case 'unlimited journal sharing':
    case 'unlimited journal sharings':
      return Icons.ios_share_rounded;
    case 'custom templates':
      return Icons.dashboard_customize_rounded;
    case 'study buddy':
    case 'study buddy feature':
      return Icons.school_rounded;
    case 'insights':
      return Icons.insights_rounded;
    case 'gratitude bubble':
      return Icons.favorite_rounded;
    case 'make your own quotes':
      return Icons.format_quote_rounded;
    case 'up to 2 themes in theme selector':
    case 'unlimited themes':
      return Icons.palette_rounded;
    case 'create your own theme':
      return Icons.brush_rounded;
    case '1 device only':
    case 'unlimited devices':
      return Icons.devices_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

class SubscriptionPlanSection extends StatelessWidget {
  const SubscriptionPlanSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.plans,
    this.currentTier,
    this.ctaLabelBuilder,
    this.onPlanTap,
    this.isPlanEnabled,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<PlanBenefits> plans;
  final MbPlanTier? currentTier;
  final String Function(PlanBenefits plan)? ctaLabelBuilder;
  final VoidCallback Function(PlanBenefits plan)? onPlanTap;
  final bool Function(PlanBenefits plan)? isPlanEnabled;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 20),
        for (final plan in plans) ...[
          SubscriptionPlanCard(
            plan: plan,
            isCurrentTier: currentTier == plan.tier,
            ctaLabel: ctaLabelBuilder?.call(plan),
            onTap: onPlanTap?.call(plan),
            ctaEnabled: isPlanEnabled?.call(plan) ?? true,
          ),
          if (plan != plans.last) const SizedBox(height: 14),
        ],
        if (footer != null) ...[const SizedBox(height: 18), footer!],
      ],
    );
  }
}

class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    super.key,
    required this.plan,
    this.isCurrentTier = false,
    this.ctaLabel,
    this.onTap,
    this.ctaEnabled = true,
    this.headerFooter,
  });

  final PlanBenefits plan;
  final bool isCurrentTier;
  final String? ctaLabel;
  final VoidCallback? onTap;
  final bool ctaEnabled;
  final Widget? headerFooter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFeatured = plan.tier == MbPlanTier.plusSupport;
    return Container(
      decoration: BoxDecoration(
        color: isFeatured ? null : _SubscriptionPalette.mintSolid,
        gradient: isFeatured ? _SubscriptionPalette.plusDream : null,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isCurrentTier
              ? _SubscriptionPalette.ombreBorder.withValues(alpha: 0.42)
              : scheme.outline.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: (isFeatured ? _SubscriptionPalette.plusGlow : scheme.primary)
                .withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            plan.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (plan.tier == MbPlanTier.plusSupport)
                            const _PlanChip(
                              label: 'Most loved',
                              background: Color(0xFFEDE6FF),
                              foreground: Color(0xFF7153C7),
                            ),
                          if (isCurrentTier)
                            _PlanChip(
                              label: 'Current plan',
                              background: _SubscriptionPalette.ombreBorder
                                  .withValues(alpha: 0.12),
                              foreground: _SubscriptionPalette.ombreText,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan.price,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.summary,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      if (headerFooter != null) ...[
                        const SizedBox(height: 12),
                        headerFooter!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              plan.toolsHeading,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SubscriptionFeatureList(items: plan.tools, featured: isFeatured),
            if (plan.caption.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                plan.caption,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (ctaLabel != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: ctaEnabled ? onTap : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(ctaLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SubscriptionFeatureList extends StatelessWidget {
  const SubscriptionFeatureList({
    super.key,
    required this.items,
    this.featured = false,
    this.forceLocked = false,
    this.compact = false,
  });

  final List<String> items;
  final bool featured;
  final bool forceLocked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: compact ? 8 : 10),
              child: SubscriptionFeatureRow(
                label: item,
                featured: featured,
                forceLocked: forceLocked,
                compact: compact,
              ),
            ),
          )
          .toList(),
    );
  }
}

class SubscriptionFeatureRow extends StatelessWidget {
  const SubscriptionFeatureRow({
    super.key,
    required this.label,
    this.featured = false,
    this.forceLocked = false,
    this.compact = false,
  });

  final String label;
  final bool featured;
  final bool forceLocked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = subscriptionFeatureIsLocked(label, forceLocked: forceLocked);
    final displayLabel = subscriptionFeatureDisplayLabel(label);

    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubscriptionFeatureIcon(
            icon: subscriptionFeatureIcon(label, forceLocked: forceLocked),
            locked: locked,
            featured: featured,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: locked ? scheme.onSurfaceVariant : null,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionFeatureIcon extends StatelessWidget {
  const _SubscriptionFeatureIcon({
    required this.icon,
    required this.locked,
    required this.featured,
  });

  final IconData icon;
  final bool locked;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradient = locked
        ? _SubscriptionPalette.lockIcon
        : featured
        ? _SubscriptionPalette.ombreIcon
        : _SubscriptionPalette.mintIcon;

    final iconColor = locked
        ? _SubscriptionPalette.lockText
        : featured
        ? _SubscriptionPalette.ombreText
        : scheme.primary;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: locked
          ? Icon(icon, size: 20, color: iconColor)
          : ShaderMask(
              shaderCallback: (bounds) =>
                  _SubscriptionPalette.glyphOmbre.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Icon(icon, size: 20, color: Colors.white),
            ),
    );
  }
}
