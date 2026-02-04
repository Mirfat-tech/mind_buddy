// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/templates_section.dart';

import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Fixes 'Supabase' error
import 'package:intl/intl.dart'; // Fixes 'DateFormat' error
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

  @override
  void initState() {
    super.initState();
    _enforceDeviceLimit();
  }

  Future<void> _enforceDeviceLimit() async {
    if (_checkedDevice) return;
    _checkedDevice = true;

    final ok = await DeviceSessionService.recordSession();
    if (!ok && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Device limit reached'),
          content: const Text(
            'Light Support allows only 1 device. Upgrade to use more devices.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go('/signin');
    }
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
      applyBackground: true, // ✅ Home background changes with theme
      appBar: AppBar(
        title: const Text('Mind Buddy'),
        actions: [
          // ✅ THEME PICKER
          IconButton(
            tooltip: 'Theme',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => _openThemePicker(context, ref),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: const _HomeBody(),
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.onSurface),
                const Spacer(),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
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
  const _HomeBody();

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
                      onUpgrade: () => context.go('/subscription'),
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

          IconButton(
            icon: Icon(
              Icons.insights,
              color: Theme.of(
                context,
              ).colorScheme.primary, // Matches the buttons
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
                title: 'Vent bubble',
                icon: Icons.chat_bubble_outline,

                onTap: () async {
                  final supabase = Supabase.instance.client;
                  final user = supabase.auth.currentUser;

                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You are not logged in.')),
                    );
                    return;
                  }

                  try {
                    final info =
                        await SubscriptionLimits.fetchForCurrentUser();
                    if (info.isPending) {
                      if (!context.mounted) return;
                      await SubscriptionLimits.showTrialUpgradeDialog(
                        context,
                        onUpgrade: () => context.go('/subscription'),
                      );
                      return;
                    }
                    final dayId = DateFormat(
                      'yyyy-MM-dd',
                    ).format(DateTime.now());

                    // 1️⃣ Try to get today's existing chat
                    final existing = await supabase
                        .from('chats')
                        .select('id, day_id')
                        .eq('user_id', user.id)
                        .eq('day_id', dayId)
                        .eq('is_archived', false)
                        .order('created_at', ascending: false)
                        .limit(1)
                        .maybeSingle();

                    // 2️⃣ If none exists, create one
                    final chat =
                        existing ??
                        await supabase
                            .from('chats')
                            .insert({
                              'user_id': user.id,
                              'day_id': dayId,
                              'is_archived': false,
                              'title': null,
                            })
                            .select('id, day_id')
                            .single();

                    if (!context.mounted) return;

                    // 3️⃣ Navigate
                    context.push('/chat/${chat['day_id']}/${chat['id']}');
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open Vent bubble: $e')),
                    );
                  }
                },
              ),
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

                // ✅ navigate to your existing Journal screen (whatever route you already use)
                // e.g. context.go('/journal?dayId=...');
              ),
              _HomeBubble(
                title: 'Pomodoro',
                icon: Icons.timer_outlined,
                onTap: () => context.go('/pomodoro'),
              ),
              // _HomeBubble(
              // title: 'Checklist',
              //icon: Icons.check_box_outlined,
              //onTap: () {
              // ✅ you said you want checklist in Templates instead,
              // so either remove this bubble OR send them to Templates.
              // context.go('/templates');
              // },
              //),
              // _HomeBubble(
              // title: 'Create table',
              //icon: Icons.table_chart_outlined,
              //onTap: () {
              // ✅ go straight to templates create
              // context.go('/templates/create');
              // },
              //),
            ],
          ),
          const SizedBox(height: 12),
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
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Trial mode: explore freely. Nothing is saved until you choose a plan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onSkip,
            child: const Text('Skip for now'),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: onUpgrade, child: const Text('Choose plan')),
        ],
      ),
    );
  }
}
