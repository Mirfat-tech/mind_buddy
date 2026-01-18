import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme_controller.dart';
import 'paper_canvas.dart';
import 'paper_styles.dart';

class ThemedPage extends ConsumerWidget {
  const ThemedPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(appThemeControllerProvider).themeId;
    final style = styleById(themeId);

    final theme = _themeFromPaperStyle(style);

    return Theme(
      data: theme,
      child: PaperCanvas(style: style, child: child),
    );
  }
}

ThemeData _themeFromPaperStyle(PaperStyle style) {
  final bg = style.paper; // ✅ use "paper" as the page background
  final surface = style.boxFill;
  final outline = style.border;
  final primary = style.accent;

  final onBg = style.text;
  final onSurface = style.text;

  final scheme = ColorScheme(
    brightness: ThemeData.estimateBrightnessForColor(bg),
    primary: primary,
    onPrimary: onBg,
    secondary: primary,
    onSecondary: onBg,
    error: Colors.red,
    onError: Colors.white,
    surface: surface,
    onSurface: onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,

    // ✅ This helps when something uses Scaffold backgroundColor.
    scaffoldBackgroundColor: bg,

    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: onBg,
      iconTheme: IconThemeData(color: onBg),
      titleTextStyle: TextStyle(
        color: onBg,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: style.mutedText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(primary),
        foregroundColor: WidgetStatePropertyAll(onBg),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: outline),
      ),
    ),

    dividerColor: outline,
  );
}
