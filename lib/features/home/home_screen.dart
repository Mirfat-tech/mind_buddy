// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/templates_section.dart';

import 'package:mind_buddy/app/app_theme_controller.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Fixes 'Supabase' error
import 'package:intl/intl.dart'; // Fixes 'DateFormat' error
//import 'widgets/pomodoro_box_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openThemePicker(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appThemeControllerProvider);

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
                final isSelected = controller.themeId == s.id;
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
  Widget build(BuildContext context, WidgetRef ref) {
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

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                onTap: () => context.go('/journal/new'),

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
