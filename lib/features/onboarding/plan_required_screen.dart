import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class PlanRequiredScreen extends ConsumerWidget {
  const PlanRequiredScreen({
    super.key,
    required this.title,
    required this.message,
    this.ctaLabel = 'See plans',
  });

  final String title;
  final String message;
  final String ctaLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = styleById(
      ref.watch(settingsControllerProvider).settings.themeId,
    );
    final useDarkCard = _usesDarkPlanRequiredCard(style);
    final scheme = Theme.of(context).colorScheme;
    final cardDecoration = BoxDecoration(
      gradient: useDarkCard
          ? null
          : const LinearGradient(
              colors: <Color>[
                Color(0xFFF2FFF8),
                Color(0xFFF1EAFF),
                Color(0xFFFFF2FA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      color: useDarkCard
          ? Color.alphaBlend(
              style.accent.withValues(alpha: 0.10),
              style.boxFill,
            )
          : null,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: useDarkCard
            ? Color.alphaBlend(
                style.accent.withValues(alpha: 0.18),
                style.border,
              )
            : scheme.outline.withValues(alpha: 0.14),
      ),
      boxShadow: [
        BoxShadow(
          color: (useDarkCard ? style.accent : scheme.primary).withValues(
            alpha: useDarkCard ? 0.14 : 0.10,
          ),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
    final iconDecoration = BoxDecoration(
      shape: BoxShape.circle,
      gradient: useDarkCard
          ? null
          : const LinearGradient(
              colors: <Color>[Color(0xFFF2F5FA), Color(0xFFE1E8F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      color: useDarkCard
          ? Color.alphaBlend(style.accent.withValues(alpha: 0.16), style.paper)
          : null,
    );
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: useDarkCard ? style.text : null,
      height: 1.4,
      fontWeight: FontWeight.w600,
    );
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: useDarkCard ? style.accent : null,
      foregroundColor: useDarkCard ? style.text : null,
    );

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(22),
            decoration: cardDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: iconDecoration,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 26,
                    color: useDarkCard ? style.text : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Text(message, textAlign: TextAlign.center, style: titleStyle),
                const SizedBox(height: 14),
                FilledButton(
                  style: buttonStyle,
                  onPressed: () => context.go('/subscription'),
                  child: Text(ctaLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _usesDarkPlanRequiredCard(PaperStyle style) {
  switch (style.id) {
    case 'midnight_pink':
    case 'midnight_blue':
    case 'Dark_Orange':
    case 'Midnight_green':
      return true;
    default:
      return false;
  }
}
