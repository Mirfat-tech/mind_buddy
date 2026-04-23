import 'package:mind_buddy/services/notification_catalog.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class NotificationSpaceSetting {
  NotificationSpaceSetting({
    required this.enabled,
    required this.frequency,
    required this.days,
    required this.time,
    required this.times,
    required this.skipWeekends,
    required this.dayOfMonth,
    required this.style,
  });

  final bool enabled;
  final String frequency; // 'most', 'certain', 'weekly', 'monthly', 'remember'
  final List<String> days; // mon..sun
  final String? time; // "HH:mm" or null
  final List<String> times; // "HH:mm"
  final bool skipWeekends;
  final int dayOfMonth; // 1..28
  final String style; // 'soft', 'quiet', 'simple'

  List<String> get reminderTimes =>
      _normalizeReminderTimes(times, fallbackTime: time);

  String? get primaryTime {
    final normalized = reminderTimes;
    return normalized.isEmpty ? null : normalized.first;
  }

  factory NotificationSpaceSetting.defaults() {
    return NotificationSpaceSetting(
      enabled: false,
      frequency: 'most',
      days: const [],
      time: null,
      times: const [],
      skipWeekends: false,
      dayOfMonth: 1,
      style: 'soft',
    );
  }

  NotificationSpaceSetting copyWith({
    bool? enabled,
    String? frequency,
    List<String>? days,
    String? time,
    List<String>? times,
    bool? skipWeekends,
    int? dayOfMonth,
    String? style,
  }) {
    final resolvedTime = time ?? this.time;
    final rawTimes = times ?? (time != null ? <String>[time] : this.times);
    final resolvedTimes = _normalizeReminderTimes(
      rawTimes,
      fallbackTime: resolvedTime,
    );
    return NotificationSpaceSetting(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      days: days ?? this.days,
      time: resolvedTimes.isEmpty ? resolvedTime : resolvedTimes.first,
      times: resolvedTimes,
      skipWeekends: skipWeekends ?? this.skipWeekends,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      style: style ?? this.style,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'frequency': frequency,
      'days': days,
      'time': primaryTime,
      'times': reminderTimes,
      'skipWeekends': skipWeekends,
      'dayOfMonth': dayOfMonth,
      'style': style,
    };
  }

  factory NotificationSpaceSetting.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final parsedDays = rawDays is List
        ? rawDays.map((d) => d.toString()).toList()
        : <String>[];
    final parsedTimes = _normalizeReminderTimes(
      json['times'] is List
          ? (json['times'] as List).map((time) => time.toString()).toList()
          : const <String>[],
      fallbackTime: json['time'] as String?,
    );
    return NotificationSpaceSetting(
      enabled: json['enabled'] == true,
      frequency: (json['frequency'] ?? 'most').toString(),
      days: parsedDays,
      time: parsedTimes.isEmpty ? json['time'] as String? : parsedTimes.first,
      times: parsedTimes,
      skipWeekends: json['skipWeekends'] == true,
      dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
      style: (json['style'] ?? 'soft').toString(),
    );
  }

  static List<String> _normalizeReminderTimes(
    Iterable<dynamic> rawTimes, {
    String? fallbackTime,
  }) {
    final seen = <String>{};
    final normalized = <String>[];

    void pushValue(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return;
      final parts = value.split(':');
      if (parts.length != 2) return;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;
      final safe =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      if (seen.add(safe)) {
        normalized.add(safe);
      }
    }

    for (final raw in rawTimes) {
      pushValue(raw.toString());
    }
    if (normalized.isEmpty && fallbackTime != null) {
      pushValue(fallbackTime);
    }
    normalized.sort();
    return normalized;
  }
}

Map<String, NotificationSpaceSetting> defaultNotificationSpaceSettings() {
  return {
    for (final category in notificationCategories)
      category.id: NotificationSpaceSetting.defaults(),
  };
}

class SettingsModel {
  SettingsModel({
    required this.themeId,
    required this.customThemes,
    required this.quietHoursEnabled,
    required this.quietStart,
    required this.quietEnd,
    required this.dailyCheckInEnabled,
    required this.dailyCheckInTime,
    required this.notificationDays,
    required this.notificationTime,
    required this.notificationRepeat,
    required this.notificationCategories,
    required this.notificationSpaceSettings,
    required this.maxNotificationsPerDay,
    required this.pomodoroAlertsEnabled,
    required this.stopwatchAlertsEnabled,
    required this.stopwatchReminderMinutes,
    required this.hapticsEnabled,
    required this.soundsEnabled,
    required this.keepInstructionsEnabled,
    required this.guideState,
    required this.updatedAt,
    required this.version,
  });

