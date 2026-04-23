import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/home/overall_features_page.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_canvas.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:mind_buddy/paper/themed_page.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class CustomThemeBuilderScreen extends ConsumerStatefulWidget {
  const CustomThemeBuilderScreen({super.key});

  @override
  ConsumerState<CustomThemeBuilderScreen> createState() =>
      _CustomThemeBuilderScreenState();
}

class _CustomThemeBuilderScreenState
    extends ConsumerState<CustomThemeBuilderScreen> {
  static const List<Color> _paperPresets = <Color>[
    Color(0xFFFFF4F0),
    Color(0xFFFFF7E9),
    Color(0xFFF6F0FF),
    Color(0xFFEFF7FF),
    Color(0xFFEFFFF7),
    Color(0xFFF4F0EA),
    Color(0xFF070A14),
    Color(0xFF101726),
  ];

  static const List<Color> _accentPresets = <Color>[
    Color(0xFFFF5AA5),
    Color(0xFFFF4FB7),
    Color(0xFF5E7BFF),
    Color(0xFF03B1BD),
    Color(0xFF1CC396),
    Color(0xFFB00F70),
    Color(0xFFBA2A1C),
    Color(0xFF22790C),
  ];

  late final TextEditingController _nameController;
  late final Future<SubscriptionInfo> _subscriptionFuture;

  late Color _paperColor;
  late Color _accentColor;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final currentTheme = styleById(
      ref.read(settingsControllerProvider).settings.themeId,
    );
    _paperColor = currentTheme.paper;
    _accentColor = currentTheme.accent;
    _nameController = TextEditingController(text: 'My Theme')
      ..addListener(_handleDraftChanged);
    _subscriptionFuture = SubscriptionLimits.fetchForCurrentUser();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleDraftChanged)
      ..dispose();
    super.dispose();
  }

  void _handleDraftChanged() {
    setState(() {});
  }

  PaperStyle get _previewStyle => buildGuidedCustomPaperStyle(
    name: _nameController.text,
    paper: _paperColor,
    accent: _accentColor,
    existingIds: paperStyles.map((style) => style.id),
  );

  Future<void> _saveTheme() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final subscription = await _subscriptionFuture;
      if (!subscription.isPlus) {
        if (!mounted) return;
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => context.go('/subscription'),
        );
        return;
      }

      final style = _previewStyle;
      await ref.read(settingsControllerProvider).addCustomTheme(style);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      context.pop();
      messenger?.showSnackBar(
        SnackBar(content: Text('${style.name} is now in your theme list.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewStyle = _previewStyle;

    return FutureBuilder<SubscriptionInfo>(
      future: _subscriptionFuture,
      builder: (context, snapshot) {
        final subscription =
            snapshot.data ?? SubscriptionLimits.fromRawTier('pending');
        final isPlus = subscription.isPlus;

        return Theme(
          data: buildThemeFromPaperStyle(previewStyle),
          child: PaperCanvas(
            style: previewStyle,
            child: MbScaffold(
              applyBackground: true,
              appBar: AppBar(
                title: const Text('Create custom theme'),
                centerTitle: true,
                leading: MbGlowBackButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/settings/appearance'),
                ),
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _panelDecoration(context),
                      child: Text(
                        'Pick your colours, name your theme, and make BrainBubble feel more like you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: previewStyle.mutedText,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isPlus) ...[
                      _LockedCustomThemeCard(
                        onUpgrade: () => context.go('/subscription'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _BuilderPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Theme name',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            enabled: isPlus,
                            decoration: const InputDecoration(
                              hintText: 'Sunset Glow',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BuilderPanel(
                      child: _ColorEditor(
                        title: 'Paper colour',
                        subtitle:
                            'Choose the main page colour. We’ll soften it to keep the theme dreamy and easy on the eyes.',
                        color: _paperColor,
                        presetColors: _paperPresets,
                        enabled: isPlus,
                        onChanged: (color) =>
                            setState(() => _paperColor = color),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BuilderPanel(
                      child: _ColorEditor(
                        title: 'Accent colour',
                        subtitle:
                            'This becomes the glow and highlight colour. We gently tune it so it stays polished and readable.',
                        color: _accentColor,
                        presetColors: _accentPresets,
                        enabled: isPlus,
                        onChanged: (color) =>
                            setState(() => _accentColor = color),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BuilderPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Live preview',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This is the real Home screen rendered in your draft theme.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: previewStyle.mutedText),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 460,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: previewStyle.border.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: previewStyle.accent.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Theme(
                                  data: buildThemeFromPaperStyle(previewStyle),
                                  child: PaperCanvas(
                                    style: previewStyle,
                                    child: const OverallFeaturesPage(
                                      previewMode: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BuilderPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Generated automatically',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Text, muted text, box fill, border, and ID are generated for you so the result stays soft, readable, and on-brand.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: previewStyle.mutedText),
                          ),
                          const SizedBox(height: 12),
                          _GeneratedValueRow(
                            label: 'Theme ID',
                            value: _previewStyle.id,
                          ),
                          const SizedBox(height: 8),
                          _GeneratedValueRow(
                            label: 'Generated border',
                            value:
                                '#${_previewStyle.border.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isPlus && !_saving ? _saveTheme : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        isPlus ? 'Save custom theme' : 'Plus Support Mode only',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _panelDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.1),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _BuilderPanel extends StatelessWidget {
  const _BuilderPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LockedCustomThemeCard extends StatelessWidget {
  const _LockedCustomThemeCard({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return _BuilderPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Custom themes are part of Plus Support Mode.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Upgrade to create and save a personal BrainBubble theme with guided colours and an automatic polished finish.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onUpgrade,
            child: const Text('View Plus Support Mode'),
          ),
        ],
      ),
    );
  }
}

class _GeneratedValueRow extends StatelessWidget {
  const _GeneratedValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorEditor extends StatefulWidget {
  const _ColorEditor({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.presetColors,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<Color> presetColors;
  final bool enabled;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends State<_ColorEditor> {
  late final TextEditingController _hexController;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _toHex(widget.color));
  }

  @override
  void didUpdateWidget(covariant _ColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.toARGB32() != widget.color.toARGB32()) {
      _hexController.text = _toHex(widget.color);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyHex() {
    final parsed = _parseHexColor(_hexController.text);
    if (parsed == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Enter a valid hex colour like #F6C7E8.')),
      );
      _hexController.text = _toHex(widget.color);
      return;
    }
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.72),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.presetColors
              .map(
                (preset) => _ColorChip(
                  color: preset,
                  selected: preset.toARGB32() == color.toARGB32(),
                  enabled: widget.enabled,
                  onTap: () => widget.onChanged(preset),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        IgnorePointer(
          ignoring: !widget.enabled,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.55,
            child: Theme(
              data: Theme.of(context).copyWith(
                sliderTheme: Theme.of(
                  context,
                ).sliderTheme.copyWith(trackHeight: 0),
              ),
              child: ColorPicker(
                pickerColor: color,
                onColorChanged: widget.onChanged,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hueWheel,
                pickerAreaHeightPercent: 0.72,
                labelTypes: const [],
                hexInputBar: false,
                portraitOnly: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
          icon: Icon(_showAdvanced ? Icons.expand_less : Icons.code_outlined),
          label: Text(_showAdvanced ? 'Hide advanced' : 'Advanced hex input'),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hexController,
                  enabled: widget.enabled,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: '#F6C7E8'),
                  onSubmitted: (_) => _applyHex(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: widget.enabled ? _applyHex : null,
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.26),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: enabled ? 0.3 : 0.12),
              blurRadius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

String _toHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

Color? _parseHexColor(String raw) {
  final cleaned = raw.trim().replaceAll('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
    return null;
  }
  return Color(int.parse('FF$cleaned', radix: 16));
}
