class SettingsModel {
  SettingsModel({
    required this.themeId,
    required this.quietHoursEnabled,
    required this.quietStart,
    required this.quietEnd,
    required this.dailyCheckInEnabled,
    required this.dailyCheckInTime,
    required this.updatedAt,
    required this.version,
  });

  final String? themeId;
  final bool quietHoursEnabled;
  final String quietStart; // "HH:mm"
  final String quietEnd; // "HH:mm"
  final bool dailyCheckInEnabled;
  final String dailyCheckInTime; // "HH:mm"
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
      'updatedAt': updatedAt,
      'version': version,
    };
  }

  factory SettingsModel.fromJson(
    Map<String, dynamic> json, {
    String? updatedAtOverride,
  }) {
    return SettingsModel(
      themeId: json['themeId'] as String?,
      quietHoursEnabled: (json['quietHoursEnabled'] ?? false) as bool,
      quietStart: (json['quietStart'] ?? '22:00') as String,
      quietEnd: (json['quietEnd'] ?? '07:00') as String,
      dailyCheckInEnabled: (json['dailyCheckInEnabled'] ?? false) as bool,
      dailyCheckInTime: (json['dailyCheckInTime'] ?? '09:00') as String,
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
