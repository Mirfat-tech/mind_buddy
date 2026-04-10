import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gratitude_carousel_models.dart';

class GratitudeCarouselStorage {
  GratitudeCarouselStorage._();

  static const String _prefsKey = 'gratitude_carousel_entries_v1';

  static Future<List<GratitudeCarouselEntry>> fetchEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return <GratitudeCarouselEntry>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <GratitudeCarouselEntry>[];
    final entries = decoded
        .map(GratitudeCarouselEntry.fromJson)
        .whereType<GratitudeCarouselEntry>()
        .toList();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  static Future<GratitudeCarouselEntry?> getEntry(String id) async {
    final entries = await fetchEntries();
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static Future<void> saveEntry(GratitudeCarouselEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await fetchEntries();
    final nextEntries = <GratitudeCarouselEntry>[
      for (final existing in entries)
        if (existing.id != entry.id) existing,
      entry,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _prefsKey,
      jsonEncode(nextEntries.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await fetchEntries();
    final nextEntries = entries.where((entry) => entry.id != id).toList();
    await prefs.setString(
      _prefsKey,
      jsonEncode(nextEntries.map((item) => item.toJson()).toList()),
    );
  }
}
