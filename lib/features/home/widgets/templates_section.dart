import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TemplatesSection extends StatelessWidget {
  const TemplatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Templates', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/templates'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, i) {
            final it = items[i];
            return _TemplateCard(
              title: it.title,
              icon: it.icon,
              badge: it.calendarLinked ? 'Daily' : 'Log',
              onTap: () {
                if (it.id == 'habits') return; // or show a SnackBar
                context.push('/templates/by-key/${it.id}/logs');
              },
            );
          },
        ),
      ],
    );
  }
}

class _TemplateItem {
  final String id;
  final String title;
  final IconData icon;
  final bool calendarLinked;
  const _TemplateItem(this.id, this.title, this.icon, this.calendarLinked);
}

// ✅ Home grid list (keep it short-ish; it’s the HOME preview)
const List<_TemplateItem> _items = [
  _TemplateItem('mood', 'Mood', Icons.emoji_emotions_outlined, true),
  _TemplateItem('water', 'Water', Icons.water_drop_outlined, true),
  _TemplateItem('sleep', 'Sleep', Icons.bedtime_outlined, true),
  // _TemplateItem('cycle', 'Menstrual cycle', Icons.favorite_border, true),
  // _TemplateItem('habits', 'Habits', Icons.check_circle_outline, true),
  //_TemplateItem('bills', 'Bills', Icons.receipt_long_outlined, true),
  //_TemplateItem('income', 'Income', Icons.payments_outlined, true),
  //_TemplateItem('expenses', 'Expenses', Icons.shopping_cart_outlined, true),
  //_TemplateItem('tasks', 'Tasks', Icons.task_alt_outlined, true),

  // A couple of “Logs”
  //_TemplateItem('wishlist', 'Wishlist', Icons.card_giftcard_outlined, false),
  //_TemplateItem('movies', 'Movie log', Icons.movie_outlined, false),
  // _TemplateItem('tv', 'TV log', Icons.tv_outlined, false),
];

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.icon,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
