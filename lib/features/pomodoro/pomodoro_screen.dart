import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/services/notification_service.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
// Required for FontFeature
import 'package:shared_preferences/shared_preferences.dart';

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
              : context.go('/home'),
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
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const PomodoroStandalone(),
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
  Timer? _timer;
  int focusMinutes = 25;
  int breakMinutes = 5;
  String mode = 'focus';
  int secondsLeft = 25 * 60;
  bool running = false;
  int focusedMinutesToday = 0;
  int _messageSeed = 0;
  DateTime? _endTime;
  final int _lastNotifTick = 0;
  SharedPreferences? _prefs;
  bool _stopRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    secondsLeft = focusMinutes * 60;
    _messageSeed = DateTime.now().millisecondsSinceEpoch;
    _restoreState();
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFromEndTime();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistState();
    }
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRunning = prefs.getBool('pomodoro_running') ?? false;
    final savedMode = prefs.getString('pomodoro_mode') ?? mode;
    final savedEnd = prefs.getString('pomodoro_end_time');
    final savedFocus = prefs.getInt('pomodoro_focus_minutes');
    final savedBreak = prefs.getInt('pomodoro_break_minutes');
    if (savedFocus != null) focusMinutes = savedFocus;
    if (savedBreak != null) breakMinutes = savedBreak;
    mode = savedMode;
    if (savedEnd != null) {
      _endTime = DateTime.tryParse(savedEnd);
    }
    if (savedRunning && _endTime != null) {
      running = true;
      _syncFromEndTime();
      _startTimer();
    } else {
      secondsLeft = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pomodoro_running', running);
    await prefs.setString('pomodoro_mode', mode);
    await prefs.setInt('pomodoro_focus_minutes', focusMinutes);
    await prefs.setInt('pomodoro_break_minutes', breakMinutes);
    if (_endTime != null) {
      await prefs.setString('pomodoro_end_time', _endTime!.toIso8601String());
    } else {
      await prefs.remove('pomodoro_end_time');
    }
  }

  void _syncFromEndTime() {
    if (!running || _endTime == null) return;
    final now = DateTime.now();
    final diff = _endTime!.difference(now).inSeconds;
    if (diff <= 0) {
      secondsLeft = 0;
      running = false;
      _stopTimer();
      _handleTimerFinished();
    } else {
      secondsLeft = diff;
    }
    if (mounted) setState(() {});
    _consumeStopRequestIfNeeded();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _consumeStopRequestIfNeeded() {
    if (_prefs == null) return;
    final requested = _prefs!.getBool('pomodoro_stop_requested') ?? false;
    if (!requested) return;
    _prefs!.setBool('pomodoro_stop_requested', false);
    _stopRequested = true;
    _handleExternalStop();
  }

  void _handleExternalStop() {
    _stopTimer();
    NotificationService.instance.cancelPomodoroStatusNotification();
    NotificationService.instance.cancelPomodoroFinishedNotification();
    setState(() {
      running = false;
      secondsLeft = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
      _endTime = null;
    });
    _persistState();
  }

  // --- TIMER LOGIC ---
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (!mounted) return;
    if (secondsLeft <= 0) return;

    setState(() => secondsLeft -= 1);
    if (running && _endTime == null) {
      _endTime = DateTime.now().add(Duration(seconds: secondsLeft));
    }
    if (running && secondsLeft % 60 == 0) {
      _updatePomodoroStatusNotification();
    }

    if (secondsLeft <= 0) {
      if (_stopRequested) return;
      _stopTimer();
      setState(() => running = false);
      NotificationService.instance.cancelPomodoroStatusNotification();
      _handleTimerFinished();
    }
    _consumeStopRequestIfNeeded();
  }

  Future<void> _handleTimerFinished() async {
    if (_stopRequested) return;
    final wasFocus = mode == 'focus';
    if (mode == 'focus') {
      setState(() => focusedMinutesToday += focusMinutes);
    }
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
    // Simple switch logic to keep flow clean
    _setMode(mode == 'focus' ? 'break' : 'focus');
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
    setState(() => running = !running);
    if (running) {
      _endTime = DateTime.now().add(Duration(seconds: secondsLeft));
      _updatePomodoroStatusNotification();
      final message = _pickPomodoroMessage(mode == 'focus');
      NotificationService.instance.schedulePomodoroEndNotification(
        wasFocus: mode == 'focus',
        endsAt: _endTime!,
        message: message,
        hapticsEnabled: settings.hapticsEnabled,
        soundsEnabled: settings.soundsEnabled,
      );
      _persistState();
      _startTimer();
    } else {
      NotificationService.instance.cancelPomodoroStatusNotification();
      NotificationService.instance.cancelPomodoroFinishedNotification();
      _persistState();
      _stopTimer();
    }
  }

  void _reset() {
    _stopTimer();
    setState(() {
      running = false;
      secondsLeft = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
      _endTime = null;
    });
    NotificationService.instance.cancelPomodoroStatusNotification();
    NotificationService.instance.cancelPomodoroFinishedNotification();
    _persistState();
  }

  void _setMode(String newMode) {
    _stopTimer();
    setState(() {
      mode = newMode;
      running = false;
      secondsLeft = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
      _endTime = null;
    });
    NotificationService.instance.cancelPomodoroStatusNotification();
    NotificationService.instance.cancelPomodoroFinishedNotification();
    _persistState();
  }

  void _updatePomodoroStatusNotification() {
    final totalSeconds = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
    if (_endTime == null) return;
    NotificationService.instance.showPomodoroStatusNotification(
      wasFocus: mode == 'focus',
      secondsLeft: secondsLeft,
      totalSeconds: totalSeconds,
      endsAt: _endTime!,
    );
  }

  // --- THE SLIDERS (Your original logic) ---
  Future<void> _pickMinutes() async {
    bool isFocus = mode == 'focus';
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
                        onChanged: (v) => setInner(() => temp = v.round()),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        Text(
          'You’ve focused for $focusedMinutesToday min today',
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 30),

        // THE GLOWING CIRCLE
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface,
              boxShadow: [
                // Outer Core Glow
                BoxShadow(
                  color: (mode == 'focus' ? scheme.primary : Colors.teal)
                      .withValues(alpha: running ? 0.3 : 0.1),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                // Wider Atmospheric Glow
                BoxShadow(
                  color: (mode == 'focus' ? scheme.primary : Colors.teal)
                      .withValues(alpha: running ? 0.15 : 0.05),
                  blurRadius: 70,
                  spreadRadius: -10,
                ),
                // Soft Shadow for depth
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, 10),
                  blurRadius: 20,
                ),
              ],
              border: Border.all(
                color: (mode == 'focus' ? scheme.primary : Colors.teal)
                    .withValues(alpha: running ? 0.4 : 0.15),
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
                    color: (mode == 'focus' ? scheme.primary : Colors.teal)
                        .withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w300,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: running ? null : _pickMinutes,
                  style: TextButton.styleFrom(
                    foregroundColor: (mode == 'focus'
                        ? scheme.primary
                        : Colors.teal),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mode == 'focus'
                            ? 'Adjust Focus Time'
                            : 'Adjust Break Time',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),

        // YOUR BUTTON LAYOUT (Modernized)
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: running ? null : () => _setMode('focus'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: mode == 'focus' ? scheme.primary : null,
                  side: mode == 'focus'
                      ? BorderSide(color: scheme.primary)
                      : null,
                ),
                child: const Text('Focus'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: running ? null : () => _setMode('break'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: mode == 'break' ? Colors.teal : null,
                  side: mode == 'break'
                      ? const BorderSide(color: Colors.teal)
                      : null,
                ),
                child: const Text('Break'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _toggleRunning,
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
                label: Text(running ? 'Pause' : 'Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _reset, child: const Text('Reset')),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              NotificationService.instance.cancelPomodoroStatusNotification();
              NotificationService.instance.cancelPomodoroFinishedNotification();
            },
            icon: const Icon(Icons.notifications_off_outlined, size: 16),
            label: const Text('Stop alert'),
          ),
        ),
        const SizedBox(height: 24),

        // BOTTOM PREVIEW CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Next: ${mode == 'focus' ? 'Break' : 'Focus'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: running
                    ? null
                    : () => _setMode(mode == 'focus' ? 'break' : 'focus'),
                child: const Text('Switch'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
