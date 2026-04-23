import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/features/settings/theme_picker_panel.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(settingsControllerProvider).settings.themeId;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Appearance'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: ListView(
        children: [
          ThemePickerPanel(selectedId: selectedId, onThemeSelected: (_) {}),
        ],
      ),
    );
  }
}
