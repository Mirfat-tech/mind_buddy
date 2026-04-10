import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'settings_model.dart';
import 'settings_repository.dart';
import '../../paper/paper_styles.dart';
import '../../services/notification_service.dart';
import '../../services/notification_catalog.dart';
import '../../guides/guide_manager.dart';
import '../habits/habit_home_widget_service.dart';

final initialSettingsProvider = Provider<SettingsModel?>((ref) => null);

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((
  ref,
) {
  final supabase = Supabase.instance.client;
  final repo = SettingsRepository(supabase);
  final initial = ref.watch(initialSettingsProvider);
  return SettingsController(repo, initialSettings: initial);
});

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo, {SettingsModel? initialSettings})
    : _settings = initialSettings ?? SettingsModel.defaults(),
      _loading = initialSettings == null;

  final SettingsRepository _repo;

  SettingsModel _settings;
  bool _loading;
  String? _loadError;

  SettingsModel get settings => _settings;
  bool get loading => _loading;
  String? get loadError => _loadError;

  Future<void> init() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    SettingsModel? local;
    SettingsModel? remote;
    try {
      local = await _repo.loadLocal();
      remote = await _repo.fetchRemote();
    } catch (_) {
      _loadError = 'Unable to sync settings right now.';
    }

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

    // Ensure splash/bootstrap always has a concrete, valid theme.
    final themeId = (_settings.themeId ?? '').trim();
    if (!isValidPaperStyleId(themeId)) {
      _settings = _settings.copyWith(themeId: kDefaultThemeId);
      await _repo.saveLocal(_settings);
      await _repo.upsertRemote(_settings);
    }

    try {
      await NotificationService.instance.rescheduleAll(_settings);
    } catch (_) {}

    try {
      await GuideManager.setKeepInstructionsVisible(
        _settings.keepInstructionsEnabled,
      );
    } catch (_) {}

    _loading = false;
    notifyListeners();
  }

  Future<void> handleAuthChange() async {
    await init();
  }

  Future<void> retryInit() async => init();

  Future<void> setTheme(String id) async {
    await update(settings.copyWith(themeId: id));
    await HabitHomeWidgetService.syncTodaySnapshot();
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
      settings.copyWith(dailyCheckInEnabled: enabled, dailyCheckInTime: time),
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

  Future<void> setNotificationCategory(String id, bool enabled) async {
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

  Future<void> setStopwatchAlertsEnabled(bool enabled) async {
    await update(settings.copyWith(stopwatchAlertsEnabled: enabled));
  }

  Future<void> setStopwatchReminderMinutes(int minutes) async {
    await update(settings.copyWith(stopwatchReminderMinutes: minutes));
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    await update(settings.copyWith(hapticsEnabled: enabled));
  }

  Future<void> setSoundsEnabled(bool enabled) async {
    await update(settings.copyWith(soundsEnabled: enabled));
  }

  Future<void> setKeepInstructionsEnabled(bool enabled) async {
    await GuideManager.setKeepInstructionsVisible(enabled);
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