  final String? themeId;
  final List<PaperStyle> customThemes;
  final bool quietHoursEnabled;
  final String quietStart; // "HH:mm"
  final String quietEnd; // "HH:mm"
  final bool dailyCheckInEnabled;
  final String dailyCheckInTime; // "HH:mm"
  final List<String> notificationDays;
  final String notificationTime; // "HH:mm"
  final bool notificationRepeat;
  final Map<String, bool> notificationCategories;
  final Map<String, NotificationSpaceSetting> notificationSpaceSettings;
  final int maxNotificationsPerDay;
  final bool pomodoroAlertsEnabled;
  final bool stopwatchAlertsEnabled;
  final int stopwatchReminderMinutes;
  final bool hapticsEnabled;
  final bool soundsEnabled;
  final bool keepInstructionsEnabled;
  final Map<String, dynamic> guideState;
  final String updatedAt; // ISO string
  final int version;

  factory SettingsModel.defaults() {
    return SettingsModel(
      themeId: null,
      customThemes: const <PaperStyle>[],
      quietHoursEnabled: false,
      quietStart: '22:00',
      quietEnd: '07:00',
      dailyCheckInEnabled: false,
      dailyCheckInTime: '09:00',
      notificationDays: const [],
      notificationTime: '09:00',
      notificationRepeat: true,
      notificationCategories: defaultNotificationCategoryState(),
      notificationSpaceSettings: defaultNotificationSpaceSettings(),
      maxNotificationsPerDay: 2,
      pomodoroAlertsEnabled: true,
      stopwatchAlertsEnabled: true,
      stopwatchReminderMinutes: 0,
      hapticsEnabled: true,
      soundsEnabled: true,
      keepInstructionsEnabled: false,
      guideState: const <String, dynamic>{},
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      version: 1,
    );
  }

  SettingsModel copyWith({
    String? themeId,
    List<PaperStyle>? customThemes,
    bool? quietHoursEnabled,
    String? quietStart,
    String? quietEnd,
    bool? dailyCheckInEnabled,
    String? dailyCheckInTime,
    List<String>? notificationDays,
    String? notificationTime,
    bool? notificationRepeat,
    Map<String, bool>? notificationCategories,
    Map<String, NotificationSpaceSetting>? notificationSpaceSettings,
    int? maxNotificationsPerDay,
    bool? pomodoroAlertsEnabled,
    bool? stopwatchAlertsEnabled,
    int? stopwatchReminderMinutes,
    bool? hapticsEnabled,
    bool? soundsEnabled,
    bool? keepInstructionsEnabled,
    Map<String, dynamic>? guideState,
    String? updatedAt,
    int? version,
  }) {
    return SettingsModel(
      themeId: themeId ?? this.themeId,
      customThemes: customThemes ?? this.customThemes,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      dailyCheckInEnabled: dailyCheckInEnabled ?? this.dailyCheckInEnabled,
      dailyCheckInTime: dailyCheckInTime ?? this.dailyCheckInTime,
      notificationDays: notificationDays ?? this.notificationDays,
      notificationTime: notificationTime ?? this.notificationTime,
      notificationRepeat: notificationRepeat ?? this.notificationRepeat,
      notificationCategories:
          notificationCategories ?? this.notificationCategories,
      notificationSpaceSettings:
          notificationSpaceSettings ?? this.notificationSpaceSettings,
      maxNotificationsPerDay:
          maxNotificationsPerDay ?? this.maxNotificationsPerDay,
      pomodoroAlertsEnabled:
          pomodoroAlertsEnabled ?? this.pomodoroAlertsEnabled,
      stopwatchAlertsEnabled:
          stopwatchAlertsEnabled ?? this.stopwatchAlertsEnabled,
      stopwatchReminderMinutes:
          stopwatchReminderMinutes ?? this.stopwatchReminderMinutes,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      keepInstructionsEnabled:
          keepInstructionsEnabled ?? this.keepInstructionsEnabled,
      guideState: guideState ?? this.guideState,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeId': themeId,
      'customThemes': customThemes.map((theme) => theme.toJson()).toList(),
      'quietHoursEnabled': quietHoursEnabled,
      'quietStart': quietStart,
      'quietEnd': quietEnd,
      'dailyCheckInEnabled': dailyCheckInEnabled,
      'dailyCheckInTime': dailyCheckInTime,
      'notificationDays': notificationDays,
      'notificationTime': notificationTime,
      'notificationRepeat': notificationRepeat,
      'notificationCategories': notificationCategories,
      'notificationSpaceSettings': notificationSpaceSettings.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'maxNotificationsPerDay': maxNotificationsPerDay,
      'pomodoroAlertsEnabled': pomodoroAlertsEnabled,
      'stopwatchAlertsEnabled': stopwatchAlertsEnabled,
      'stopwatchReminderMinutes': stopwatchReminderMinutes,
      'hapticsEnabled': hapticsEnabled,
      'soundsEnabled': soundsEnabled,
      'keepInstructionsEnabled': keepInstructionsEnabled,
      'guideState': guideState,
      'updatedAt': updatedAt,
      'version': version,
    };
  }

