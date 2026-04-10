import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/features/mood/mood_catalog.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class TestPage extends ConsumerStatefulWidget {
  const TestPage({super.key});

  @override
  ConsumerState<TestPage> createState() => _TestPageState();
}

enum _TestFlowStep { mood, expression }

class _TestPageState extends ConsumerState<TestPage> {
  _TestFlowStep _step = _TestFlowStep.mood;
  String? _selectedMood;

  static const List<_ExpressionDestination> _destinations = [
    _ExpressionDestination('Brain Fog Bubble', Icons.blur_on_rounded, '/brain-fog'),
    _ExpressionDestination(
      'Gratitude Bubble',
      Icons.auto_awesome_rounded,
      '/gratitude-bubble',
    ),
    _ExpressionDestination('Habit Bubble', Icons.checklist_rounded, '/habits'),
    _ExpressionDestination('Journal Bubble', Icons.menu_book_rounded, '/journals'),
    _ExpressionDestination('Pomodoro Bubble', Icons.timer_rounded, '/pomodoro'),
    _ExpressionDestination('Quote Bubble', Icons.format_quote_rounded, '/quotes'),
  ];

  void _selectMood(String mood) {
    setState(() {
      _selectedMood = mood;
      _step = _TestFlowStep.expression;
    });
  }

  void _resetFlow() {
    setState(() {
      _step = _TestFlowStep.mood;
      _selectedMood = null;
    });
  }

  List<_ExpressionDestination> _orderedDestinations() {
    final mood = _selectedMood;
    if (mood == null) return _destinations;
    final emphasized = switch (moodToneOf(mood)) {
      MoodTone.negative => <String>{
          'Brain Fog Bubble',
          'Journal Bubble',
          'Pomodoro Bubble',
        },
      MoodTone.positive => <String>{
          'Gratitude Bubble',
          'Quote Bubble',
          'Journal Bubble',
        },
      MoodTone.neutral => <String>{
          'Habit Bubble',
          'Pomodoro Bubble',
          'Journal Bubble',
        },
    };
    final ordered = [..._destinations];
    ordered.sort((a, b) {
      final aPinned = emphasized.contains(a.label);
      final bPinned = emphasized.contains(b.label);
      if (aPinned == bPinned) return 0;
      return aPinned ? -1 : 1;
    });
    return ordered;
  }

  String _expressionPrompt() {
    final mood = _selectedMood;
    if (mood == null) return 'How would you like to express it?';
    return switch (moodToneOf(mood)) {
      MoodTone.negative => 'Would you like to express this through…',
      MoodTone.positive => 'How would you like to express it?',
      MoodTone.neutral => 'What feels right for this mood?',
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).settings;
    final style = styleById(settings.themeId);
    final cloudStyle = BubbleCloudStyle(
      centerFill: Color.lerp(style.boxFill, style.paper, 0.45)!,
      bubbleFill: Color.lerp(style.boxFill, style.paper, 0.18)!,
      textColor: style.text,
      mutedTextColor: style.mutedText,
      glowColor: style.accent,
      borderColor: style.border,
    );
    final emphasizedLabels = _selectedMood == null
        ? const <String>{}
        : switch (moodToneOf(_selectedMood!)) {
            MoodTone.negative => <String>{
                'Brain Fog Bubble',
                'Journal Bubble',
                'Pomodoro Bubble',
              },
            MoodTone.positive => <String>{
                'Gratitude Bubble',
                'Quote Bubble',
                'Journal Bubble',
              },
            MoodTone.neutral => <String>{
                'Habit Bubble',
                'Pomodoro Bubble',
                'Journal Bubble',
              },
          };

    return Scaffold(
      backgroundColor: style.paper,
      body: Stack(
        children: [
          Positioned.fill(child: _TestPageBackground(style: style)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _GlassCircleButton(
                        icon: Icons.arrow_back_rounded,
                        style: style,
                        onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                      ),
                      const Spacer(),
                      Text(
                        'TestPage',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: style.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _GlassCircleButton(
                        icon: Icons.refresh_rounded,
                        style: style,
                        onTap: _resetFlow,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Experimental mood-guided bubble flow',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: style.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _step == _TestFlowStep.mood
                          ? OnboardingBubbleCloud(
                              key: const ValueKey<String>('mood-step'),
                              centerText: 'Hey… how are you feeling today?',
                              instructionText: 'Tap a mood bubble',
                              style: cloudStyle,
                              choices: [
                                for (final mood in moodOptions)
                                  BubbleChoice(
                                    label: mood,
                                    selected: _selectedMood == mood,
                                    onTap: () => _selectMood(mood),
                                  ),
                              ],
                            )
                          : OnboardingBubbleCloud(
                              key: ValueKey<String>('expression-${_selectedMood ?? ''}'),
                              centerText: _expressionPrompt(),
                              instructionText: _selectedMood == null
                                  ? 'Choose a bubble'
                                  : 'Mood selected: ${displayMood(_selectedMood!)}',
                              style: cloudStyle,
                              choices: [
                                for (final destination in _orderedDestinations())
                                  BubbleChoice(
                                    label: destination.label,
                                    emphasized: emphasizedLabels.contains(destination.label),
                                    onTap: () => context.go(destination.route),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _step == _TestFlowStep.expression ? _resetFlow : null,
                    child: Text(
                      _step == _TestFlowStep.expression
                          ? 'Choose another mood'
                          : 'Take your time',
                      style: TextStyle(color: style.mutedText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressionDestination {
  const _ExpressionDestination(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.style,
    required this.onTap,
  });

  final IconData icon;
  final PaperStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Color.lerp(style.boxFill, Colors.white, 0.25)!.withValues(alpha: 0.82),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: style.border.withValues(alpha: 0.75)),
                boxShadow: [
                  BoxShadow(
                    color: style.accent.withValues(alpha: 0.18),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: style.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _TestPageBackground extends StatefulWidget {
  const _TestPageBackground({required this.style});

  final PaperStyle style;

  @override
  State<_TestPageBackground> createState() => _TestPageBackgroundState();
}

class _TestPageBackgroundState extends State<_TestPageBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final drift = Curves.easeInOut.transform(_controller.value);
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(style.paper, style.boxFill, 0.18)!,
                      style.paper,
                      Color.lerp(style.paper, style.accent, 0.06)!,
                    ],
                  ),
                ),
              ),
            ),
            _BlurOrb(
              left: -30 + (drift * 12),
              top: 90 - (drift * 18),
              size: 170,
              color: style.accent.withValues(alpha: 0.14),
            ),
            _BlurOrb(
              right: -40 + (drift * 14),
              top: 210 + (drift * 10),
              size: 210,
              color: style.border.withValues(alpha: 0.28),
            ),
            _BlurOrb(
              left: 80 - (drift * 8),
              bottom: -20 + (drift * 14),
              size: 220,
              color: style.accent.withValues(alpha: 0.10),
            ),
          ],
        );
      },
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
