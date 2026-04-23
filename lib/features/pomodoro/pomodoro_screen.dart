import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/pomodoro/study_buddy_controller.dart';
import 'package:mind_buddy/features/pomodoro/study_buddy_panel.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:mind_buddy/services/notification_service.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Focus Timer'),
        leading: MbGlowBackButton(
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/'),
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.notifications_outlined,
            onPressed: () => context.push('/settings/notifications'),
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_pomodoro',
        text: 'Start when you are ready. Rest is part of it.',
        iconText: '✨',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            return SafeArea(
              top: false,
              bottom: true,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  10,
                  24,
                  20 + mediaQuery.padding.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const PomodoroStandalone(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PomodoroStandalone extends ConsumerStatefulWidget {
  const PomodoroStandalone({super.key});

  @override
  ConsumerState<PomodoroStandalone> createState() => _PomodoroStandaloneState();
}

class _PomodoroStandaloneState extends ConsumerState<PomodoroStandalone>
    with WidgetsBindingObserver {
  static const String _modeFocus = 'focus';
  static const String _modeBreak = 'break';
  static const String _modeStopwatch = 'stopwatch';

  Timer? _timer;
  int focusMinutes = 25;
  int breakMinutes = 5;
  String mode = _modeFocus;
  int secondsLeft = 25 * 60;
  bool running = false;
  int _messageSeed = 0;
  DateTime? _endTime;
  DateTime? _lastTickAt;
  SharedPreferences? _prefs;
  bool _stopRequested = false;
  int _stopwatchElapsedSeconds = 0;
  List<int> _stopwatchLaps = <int>[];
  String _trackingDayKey = _dayKeyFor(DateTime.now());
  int _totalStudySeconds = 0;
  int _totalBreakSeconds = 0;
  int _sessionStudySeconds = 0;
  int _sessionBreakSeconds = 0;
  bool _screenActive = true;
  bool _studyBuddyOpen = false;
  bool _studyBuddyUnlocked = false;
  bool _showingStudyBuddyUpgradePrompt = false;
  int _studyBuddyShakeTrigger = 0;
  int _lastStopwatchReminderBucket = 0;
  late final StudyBuddyMessageController _studyBuddyController;

  bool get _isStopwatchFamily => mode == _modeStopwatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    secondsLeft = focusMinutes * 60;
    _messageSeed = DateTime.now().millisecondsSinceEpoch;
    _studyBuddyController = StudyBuddyMessageController();
    unawaited(_studyBuddyController.initialize());
    unawaited(_refreshStudyBuddyAccess());
    _restoreState();
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _studyBuddyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _screenActive = true;
      unawaited(_studyBuddyController.refreshQuotes());
      unawaited(_refreshStudyBuddyAccess());
      _syncFromSavedState();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _screenActive = false;
      _syncProgress(now: DateTime.now());
      _syncStudyBuddy();
      _persistState();
    }
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final savedRunning = prefs.getBool('pomodoro_running') ?? false;
    final savedMode = prefs.getString('pomodoro_mode') ?? mode;
    final savedEnd = prefs.getString('pomodoro_end_time');
    final savedFocus = prefs.getInt('pomodoro_focus_minutes');
    final savedBreak = prefs.getInt('pomodoro_break_minutes');
    final savedLastTick = prefs.getString('pomodoro_last_tick_at');
    final savedStopwatchElapsed =
        prefs.getInt('pomodoro_stopwatch_elapsed') ?? 0;
    final savedStudySeconds = prefs.getInt('pomodoro_total_study_seconds') ?? 0;
    final savedBreakSeconds = prefs.getInt('pomodoro_total_break_seconds') ?? 0;
    final savedSessionStudySeconds =
        prefs.getInt('pomodoro_session_study_seconds') ?? 0;
    final savedSessionBreakSeconds =
        prefs.getInt('pomodoro_session_break_seconds') ?? 0;
    final savedDayKey =
        prefs.getString('pomodoro_tracking_day') ?? _dayKeyFor(DateTime.now());
    final savedLaps =
        prefs.getStringList('pomodoro_stopwatch_laps') ?? const [];
    final savedReminderBucket =
        prefs.getInt('pomodoro_stopwatch_reminder_bucket') ?? 0;

    if (savedFocus != null) focusMinutes = savedFocus;
    if (savedBreak != null) breakMinutes = savedBreak;
    mode = savedMode;
    _trackingDayKey = savedDayKey;
    _totalStudySeconds = savedStudySeconds;
    _totalBreakSeconds = savedBreakSeconds;
    _sessionStudySeconds = savedSessionStudySeconds;
    _sessionBreakSeconds = savedSessionBreakSeconds;
    _stopwatchElapsedSeconds = savedStopwatchElapsed;
    _stopwatchLaps = savedLaps
        .map(int.tryParse)
        .whereType<int>()
        .toList(growable: true);
    _lastStopwatchReminderBucket = savedReminderBucket;
    _lastTickAt = savedLastTick == null
        ? null
        : DateTime.tryParse(savedLastTick);
    if (savedEnd != null) {
      _endTime = DateTime.tryParse(savedEnd);
    }

    _ensureDailyTracking(DateTime.now());
    running = savedRunning;

    if (running) {
      _syncProgress(now: DateTime.now());
      if (running) {
        _startTimer();
      }
    } else {
      secondsLeft = _initialSecondsForMode(mode);
    }

    _syncStudyBuddy();
    if (mounted) setState(() {});
  }

  Future<void> _persistState() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool('pomodoro_running', running);
    await prefs.setString('pomodoro_mode', mode);
    await prefs.setInt('pomodoro_focus_minutes', focusMinutes);
    await prefs.setInt('pomodoro_break_minutes', breakMinutes);
    await prefs.setInt('pomodoro_stopwatch_elapsed', _stopwatchElapsedSeconds);
    await prefs.setInt('pomodoro_total_study_seconds', _totalStudySeconds);
    await prefs.setInt('pomodoro_total_break_seconds', _totalBreakSeconds);
    await prefs.setInt('pomodoro_session_study_seconds', _sessionStudySeconds);
    await prefs.setInt('pomodoro_session_break_seconds', _sessionBreakSeconds);
    await prefs.setString('pomodoro_tracking_day', _trackingDayKey);
    await prefs.setStringList(
      'pomodoro_stopwatch_laps',
      _stopwatchLaps.map((lap) => lap.toString()).toList(growable: false),
    );
    await prefs.setInt(
      'pomodoro_stopwatch_reminder_bucket',
      _lastStopwatchReminderBucket,
    );
    if (_endTime != null) {
      await prefs.setString('pomodoro_end_time', _endTime!.toIso8601String());
    } else {
      await prefs.remove('pomodoro_end_time');
    }
    if (_lastTickAt != null) {
      await prefs.setString(
        'pomodoro_last_tick_at',
        _lastTickAt!.toIso8601String(),
      );
    } else {
      await prefs.remove('pomodoro_last_tick_at');
    }
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _ensureDailyTracking(DateTime now) {
    final today = _dayKeyFor(now);
    if (_trackingDayKey == today) return;
    _trackingDayKey = today;
    _totalStudySeconds = 0;
    _totalBreakSeconds = 0;
    _lastStopwatchReminderBucket = 0;
  }

  int _trackedDeltaForToday(DateTime from, DateTime to) {
    final todayStart = DateTime(to.year, to.month, to.day);
    final effectiveFrom = from.isBefore(todayStart) ? todayStart : from;
    if (!to.isAfter(effectiveFrom)) return 0;
    return to.difference(effectiveFrom).inSeconds;
  }

  void _syncProgress({required DateTime now}) {
    if (!running) {
      _consumeStopRequestIfNeeded();
      _consumeStopwatchPauseRequestIfNeeded();
      return;
    }

    _ensureDailyTracking(now);
    final previousTick = _lastTickAt ?? now;

    if (mode == _modeStopwatch) {
      final rawDelta = now.difference(previousTick).inSeconds;
      if (rawDelta > 0) {
        _stopwatchElapsedSeconds += rawDelta;
        _totalStudySeconds += _trackedDeltaForToday(previousTick, now);
        _sessionStudySeconds += rawDelta;
        _lastTickAt = now;
      }
      _consumeStopwatchPauseRequestIfNeeded();
      return;
    }

    _endTime ??= now.add(Duration(seconds: secondsLeft));

    final effectiveNow = now.isBefore(_endTime!) ? now : _endTime!;
    final trackedDelta = _trackedDeltaForToday(previousTick, effectiveNow);
    if (trackedDelta > 0) {
      if (mode == _modeBreak) {
        _totalBreakSeconds += trackedDelta;
        _sessionBreakSeconds += trackedDelta;
      } else {
        _totalStudySeconds += trackedDelta;
        _sessionStudySeconds += trackedDelta;
      }
    }
    _lastTickAt = effectiveNow;

    final diff = _endTime!.difference(now).inSeconds;
    if (diff <= 0) {
      secondsLeft = 0;
      running = false;
      _stopTimer();
      NotificationService.instance.cancelPomodoroStatusNotification();
      _handleTimerFinished();
    } else {
      secondsLeft = diff;
    }

    _consumeStopRequestIfNeeded();
  }

  void _syncFromSavedState() {
    _syncProgress(now: DateTime.now());
    _syncStudyBuddy();
    if (mounted) setState(() {});
  }

  void _consumeStopRequestIfNeeded() {
    if (_prefs == null) return;
    final requested = _prefs!.getBool('pomodoro_stop_requested') ?? false;
    if (!requested || mode == _modeStopwatch) return;
    _prefs!.setBool('pomodoro_stop_requested', false);
    _stopRequested = true;
    _handleExternalStop();
  }

  void _consumeStopwatchPauseRequestIfNeeded() {
    if (_prefs == null) return;
    final requested = _prefs!.getBool('stopwatch_pause_requested') ?? false;
    if (!requested || mode != _modeStopwatch) return;
    _prefs!.setBool('stopwatch_pause_requested', false);
    if (!running) return;
    _stopTimer();
    NotificationService.instance.cancelStopwatchStatusNotification();
    NotificationService.instance.cancelStopwatchReminderNotification();
    setState(() {
      running = false;
      _lastTickAt = null;
    });
    _syncStudyBuddy();
    _persistState();
  }

  void _handleExternalStop() {
    _stopTimer();
    NotificationService.instance.cancelPomodoroStatusNotification();
    NotificationService.instance.cancelPomodoroFinishedNotification();
    setState(() {
      running = false;
      secondsLeft = _initialSecondsForMode(mode);
      _endTime = null;
      _lastTickAt = null;
    });
    _studyBuddyController.dismissSessionCompletionPrompt();
    _syncStudyBuddy();
    _persistState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (!mounted || !running) return;

    setState(() {
      _syncProgress(now: DateTime.now());
    });
    _syncStudyBuddy();
    _persistState();
  }

  Future<void> _handleTimerFinished() async {
    if (_stopRequested) return;
    final wasFocus = mode == _modeFocus;
    final settings = ref.read(settingsControllerProvider).settings;
    final message = _pickPomodoroMessage(wasFocus);
    if (settings.pomodoroAlertsEnabled) {
      await _showCompletionMessage(wasFocus, message);
      await NotificationService.instance.showPomodoroFinishedNotification(
        wasFocus: wasFocus,
        message: message,
        hapticsEnabled: settings.hapticsEnabled,
        soundsEnabled: settings.soundsEnabled,
      );
    }
    _setMode(mode == _modeFocus ? _modeBreak : _modeFocus);
    if (wasFocus) {
      _studyBuddyController.showSessionCompletionPrompt();
    }
  }

  Future<void> _showCompletionMessage(bool wasFocus, String message) async {
    if (!mounted) return;

    final title = wasFocus ? 'Focus timer finished' : 'Break time finished';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _pickPomodoroMessage(bool wasFocus) {
    final focusMessages = [
      'Time’s up — you showed up, and that counts.',
      'That was a focused moment. Well done for being here.',
      'You can pause now. You did enough for this block.',
      'Focus time ended. Want to rest or continue?',
      'Your timer’s done — follow your energy.',
    ];

    final breakMessages = [
      'Your break is over — only return if you’re ready.',
      'Break time ended. No rush.',
      'Whenever you’re ready, you can begin again.',
      'Gently back, or gently done — both are okay.',
    ];

    _messageSeed += 1;
    final list = wasFocus ? focusMessages : breakMessages;
    final index = _messageSeed % list.length;
    return list[index];
  }

  void _toggleRunning() {
    final settings = ref.read(settingsControllerProvider).settings;

    if (mode == _modeStopwatch) {
      if (!running) {
        _studyBuddyController.dismissSessionCompletionPrompt();
        setState(() {
          if (_stopwatchElapsedSeconds == 0) {
            _resetStudyBuddySessionState();
          }
          running = true;
          _lastTickAt = DateTime.now();
        });
        if (settings.stopwatchAlertsEnabled) {
          NotificationService.instance.showStopwatchStatusNotification();
        }
        _syncStudyBuddy();
        _persistState();
        _startTimer();
      } else {
        _syncProgress(now: DateTime.now());
        setState(() {
          running = false;
          _lastTickAt = null;
        });
        NotificationService.instance.cancelStopwatchStatusNotification();
        NotificationService.instance.cancelStopwatchReminderNotification();
        _syncStudyBuddy();
        _persistState();
        _stopTimer();
      }
      return;
    }

    if (!running) {
      _studyBuddyController.dismissSessionCompletionPrompt();
      setState(() {
        if (mode == _modeFocus &&
            secondsLeft == focusMinutes * 60 &&
            _endTime == null) {
          _resetStudyBuddySessionState();
        }
        running = true;
      });
      _stopRequested = false;
      _lastTickAt = DateTime.now();
      _endTime = DateTime.now().add(Duration(seconds: secondsLeft));
      final message = _pickPomodoroMessage(mode == _modeFocus);
      NotificationService.instance.schedulePomodoroEndNotification(
        wasFocus: mode == _modeFocus,
        endsAt: _endTime!,
        message: message,
        hapticsEnabled: settings.hapticsEnabled,
        soundsEnabled: settings.soundsEnabled,
      );
      _syncStudyBuddy();
      _persistState();
      _startTimer();
    } else {
      _syncProgress(now: DateTime.now());
      setState(() {
        running = false;
      });
      NotificationService.instance.cancelPomodoroStatusNotification();
      NotificationService.instance.cancelPomodoroFinishedNotification();
      _lastTickAt = null;
      _syncStudyBuddy();
      _persistState();
      _stopTimer();
    }
  }

  void _handleBubbleHold() {
    _toggleRunning();
  }

  void _reset() {
    _syncProgress(now: DateTime.now());
    _stopTimer();
    setState(() {
      running = false;
      if (mode == _modeStopwatch) {
        _stopwatchElapsedSeconds = 0;
        _stopwatchLaps = <int>[];
        _lastStopwatchReminderBucket = 0;
      } else {
        secondsLeft = _initialSecondsForMode(mode);
      }
      _sessionStudySeconds = 0;
      _sessionBreakSeconds = 0;
      _endTime = null;
      _lastTickAt = null;
    });
    NotificationService.instance.cancelPomodoroStatusNotification();
    NotificationService.instance.cancelPomodoroFinishedNotification();
    NotificationService.instance.cancelStopwatchStatusNotification();
    NotificationService.instance.cancelStopwatchReminderNotification();
    _studyBuddyController.dismissSessionCompletionPrompt();
    _syncStudyBuddy();
    _persistState();
  }

  Future<void> _confirmReset() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset your flow?'),
        content: const Text(
          'This will softly clear your current focus, including your Study Buddy progress 🫧\nJust making sure you’re okay to start fresh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Start fresh'),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      _reset();
    }
  }

  void _recordLap() {
    if (mode != _modeStopwatch) return;
    _syncProgress(now: DateTime.now());
    if (_stopwatchElapsedSeconds <= 0) return;
    setState(() {
      _stopwatchLaps = <int>[_stopwatchElapsedSeconds, ..._stopwatchLaps];
    });
    _persistState();
  }

  void _deleteLapAt(int index) {
    if (index < 0 || index >= _stopwatchLaps.length) return;
    setState(() {
      _stopwatchLaps = List<int>.from(_stopwatchLaps)..removeAt(index);
    });
    _persistState();
  }

  void _setMode(String newMode) {
    _syncProgress(now: DateTime.now());
    _stopTimer();
    NotificationService.instance.cancelPomodoroStatusNotification();
    NotificationService.instance.cancelPomodoroFinishedNotification();
    NotificationService.instance.cancelStopwatchStatusNotification();
    NotificationService.instance.cancelStopwatchReminderNotification();

    setState(() {
      running = false;
      mode = newMode;
      _stopRequested = false;
      _endTime = null;
      _lastTickAt = null;
      if (newMode != _modeStopwatch) {
        secondsLeft = _initialSecondsForMode(newMode);
      }
    });
    _studyBuddyController.dismissSessionCompletionPrompt();
    _syncStudyBuddy();
    _persistState();
  }

  void _syncStudyBuddy() {
    final routeIsCurrent = mounted
        ? (ModalRoute.of(context)?.isCurrent ?? true)
        : false;
    _studyBuddyController.updateSnapshot(
      StudyBuddyLiveSnapshot(
        mode: mode,
        running: running,
        sessionStudySeconds: _sessionStudySeconds,
        sessionBreakSeconds: _sessionBreakSeconds,
      ),
      screenActive: _screenActive && mounted && routeIsCurrent,
    );
  }

  void _setTopFamily(bool useStopwatch) {
    if (useStopwatch) {
      if (mode != _modeStopwatch) {
        _setMode(_modeStopwatch);
      }
      return;
    }
    if (mode == _modeStopwatch) {
      _setMode(_modeFocus);
    }
  }

  void _openStudyLog() {
    _studyBuddyController.dismissSessionCompletionPrompt();
    context.push('/templates/by-key/study/logs');
  }

  void _openTasksLog() {
    _studyBuddyController.dismissSessionCompletionPrompt();
    context.push('/templates/by-key/tasks/logs');
  }

  void _openHabitBubble() {
    _studyBuddyController.dismissSessionCompletionPrompt();
    context.push('/habits');
  }

  Future<void> _refreshStudyBuddyAccess() async {
    final subscription = await SubscriptionLimits.fetchForCurrentUser();
    if (!mounted) return;
    setState(() {
      _studyBuddyUnlocked = subscription.isPlus;
      if (!_studyBuddyUnlocked) {
        _studyBuddyOpen = false;
      }
    });
  }

  Future<void> _showStudyBuddyUpgradePrompt() async {
    if (_showingStudyBuddyUpgradePrompt || !mounted) return;
    _showingStudyBuddyUpgradePrompt = true;
    await Future<void>.delayed(const Duration(milliseconds: 430));
    if (!mounted) {
      _showingStudyBuddyUpgradePrompt = false;
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Study Buddy is resting for now.\nWant to wake it up? Plus mode can help with that ✨',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/subscription');
              },
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Upgrade to Plus'),
            ),
          ],
        ),
      ),
    );
    _showingStudyBuddyUpgradePrompt = false;
  }

  Future<void> _handleLockedStudyBuddyAccess() async {
    setState(() {
      _studyBuddyShakeTrigger += 1;
      _studyBuddyOpen = false;
    });
    await _showStudyBuddyUpgradePrompt();
  }

  Future<void> _handleStudyBuddyTap() async {
    final subscription = await SubscriptionLimits.fetchForCurrentUser();
    if (!mounted) return;
    if (subscription.isPlus) {
      setState(() {
        _studyBuddyUnlocked = true;
        _studyBuddyOpen = !_studyBuddyOpen;
      });
      return;
    }
    setState(() {
      _studyBuddyUnlocked = false;
    });
    await _handleLockedStudyBuddyAccess();
  }

  Future<void> _handleStudyBuddyLongPress() async {
    final subscription = await SubscriptionLimits.fetchForCurrentUser();
    if (!mounted) return;
    if (subscription.isPlus) {
      setState(() {
        _studyBuddyUnlocked = true;
      });
      await _showStudyBuddyDetails();
      return;
    }
    setState(() {
      _studyBuddyUnlocked = false;
    });
    await _handleLockedStudyBuddyAccess();
  }

  void _resetStudyBuddySessionState() {
    _sessionStudySeconds = 0;
    _sessionBreakSeconds = 0;
  }

  Future<void> _showStudyBuddyDetails() async {
    _syncProgress(now: DateTime.now());
    _syncStudyBuddy();
    if (mounted) {
      setState(() {});
    }
    final detail = _studyBuddyController.buildDetailView();
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.read(settingsControllerProvider).settings;
    final activeStyle = styleById(settings.themeId);
    final useDarkPopupSurface = _usesDarkStudyBuddyPopup(activeStyle);
    final popupDecoration = BoxDecoration(
      gradient: useDarkPopupSurface
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.58),
                  scheme.surface,
                ),
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.1),
                  scheme.surface,
                ),
              ],
            ),
      color: useDarkPopupSurface
          ? Color.alphaBlend(
              activeStyle.accent.withValues(alpha: 0.08),
              activeStyle.boxFill,
            )
          : null,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: useDarkPopupSurface
            ? Color.alphaBlend(
                activeStyle.accent.withValues(alpha: 0.14),
                activeStyle.border,
              )
            : scheme.primary.withValues(alpha: 0.16),
      ),
      boxShadow: [
        BoxShadow(
          color: (useDarkPopupSurface ? activeStyle.accent : scheme.primary)
              .withValues(alpha: useDarkPopupSurface ? 0.08 : 0.12),
          blurRadius: 20,
          offset: const Offset(0, 12),
        ),
      ],
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: popupDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  detail.focusSummary,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.breakSummary,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.32,
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    detail.supportiveMessage,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (detail.prompt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    detail.prompt!,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
                if (detail.showLogActions) ...[
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StudyBuddyActionChip(
                        label: 'Study Log',
                        color: scheme.primary,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _openStudyLog();
                        },
                      ),
                      const SizedBox(height: 10),
                      _StudyBuddyActionChip(
                        label: 'Task Template',
                        color: scheme.primary,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _openTasksLog();
                        },
                      ),
                      const SizedBox(height: 10),
                      _StudyBuddyActionChip(
                        label: 'Habit Bubble',
                        color: scheme.primary,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _openHabitBubble();
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  int _initialSecondsForMode(String currentMode) {
    if (currentMode == _modeBreak) return breakMinutes * 60;
    if (currentMode == _modeStopwatch) return 0;
    return focusMinutes * 60;
  }

  Future<void> _pickMinutes() async {
    if (mode == _modeStopwatch) return;
    final isFocus = mode == _modeFocus;
    int temp = isFocus ? focusMinutes : breakMinutes;

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFocus ? 'Focus Length' : 'Break Length',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (context, setInner) {
                  return Column(
                    children: [
                      Text(
                        '$temp min',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Slider(
                        value: temp.toDouble(),
                        min: isFocus ? 5 : 1,
                        max: isFocus ? 120 : 60,
                        onChanged: (value) =>
                            setInner(() => temp = value.round()),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, temp),
                  child: const Text('Set Duration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        if (isFocus) {
          focusMinutes = selected;
        } else {
          breakMinutes = selected;
        }
        if (!running) secondsLeft = selected * 60;
      });
      _persistState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _modeColor(scheme);
    final studyBuddyEnabled = _studyBuddyUnlocked;
    final screenHeight = MediaQuery.of(context).size.height;
    final bubbleSize = screenHeight < 780 ? 220.0 : 240.0;
    final timeLabel = _isStopwatchFamily
        ? _formatStopwatch(_stopwatchElapsedSeconds)
        : _formatCountdown(secondsLeft);
    final helperLabel = running ? '(hold to pause)' : '(hold to start)';
    final bubbleTextColor = scheme.onSurface;

    return Column(
      children: [
        _TopModeToggle(
          useStopwatch: _isStopwatchFamily,
          onChanged: _setTopFamily,
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onLongPress: _handleBubbleHold,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: bubbleSize,
              height: bubbleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: running ? 0.3 : 0.1),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: running ? 0.15 : 0.05),
                    blurRadius: 70,
                    spreadRadius: -10,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 10),
                    blurRadius: 20,
                  ),
                ],
                border: Border.all(
                  color: accent.withValues(alpha: running ? 0.4 : 0.15),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mode.toUpperCase(),
                    style: TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: _isStopwatchFamily ? 46 : 58,
                      fontWeight: FontWeight.w300,
                      color: bubbleTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!_isStopwatchFamily)
                    TextButton(
                      onPressed: running ? null : _pickMinutes,
                      style: TextButton.styleFrom(foregroundColor: accent),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mode == _modeFocus
                                ? 'Adjust Focus Time'
                                : 'Adjust Break Time',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            helperLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: bubbleTextColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        helperLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: bubbleTextColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (!_isStopwatchFamily)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: running ? null : () => _setMode(_modeFocus),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mode == _modeFocus ? scheme.primary : null,
                    side: mode == _modeFocus
                        ? BorderSide(color: scheme.primary)
                        : null,
                  ),
                  child: const Text('Focus'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: running ? null : () => _setMode(_modeBreak),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mode == _modeBreak ? Colors.teal : null,
                    side: mode == _modeBreak
                        ? const BorderSide(color: Colors.teal)
                        : null,
                  ),
                  child: const Text('Break'),
                ),
              ),
              const SizedBox(width: 12),
              _CompactIconButton(
                onPressed: _confirmReset,
                icon: Icons.restart_alt_rounded,
                semanticLabel: 'Reset timer',
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stopwatchElapsedSeconds > 0 ? _recordLap : null,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Lap'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CompactIconButton(
                onPressed: _confirmReset,
                icon: Icons.restart_alt_rounded,
                semanticLabel: 'Reset stopwatch',
              ),
            ],
          ),
        if (_isStopwatchFamily && _stopwatchLaps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _stopwatchLaps
                  .take(4)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lap ${_stopwatchLaps.length - entry.key} · ${_formatStopwatch(entry.value)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _deleteLapAt(entry.key),
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: scheme.onSurface.withValues(alpha: 0.58),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              NotificationService.instance.cancelPomodoroStatusNotification();
              NotificationService.instance.cancelPomodoroFinishedNotification();
              NotificationService.instance.cancelStopwatchStatusNotification();
              NotificationService.instance
                  .cancelStopwatchReminderNotification();
            },
            icon: const Icon(Icons.notifications_off_outlined, size: 16),
            label: const Text('Stop alert'),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/bubble-pool'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.75),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'View Bubble Pool',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StudyBuddyPanel(
          controller: _studyBuddyController,
          isOpen: studyBuddyEnabled && _studyBuddyOpen,
          onTapBubble: () {
            unawaited(_handleStudyBuddyTap());
          },
          onLongPress: () {
            unawaited(_handleStudyBuddyLongPress());
          },
          shakeTrigger: _studyBuddyShakeTrigger,
        ),
      ],
    );
  }

  Color _modeColor(ColorScheme scheme) {
    switch (mode) {
      case _modeBreak:
        return Colors.teal;
      case _modeStopwatch:
        return scheme.primary;
      case _modeFocus:
      default:
        return scheme.primary;
    }
  }
}

bool _usesDarkStudyBuddyPopup(PaperStyle style) {
  switch (style.id) {
    case 'midnight_pink':
    case 'midnight_blue':
    case 'Dark_Orange':
    case 'Midnight_green':
      return true;
    default:
      return false;
  }
}

class _TopModeToggle extends StatelessWidget {
  const _TopModeToggle({required this.useStopwatch, required this.onChanged});

  final bool useStopwatch;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TopModeChip(
              label: 'Timer',
              selected: !useStopwatch,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TopModeChip(
              label: 'Stopwatch',
              selected: useStopwatch,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyBuddyActionChip extends StatelessWidget {
  const _StudyBuddyActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopModeChip extends StatelessWidget {
  const _TopModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.onPressed,
    required this.icon,
    required this.semanticLabel,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 50,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.75)),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

String _formatCountdown(int totalSeconds) {
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatStopwatch(int totalSeconds) {
  final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _dayKeyFor(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
