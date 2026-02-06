import 'package:mind_buddy/services/notification_catalog.dart';

class NotificationSpaceSetting {
  NotificationSpaceSetting({
    required this.enabled,
    required this.frequency,
    required this.days,
    required this.time,
    required this.skipWeekends,
    required this.dayOfMonth,
    required this.style,
  });

  final bool enabled;
  final String frequency; // 'most', 'certain', 'weekly', 'monthly', 'remember'
  final List<String> days; // mon..sun
  final String? time; // "HH:mm" or null
  final bool skipWeekends;
  final int dayOfMonth; // 1..28
  final String style; // 'soft', 'quiet', 'simple'

  factory NotificationSpaceSetting.defaults() {
    return NotificationSpaceSetting(
      enabled: false,
      frequency: 'most',
      days: const [],
      time: null,
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
    bool? skipWeekends,
    int? dayOfMonth,
    String? style,
  }) {
    return NotificationSpaceSetting(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      days: days ?? this.days,
      time: time ?? this.time,
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
      'time': time,
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
    return NotificationSpaceSetting(
      enabled: json['enabled'] == true,
      frequency: (json['frequency'] ?? 'most').toString(),
      days: parsedDays,
      time: json['time'] as String?,
      skipWeekends: json['skipWeekends'] == true,
      dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
      style: (json['style'] ?? 'soft').toString(),
    );
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
    required this.calendarRemindersEnabled,
    required this.pomodoroAlertsEnabled,
    required this.keepInstructionsEnabled,
    required this.updatedAt,
    required this.version,
  });

  final String? themeId;
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
  final bool calendarRemindersEnabled;
  final bool pomodoroAlertsEnabled;
  final bool keepInstructionsEnabled;
  final String updatedAt; // ISO string
  final int version;

  factory SettingsModel.defaults() {
    return SettingsModel(
      themeId: null,
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
      calendarRemindersEnabled: true,
      pomodoroAlertsEnabled: true,
      keepInstructionsEnabled: false,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      version: 1,
    );
  }

  SettingsModel copyWith({
    String? themeId,
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
    bool? calendarRemindersEnabled,
    bool? pomodoroAlertsEnabled,
    bool? keepInstructionsEnabled,
    String? updatedAt,
    int? version,
  }) {
    return SettingsModel(
      themeId: themeId ?? this.themeId,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      dailyCheckInEnabled: dailyCheckInEnabled ?? this.dailyCheckInEnabled,
      dailyCheckInTime: dailyCheckInTime ?? this.dailyCheckInTime,
      notificationDays: notificationDays ?? this.notificationDays,
      notificationTime: notificationTime ?? this.notificationTime,
      notificationRepeat: notificationRepeat ?? this.notificationRepeat,
      notificationCategories: notificationCategories ?? this.notificationCategories,
      notificationSpaceSettings:
          notificationSpaceSettings ?? this.notificationSpaceSettings,
      maxNotificationsPerDay:
          maxNotificationsPerDay ?? this.maxNotificationsPerDay,
      calendarRemindersEnabled:
          calendarRemindersEnabled ?? this.calendarRemindersEnabled,
      pomodoroAlertsEnabled: pomodoroAlertsEnabled ?? this.pomodoroAlertsEnabled,
      keepInstructionsEnabled:
          keepInstructionsEnabled ?? this.keepInstructionsEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeId': themeId,
      'quietHoursEnabled': quietHoursEnabled,
      'quietStart': quietStart,
      'quietEnd': quietEnd,
      'dailyCheckInEnabled': dailyCheckInEnabled,
      'dailyCheckInTime': dailyCheckInTime,
      'notificationDays': notificationDays,
      'notificationTime': notificationTime,
      'notificationRepeat': notificationRepeat,
      'notificationCategories': notificationCategories,
      'notificationSpaceSettings':
          notificationSpaceSettings.map((key, value) => MapEntry(key, value.toJson())),
      'maxNotificationsPerDay': maxNotificationsPerDay,
      'calendarRemindersEnabled': calendarRemindersEnabled,
      'pomodoroAlertsEnabled': pomodoroAlertsEnabled,
      'keepInstructionsEnabled': keepInstructionsEnabled,
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
          parsedSpaceSettings[key.toString()] =
              NotificationSpaceSetting.fromJson(
                Map<String, dynamic>.from(value),
              );
        }
      });
    }

    return SettingsModel(
      themeId: json['themeId'] as String?,
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
      calendarRemindersEnabled:
          (json['calendarRemindersEnabled'] ?? true) as bool,
      pomodoroAlertsEnabled: (json['pomodoroAlertsEnabled'] ?? true) as bool,
      keepInstructionsEnabled:
          (json['keepInstructionsEnabled'] ?? false) as bool,
      updatedAt: (updatedAtOverride ??
              json['updatedAt'] ??
              DateTime.fromMillisecondsSinceEpoch(0).toIso8601String())
          as String,
      version: (json['version'] ?? 1) as int,
    );
  }

  DateTime get updatedAtDateTime =>
      DateTime.tryParse(updatedAt) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
