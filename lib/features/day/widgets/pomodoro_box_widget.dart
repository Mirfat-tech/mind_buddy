import 'dart:async';
import 'package:flutter/material.dart';

class PomodoroBoxWidget extends StatefulWidget {
  const PomodoroBoxWidget({
    super.key,
    required this.box,
    required this.onSaveContent,
  });

  final Map<String, dynamic> box;

  /// Save updated jsonb content back to Supabase via repo.updateBoxContent(...)
  final Future<void> Function(Map<String, dynamic> newContent) onSaveContent;

  @override
  State<PomodoroBoxWidget> createState() => _PomodoroBoxWidgetState();
}

class _PomodoroBoxWidgetState extends State<PomodoroBoxWidget> {
  Timer? _timer;

  late int focusMinutes;
  late int shortBreakMinutes;
  late int longBreakMinutes;

  late String mode; // 'focus' | 'short_break' | 'long_break'
  late int secondsLeft;
  late bool running;

  Map<String, dynamic> get _content {
    final raw = widget.box['content'];
    if (raw is Map) return raw.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    _hydrateFromContent();
    if (running) {
      _startTimer(); // resume if it was running
    }
  }

  @override
  void didUpdateWidget(covariant PomodoroBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the box changed externally (reload), re-hydrate state.
    if (oldWidget.box['id'] != widget.box['id'] ||
        oldWidget.box['content'] != widget.box['content']) {
      _stopTimer();
      _hydrateFromContent();
      if (running) _startTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _hydrateFromContent() {
    final c = _content;

    focusMinutes = (c['focusMinutes'] as int?) ?? 25;
    shortBreakMinutes = (c['shortBreakMinutes'] as int?) ?? 5;
    longBreakMinutes = (c['longBreakMinutes'] as int?) ?? 15;

    mode = (c['mode'] as String?) ?? 'focus';
    running = (c['running'] as bool?) ?? false;

    // If secondsLeft missing, derive from mode
    final defaultSeconds = _modeMinutes(mode) * 60;
    secondsLeft = (c['secondsLeft'] as int?) ?? defaultSeconds;

    // Guard against weird values
    if (secondsLeft < 0) secondsLeft = defaultSeconds;
  }

  int _modeMinutes(String m) {
    switch (m) {
      case 'short_break':
        return shortBreakMinutes;
      case 'long_break':
        return longBreakMinutes;
      case 'focus':
      default:
        return focusMinutes;
    }
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'short_break':
        return 'Short break';
      case 'long_break':
        return 'Long break';
      case 'focus':
      default:
        return 'Focus';
    }
  }

  Future<void> _persist() async {
    final newContent = <String, dynamic>{
      ..._content,
      'mode': mode,
      'running': running,
      'secondsLeft': secondsLeft,
      'focusMinutes': focusMinutes,
      'shortBreakMinutes': shortBreakMinutes,
      'longBreakMinutes': longBreakMinutes,
    };
    await widget.onSaveContent(newContent);
  }

  void _tick() async {
    if (!mounted) return;

    if (secondsLeft <= 0) {
      // auto-stop at 0 (keep mode as-is; you can change later to auto-switch)
      setState(() {
        running = false;
        secondsLeft = 0;
      });
      _stopTimer();
      await _persist();
      return;
    }

    setState(() {
      secondsLeft -= 1;
    });

    // Persist occasionally so refresh doesn't lose progress.
    // (Every 10 seconds is a decent compromise.)
    if (secondsLeft % 10 == 0) {
      await _persist();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _toggleRunning() async {
    setState(() => running = !running);

    if (running) {
      _startTimer();
    } else {
      _stopTimer();
    }

    await _persist();
  }

  Future<void> _reset() async {
    _stopTimer();
    setState(() {
      running = false;
      secondsLeft = _modeMinutes(mode) * 60;
    });
    await _persist();
  }

  Future<void> _setMode(String newMode) async {
    if (newMode == mode) return;

    _stopTimer();
    setState(() {
      mode = newMode;
      running = false;
      secondsLeft = _modeMinutes(mode) * 60;
    });
    await _persist();
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(secondsLeft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_modeLabel(mode)} • $time',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setMode('focus'),
                child: const Text('Focus'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setMode('short_break'),
                child: const Text('Short'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setMode('long_break'),
                child: const Text('Long'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

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
      ],
    );
  }
}
