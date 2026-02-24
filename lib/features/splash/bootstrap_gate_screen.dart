import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';

class BootstrapGateScreen extends ConsumerStatefulWidget {
  const BootstrapGateScreen({super.key});

  @override
  ConsumerState<BootstrapGateScreen> createState() =>
      _BootstrapGateScreenState();
}

class _BootstrapGateScreenState extends ConsumerState<BootstrapGateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.98,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future<void>.microtask(_runBootstrap);
  }

  Future<void> _runBootstrap() async {
    try {
      await ref.read(settingsControllerProvider).init();
      await StartupUserDataService.instance
          .fetchCombinedForCurrentUser()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Startup errors should not block entry.
    }
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go('/home');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(settingsControllerProvider).settings.themeId;
    final hasResolvedTheme = themeId != null;
    final style = hasResolvedTheme ? styleById(themeId) : null;
    final bg = style?.paper;
    final logoTint = style?.accent ?? Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: bg == null
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF090E1A), Color(0xFF111A2A)],
                ),
              )
            : BoxDecoration(color: bg),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortest = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final logoSize = (shortest * 0.55).clamp(180.0, 420.0);
              return Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: SizedBox(
                      width: logoSize,
                      height: logoSize,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          hasResolvedTheme
                              ? logoTint.withValues(alpha: 0.2)
                              : Colors.transparent,
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          'assets/images/MYBB_Trans_logo_2.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
