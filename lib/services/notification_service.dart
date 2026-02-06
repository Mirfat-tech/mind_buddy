import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../features/settings/settings_model.dart';
import 'notification_catalog.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
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
      await _scheduleCalendarReminders();
    }
  }

  Future<void> showPomodoroFinishedNotification({
    required bool wasFocus,
    required String message,
  }) async {
    await init();
    final title = wasFocus ? 'Focus timer finished' : 'Break time finished';
    await _plugin.show(
      900001,
      title,
      message,
      _defaultDetails(),
    );
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
        _defaultDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            settings.notificationRepeat ? DateTimeComponents.dayOfWeekAndTime : null,
      );
    }
  }

  Future<void> _scheduleCalendarReminders() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    List<Map<String, dynamic>> reminders = [];

    try {
      final rows = await supabase
          .from('reminders')
          .select('id, title, day, time, is_completed, is_done')
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

    for (final reminder in reminders) {
      final scheduled = _parseReminderDate(reminder);
      if (scheduled == null) continue;
      if (scheduled.isBefore(now)) continue;

      final title = (reminder['title'] ?? 'Reminder').toString();
      final id = _reminderNotificationId(reminder['id']);

      await _plugin.zonedSchedule(
        id,
        'Reminder',
        '$title\nReminder',
        tz.TZDateTime.from(scheduled, tz.local),
        _defaultDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
    }
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
    final list = isMorning ? category.morningMessages : category.eveningMessages;
    if (list.isEmpty) return category.description;
    final index = max(0, scheduled.day % list.length);
    return list[index];
  }

  String _withSubtitle(String message, String subtitle, DateTime scheduled) {
    final addSoftClose = scheduled.day % 4 == 0;
    final suffix =
        addSoftClose ? '\nOr ignore this — that is okay too.' : '';
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

  NotificationDetails _defaultDetails() {
    const android = AndroidNotificationDetails(
      'mind_buddy_gentle',
      'Mind Buddy',
      channelDescription: 'Gentle check-ins and reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: ios);
  }
}
