// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/templates_section.dart';

import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Fixes 'Supabase' error
import 'package:mind_buddy/features/auth/device_session_service.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'widgets/pomodoro_box_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _checkedDevice = false;
  final GlobalKey _themeSelectorButtonKey = GlobalKey();
  final GlobalKey _insightsButtonKey = GlobalKey();
  final GlobalKey _settingsButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _enforceDeviceLimit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GuideManager.showGuideIfNeeded(
        context: context,
        pageId: 'home',
        steps: [
          GuideStep(
            key: _themeSelectorButtonKey,
            title: 'Feeling a different vibe today?',
            body: 'Tap the theme bubble to shift your colours.',
          ),
          GuideStep(
            key: _insightsButtonKey,
            title: 'Curious what your brain’s been up to?',
            body: 'Tap here to view insights, streaks and reflections.',
          ),
          GuideStep(
            key: _settingsButtonKey,
            title: 'Need to adjust your bubble?',
            body: 'Open settings to customise your flow.',
          ),
        ],
      );
    });
  }

  Future<void> _enforceDeviceLimit() async {
    if (_checkedDevice) return;
    _checkedDevice = true;

    final registration = await DeviceSessionService.registerDevice();
    if (!mounted || registration.allowed) {
      return;
    }
    if (!registration.shouldBlockForDeviceLimit) {
      return;
    }
    if (registration.entitlementCheckFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not verify your subscription right now. Signed in with temporary access.',
          ),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device limit reached'),
        content: Text(registration.blockedMessage()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.go('/settings');
            },
            child: const Text('Manage devices'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go('/settings');
  }

  Future<void> _openThemePicker(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(settingsControllerProvider);

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Choose theme',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              // Make sure paperStyles exists in paper_styles.dart
              ...paperStyles.map((s) {
                final isSelected = controller.settings.themeId == s.id;
                return ListTile(
                  title: Text(s.name),
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, s.id),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await controller.setTheme(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('MyBrainBubble'),
        actions: [
          MbGlowIconButton(
            key: _themeSelectorButtonKey,
            icon: Icons.palette_outlined,
            onPressed: () => _openThemePicker(context, ref),
          ),
          MbGlowIconButton(
            icon: Icons.help_outline,
            onPressed: () => GuideManager.showGuideIfNeeded(
              context: context,
              pageId: 'home',
              force: true,
              steps: [
                GuideStep(
                  key: _themeSelectorButtonKey,
                  title: 'Feeling a different vibe today?',
                  body: 'Tap the theme bubble to shift your colours.',
                ),
                GuideStep(
                  key: _insightsButtonKey,
                  title: 'Curious what your brain’s been up to?',
                  body: 'Tap here to view insights, streaks and reflections.',
                ),
                GuideStep(
                  key: _settingsButtonKey,
                  title: 'Need to adjust your bubble?',
                  body: 'Open settings to customise your flow.',
                ),
              ],
            ),
          ),
          MbGlowIconButton(
            key: _settingsButtonKey,
            icon: Icons.settings_outlined,
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_home',
        text: 'Choose a bubble to begin. Everything starts small.',
        iconText: '✨',
        child: _HomeBody(insightsButtonKey: _insightsButtonKey),
      ),
    );
  }
}

class _HomeBubble extends StatelessWidget {
  const _HomeBubble({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      // This decoration creates the glow effect
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15), // The glow color
            blurRadius: 20, // How soft the glow is
            spreadRadius: 2, // How far the glow extends
            offset: const Offset(0, 4), // Subtle downward shift
          ),
        ],
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline.withOpacity(0.25)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.onSurfaceVariant, size: 22),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _trialBannerControllerProvider =
    StateNotifierProvider<_TrialBannerController, bool>((ref) {
      return _TrialBannerController();
    });

class _TrialBannerController extends StateNotifier<bool> {
  _TrialBannerController() : super(true) {
    _load();
  }

  static const _prefsKey = 'trial_banner_dismissed';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = !(prefs.getBool(_prefsKey) ?? false);
  }

  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    state = false;
  }

  Future<void> show() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
    state = true;
  }
}

final _pendingTierProvider = FutureProvider<bool>((ref) async {
  final info = await SubscriptionLimits.fetchForCurrentUser();
  return info.isPending;
});

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.insightsButtonKey});

  final GlobalKey insightsButtonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(_pendingTierProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pendingAsync.when(
            data: (isPending) {
              final showBanner =
                  ref.watch(_trialBannerControllerProvider) && isPending;
              return showBanner
                  ? _TrialBanner(
                      onUpgrade: () {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user == null) {
                          context.go('/signin?from=/subscription');
                        } else {
                          context.go('/subscription');
                        }
                      },
                      onSkip: () => ref
                          .read(_trialBannerControllerProvider.notifier)
                          .dismiss(),
                    )
                  : const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 12),

          // CALENDAR
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go('/calendar'),
              child: const Text('Calendar'),
            ),
          ),
          const SizedBox(height: 10),

          // BRAIN FOG
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go('/brain-fog'),
              child: const Text('Brain fog bubble 😶‍🌫️'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go('/gratitude-bubble'),
              child: const Text('Gratitude bubble ✨'),
            ),
          ),

          IconButton(
            key: insightsButtonKey,
            icon: Icon(
              Icons.insights,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            onPressed: () => context.go('/insights'),
          ),
          // ✅ Put this where your Home body content goes
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _HomeBubble(
                title: 'Habit bubble',
                icon: Icons.checklist_rtl,
                onTap: () => context.go('/habits'),
                // e.g. context.go('/habits/manage');
              ),
              _HomeBubble(
                title: 'Journal bubble',
                icon: Icons.menu_book_outlined,
                onTap: () => context.go('/journals'),
              ),
              _HomeBubble(
                title: 'Pomodoro bubble',
                icon: Icons.timer_outlined,
                onTap: () => context.go('/pomodoro'),
              ),
              _HomeBubble(
                title: 'Quote bubble',
                icon: Icons.format_quote_outlined,
                onTap: () => context.go('/quotes'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TemplatesSection(),

          //ElevatedButton.icon(
          //onPressed: () async {
          //final created = await context.push<bool>('/templates/create');

          // If user saved a template, take them to Templates page
          //if (created == true && context.mounted) {
          //context.go(
          //  '/templates'); // or whatever your templates list route is
          //}
          //},
          //icon: const Icon(Icons.add),
          //label: const Text('Create logs template'),
          //),
          //const SizedBox(height: 12),
          const SizedBox(
            height: 24,
          ), // optional bottom padding so grid doesn't hit bottom
        ],
      ),
    );
  }

  String todayDayId() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.onUpgrade, required this.onSkip});

  final VoidCallback onUpgrade;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'FREE MODE uses 24-hour preview mode for templates. Preview data disappears after 24 hours.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onUpgrade,
                  child: const Text('View modes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
