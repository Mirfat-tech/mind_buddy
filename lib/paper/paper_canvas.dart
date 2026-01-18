import 'package:flutter/material.dart';
import 'paper_styles.dart';

class PaperCanvas extends StatelessWidget {
  const PaperCanvas({super.key, required this.style, required this.child});

  final PaperStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // This is the IMPORTANT part: always paint the background using the style.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.paper, // ✅ background follows selected theme
      ),
      child: child,
    );
  }
}
