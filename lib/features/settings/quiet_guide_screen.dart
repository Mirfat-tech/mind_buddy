import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';

class QuietGuideScreen extends StatelessWidget {
  const QuietGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Quiet Guide'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Small cues, soft on purpose',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'These hints fade away once you interact.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          _GuideItem(
            title: 'Templates',
            text: 'Swipe a template to hide it.',
          ),
          _GuideItem(
            title: 'Templates',
            text: 'Use the + button to add your own.',
          ),
          _GuideItem(
            title: 'Log tables',
            text: 'Tap a date to edit. Hold a row to delete.',
          ),
          _GuideItem(
            title: 'Log tables',
            text:
                'For a clearer view, turn off portrait lock and rotate your phone.',
          ),
          _GuideItem(
            title: 'Journal',
            text: 'Search to filter. Tap an entry to open.',
          ),
          _GuideItem(
            title: 'Chat',
            text: 'Open the menu to find past chats.',
          ),
          _GuideItem(
            title: 'Brain fog',
            text: 'Long press to pop. Tap to edit. Drag to move.',
          ),
          _GuideItem(
            title: 'Pomodoro',
            text: 'Start when you are ready. Rest is part of it.',
          ),
          _GuideItem(
            title: 'Insights',
            text: 'Scroll gently. Insights unfold at your pace.',
          ),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.55)),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
