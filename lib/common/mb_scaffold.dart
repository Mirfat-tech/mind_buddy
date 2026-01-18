// lib/common/mb_scaffold.dart
import 'package:flutter/material.dart';

class MbScaffold extends StatelessWidget {
  const MbScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.applyBackground = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final bool applyBackground;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    // If applyBackground is false, we want PaperCanvas to be visible,
    // so the Scaffold MUST be transparent.
    final bgColor = applyBackground
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.transparent;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
