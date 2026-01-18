import 'package:flutter/material.dart';
import 'paper_styles.dart';

class HoboBox extends StatelessWidget {
  const HoboBox({
    super.key,
    required this.style,
    required this.child,
    this.title,
    this.trailing,
  });

  final PaperStyle style;
  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: style.boxFill,
        border: Border.all(color: style.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Row(
                children: [
                  Text(
                    title!,
                    style: TextStyle(
                      color: style.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            if (title != null) const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
