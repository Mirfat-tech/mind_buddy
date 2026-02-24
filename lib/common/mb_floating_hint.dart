import 'package:flutter/material.dart';

class MbFloatingHintOverlay extends StatelessWidget {
  const MbFloatingHintOverlay({
    super.key,
    required this.child,
    required this.hintKey,
    required this.text,
    this.align = Alignment.center,
    this.iconText,
    this.visual,
    this.autoHide = const Duration(seconds: 7),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    this.bottomOffset = 0,
  });

  final Widget child;
  final String hintKey;
  final String text;
  final Alignment align;
  final String? iconText;
  final Widget? visual;
  final Duration autoHide;
  final EdgeInsets padding;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) => child;
}
