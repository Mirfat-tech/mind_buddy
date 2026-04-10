import 'package:flutter/material.dart';

@immutable
class HabitCategoryPreset {
  const HabitCategoryPreset({
    required this.name,
    required this.icon,
    required this.sortOrder,
  });

  final String name;
  final String icon;
  final int sortOrder;
}

class HabitCategoryCatalog {
  HabitCategoryCatalog._();

  static const List<HabitCategoryPreset> builtInCategories =
      <HabitCategoryPreset>[
        HabitCategoryPreset(name: 'Morning routine', icon: '🌅', sortOrder: 0),
        HabitCategoryPreset(
          name: 'Afternoon routine',
          icon: '☀️',
          sortOrder: 1,
        ),
        HabitCategoryPreset(name: 'Night routine', icon: '🌙', sortOrder: 2),
        HabitCategoryPreset(name: 'Personal', icon: '🫧', sortOrder: 3),
        HabitCategoryPreset(name: 'Work', icon: '💼', sortOrder: 4),
      ];
}
