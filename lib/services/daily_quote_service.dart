import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyQuoteSettings {
  const DailyQuoteSettings({
    required this.customQuotes,
    required this.notificationTimes,
    required this.styleId,
  });

  final List<String> customQuotes;
  final List<String> notificationTimes;
  final String styleId;

  List<String> get allQuotes => <String>[
    ...DailyQuoteService.defaultQuotes,
    ...customQuotes,
  ];

  DailyQuoteSettings copyWith({
    List<String>? customQuotes,
    List<String>? notificationTimes,
    String? styleId,
  }) {
    return DailyQuoteSettings(
      customQuotes: customQuotes ?? this.customQuotes,
      notificationTimes: notificationTimes ?? this.notificationTimes,
      styleId: styleId ?? this.styleId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'custom_quotes': customQuotes,
      'notification_times': notificationTimes,
      'style_id': styleId,
    };
  }

  factory DailyQuoteSettings.fromJson(Map<String, dynamic> json) {
    final rawQuotes = json['custom_quotes'];
    final rawTimes = json['notification_times'];
    return DailyQuoteSettings(
      customQuotes: rawQuotes is List
          ? rawQuotes.map((item) => item.toString()).toList()
          : const <String>[],
      notificationTimes: rawTimes is List
          ? rawTimes.map((item) => item.toString()).toList()
          : const <String>[],
      styleId: (json['style_id'] ?? 'soft').toString(),
    );
  }

  factory DailyQuoteSettings.defaults() {
    return const DailyQuoteSettings(
      customQuotes: <String>[],
      notificationTimes: <String>[],
      styleId: 'soft',
    );
  }
}

class DailyQuoteService {
  DailyQuoteService._();

  static const String _storagePrefix = 'daily_quote_bubble_v1';

  static const List<String> defaultQuotes = <String>[
    'I only identify with my positive thoughts',
    'I allow my negative thoughts to pass by',
    'When negative thoughts come up, I tell myself I am experiencing that emotion, I am not the emotion itself',
    'I am destined for success',
    'I am allowed to take up space',
    'I get more and more beautiful by the day',
    'I allow all positive thoughts to stay and all negative thoughts to pass on by',
    'My past is behind me for a reason',
    'I am allowed to change my life because it’s always my turn to decide',
    'Talk to yourself like someone you love',
    'I have every right to be happy',
    'I am aligned with the path of my goals',
    'I am divinely protected',
  ];

  static Future<DailyQuoteSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _storageKey());
    if (raw == null || raw.trim().isEmpty) {
      return DailyQuoteSettings.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _sanitize(DailyQuoteSettings.fromJson(decoded));
      }
      if (decoded is Map) {
        return _sanitize(
          DailyQuoteSettings.fromJson(Map<String, dynamic>.from(decoded)),
        );
      }
    } catch (_) {}
    return DailyQuoteSettings.defaults();
  }

  static Future<void> save(DailyQuoteSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final next = _sanitize(settings);
    await prefs.setString(await _storageKey(), jsonEncode(next.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _storageKey());
  }

  static DailyQuoteSettings _sanitize(DailyQuoteSettings settings) {
    final customQuotes = settings.customQuotes
        .map((quote) => quote.trim())
        .where((quote) => quote.isNotEmpty)
        .toSet()
        .toList();
    final notificationTimes = settings.notificationTimes
        .map((time) => time.trim())
        .where(_isValidTime)
        .toSet()
        .toList()
      ..sort();
    return DailyQuoteSettings(
      customQuotes: customQuotes,
      notificationTimes: notificationTimes,
      styleId: settings.styleId.trim().isEmpty ? 'soft' : settings.styleId,
    );
  }

  static bool _isValidTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts.first);
    final minute = int.tryParse(parts.last);
    if (hour == null || minute == null) return false;
    return hour >= 0 && hour < 24 && minute >= 0 && minute < 60;
  }

  static Future<String> _storageKey() async {
    final user = Supabase.instance.client.auth.currentUser;
    final suffix = user?.id ?? 'guest';
    return '$_storagePrefix:$suffix';
  }
}
