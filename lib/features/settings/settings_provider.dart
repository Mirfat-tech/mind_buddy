import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_model.dart';
import 'settings_repository.dart';
import '../../paper/paper_styles.dart';
import '../../services/notification_service.dart';
import '../../services/notification_catalog.dart';
import '../../services/subscription_limits.dart';
import '../../guides/guide_manager.dart';
import '../habits/habit_home_widget_service.dart';

final initialSettingsProvider = Provider<SettingsModel?>((ref) => null);

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(
    'SettingsRepository must be overridden at bootstrap.',
  );
});

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((
  ref,
) {
  final repo = ref.watch(settingsRepositoryProvider);
  final initial = ref.watch(initialSettingsProvider);
  return SettingsController(repo, initialSettings: initial);
});

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo, {SettingsModel? initialSettings})
    : _settings = initialSettings ?? SettingsModel.defaults(),
      _loading = initialSettings == null {
    setCustomPaperStyles(_settings.customThemes);
  }

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

    try {
      final initialized = await _repo.initialize();
      _settings = initialized;
      setCustomPaperStyles(_settings.customThemes);
      await ensureThemeAccessForCurrentPlan();
    } catch (_) {
      _loadError = 'Unable to sync settings right now.';
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

  Future<void> addCustomTheme(
    PaperStyle theme, {
    bool selectAfterSave = true,
  }) async {
    final nextThemes = <PaperStyle>[...settings.customThemes, theme];
    await update(
      settings.copyWith(
        customThemes: nextThemes,
        themeId: selectAfterSave ? theme.id : settings.themeId,
      ),
    );
    await HabitHomeWidgetService.syncTodaySnapshot();
  }

  Future<bool> removeCustomTheme(String themeId) async {
    final existing = settings.customThemes.any((theme) => theme.id == themeId);
    if (!existing) return false;

    final nextThemes = settings.customThemes
        .where((theme) => theme.id != themeId)
        .toList(growable: false);
    final nextThemeId = settings.themeId == themeId
        ? kDefaultThemeId
        : settings.themeId;

    await update(
      settings.copyWith(customThemes: nextThemes, themeId: nextThemeId),
    );
    await HabitHomeWidgetService.syncTodaySnapshot();
    return true;
  }

  Future<void> restoreCustomTheme(
    PaperStyle theme, {
    int? index,
    bool reselect = false,
  }) async {
    final nextThemes = <PaperStyle>[...settings.customThemes];
    final targetIndex = index == null
        ? nextThemes.length
        : index.clamp(0, nextThemes.length);
    nextThemes.insert(targetIndex, theme);

    await update(
      settings.copyWith(
        customThemes: nextThemes,
        themeId: reselect ? theme.id : settings.themeId,
      ),
    );
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
    _settings = await _repo.saveLocalFirst(next);
    setCustomPaperStyles(_settings.customThemes);
    notifyListeners();

    await NotificationService.instance.rescheduleAll(_settings);
  }

  Future<void> ensureThemeAccessForCurrentPlan() async {
    final subscription = await SubscriptionLimits.fetchForCurrentUser();
    if (subscription.isPlus) return;

    final currentStyle = styleById(_settings.themeId);
    final safeThemeId = isThemeAccessibleForFree(currentStyle)
        ? currentStyle.id
        : kFreeFallbackThemeId;

    if (safeThemeId == _settings.themeId) {
      return;
    }

    _settings = await _repo.saveLocalFirst(
      _settings.copyWith(themeId: safeThemeId),
    );
    setCustomPaperStyles(_settings.customThemes);
    notifyListeners();
  }
}
