import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gratitude_carousel_models.dart';

abstract class GratitudeCarouselEntryStorage {
  const GratitudeCarouselEntryStorage();

  Future<List<GratitudeCarouselEntry>> fetchEntries();
  Future<GratitudeCarouselEntry?> getEntry(String id);
  Future<void> saveEntry(GratitudeCarouselEntry entry);
  Future<void> deleteEntry(String id);
}

class SharedPrefsGratitudeCarouselStorage
    extends GratitudeCarouselEntryStorage {
  const SharedPrefsGratitudeCarouselStorage();

  static const String _prefsKey = 'gratitude_carousel_entries_v1';

  Future<List<GratitudeCarouselEntry>> _fetchEntries() async {
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

  Future<GratitudeCarouselEntry?> _getEntry(String id) async {
    final entries = await _fetchEntries();
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> _saveEntry(GratitudeCarouselEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _fetchEntries();
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

  Future<void> _deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _fetchEntries();
    final nextEntries = entries.where((entry) => entry.id != id).toList();
    await prefs.setString(
      _prefsKey,
      jsonEncode(nextEntries.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<List<GratitudeCarouselEntry>> fetchEntries() {
    return _fetchEntries();
  }

  @override
  Future<GratitudeCarouselEntry?> getEntry(String id) {
    return _getEntry(id);
  }

  @override
  Future<void> saveEntry(GratitudeCarouselEntry entry) {
    return _saveEntry(entry);
  }

  @override
  Future<void> deleteEntry(String id) {
    return _deleteEntry(id);
  }
}

class InMemoryGratitudeCarouselStorage extends GratitudeCarouselEntryStorage {
  InMemoryGratitudeCarouselStorage({
    List<GratitudeCarouselEntry> seedEntries = const <GratitudeCarouselEntry>[],
  }) : _entries = seedEntries.toList(growable: true);

  final List<GratitudeCarouselEntry> _entries;

  @override
  Future<List<GratitudeCarouselEntry>> fetchEntries() async {
    final entries = _entries.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  @override
  Future<GratitudeCarouselEntry?> getEntry(String id) async {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<void> saveEntry(GratitudeCarouselEntry entry) async {
    _entries.removeWhere((existing) => existing.id == entry.id);
    _entries.add(entry);
    _entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
  }
}

class GratitudeCarouselStorage {
  GratitudeCarouselStorage._();

  static const GratitudeCarouselEntryStorage instance =
      SharedPrefsGratitudeCarouselStorage();

  static Future<List<GratitudeCarouselEntry>> fetchEntries() {
    return instance.fetchEntries();
  }

  static Future<GratitudeCarouselEntry?> getEntry(String id) {
    return instance.getEntry(id);
  }

  static Future<void> saveEntry(GratitudeCarouselEntry entry) {
    return instance.saveEntry(entry);
  }

  static Future<void> deleteEntry(String id) {
    return instance.deleteEntry(id);
  }
}
