import 'package:flutter/material.dart';

class PaperStyle {
  const PaperStyle({
    required this.id,
    required this.name,
    required this.paper,
    required this.boxFill,
    required this.border,
    required this.text,
    required this.mutedText,
    required this.accent,
  });
  final String id;
  final String name;
  final Color paper;
  final Color boxFill;
  final Color border;
  final Color text;
  final Color mutedText;
  final Color accent;
}

final paperStyles = <PaperStyle>[
  // Your existing style (keep if you want)
  const PaperStyle(
    id: 'paper_blush',
    name: 'Paper Blush',
    paper: Color(0xFFFFF4F0),
    boxFill: Color(0xFFFFF0F3),
    border: Color(0xFFFFD2DC),
    text: Color(0xFF2B2B2B),
    mutedText: Color(0xFF8A6B74),
    accent: Color(0xFFFF5AA5),
  ),
  // Cream + Neon Pink
  const PaperStyle(
    id: 'cream_pop',
    name: 'Cream Pop',
    paper: Color(0xFFFFF7E9),
    boxFill: Color(0xFFFFF1FB),
    border: Color(0xFFFFC7E6),
    text: Color(0xFF2A2A2A),
    mutedText: Color(0xFF7A6B6B),
    accent: Color(0xFFFF3DBA),
  ),
  // Cream + Neon Mint
  const PaperStyle(
    id: 'mint_cream',
    name: 'Mint Cream',
    paper: Color(0xFFFFF7E9),
    boxFill: Color(0xFFEFFFF7),
    border: Color(0xFFB7FFD8),
    text: Color(0xFF242424),
    mutedText: Color(0xFF6E7A74),
    accent: Color.fromARGB(255, 28, 195, 150),
  ),

  // Lilac + Baby Blue
  const PaperStyle(
    id: 'lilac_dream',
    name: 'Lilac Dream',
    paper: Color(0xFFF6F0FF),
    boxFill: Color(0xFFEEF6FF),
    border: Color(0xFFCDBBFF),
    text: Color(0xFF26233A),
    mutedText: Color(0xFF6E6790),
    accent: Color(0xFF5E7BFF),
  ),
  // Baby Blue + Pink Accent
  const PaperStyle(
    id: 'baby_blue',
    name: 'Baby Blue',
    paper: Color(0xFFEFF7FF),
    boxFill: Color(0xFFFFFFFF),
    border: Color(0xFFB7D9FF),
    text: Color(0xFF1E2A35),
    mutedText: Color(0xFF5D7286),
    accent: Color(0xFFFF4FB7),
  ),
//Aqua blue
  const PaperStyle(
    id: 'Aqua_blue',
    name: 'Aqua Blue',
    paper: Color(0xFFEFF7FF),
    boxFill: Color(0xFFFFFFFF),
    border: Color(0xFFB7D9FF),
    text: Color(0xFF1E2A35),
    mutedText: Color(0xFF5D7286),
    accent: Color.fromARGB(255, 3, 177, 189),
  ),
  // midnight_pink
  const PaperStyle(
    id: 'midnight_pink',
    name: 'Midnight Pink',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color(0xFFF2F4FF),
    mutedText: Color(0xFFA2AACB),
    accent: Color.fromARGB(255, 176, 15, 112),
  ),
  // experiment
  const PaperStyle(
    id: 'midnight_blue',
    name: 'Midnight Blue',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color.fromARGB(255, 196, 196, 206),
    mutedText: Color(0xFFA2AACB),
    accent: Color.fromARGB(255, 15, 31, 177),
  ),

  // Dark Orange
  const PaperStyle(
    id: 'Dark_Orange',
    name: 'Dark & Orange',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color.fromARGB(255, 199, 191, 197),
    mutedText: Color.fromARGB(255, 222, 6, 178),
    accent: Color.fromARGB(255, 186, 42, 28),
  ),

  //Midnight_green
  const PaperStyle(
    id: 'Midnight_green',
    name: 'Midnight green',
    paper: Color(0xFF070A14),
    boxFill: Color.fromARGB(200, 18, 24, 42),
    border: Color(0xFF2A3145),
    text: Color.fromARGB(255, 199, 191, 197),
    mutedText: Color.fromARGB(255, 222, 6, 178),
    accent: Color.fromARGB(255, 34, 121, 12),
  ),

  //linen gray
  const PaperStyle(
    id: 'linen_gray',
    name: 'Linen Gray',
    paper: Color(0xFFECEBE8),
    boxFill: Color(0xFFF2F1EE),
    border: Color(0xFFD4D1CA),
    text: Color(0xFF2D2D2D),
    mutedText: Color(0xFF7F7C76),
    accent: Color(0xFFB7B2A8),
  ),
  const PaperStyle(
    id: 'dusty_blue',
    name: 'Dusty Blue Margin',
    paper: Color(0xFFF3F0E8),
    boxFill: Color(0xFFF6F3EC),
    border: Color(0xFFD7D2C8),
    text: Color(0xFF2C2C2C),
    mutedText: Color(0xFF7B766F),
    accent: Color(0xFF6E7C91),
  ),
];

PaperStyle styleById(String? id) {
  if (id == null) return paperStyles.firstWhere(
        (s) => s.id == 'baby_blue',
        orElse: () => paperStyles.first,
      );
  return paperStyles.firstWhere(
    (s) => s.id == id,
    orElse: () => paperStyles.first,
  );
}
