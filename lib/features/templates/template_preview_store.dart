import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TemplatePreviewStore {
  TemplatePreviewStore._();

  static const String _storagePrefix = 'template_preview_store_v1:';
  static const String createdAtKey = '_preview_created_at';
  static const String expiresAtKey = '_preview_expires_at';
  static const String isPreviewKey = '_is_preview_entry';

  static String _storageKey(String userId) => '$_storagePrefix$userId';

  static Future<List<Map<String, dynamic>>> loadEntries({
    required String userId,
    required String tableName,
    List<String> legacyStorageKeys = const <String>[],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final allEntries = await _readAllEntries(
      prefs,
      userId,
      legacyStorageKeys: legacyStorageKeys,
    );
    final normalized = _normalizeStorageMap(allEntries);
    await _persistAllEntries(prefs, userId, normalized);
    return List<Map<String, dynamic>>.from(normalized[tableName] ?? const []);
  }

  static Future<void> saveEntries({
    required String userId,
    required String tableName,
    required List<Map<String, dynamic>> entries,
    List<String> legacyStorageKeys = const <String>[],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final allEntries = await _readAllEntries(
      prefs,
      userId,
      legacyStorageKeys: legacyStorageKeys,
    );
    final normalized = _normalizeStorageMap(allEntries);
    normalized[tableName] = _normalizeEntries(entries);
    await _persistAllEntries(prefs, userId, normalized);
  }

  static Future<List<Map<String, dynamic>>> listEntriesForDay({
    required String userId,
    required String tableName,
    required String dayKey,
  }) async {
    final entries = await loadEntries(userId: userId, tableName: tableName);
    return entries
        .where((entry) => (entry['day'] ?? '').toString() == dayKey)
        .toList();
  }

  static Future<Set<String>> listDayKeysInRange({
    required String userId,
    required String tableName,
    required String startDayKey,
    required String endDayKey,
  }) async {
    final entries = await loadEntries(userId: userId, tableName: tableName);
    return entries
        .map((entry) => (entry['day'] ?? '').toString())
        .where(
          (day) =>
              day.isNotEmpty &&
              day.compareTo(startDayKey) >= 0 &&
              day.compareTo(endDayKey) <= 0,
        )
        .toSet();
  }

  static Map<String, dynamic> createPreviewEntry(
    Map<String, dynamic> input, {
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    final created = createdAt ?? DateTime.now();
    return <String, dynamic>{
      ...input,
      createdAtKey: created.toIso8601String(),
      if (expiresAt != null) expiresAtKey: expiresAt.toIso8601String(),
      isPreviewKey: true,
    };
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _readAllEntries(
    SharedPreferences prefs,
    String userId, {
    List<String> legacyStorageKeys = const <String>[],
  }) async {
    final raw = prefs.getString(_storageKey(userId));
    final decoded = _decodeStorageMap(raw);
    var merged = Map<String, List<Map<String, dynamic>>>.from(decoded);

    if (legacyStorageKeys.isNotEmpty) {
      var didMigrateLegacy = false;
      for (final legacyKey in legacyStorageKeys) {
        final legacyRaw = prefs.getString(legacyKey);
        if (legacyRaw == null || legacyRaw.isEmpty) continue;
        final migrated = _decodeLegacyEntries(legacyRaw);
        if (migrated == null) {
          await prefs.remove(legacyKey);
          continue;
        }
        final tableName = migrated.$1;
        final rows = migrated.$2;
        if (rows.isNotEmpty) {
          merged[tableName] = <Map<String, dynamic>>[
            ...?merged[tableName],
            ...rows,
          ];
        }
        await prefs.remove(legacyKey);
        didMigrateLegacy = true;
      }
      if (didMigrateLegacy) {
        merged = _normalizeStorageMap(merged);
        await _persistAllEntries(prefs, userId, merged);
      }
    }

    return merged;
  }

  static Future<void> _persistAllEntries(
    SharedPreferences prefs,
    String userId,
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    final normalized = <String, dynamic>{};
    data.forEach((tableName, entries) {
      if (entries.isEmpty) return;
      normalized[tableName] = entries;
    });
    if (normalized.isEmpty) {
      await prefs.remove(_storageKey(userId));
      return;
    }
    await prefs.setString(_storageKey(userId), jsonEncode(normalized));
  }

  static Map<String, List<Map<String, dynamic>>> _decodeStorageMap(
    String? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return <String, List<Map<String, dynamic>>>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<Map<String, dynamic>>>{};
      final result = <String, List<Map<String, dynamic>>>{};
      decoded.forEach((key, value) {
        if (key is! String || value is! List) return;
        result[key] = value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      });
      return result;
    } catch (_) {
      return <String, List<Map<String, dynamic>>>{};
    }
  }

  static (String, List<Map<String, dynamic>>)? _decodeLegacyEntries(
    String raw,
  ) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) {
        return ('', <Map<String, dynamic>>[]);
      }
      final entries = decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      if (entries.isEmpty) {
        return ('', <Map<String, dynamic>>[]);
      }
      final tableName = (entries.first['_preview_table_name'] ?? '').toString();
      if (tableName.isEmpty) {
        return ('', <Map<String, dynamic>>[]);
      }
      return (tableName, entries);
    } catch (_) {
      return null;
    }
  }

  static Map<String, List<Map<String, dynamic>>> _normalizeStorageMap(
    Map<String, List<Map<String, dynamic>>> input,
  ) {
    final cleaned = <String, List<Map<String, dynamic>>>{};
    input.forEach((tableName, entries) {
      final normalized = _normalizeEntries(entries);
      if (normalized.isNotEmpty) {
        cleaned[tableName] = normalized;
      }
    });
    return cleaned;
  }

  static List<Map<String, dynamic>> _normalizeEntries(
    List<Map<String, dynamic>> entries,
  ) {
    final normalized = <Map<String, dynamic>>[];
    for (final rawEntry in entries) {
      final entry = Map<String, dynamic>.from(rawEntry);
      final createdAtRaw =
          (entry[createdAtKey] ?? entry['_preview_saved_at'] ?? '').toString();
      final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      normalized.add(<String, dynamic>{
        ...entry,
        createdAtKey: createdAt.toIso8601String(),
        if (entry[expiresAtKey] != null &&
            entry[expiresAtKey].toString().isNotEmpty)
          expiresAtKey: entry[expiresAtKey].toString(),
        isPreviewKey: true,
      });
    }
    normalized.sort((a, b) {
      final aCreated =
          DateTime.tryParse((a[createdAtKey] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bCreated =
          DateTime.tryParse((b[createdAtKey] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bCreated.compareTo(aCreated);
    });
    return normalized;
  }
}
