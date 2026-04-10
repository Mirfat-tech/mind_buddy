import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MbBreakpoint { phone, tablet, desktop }

class MbResponsive {
  const MbResponsive._(this.width);

  factory MbResponsive.of(BuildContext context) {
    return MbResponsive._(MediaQuery.sizeOf(context).width);
  }

  factory MbResponsive.fromConstraints(BoxConstraints constraints) {
    return MbResponsive._(constraints.maxWidth);
  }

  final double width;

  MbBreakpoint get breakpoint {
    if (width >= 1200) return MbBreakpoint.desktop;
    if (width >= 700) return MbBreakpoint.tablet;
    return MbBreakpoint.phone;
  }

  bool get isPhone => breakpoint == MbBreakpoint.phone;
  bool get isTablet => breakpoint == MbBreakpoint.tablet;
  bool get isDesktop => breakpoint == MbBreakpoint.desktop;
  bool get isTabletUp => !isPhone;

  double get horizontalPadding => _fluid(16, 28, 40);
  double get sectionGap => _fluid(18, 26, 34);
  double get blockGap => _fluid(12, 18, 24);
  double get compactGap => _fluid(8, 12, 16);
  double get cardRadius => _fluid(16, 20, 24);
  double get cardPadding => _fluid(14, 20, 24);
  double get iconSize => _fluid(20, 24, 28);
  double get actionIconSize => _fluid(20, 22, 24);
  double get titleSize => _fluid(26, 30, 34);
  double get sectionTitleSize => _fluid(18, 21, 24);
  double get bodySize => _fluid(14, 15, 16);
  double get logoSize => _fluid(132, 164, 188);
  double get buttonHeight => _fluid(52, 56, 60);

  double get authMaxWidth => isPhone ? 560 : (isTablet ? 640 : 720);
  double get timerMaxWidth => isPhone ? 560 : (isTablet ? 720 : 820);
  double get dashboardMaxWidth => isPhone ? 680 : (isTablet ? 980 : 1180);

  int columnsFor({
    required int phone,
    required int tablet,
    required int desktop,
  }) {
    switch (breakpoint) {
      case MbBreakpoint.phone:
        return phone;
      case MbBreakpoint.tablet:
        return tablet;
      case MbBreakpoint.desktop:
        return desktop;
    }
  }

  double _fluid(double phone, double tablet, double desktop) {
    if (width <= 700) {
      return _interpolate(width, 320, 700, phone, tablet);
    }
    return _interpolate(width, 700, 1400, tablet, desktop);
  }

  double _interpolate(
    double current,
    double minWidth,
    double maxWidth,
    double minValue,
    double maxValue,
  ) {
    final t = ((current - minWidth) / (maxWidth - minWidth)).clamp(0.0, 1.0);
    return minValue + (maxValue - minValue) * t;
  }
}

class MbResponsiveContent extends StatelessWidget {
  const MbResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final responsive = MbResponsive.of(context);
    return Align(
      alignment: alignment,
      child: Padding(
        padding:
            padding ??
            EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? responsive.dashboardMaxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}

class MbResponsiveCard extends StatelessWidget {
  const MbResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.color,
    this.border,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final responsive = MbResponsive.of(context);

    return Container(
      padding: padding ?? EdgeInsets.all(responsive.cardPadding),
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius ?? responsive.cardRadius),
        border:
            border ?? Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: scheme.primary.withValues(alpha: 0.09),
              ),
            ],
      ),
      child: child,
    );
  }
}

double clampWidth(double width, double min, double max) {
  return math.min(math.max(width, min), max);
}
