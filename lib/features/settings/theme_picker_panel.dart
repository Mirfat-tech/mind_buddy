import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class ThemePickerPanel extends ConsumerWidget {
  const ThemePickerPanel({
    super.key,
    required this.selectedId,
    required this.onThemeSelected,
    this.padding = const EdgeInsets.all(16),
    this.showTitle = true,
  });

  final String? selectedId;
  final ValueChanged<String> onThemeSelected;
  final EdgeInsets padding;
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider);
    final settings = ref.watch(settingsControllerProvider).settings;

    return FutureBuilder<SubscriptionInfo>(
      future: SubscriptionLimits.fetchForCurrentUser(),
      builder: (context, snapshot) {
        final subscription =
            snapshot.data ?? SubscriptionLimits.fromRawTier('free');
        final isPlusUnlocked = subscription.isPlus;

        final activeStyle = styleById(selectedId);
        if (!isPlusUnlocked && !isThemeAccessibleForFree(activeStyle)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.ensureThemeAccessForCurrentPlan();
          });
        }

        bool isLocked(PaperStyle style) =>
            !isPlusUnlocked && !isThemeAccessibleForFree(style);

        Future<void> handleThemeTap(PaperStyle style) async {
          if (isLocked(style)) {
            if (!context.mounted) return;
            context.push('/settings/theme-preview/${style.id}');
            return;
          }
          await controller.setTheme(style.id);
          onThemeSelected(style.id);
        }

        Future<void> handleDeleteCustomTheme(PaperStyle style) async {
          final deletedIndex = settings.customThemes.indexWhere(
            (theme) => theme.id == style.id,
          );
          if (deletedIndex < 0) return;

          final wasSelected = selectedId == style.id;
          final didDelete = await controller.removeCustomTheme(style.id);
          if (!didDelete || !context.mounted) return;

          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          final controllerResult = messenger?.showSnackBar(
            SnackBar(
              content: Text('${style.name} deleted.'),
              action: SnackBarAction(label: 'Undo', onPressed: () {}),
            ),
          );

          final reason = await controllerResult?.closed;
          if (reason == SnackBarClosedReason.action) {
            await controller.restoreCustomTheme(
              style,
              index: deletedIndex,
              reselect: wasSelected,
            );
            if (wasSelected) {
              onThemeSelected(style.id);
            }
          }
        }

        return ListView(
          padding: padding,
          children: [
            if (showTitle) ...[
              Text(
                'Choose theme',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
            ],
            _CreateCustomThemeTile(
              isLocked: !isPlusUnlocked,
              onTap: () async {
                if (!isPlusUnlocked) {
                  await SubscriptionLimits.showTrialUpgradeDialog(
                    context,
                    onUpgrade: () => context.go('/subscription'),
                  );
                  return;
                }
                if (!context.mounted) return;
                context.push('/settings/custom-theme');
              },
            ),
            if (settings.customThemes.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Your custom themes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ...settings.customThemes.map((style) {
                final selected = selectedId == style.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ThemeListTile(
                    label: style.name,
                    isSelected: selected,
                    isLocked: isLocked(style),
                    subtitle: 'Custom',
                    onTap: () => handleThemeTap(style),
                    onDelete: isPlusUnlocked
                        ? () => handleDeleteCustomTheme(style)
                        : null,
                  ),
                );
              }),
            ],
            const SizedBox(height: 18),
            Text(
              'Preset themes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...presetPaperStyles.map((style) {
              final selected = selectedId == style.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ThemeListTile(
                  label: style.name,
                  isSelected: selected,
                  isLocked: isLocked(style),
                  onTap: () => handleThemeTap(style),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _CreateCustomThemeTile extends StatelessWidget {
  const _CreateCustomThemeTile({required this.isLocked, required this.onTap});

  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(
            isLocked ? Icons.lock_outline : Icons.auto_awesome_outlined,
            color: scheme.primary,
          ),
        ),
        title: const Text('Create custom theme'),
        subtitle: Text(
          isLocked
              ? 'Plus Support Mode only'
              : 'Name it, pick two colours, and we’ll shape the rest.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ThemeListTile extends StatelessWidget {
  const _ThemeListTile({
    required this.label,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
    this.subtitle,
    this.onDelete,
  });

  final String label;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;
  final String? subtitle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.25),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: _ThemeTileTrailing(
          isLocked: isLocked,
          isSelected: isSelected,
          onDelete: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ThemeTileTrailing extends StatelessWidget {
  const _ThemeTileTrailing({
    required this.isLocked,
    required this.isSelected,
    this.onDelete,
  });

  final bool isLocked;
  final bool isSelected;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isLocked) {
      return Icon(Icons.lock_outline, color: scheme.primary);
    }

    final children = <Widget>[
      if (isSelected) const Icon(Icons.check),
      if (onDelete != null)
        IconButton(
          tooltip: 'Delete custom theme',
          icon: Icon(
            Icons.delete_outline,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: onDelete,
        ),
    ];

    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
