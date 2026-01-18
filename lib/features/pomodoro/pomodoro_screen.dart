import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: PomodoroStandalone(),
      ),
    );
  }
}

class PomodoroStandalone extends StatefulWidget {
  const PomodoroStandalone({super.key});

  @override
  State<PomodoroStandalone> createState() => _PomodoroStandaloneState();
}

class _PomodoroStandaloneState extends State<PomodoroStandalone> {
  Timer? _timer;

  int focusMinutes = 25;
  int breakMinutes = 5;

  String mode = 'focus'; // focus | break
  int secondsLeft = 25 * 60;
  bool running = false;

  // “streak” / total focused today (in-app session, resets at date change)
  String _todayKey = _dateKey(DateTime.now());
  int focusedMinutesToday = 0;

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    secondsLeft = focusMinutes * 60;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _ensureToday() {
    final nowKey = _dateKey(DateTime.now());
    if (nowKey != _todayKey) {
      _todayKey = nowKey;
      focusedMinutesToday = 0;
    }
  }

  int _modeMinutes(String m) {
    switch (m) {
      case 'break':
        return breakMinutes;
      case 'focus':
      default:
        return focusMinutes;
    }
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'break':
        return 'Break';
      case 'focus':
      default:
        return 'Focus';
    }
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() async {
    if (!mounted) return;

    _ensureToday();

    if (secondsLeft <= 0) return;

    setState(() => secondsLeft -= 1);

    if (secondsLeft <= 0) {
      _stopTimer();
      setState(() {
        running = false;
        secondsLeft = 0;
      });

      await _handleTimerFinished();
    }
  }

  Future<void> _handleTimerFinished() async {
    if (!mounted) return;

    if (mode == 'focus') {
      setState(() {
        focusedMinutesToday += focusMinutes;
      });

      final startBreak = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Focus time is done'),
          content: const Text('Start break?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start break'),
            ),
          ],
        ),
      );

      if (startBreak == true && mounted) {
        _setMode('break', autoStart: true);
      }
      return;
    }

    final startFocus = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Break is done'),
        content: const Text('Start focus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start focus'),
          ),
        ],
      ),
    );

    if (startFocus == true && mounted) {
      _setMode('focus', autoStart: true);
    }
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
      secondsLeft = _modeMinutes(mode) * 60;
    });
  }

  void _setMode(String newMode, {bool autoStart = false}) {
    _stopTimer();
    setState(() {
      mode = newMode;
      running = autoStart;
      secondsLeft = _modeMinutes(mode) * 60;
    });

    if (autoStart) _startTimer();
  }

  Future<void> _pickFocusMinutes() async {
    int temp = focusMinutes;

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Focus length',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setInner) {
                    return Column(
                      children: [
                        Text(
                          '$temp min',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: temp.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 115,
                          label: '$temp',
                          onChanged: (v) => setInner(() => temp = v.round()),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, temp),
                  child: const Text('Set focus length'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      focusMinutes = selected;
      if (mode == 'focus' && !running) {
        secondsLeft = focusMinutes * 60;
      }
    });
  }

  Future<void> _pickBreakMinutes() async {
    int temp = breakMinutes;

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Break length',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setInner) {
                    return Column(
                      children: [
                        Text(
                          '$temp min',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: temp.toDouble(),
                          min: 1,
                          max: 60,
                          divisions: 59,
                          label: '$temp',
                          onChanged: (v) => setInner(() => temp = v.round()),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, temp),
                  child: const Text('Set break length'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      breakMinutes = selected;
      if (mode == 'break' && !running) {
        secondsLeft = breakMinutes * 60;
      }
    });
  }

  String _nextLabel() {
    if (mode == 'focus') return 'Next: Break';
    return 'Next: Focus';
  }

  int _nextSeconds() {
    if (mode == 'focus') return breakMinutes * 60;
    return focusMinutes * 60;
  }

  @override
  Widget build(BuildContext context) {
    _ensureToday();

    final time = _formatTime(secondsLeft);
    final nextTime = _formatTime(_nextSeconds());

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You’ve focused for $focusedMinutesToday min today',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface,
              border: Border.all(color: scheme.outline.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 2,
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _modeLabel(mode),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (mode == 'focus')
                  TextButton.icon(
                    onPressed: running ? null : _pickFocusMinutes,
                    icon: const Icon(Icons.tune),
                    label: Text('Focus: $focusMinutes min'),
                  )
                else
                  TextButton.icon(
                    onPressed: running ? null : _pickBreakMinutes,
                    icon: const Icon(Icons.tune),
                    label: Text('Break: $breakMinutes min'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: running ? null : () => _setMode('focus'),
                child: const Text('Focus'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: running ? null : () => _setMode('break'),
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
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _reset, child: const Text('Reset')),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_nextLabel()} • $nextTime',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: running
                    ? null
                    : () {
                        if (mode == 'focus') {
                          _setMode('break');
                        } else {
                          _setMode('focus');
                        }
                      },
                child: const Text('Switch'),
              )
            ],
          ),
        ),
      ],
    );
  }
}