  factory SettingsModel.fromJson(
    Map<String, dynamic> json, {
    String? updatedAtOverride,
  }) {
    final rawDays = json['notificationDays'];
    final parsedDays = rawDays is List
        ? rawDays.map((d) => d.toString()).toList()
        : <String>[];

    final rawCategories = json['notificationCategories'];
    final parsedCategories = defaultNotificationCategoryState();
    if (rawCategories is Map) {
      rawCategories.forEach((key, value) {
        parsedCategories[key.toString()] = value == true;
      });
    }

    final rawSpaceSettings = json['notificationSpaceSettings'];
    final parsedSpaceSettings = defaultNotificationSpaceSettings();
    if (rawSpaceSettings is Map) {
      rawSpaceSettings.forEach((key, value) {
        if (value is Map) {
          parsedSpaceSettings[key
              .toString()] = NotificationSpaceSetting.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    final rawGuideState = json['guideState'];
    final parsedGuideState = rawGuideState is Map
        ? Map<String, dynamic>.from(rawGuideState)
        : <String, dynamic>{};

    final rawCustomThemes = json['customThemes'];
    final parsedCustomThemes = rawCustomThemes is List
        ? rawCustomThemes
              .whereType<Map>()
              .map(
                (theme) =>
                    PaperStyle.fromJson(Map<String, dynamic>.from(theme)),
              )
              .where((theme) => theme.id.trim().isNotEmpty)
              .toList()
        : <PaperStyle>[];

    return SettingsModel(
      themeId: json['themeId'] as String?,
      customThemes: parsedCustomThemes,
      quietHoursEnabled: (json['quietHoursEnabled'] ?? false) as bool,
      quietStart: (json['quietStart'] ?? '22:00') as String,
      quietEnd: (json['quietEnd'] ?? '07:00') as String,
      dailyCheckInEnabled: (json['dailyCheckInEnabled'] ?? false) as bool,
      dailyCheckInTime: (json['dailyCheckInTime'] ?? '09:00') as String,
      notificationDays: parsedDays,
      notificationTime: (json['notificationTime'] ?? '09:00') as String,
      notificationRepeat: (json['notificationRepeat'] ?? true) as bool,
      notificationCategories: parsedCategories,
      notificationSpaceSettings: parsedSpaceSettings,
      maxNotificationsPerDay: (json['maxNotificationsPerDay'] ?? 2) as int,
      pomodoroAlertsEnabled: (json['pomodoroAlertsEnabled'] ?? true) as bool,
      stopwatchAlertsEnabled: (json['stopwatchAlertsEnabled'] ?? true) as bool,
      stopwatchReminderMinutes: (json['stopwatchReminderMinutes'] ?? 0) as int,
      hapticsEnabled: (json['hapticsEnabled'] ?? true) as bool,
      soundsEnabled: (json['soundsEnabled'] ?? true) as bool,
      keepInstructionsEnabled:
          (json['keepInstructionsEnabled'] ?? false) as bool,
      guideState: parsedGuideState,
      updatedAt:
          (updatedAtOverride ??
                  json['updatedAt'] ??
                  DateTime.fromMillisecondsSinceEpoch(0).toIso8601String())
              as String,
      version: (json['version'] ?? 1) as int,
    );
  }

  DateTime get updatedAtDateTime =>
      DateTime.tryParse(updatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
