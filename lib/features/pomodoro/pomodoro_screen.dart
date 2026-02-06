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
import 'dart:ui'; // Required for FontFeature

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
  ConsumerState<PomodoroStandalone> createState() =>
      _PomodoroStandaloneState();
}

class _PomodoroStandaloneState extends ConsumerState<PomodoroStandalone> {
  Timer? _timer;
  int focusMinutes = 25;
  int breakMinutes = 5;
  String mode = 'focus';
  int secondsLeft = 25 * 60;
  bool running = false;
  int focusedMinutesToday = 0;
  int _messageSeed = 0;

  @override
  void initState() {
    super.initState();
    secondsLeft = focusMinutes * 60;
    _messageSeed = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

    if (secondsLeft <= 0) {
      _stopTimer();
      setState(() => running = false);
      _handleTimerFinished();
    }
  }

  Future<void> _handleTimerFinished() async {
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
    setState(() => running = !running);
    if (running) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _reset() {
    _stopTimer();
    setState(() {
      running = false;
      secondsLeft = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
    });
  }

  void _setMode(String newMode) {
    _stopTimer();
    setState(() {
      mode = newMode;
      running = false;
      secondsLeft = (mode == 'focus' ? focusMinutes : breakMinutes) * 60;
    });
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
        if (isFocus)
          focusMinutes = selected;
        else
          breakMinutes = selected;
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
                TextButton.icon(
                  onPressed: running ? null : _pickMinutes,
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(
                    '${mode == 'focus' ? focusMinutes : breakMinutes} min',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: (mode == 'focus'
                        ? scheme.primary
                        : Colors.teal),
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
