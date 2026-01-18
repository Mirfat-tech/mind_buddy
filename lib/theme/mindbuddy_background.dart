import 'package:flutter/material.dart';

/// Background disabled.
/// This keeps the widget name so the rest of the app compiles,
/// but removes the gradient + circles everywhere.
class MindBuddyBackground extends StatelessWidget {
  final Widget child;
  const MindBuddyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
