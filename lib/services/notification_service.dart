import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/database/app_database.dart';
import '../features/settings/settings_model.dart';
import '../features/settings/data/local/notifications_local_data_source.dart';
import '../features/templates/template_reminder_support.dart';
import 'daily_quote_service.dart';
import 'notification_catalog.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'stop_pomodoro') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pomodoro_stop_requested', true);
  } else if (response.actionId == 'pause_stopwatch') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stopwatch_pause_requested', true);
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AppDatabase _database = AppDatabase.shared();
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
        DarwinNotificationCategory(
          'stopwatch',
          actions: [DarwinNotificationAction.plain('pause_stopwatch', 'Pause')],
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
        } else if (response.actionId == 'pause_stopwatch') {
          await cancelStopwatchStatusNotification();
          await cancelStopwatchReminderNotification();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('stopwatch_pause_requested', true);
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

    await _scheduleHabitNotifications(settings);
    await _scheduleDailyQuoteNotifications(settings);
    await _scheduleTemplateNotifications(settings);
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

  Future<void> showStopwatchStatusNotification() async {
    await init();
    const android = AndroidNotificationDetails(
      'mind_buddy_stopwatch_status',
      'Stopwatch (Status)',
      channelDescription: 'Stopwatch status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      playSound: false,
      actions: [
        AndroidNotificationAction(
          'pause_stopwatch',
          'Pause',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      categoryIdentifier: 'stopwatch',
    );
    await _plugin.show(
      900010,
      'Stopwatch running',
      'Your stopwatch is running quietly in the background.',
      const NotificationDetails(android: android, iOS: ios),
    );
  }

  Future<void> showStopwatchReminderNotification({
    required Duration elapsed,
    required bool hapticsEnabled,
    required bool soundsEnabled,
  }) async {
    await init();
    await _plugin.show(
      900011,
      'Stopwatch still running',
      '${_formatDurationLabel(elapsed)} elapsed',
      _defaultDetails(
        hapticsEnabled: hapticsEnabled,
        soundsEnabled: soundsEnabled,
      ),
    );
  }

  Future<void> cancelStopwatchStatusNotification() async {
    await init();
    await _plugin.cancel(900010);
  }

  Future<void> cancelStopwatchReminderNotification() async {
    await init();
    await _plugin.cancel(900011);
  }

  String _formatDurationLabel(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _scheduleDailyQuoteNotifications(SettingsModel settings) async {
    final quoteSettings = await DailyQuoteService.load();
    final quotes = quoteSettings.allQuotes;
    if (quotes.isEmpty || quoteSettings.notificationTimes.isEmpty) {
      return;
    }

    for (
      var index = 0;
      index < quoteSettings.notificationTimes.length;
      index++
    ) {
      final time = _parseTime(quoteSettings.notificationTimes[index]);
      if (time == null) continue;
      final scheduled = _nextInstanceOfTime(time);
      final quote = _pickDailyQuote(
        quotes: quotes,
        scheduled: scheduled,
        slotIndex: index,
      );
      await _plugin.zonedSchedule(
        _dailyQuoteNotificationId(index),
        'Quote bubble',
        quote,
        scheduled,
        _defaultDetails(
          hapticsEnabled: settings.hapticsEnabled,
          soundsEnabled: settings.soundsEnabled,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _scheduleHabitNotifications(SettingsModel settings) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final localDataSource = NotificationsLocalDataSource(_database);
    final habits = await localDataSource.loadHabitSnapshot(userId: user.id);

    for (final habit in habits) {
      final habitId = habit.id;
      final habitName = habit.name;
      if (habitId.isEmpty || habitName.isEmpty) continue;

      final setting = settings.notificationSpaceSettings['habit:$habitId'];
      if (setting == null || !setting.enabled) continue;
      if (setting.frequency == 'remember') continue;

      final time = _parseTime(setting.time ?? '09:00');
      if (time == null) continue;

      const title = 'Habit Tracker';
      final body = switch (setting.style) {
        'simple' => habitName,
        'quiet' => '$habitName\nHabit reminder',
        _ => 'Gentle nudge for $habitName\nHabit Tracker',
      };

      if (setting.frequency == 'monthly') {
        await _plugin.zonedSchedule(
          _habitNotificationId(habitId, 'monthly'),
          title,
          body,
          _nextInstanceOfMonthDayTime(setting.dayOfMonth, time),
          _defaultDetails(
            hapticsEnabled: settings.hapticsEnabled,
            soundsEnabled: settings.soundsEnabled,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
        continue;
      }

      final weekdays = switch (setting.frequency) {
        'weekly' => setting.days.isEmpty ? <String>['mon'] : setting.days,
        'certain' => setting.days.isEmpty ? <String>['mon'] : setting.days,
        'most' =>
          setting.skipWeekends
              ? <String>['mon', 'tue', 'wed', 'thu', 'fri']
              : <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        _ => <String>[],
      };

      for (final day in weekdays) {
        final weekday = _weekdayFromKey(day);
        if (weekday == null) continue;
        await _plugin.zonedSchedule(
          _habitNotificationId(habitId, day),
          title,
          body,
          _nextInstanceOfWeekdayTime(weekday, time),
          _defaultDetails(
            hapticsEnabled: settings.hapticsEnabled,
            soundsEnabled: settings.soundsEnabled,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  Future<void> _scheduleTemplateNotifications(SettingsModel settings) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final targets = await loadTemplateReminderTargetsLocal(
      database: _database,
      userId: user.id,
    );

    final seen = <String>{};
    for (final target in targets) {
      if (!seen.add(target.spaceId)) continue;
      final setting = settings.notificationSpaceSettings[target.spaceId];
      if (setting == null || !setting.enabled) continue;
      if (setting.frequency == 'remember') continue;

      final times = templateReminderTimesOfDay(setting);
      if (times.isEmpty) continue;

      final category = notificationCategories
          .cast<NotificationCategory?>()
          .firstWhere(
            (item) => item?.id == target.templateKey,
            orElse: () => null,
          );

      if (setting.frequency == 'monthly') {
        for (final time in times) {
          final title = target.title;
          final body = category != null
              ? _notificationBodyForCategory(
                  category: category,
                  style: setting.style,
                  time: time,
                )
              : _notificationBodyForTitle(
                  title: target.title,
                  style: setting.style,
                );
          final suffix =
              'monthly-${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}';
          await _plugin.zonedSchedule(
            _spaceNotificationId(target.spaceId, suffix),
            title,
            body,
            _nextInstanceOfMonthDayTime(setting.dayOfMonth, time),
            _defaultDetails(
              hapticsEnabled: settings.hapticsEnabled,
              soundsEnabled: settings.soundsEnabled,
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          );
        }
        continue;
      }

      final weekdays = switch (setting.frequency) {
        'weekly' => setting.days.isEmpty ? <String>['mon'] : setting.days,
        'certain' => setting.days.isEmpty ? <String>['mon'] : setting.days,
        'most' =>
          setting.skipWeekends
              ? <String>['mon', 'tue', 'wed', 'thu', 'fri']
              : <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        _ => <String>[],
      };

      for (final day in weekdays) {
        final weekday = _weekdayFromKey(day);
        if (weekday == null) continue;
        for (final time in times) {
          final title = target.title;
          final body = category != null
              ? _notificationBodyForCategory(
                  category: category,
                  style: setting.style,
                  time: time,
                )
              : _notificationBodyForTitle(
                  title: target.title,
                  style: setting.style,
                );
          final suffix =
              '$day-${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}';
          await _plugin.zonedSchedule(
            _spaceNotificationId(target.spaceId, suffix),
            title,
            body,
            _nextInstanceOfWeekdayTime(weekday, time),
            _defaultDetails(
              hapticsEnabled: settings.hapticsEnabled,
              soundsEnabled: settings.soundsEnabled,
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    }
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

  int _habitNotificationId(String habitId, String suffix) {
    return 300000 + ('habit:$habitId:$suffix').hashCode.abs() % 500000;
  }

  int _spaceNotificationId(String id, String suffix) {
    return 850000 + ('$id:$suffix').hashCode.abs() % 40000;
  }

  int _dailyQuoteNotificationId(int index) {
    return 700000 + index;
  }

  String _pickDailyQuote({
    required List<String> quotes,
    required DateTime scheduled,
    required int slotIndex,
  }) {
    final seed =
        (scheduled.year * 10000) +
        (scheduled.month * 100) +
        scheduled.day +
        (slotIndex * 17) +
        (scheduled.hour * 7) +
        scheduled.minute;
    final index = seed.abs() % quotes.length;
    return quotes[index];
  }

  String _notificationBodyForCategory({
    required NotificationCategory category,
    required String style,
    required TimeOfDay time,
  }) {
    final messages = time.hour < 15
        ? category.morningMessages
        : category.eveningMessages;
    final fallback = messages.isEmpty
        ? category.description
        : messages[(time.hour + (time.minute * 7)) % messages.length];
    return switch (style) {
      'simple' => category.subtitle,
      'quiet' => '$fallback\n${category.subtitle}',
      _ => '$fallback\n${category.title}',
    };
  }

  String _notificationBodyForTitle({
    required String title,
    required String style,
  }) {
    return switch (style) {
      'simple' => title,
      'quiet' => '$title\nTemplate reminder',
      _ => 'Gentle nudge for $title\nTemplate reminder',
    };
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
