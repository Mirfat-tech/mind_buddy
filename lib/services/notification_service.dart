import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../features/settings/settings_model.dart';
import 'notification_catalog.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'stop_pomodoro') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pomodoro_stop_requested', true);
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _maxReminderTimesPerDay = 50;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'pomodoro',
          actions: [DarwinNotificationAction.plain('stop_pomodoro', 'Stop')],
          options: {DarwinNotificationCategoryOption.customDismissAction},
        ),
      ],
    );

    final settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.actionId == 'stop_pomodoro') {
          await cancelPomodoroStatusNotification();
          await cancelPomodoroFinishedNotification();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('pomodoro_stop_requested', true);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _ensureTimeZone();
    _initialized = true;
  }

  Future<void> _ensureTimeZone() async {
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> rescheduleAll(SettingsModel settings) async {
    await init();
    await _plugin.cancelAll();

    await _scheduleCategoryNotifications(settings);

    if (settings.calendarRemindersEnabled) {
      await _scheduleCalendarReminders(settings);
    }
  }

  Future<void> showPomodoroFinishedNotification({
    required bool wasFocus,
    required String message,
    required bool hapticsEnabled,
    required bool soundsEnabled,
  }) async {
    await init();
    final title = wasFocus ? 'Focus timer finished' : 'Break time finished';
    await _plugin.show(
      900001,
      title,
      message,
      _pomodoroAlertDetails(
        hapticsEnabled: hapticsEnabled,
        soundsEnabled: soundsEnabled,
      ),
    );
  }

  Future<void> schedulePomodoroEndNotification({
    required bool wasFocus,
    required DateTime endsAt,
    required String message,
    required bool hapticsEnabled,
    required bool soundsEnabled,
  }) async {
    await init();
    final title = wasFocus ? 'Focus timer finished' : 'Break time finished';
    await _plugin.zonedSchedule(
      900001,
      title,
      message,
      tz.TZDateTime.from(endsAt, tz.local),
      _pomodoroAlertDetails(
        hapticsEnabled: hapticsEnabled,
        soundsEnabled: soundsEnabled,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  Future<void> showPomodoroStatusNotification({
    required bool wasFocus,
    required int secondsLeft,
    required int totalSeconds,
    required DateTime endsAt,
  }) async {
    await init();
    final minutesLeft = (secondsLeft / 60).ceil();
    final endLabel =
        '${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}';
    final title = wasFocus ? 'Focus timer running' : 'Break timer running';
    final body = '$minutesLeft min left • Ends at $endLabel';
    final android = AndroidNotificationDetails(
      'mind_buddy_pomodoro_status',
      'Pomodoro (Status)',
      channelDescription: 'Pomodoro timer status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showProgress: true,
      onlyAlertOnce: true,
      playSound: false,
      maxProgress: totalSeconds,
      progress: (totalSeconds - secondsLeft).clamp(0, totalSeconds),
      actions: const [
        AndroidNotificationAction(
          'stop_pomodoro',
          'Stop',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      categoryIdentifier: 'pomodoro',
    );
    await _plugin.show(
      900000,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }

  Future<void> cancelPomodoroStatusNotification() async {
    await init();
    await _plugin.cancel(900000);
  }

  Future<void> cancelPomodoroFinishedNotification() async {
    await init();
    await _plugin.cancel(900001);
  }

  Future<void> _scheduleCategoryNotifications(SettingsModel settings) async {
    final days = settings.notificationDays;
    if (days.isEmpty) return;

    final enabledCategories = notificationCategories
        .where(
          (category) => settings.notificationCategories[category.id] == true,
        )
        .toList();

    if (enabledCategories.isEmpty) return;

    final time = _parseTime(settings.notificationTime);
    if (time == null) return;

    for (final day in days) {
      final weekday = _weekdayFromKey(day);
      if (weekday == null) continue;

      final scheduled = _nextInstanceOfWeekdayTime(weekday, time);
      final category =
          enabledCategories[(weekday - 1) % enabledCategories.length];
      final message = _pickMessage(category, scheduled);
      final body = _withSubtitle(message, category.subtitle, scheduled);

      final id = _categoryNotificationId(category.id, weekday);

      await _plugin.zonedSchedule(
        id,
        category.title,
        body,
        scheduled,
        _defaultDetails(
          hapticsEnabled: settings.hapticsEnabled,
          soundsEnabled: settings.soundsEnabled,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: settings.notificationRepeat
            ? DateTimeComponents.dayOfWeekAndTime
            : null,
      );
    }
  }

  Future<void> _scheduleCalendarReminders(SettingsModel settings) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 30));

    List<Map<String, dynamic>> reminders = [];

    try {
      final rows = await supabase
          .from('reminders')
          .select(
            'id, title, day, time, repeat, repeat_days, end_day, is_completed, is_done',
          )
          .eq('user_id', user.id);

      reminders = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      try {
        final rows = await supabase
            .from('calendar_events')
            .select('id, title, datetime, type')
            .eq('user_id', user.id)
            .eq('type', 'reminder');
        reminders = List<Map<String, dynamic>>.from(rows);
      } catch (err) {
        debugPrint('Reminder fetch failed: $err');
        return;
      }
    }

    List<Map<String, dynamic>> skips = [];
    try {
      final rows = await supabase
          .from('reminders_skips')
          .select('reminder_id, day')
          .eq('user_id', user.id)
          .gte('day', _formatDate(now))
          .lte('day', _formatDate(horizon));
      skips = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Reminder skips fetch failed: $e');
    }
    final skippedKeys = skips
        .map((r) => '${r['reminder_id']}-${r['day']}')
        .toSet();

    for (final reminder in reminders) {
      final title = (reminder['title'] ?? 'Reminder').toString();
      final occurrences = _generateReminderOccurrences(
        reminder,
        now,
        horizon,
        skippedKeys,
      );
      for (final occurrence in occurrences) {
        if (occurrence.isBefore(now)) continue;
        final id = _reminderOccurrenceId(reminder['id'], occurrence);
        await _plugin.zonedSchedule(
          id,
          'Reminder',
          '$title\nReminder',
          tz.TZDateTime.from(occurrence, tz.local),
          _defaultDetails(
            hapticsEnabled: settings.hapticsEnabled,
            soundsEnabled: settings.soundsEnabled,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: null,
        );
      }
    }
  }

  List<DateTime> _generateReminderOccurrences(
    Map<String, dynamic> reminder,
    DateTime start,
    DateTime end,
    Set<String> skippedKeys,
  ) {
    final dayStr = reminder['day']?.toString() ?? '';
    final endStr = reminder['end_day']?.toString() ?? '';
    final baseDate = DateTime.tryParse(dayStr);
    final endDate = endStr.isEmpty ? null : DateTime.tryParse(endStr);
    if (baseDate == null) return [];

    final times = _parseReminderTimes(
      reminder['time'],
    ).take(_maxReminderTimesPerDay).toList();
    if (times.isEmpty) {
      return [];
    }
    final repeat = (reminder['repeat'] ?? 'never').toString().toLowerCase();
    final repeatDaysRaw = (reminder['repeat_days'] ?? '')
        .toString()
        .toLowerCase();
    final repeatDays = repeatDaysRaw
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toSet();

    final occurrences = <DateTime>[];
    DateTime cursor = DateTime(start.year, start.month, start.day);
    while (!cursor.isAfter(end)) {
      final dateOnly = DateTime(cursor.year, cursor.month, cursor.day);
      final reminderBase = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
      );
      if (dateOnly.isBefore(reminderBase)) {
        cursor = cursor.add(const Duration(days: 1));
        continue;
      }
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day);
        if (dateOnly.isAfter(end)) {
          cursor = cursor.add(const Duration(days: 1));
          continue;
        }
      }

      bool match = false;
      switch (repeat) {
        case 'never':
          match = dateOnly == reminderBase;
          break;
        case 'daily':
          match = true;
          break;
        case 'weekly':
          match = dateOnly.weekday == reminderBase.weekday;
          break;
        case 'fortnightly':
          match = dateOnly.difference(reminderBase).inDays % 14 == 0;
          break;
        case 'monthly':
          match = dateOnly.day == reminderBase.day;
          break;
        case 'weekdays':
          match =
              dateOnly.weekday >= DateTime.monday &&
              dateOnly.weekday <= DateTime.friday;
          break;
        case 'weekends':
          match =
              dateOnly.weekday == DateTime.saturday ||
              dateOnly.weekday == DateTime.sunday;
          break;
        case 'custom':
          match = repeatDays.contains(_weekdayKey(dateOnly.weekday));
          break;
      }

      if (match) {
        final key = '${reminder['id']}-${_formatDate(dateOnly)}';
        if (!skippedKeys.contains(key)) {
          for (final time in times) {
            occurrences.add(
              DateTime(
                dateOnly.year,
                dateOnly.month,
                dateOnly.day,
                time.hour,
                time.minute,
              ),
            );
          }
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return occurrences;
  }

  int _reminderOccurrenceId(dynamic id, DateTime date) {
    final base = _reminderNotificationId(id);
    final y = date.year % 100;
    final m = date.month;
    final d = date.day;
    final hhmm = (date.hour * 100) + date.minute;
    return base + (y * 1000000) + (m * 10000) + (d * 100) + hhmm;
  }

  DateTime? _parseReminderDate(Map<String, dynamic> reminder) {
    if (reminder['datetime'] != null) {
      return DateTime.tryParse(reminder['datetime'].toString());
    }

    final day = reminder['day']?.toString();
    if (day == null || day.isEmpty) return null;
    final time = reminder['time']?.toString() ?? '09:00';
    final parts = time.split(':');
    if (parts.length < 2) return DateTime.tryParse(day);

    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    final date = DateTime.tryParse(day);
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfMonthDayTime(int dayOfMonth, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    int year = now.year;
    int month = now.month;

    int lastDay = DateTime(year, month + 1, 0).day;
    int day = dayOfMonth.clamp(1, lastDay);

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      year,
      month,
      day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
      lastDay = DateTime(year, month + 1, 0).day;
      day = dayOfMonth.clamp(1, lastDay);
      scheduled = tz.TZDateTime(
        tz.local,
        year,
        month,
        day,
        time.hour,
        time.minute,
      );
    }
    return scheduled;
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _pickMessage(NotificationCategory category, DateTime scheduled) {
    final isMorning = scheduled.hour < 12;
    final list = isMorning
        ? category.morningMessages
        : category.eveningMessages;
    if (list.isEmpty) return category.description;
    final index = max(0, scheduled.day % list.length);
    return list[index];
  }

  String _withSubtitle(String message, String subtitle, DateTime scheduled) {
    final addSoftClose = scheduled.day % 4 == 0;
    final suffix = addSoftClose ? '\nOr ignore this — that is okay too.' : '';
    return '$message\n$subtitle$suffix';
  }

  int _categoryNotificationId(String categoryId, int weekday) {
    return categoryId.hashCode.abs() % 100000 + weekday;
  }

  int _reminderNotificationId(dynamic id) {
    final value = int.tryParse(id?.toString() ?? '');
    if (value != null) return 200000 + value;
    return 200000 + id.hashCode.abs() % 80000;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  int? _weekdayFromKey(String key) {
    switch (key) {
      case 'mon':
        return DateTime.monday;
      case 'tue':
        return DateTime.tuesday;
      case 'wed':
        return DateTime.wednesday;
      case 'thu':
        return DateTime.thursday;
      case 'fri':
        return DateTime.friday;
      case 'sat':
        return DateTime.saturday;
      case 'sun':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  String _weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return '';
    }
  }

  List<TimeOfDay> _parseReminderTimes(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.trim().isEmpty) {
      return const [TimeOfDay(hour: 9, minute: 0)];
    }
    final seen = <String>{};
    final parsed = <TimeOfDay>[];
    for (final token in text.split(',')) {
      final t = _parseTime(token.trim());
      if (t == null) continue;
      final key =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      if (seen.add(key)) {
        parsed.add(t);
      }
    }
    if (parsed.isEmpty) {
      return const [TimeOfDay(hour: 9, minute: 0)];
    }
    parsed.sort((a, b) {
      final am = a.hour * 60 + a.minute;
      final bm = b.hour * 60 + b.minute;
      return am.compareTo(bm);
    });
    return parsed;
  }

  NotificationDetails _defaultDetails({
    required bool hapticsEnabled,
    required bool soundsEnabled,
  }) {
    final android = AndroidNotificationDetails(
      'mind_buddy_gentle',
      'MyBrainBubble',
      channelDescription: 'Gentle check-ins and reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: soundsEnabled,
      enableVibration: hapticsEnabled,
    );
    final ios = DarwinNotificationDetails(
      presentSound: soundsEnabled,
      presentAlert: true,
      presentBadge: true,
      sound: soundsEnabled ? 'default' : null,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  NotificationDetails _pomodoroAlertDetails({
    required bool hapticsEnabled,
    required bool soundsEnabled,
  }) {
    final android = AndroidNotificationDetails(
      'mind_buddy_pomodoro_alert',
      'Pomodoro (Alert)',
      channelDescription: 'Pomodoro timer finished alerts',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      onlyAlertOnce: true,
      playSound: soundsEnabled,
      enableVibration: hapticsEnabled,
      actions: const [
        AndroidNotificationAction(
          'stop_pomodoro',
          'Stop',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    final ios = DarwinNotificationDetails(
      categoryIdentifier: 'pomodoro',
      presentSound: soundsEnabled,
      sound: soundsEnabled ? 'default' : null,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: android, iOS: ios);
  }
}
