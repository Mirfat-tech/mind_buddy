import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TemplatesSection extends StatelessWidget {
  const TemplatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    const items = _items;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 360 ? 2 : 3;
    final childAspectRatio = width < 360 ? 1.85 : 1.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Templates',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/templates'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: childAspectRatio,
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
        const SizedBox(height: 10),
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
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          maxLines: 1,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
