import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider);
    final selectedId = ref.watch(settingsControllerProvider).settings.themeId;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Appearance'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Paper Themes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...paperStyles.map((style) {
            final isSelected = selectedId == style.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.25),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                title: Text(style.name),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => controller.setTheme(style.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}
