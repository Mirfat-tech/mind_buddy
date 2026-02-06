import 'package:flutter/material.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';

class TemplateScreen extends StatelessWidget {
  final String templateId;

  const TemplateScreen({super.key, required this.templateId});

  @override
  Widget build(BuildContext context) {
    final config = _TemplateConfig.fromId(templateId);

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: Text(config.title),
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/templates'),
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            onPressed: () =>
                context.push('/settings/notifications?from=templates'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _GlowPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(config.icon),
                  const SizedBox(width: 10),
                  Text(
                    config.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                config.calendarLinked ? 'Daily template' : 'Log template',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    config.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Next: build ${config.title} form + save'),
                    ),
                  );
                },
                child: Text(config.primaryCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowPanel extends StatelessWidget {
  const _GlowPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TemplateConfig {
  final String id;
  final String title;
  final IconData icon;
  final bool calendarLinked;
  final String description;
  final String primaryCta;

  const _TemplateConfig({
    required this.id,
    required this.title,
    required this.icon,
    required this.calendarLinked,
    required this.description,
    required this.primaryCta,
  });

  static _TemplateConfig fromId(String id) {
    switch (id) {
      case 'mood':
        return const _TemplateConfig(
          id: 'mood',
          title: 'Mood',
          icon: Icons.mood_outlined,
          calendarLinked: true,
          description: 'Mood tracker screen goes here (rating + notes).',
          primaryCta: 'Add mood entry',
        );
      case 'cycle':
        return const _TemplateConfig(
          id: 'cycle',
          title: 'Menstrual cycle',
          icon: Icons.favorite_border,
          calendarLinked: true,
          description: 'Cycle tracker screen goes here (flow/symptoms).',
          primaryCta: 'Log cycle',
        );
      case 'water':
        return const _TemplateConfig(
          id: 'water',
          title: 'Water',
          icon: Icons.water_drop_outlined,
          calendarLinked: true,
          description: 'Water tracker screen goes here (cups/ml).',
          primaryCta: 'Add water',
        );
      case 'sleep':
        return const _TemplateConfig(
          id: 'sleep',
          title: 'Sleep',
          icon: Icons.bedtime_outlined,
          calendarLinked: true,
          description: 'Sleep tracker screen goes here (hours/quality).',
          primaryCta: 'Log sleep',
        );
      //case 'habits':
      //return const _TemplateConfig(
      //id: 'habits',
      //title: 'Habits',
      //icon: Icons.check_circle_outline,
      //calendarLinked: true,
      //description: 'Habit tracker screen goes here (tick list).',
      //primaryCta: 'Update habits',
      //);
      case 'bills':
        return const _TemplateConfig(
          id: 'bills',
          title: 'Bills',
          icon: Icons.receipt_long_outlined,
          calendarLinked: true,
          description: 'Bills screen goes here (due/paid).',
          primaryCta: 'Add bill',
        );
      case 'income':
        return const _TemplateConfig(
          id: 'income',
          title: 'Income',
          icon: Icons.payments_outlined,
          calendarLinked: true,
          description: 'Income screen goes here.',
          primaryCta: 'Add income',
        );
      case 'expenses':
        return const _TemplateConfig(
          id: 'expenses',
          title: 'Expenses',
          icon: Icons.shopping_cart_outlined,
          calendarLinked: true,
          description: 'Expenses screen goes here.',
          primaryCta: 'Add expense',
        );
      case 'tasks':
        return const _TemplateConfig(
          id: 'tasks',
          title: 'Tasks',
          icon: Icons.task_alt_outlined,
          calendarLinked: true,
          description: 'Tasks screen goes here (list + status).',
          primaryCta: 'Add task',
        );
      case 'wishlist':
        return const _TemplateConfig(
          id: 'wishlist',
          title: 'Wishlist',
          icon: Icons.card_giftcard_outlined,
          calendarLinked: false,
          description: 'Wishlist screen goes here (items + links).',
          primaryCta: 'Add to wishlist',
        );
      case 'movies':
        return const _TemplateConfig(
          id: 'movies',
          title: 'Movie log',
          icon: Icons.movie_outlined,
          calendarLinked: false,
          description: 'Movie log screen goes here.',
          primaryCta: 'Add movie',
        );
      case 'tv_log':
        return const _TemplateConfig(
          id: 'tv_log',
          title: 'TV log',
          icon: Icons.tv_outlined,
          calendarLinked: false,
          description: 'TV log screen goes here.',
          primaryCta: 'Add show',
        );
      case 'music':
        return const _TemplateConfig(
          id: 'music',
          title: 'Music history',
          icon: Icons.library_music_outlined,
          calendarLinked: false,
          description: 'Music history screen goes here.',
          primaryCta: 'Add music',
        );
      case 'places':
        return const _TemplateConfig(
          id: 'places',
          title: 'Places',
          icon: Icons.place_outlined,
          calendarLinked: false,
          description: 'Places screen goes here.',
          primaryCta: 'Add place',
        );
      case 'restaurants':
        return const _TemplateConfig(
          id: 'restaurants',
          title: 'Restaurants',
          icon: Icons.restaurant_outlined,
          calendarLinked: false,
          description: 'Restaurants screen goes here.',
          primaryCta: 'Add restaurant',
        );
      case 'books':
        return const _TemplateConfig(
          id: 'books',
          title: 'Books',
          icon: Icons.menu_book_outlined,
          calendarLinked: false,
          description: 'Books screen goes here.',
          primaryCta: 'Add book',
        );
      default:
        return _TemplateConfig(
          id: id,
          title: 'Template',
          icon: Icons.dashboard_customize_outlined,
          calendarLinked: false,
          description: 'Unknown template id: "$id"',
          primaryCta: 'OK',
        );
    }
  }
}
