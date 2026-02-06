import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings_model.dart';
import 'settings_repository.dart';
import '../../services/notification_service.dart';
import '../../services/notification_catalog.dart';

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((
  ref,
) {
  final supabase = Supabase.instance.client;
  final repo = SettingsRepository(supabase);
  return SettingsController(repo);
});

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo);

  final SettingsRepository _repo;

  SettingsModel _settings = SettingsModel.defaults();
  bool _loading = true;

  SettingsModel get settings => _settings;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    SettingsModel? local = await _repo.loadLocal();
    SettingsModel? remote = await _repo.fetchRemote();

    if (local != null) {
      _settings = local;
    }

    if (remote != null) {
      final newer = _pickNewest(local, remote);
      _settings = newer;
      await _repo.saveLocal(_settings);
    } else if (local != null) {
      await _repo.upsertRemote(local);
    }

    await NotificationService.instance.rescheduleAll(_settings);

    _loading = false;
    notifyListeners();
  }

  Future<void> handleAuthChange() async {
    await init();
  }

  Future<void> setTheme(String id) async {
    await update(settings.copyWith(themeId: id));
  }

  Future<void> setQuietHours({
    required bool enabled,
    required String start,
    required String end,
  }) async {
    await update(
      settings.copyWith(
        quietHoursEnabled: enabled,
        quietStart: start,
        quietEnd: end,
      ),
    );
  }

  Future<void> setDailyCheckIn({
    required bool enabled,
    required String time,
  }) async {
    await update(
      settings.copyWith(
        dailyCheckInEnabled: enabled,
        dailyCheckInTime: time,
      ),
    );
  }

  Future<void> setNotificationSchedule({
    required List<String> days,
    required String time,
    required bool repeat,
  }) async {
    await update(
      settings.copyWith(
        notificationDays: days,
        notificationTime: time,
        notificationRepeat: repeat,
      ),
    );
  }

  Future<void> setNotificationCategory(
    String id,
    bool enabled,
  ) async {
    final next = Map<String, bool>.from(settings.notificationCategories);
    next[id] = enabled;
    await update(settings.copyWith(notificationCategories: next));
  }

  Future<void> setNotificationSpaceSetting(
    String id,
    NotificationSpaceSetting setting,
  ) async {
    final next = Map<String, NotificationSpaceSetting>.from(
      settings.notificationSpaceSettings,
    );
    next[id] = setting;
    await update(settings.copyWith(notificationSpaceSettings: next));
  }

  Future<void> setMaxNotificationsPerDay(int value) async {
    await update(settings.copyWith(maxNotificationsPerDay: value));
  }

  Future<void> setAllNotificationCategories(bool enabled) async {
    final next = <String, bool>{
      for (final category in notificationCategories) category.id: enabled,
    };
    await update(settings.copyWith(notificationCategories: next));
  }

  Future<void> setCalendarRemindersEnabled(bool enabled) async {
    await update(settings.copyWith(calendarRemindersEnabled: enabled));
  }

  Future<void> setPomodoroAlertsEnabled(bool enabled) async {
    await update(settings.copyWith(pomodoroAlertsEnabled: enabled));
  }

  Future<void> setKeepInstructionsEnabled(bool enabled) async {
    await update(settings.copyWith(keepInstructionsEnabled: enabled));
  }

  Future<void> update(SettingsModel next) async {
    final now = DateTime.now().toIso8601String();
    _settings = next.copyWith(updatedAt: now);
    notifyListeners();

    await _repo.saveLocal(_settings);
    await _repo.upsertRemote(_settings);
    await NotificationService.instance.rescheduleAll(_settings);
  }

  SettingsModel _pickNewest(SettingsModel? local, SettingsModel remote) {
    if (local == null) return remote;
    return local.updatedAtDateTime.isAfter(remote.updatedAtDateTime)
        ? local
        : remote;
  }
}
