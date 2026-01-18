import 'package:flutter/material.dart';

class AppColors {
  // Gradient stops (your palette)
  static const Color grad1 = Color(0xFFD8CCFF); // #D8CCFF
  static const Color grad2 = Color(0xFFBFD9FF); // #BFD9FF
  static const Color grad3 = Color(0xFFE8DFFF); // #E8DFFF

  // Text
  static const Color textPrimary = Color(
    0xFFF7F5FF,
  ); // cool white / pale violet
  static const Color textSecondary = Color(0xFFE7E2FF);

  // “Frosted” surfaces
  static const Color frostedFill = Color(0x66FFFFFF); // ~40% white
  static const Color frostedBorder = Color(0x40FFFFFF); // subtle border

  // Bubble tints (use low opacity in widgets)
  static const Color bubbleLilac = Color(0xFFCBB7FF);
  static const Color bubbleBlue = Color(0xFFBBD9FF);
  static const Color bubblePink = Color(0xFFFFC7E8);

  // Button / accent
  static const Color primary = Color(0xFFA99CFF); // periwinkle-ish
  static const Color glow = Color(0x66B9B0FF); // inner glow tint
}
