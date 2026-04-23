import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mind_buddy/features/pomodoro/study_buddy_controller.dart';

class StudyBuddyPanel extends StatefulWidget {
  const StudyBuddyPanel({
    super.key,
    required this.controller,
    required this.isOpen,
    required this.onTapBubble,
    required this.onLongPress,
    required this.shakeTrigger,
  });

  final StudyBuddyMessageController controller;
  final bool isOpen;
  final VoidCallback onTapBubble;
  final VoidCallback onLongPress;
  final int shakeTrigger;

  @override
  State<StudyBuddyPanel> createState() => _StudyBuddyPanelState();
}

class _StudyBuddyPanelState extends State<StudyBuddyPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(covariant StudyBuddyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTrigger != oldWidget.shakeTrigger) {
      _shakeController
        ..stop()
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller,
        _shakeController,
      ]),
      builder: (context, _) {
        final view = widget.controller.currentView;
        final highlighted = view.highlighted;
        final accent = scheme.primary;
        final shakeOffset =
            math.sin(_shakeController.value * math.pi * 5) *
            10 *
            (1 - _shakeController.value);
        final borderColor = highlighted
            ? accent.withValues(alpha: 0.28)
            : scheme.outline.withValues(alpha: 0.12);
        final glowColor = highlighted
            ? accent.withValues(alpha: 0.16)
            : accent.withValues(alpha: 0.08);
        final baseSurface = Color.alphaBlend(
          accent.withValues(alpha: highlighted ? 0.14 : 0.08),
          scheme.surface,
        );

        return Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: GestureDetector(
                  onTap: widget.onTapBubble,
                  onLongPress: widget.onLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: _BuddyOrb(color: accent, highlighted: highlighted),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: widget.isOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.alphaBlend(
                                  Colors.white.withValues(alpha: 0.52),
                                  baseSurface,
                                ),
                                baseSurface,
                                Color.alphaBlend(
                                  accent.withValues(
                                    alpha: highlighted ? 0.18 : 0.08,
                                  ),
                                  scheme.surface,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor,
                                blurRadius: highlighted ? 22 : 14,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      view.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: accent,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      view.body,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.32,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    if (view.detail != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        view.detail!,
                                        style: TextStyle(
                                          fontSize: 12.9,
                                          height: 1.3,
                                          color: scheme.onSurface.withValues(
                                            alpha: 0.78,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (view.quoteCredit != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        view.quoteCredit!,
                                        style: TextStyle(
                                          fontSize: 12.2,
                                          fontWeight: FontWeight.w600,
                                          color: accent.withValues(alpha: 0.86),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      '(Hold bubble to see more)',
                                      style: TextStyle(
                                        fontSize: 12.2,
                                        fontWeight: FontWeight.w600,
                                        color: accent.withValues(alpha: 0.84),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BuddyOrb extends StatelessWidget {
  const _BuddyOrb({required this.color, required this.highlighted});

  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      scale: highlighted ? 1.04 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.96),
              color.withValues(alpha: highlighted ? 0.3 : 0.2),
              const Color(
                0xFFE7D8FF,
              ).withValues(alpha: highlighted ? 0.46 : 0.28),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: highlighted ? 0.24 : 0.14),
              blurRadius: highlighted ? 22 : 16,
              spreadRadius: highlighted ? 1.5 : 0.6,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 7,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
