import 'package:flutter/material.dart';

class LogTableControls extends StatelessWidget {
  const LogTableControls({
    super.key,
    required this.searchController,
    required this.onClearSearch,
    required this.sortLabel,
    required this.onChangeSort,
  });

  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final String sortLabel;
  final ValueChanged<String> onChangeSort;

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sort',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _SortOptionTile(
                label: 'Newest first',
                selected: sortLabel == 'Newest first',
                onTap: () {
                  onChangeSort('Newest first');
                  Navigator.pop(ctx);
                },
              ),
              _SortOptionTile(
                label: 'Oldest first',
                selected: sortLabel == 'Oldest first',
                onTap: () {
                  onChangeSort('Oldest first');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search logs...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outline.withOpacity(0.25),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outline.withOpacity(0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.primary.withOpacity(0.5),
                  ),
                ),
                fillColor: scheme.surface,
                filled: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _GlowIconBubble(
          icon: Icons.filter_list,
          onTap: () => _showSortSheet(context),
          glowColor: scheme.primary.withOpacity(0.35),
        ),
      ],
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: cs.primary)
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _GlowIconBubble extends StatelessWidget {
  const _GlowIconBubble({
    required this.icon,
    required this.onTap,
    required this.glowColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: cs.primary),
      ),
    );
  }
}
