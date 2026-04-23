import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bubble_entry.dart';

const String _bubbleStorageMarker = '[[mbb::bubble::v2]]';

abstract class BubbleBoardStorage {
  const BubbleBoardStorage();

  Future<List<BubbleEntry>> fetchEntries();
  Future<void> saveEntry(BubbleEntry entry);
  Future<void> deleteEntry(BubbleEntry entry);
  Future<void> clearAll();
}

class InMemoryBubbleBoardStorage extends BubbleBoardStorage {
  InMemoryBubbleBoardStorage({
    List<BubbleEntry> seedEntries = const <BubbleEntry>[],
    this.onMutated,
  }) : _entries = seedEntries.map(_cloneEntry).toList(growable: true);

  final VoidCallback? onMutated;
  final List<BubbleEntry> _entries;

  @override
  Future<List<BubbleEntry>> fetchEntries() async {
    return _entries.map(_cloneEntry).toList(growable: false);
  }

  @override
  Future<void> saveEntry(BubbleEntry entry) async {
    final index = _entries.indexWhere((existing) => existing.id == entry.id);
    final copy = _cloneEntry(entry);
    if (index >= 0) {
      _entries[index] = copy;
    } else {
      _entries.add(copy);
    }
    onMutated?.call();
  }

  @override
  Future<void> deleteEntry(BubbleEntry entry) async {
    _entries.removeWhere((existing) => existing.id == entry.id);
    onMutated?.call();
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
    onMutated?.call();
  }
}

class SupabaseBubbleBoardStorage extends BubbleBoardStorage {
  const SupabaseBubbleBoardStorage({required this.tableName});

  final String tableName;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<List<BubbleEntry>> fetchEntries() async {
    final data = await _supabase.from(tableName).select();
    return data
        .map(
          (item) => BubbleEntry(
            id: item['id'].toString(),
            text: _decodeBubblePayload(item['text']).$1,
            solutionText: _decodeBubblePayload(item['text']).$2,
            offset: Offset(
              (item['x_pos'] ?? 100).toDouble(),
              (item['y_pos'] ?? 100).toDouble(),
            ),
            createdAt:
                DateTime.tryParse((item['created_at'] ?? '').toString()) ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveEntry(BubbleEntry entry) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final isTempId = RegExp(r'^\d+$').hasMatch(entry.id);
    final data = <String, dynamic>{
      'user_id': user.id,
      'text': _encodeBubblePayload(entry),
      'x_pos': entry.offset.dx,
      'y_pos': entry.offset.dy,
      'created_at': entry.createdAt.toIso8601String(),
    };
    if (!isTempId) {
      data['id'] = entry.id;
    }
    await _supabase.from(tableName).upsert(data);
  }

  @override
  Future<void> deleteEntry(BubbleEntry entry) async {
    final isRealId = !RegExp(r'^\d+$').hasMatch(entry.id);
    if (!isRealId) return;
    await _supabase.from(tableName).delete().match({'id': entry.id});
  }

  @override
  Future<void> clearAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from(tableName).delete().match({'user_id': user.id});
  }
}

class SharedPrefsBubbleBoardStorage extends BubbleBoardStorage {
  const SharedPrefsBubbleBoardStorage({required this.storageKey});

  final String storageKey;

  @override
  Future<List<BubbleEntry>> fetchEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <BubbleEntry>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <BubbleEntry>[];

    return decoded.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return BubbleEntry(
        id: (map['id'] ?? '').toString(),
        text: _decodeBubblePayload(map['text']).$1,
        solutionText: _decodeBubblePayload(map['text']).$2,
        offset: Offset(
          ((map['x'] ?? 100) as num).toDouble(),
          ((map['y'] ?? 100) as num).toDouble(),
        ),
        createdAt:
            DateTime.tryParse((map['created_at'] ?? '').toString()) ??
            DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> saveEntry(BubbleEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await fetchEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    await prefs.setString(storageKey, jsonEncode(_encodeEntries(entries)));
  }

  @override
  Future<void> deleteEntry(BubbleEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await fetchEntries()
      ..removeWhere((e) => e.id == entry.id);
    await prefs.setString(storageKey, jsonEncode(_encodeEntries(entries)));
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  List<Map<String, dynamic>> _encodeEntries(List<BubbleEntry> entries) {
    return entries
        .map(
          (entry) => <String, dynamic>{
            'id': entry.id,
            'text': _encodeBubblePayload(entry),
            'x': entry.offset.dx,
            'y': entry.offset.dy,
            'created_at': entry.createdAt.toIso8601String(),
          },
        )
        .toList();
  }
}

String _encodeBubblePayload(BubbleEntry entry) {
  if (entry.solutionText.trim().isEmpty) {
    return entry.text;
  }
  return '$_bubbleStorageMarker${jsonEncode(<String, dynamic>{'text': entry.text, 'solution_text': entry.solutionText})}';
}

BubbleEntry _cloneEntry(BubbleEntry entry) {
  return BubbleEntry(
    id: entry.id,
    text: entry.text,
    solutionText: entry.solutionText,
    offset: entry.offset,
    createdAt: entry.createdAt,
  );
}

(String, String) _decodeBubblePayload(Object? rawText) {
  final text = (rawText ?? '').toString();
  if (!text.startsWith(_bubbleStorageMarker)) {
    return (text, '');
  }
  final payloadText = text.substring(_bubbleStorageMarker.length);
  try {
    final decoded = jsonDecode(payloadText);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      return (
        map['text']?.toString() ?? '',
        map['solution_text']?.toString() ?? '',
      );
    }
  } catch (_) {}
  return (text, '');
}
