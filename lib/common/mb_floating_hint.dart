import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MbFloatingHintOverlay extends ConsumerWidget {
  const MbFloatingHintOverlay({
    super.key,
    required this.child,
    required this.hintKey,
    required this.text,
    this.align = Alignment.center,
    this.iconText,
    this.visual,
    this.autoHide = const Duration(seconds: 7),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    this.bottomOffset = 0,
  });

  final Widget child;
  final String hintKey;
  final String text;
  final Alignment align;
  final String? iconText;
  final Widget? visual;
  final Duration autoHide;
  final EdgeInsets padding;
  final double bottomOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keepHints =
        ref.watch(settingsControllerProvider).settings.keepInstructionsEnabled;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Align(
            alignment: align,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomOffset),
              child: MbFloatingHint(
                hintKey: hintKey,
                text: text,
                iconText: iconText,
                visual: visual,
                autoHide: autoHide,
                padding: padding,
                forceShow: keepHints,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MbFloatingHint extends StatefulWidget {
  const MbFloatingHint({
    super.key,
    required this.hintKey,
    required this.text,
    this.iconText,
    this.visual,
    this.autoHide = const Duration(seconds: 7),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    this.forceShow = false,
  });

  final String hintKey;
  final String text;
  final String? iconText;
  final Widget? visual;
  final Duration autoHide;
  final EdgeInsets padding;
  final bool forceShow;

  @override
  State<MbFloatingHint> createState() => _MbFloatingHintState();
}

class _MbFloatingHintState extends State<MbFloatingHint>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _manuallyDismissed = false;
  Timer? _timer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.98,
      upperBound: 1.02,
    )..repeat(reverse: true);

    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(widget.hintKey) ?? false;
    if (!mounted) return;
    if (_manuallyDismissed) return;
    if (shown && !widget.forceShow) return;

    setState(() => _visible = true);
    if (!widget.forceShow) {
      _timer = Timer(widget.autoHide, _dismiss);
    }
  }

  Future<void> _dismiss() async {
    if (!mounted || !_visible) return;
    setState(() {
      _visible = false;
      _manuallyDismissed = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.hintKey, true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forceShow && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (!_manuallyDismissed) {
            setState(() => _visible = true);
          }
        }
      });
    }
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: false,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: ScaleTransition(
              scale: _pulse,
              child: Dismissible(
                key: ValueKey(widget.hintKey),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => _dismiss(),
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: widget.padding,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: scheme.primary.withOpacity(0.55),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scheme.surface.withOpacity(0.7),
                                scheme.surface.withOpacity(0.7),
                                scheme.surface.withOpacity(0.25),
                              ],
                              stops: const [0.0, 0.78, 1.0],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _DotRow(color: scheme.primary.withOpacity(0.3)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.iconText != null) ...[
                                    Text(widget.iconText!,
                                        style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                  ],
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 260),
                                    child: Text(
                                      '${widget.text} (swipe to remove)',
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.3,
                                        color:
                                            scheme.onSurface.withOpacity(0.65),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.visual != null) ...[
                                const SizedBox(height: 8),
                                widget.visual!,
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _DotRow extends StatefulWidget {
  const _DotRow({required this.color});

  final Color color;

  @override
  State<_DotRow> createState() => _DotRowState();
}

class _DotRowState extends State<_DotRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, child) {
        final dx = (0.5 - _slide.value) * 8;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          6,
          (index) => Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.5 + (index * 0.05)),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
