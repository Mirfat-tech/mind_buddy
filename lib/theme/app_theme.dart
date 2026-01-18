import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildMindBuddyTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor:
        Colors.transparent, // important for gradient background widget
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      surface: AppColors.frostedFill,
    ),
    textTheme: base.textTheme.copyWith(
      bodyLarge: const TextStyle(
        color: AppColors.textPrimary,
        shadows: [
          Shadow(blurRadius: 6, color: Color(0x66000000), offset: Offset(0, 1)),
        ],
      ),
      bodyMedium: const TextStyle(
        color: AppColors.textSecondary,
        shadows: [
          Shadow(blurRadius: 6, color: Color(0x55000000), offset: Offset(0, 1)),
        ],
      ),
      titleLarge: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(blurRadius: 8, color: Color(0x66000000), offset: Offset(0, 1)),
        ],
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style:
          ElevatedButton.styleFrom(
            backgroundColor: AppColors.frostedFill,
            foregroundColor: AppColors.textPrimary,
            shape: const StadiumBorder(), // pill shape
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            elevation: 0,
          ).copyWith(
            side: WidgetStateProperty.all(
              const BorderSide(color: AppColors.frostedBorder, width: 1),
            ),
          ),
    ),
  );
}
