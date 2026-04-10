import 'package:flutter/material.dart';

import 'package:mind_buddy/common/mb_responsive.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final responsive = MbResponsive.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            responsive.horizontalPadding,
            responsive.sectionGap,
            responsive.horizontalPadding,
            responsive.sectionGap + bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: responsive.authMaxWidth),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthHeader(title: title, subtitle: subtitle),
                      SizedBox(height: responsive.sectionGap),
                      child,
                      if (bottom != null) ...[
                        SizedBox(height: responsive.blockGap),
                        bottom!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final responsive = MbResponsive.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Image.asset(
          'assets/images/MYBB_Trans_logo_2.png',
          width: responsive.logoSize,
          height: responsive.logoSize,
          fit: BoxFit.contain,
        ),
        SizedBox(height: responsive.blockGap),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: responsive.titleSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: responsive.compactGap),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: responsive.bodySize,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class AuthSectionCard extends StatelessWidget {
  const AuthSectionCard({
    super.key,
    required this.child,
    this.transparent = false,
  });

  final Widget child;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    return MbResponsiveCard(
      color: transparent ? Colors.transparent : null,
      border: transparent ? Border.all(color: Colors.transparent) : null,
      boxShadow: transparent
          ? const []
          : [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
      child: child,
    );
  }
}
