import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class UserProfile {
  final String userId;
  final String? displayName;

  const UserProfile({required this.userId, this.displayName});
}

class MemoryNote {
  final String key;
  final String value;
  final int confidence;

  const MemoryNote({
    required this.key,
    required this.value,
    required this.confidence,
  });
}

class MemoryService {
  MemoryService(this._supabase);

  final SupabaseClient _supabase;

  Future<UserProfile> getOrCreateProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    try {
      final bundle = await StartupUserDataService.instance.fetchCombinedForUser(
        user.id,
      );
      final profile = bundle.userProfileRow;
      if (profile != null) {
        return UserProfile(
          userId: user.id,
          displayName: profile['display_name']?.toString(),
        );
      }
      await _supabase.from('user_profile').upsert({
        'user_id': user.id,
        'display_name': null,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return UserProfile(userId: user.id, displayName: null);
    } catch (e) {
      // Return safe default if user_profile fetch fails.
      return UserProfile(userId: user.id, displayName: null);
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('user_profile').upsert({
      'user_id': user.id,
      'display_name': name,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> upsertMemory({
    required String key,
    required String value,
    int confidence = 100,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('user_memory').upsert({
      'user_id': user.id,
      'key': key,
      'value': value,
      'confidence': confidence,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<MemoryNote>> fetchMemoryNotes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    final rows = await _supabase
        .from('user_memory')
        .select('key, value, confidence')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map(
          (r) => MemoryNote(
            key: r['key'].toString(),
            value: r['value'].toString(),
            confidence: (r['confidence'] as num?)?.toInt() ?? 100,
          ),
        )
        .toList();
  }
}

final memoryControllerProvider = ChangeNotifierProvider<MemoryController>((
  ref,
) {
  final supabase = Supabase.instance.client;
  return MemoryController(MemoryService(supabase));
});

class MemoryController extends ChangeNotifier {
  MemoryController(this._service);

  final MemoryService _service;
  bool _loading = true;
  String? _loadError;
  String? _displayName;
  final Map<String, String> _notes = {};
  bool _memoryEnabled = false;

  bool get loading => _loading;
  String? get loadError => _loadError;
  String? get displayName => _displayName;
  Map<String, String> get notes => Map.unmodifiable(_notes);

  Future<void> init() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _displayName = null;
      _notes.clear();
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final profile = await _service.getOrCreateProfile();
      _displayName = profile.displayName;
      final subscription = await SubscriptionLimits.fetchForCurrentUser();
      _memoryEnabled = subscription.supportsMemory;

      if (_memoryEnabled) {
        final memoryNotes = await _service.fetchMemoryNotes();
        _notes
          ..clear()
          ..addEntries(memoryNotes.map((n) => MapEntry(n.key, n.value)));
      } else {
        _notes.clear();
      }
    } catch (e) {
      _displayName = null;
      _notes.clear();
      _loadError = 'Unable to load memory data.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> handleAuthChange() async {
    await init();
  }

  Future<void> retry() async => init();

  String buildMemoryContext() {
    if (!_memoryEnabled) return '';
    final buffer = StringBuffer();
    final name = _displayName ?? _notes['name'];
    final otherNotes = _notes.entries.where((e) => e.key != 'name');
    if (name == null && otherNotes.isEmpty) return '';
    buffer.writeln('Memory context:');
    if (name != null && name.trim().isNotEmpty) {
      buffer.writeln('User name: $name');
    }
    if (otherNotes.isNotEmpty) {
      buffer.writeln('Known memory notes:');
      for (final entry in otherNotes) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
    }
    buffer.writeln(
      'Only use these if relevant. If the user contradicts, prefer the latest user message.',
    );
    return buffer.toString().trim();
  }

  Future<void> captureFromMessage(String text) async {
    if (!_memoryEnabled) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final name = _extractName(trimmed);
    if (name != null) {
      await _service.updateDisplayName(name);
      await _service.upsertMemory(key: 'name', value: name);
      _displayName = name;
      _notes['name'] = name;
      notifyListeners();
    }

    final preference = _extractPreference(trimmed);
    if (preference != null) {
      await _service.upsertMemory(key: 'preference', value: preference);
      _notes['preference'] = preference;
      notifyListeners();
    }

    final avoid = _extractAvoidance(trimmed);
    if (avoid != null) {
      await _service.upsertMemory(key: 'avoid', value: avoid);
      _notes['avoid'] = avoid;
      notifyListeners();
    }
  }

  String? _extractName(String text) {
    final patterns = [
      RegExp(
        r"\bmy name is ([A-Za-z][A-Za-z'\- ]{1,40})",
        caseSensitive: false,
      ),
      RegExp(r"\bcall me ([A-Za-z][A-Za-z'\- ]{1,40})", caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)?.trim();
        if (raw != null && raw.isNotEmpty) return raw;
      }
    }
    return null;
  }

  String? _extractPreference(String text) {
    final match = RegExp(
      r'\bi prefer ([^\.!\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.length > 80 ? value.substring(0, 80) : value;
  }

  String? _extractAvoidance(String text) {
    final match = RegExp(
      r"\bdon't (?:do|say|call|mention) ([^\.!\n]+)",
      caseSensitive: false,
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.length > 80 ? value.substring(0, 80) : value;
  }
}
