import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/bubbles/bubble_board_screen.dart';
import 'package:mind_buddy/features/bubbles/bubble_board_storage.dart';
import 'package:mind_buddy/features/bubbles/bubble_entry.dart';

class GratitudeBubbleScreen extends StatefulWidget {
  const GratitudeBubbleScreen({super.key});

  static const BubbleBoardStorage _localStorage = SharedPrefsBubbleBoardStorage(
    storageKey: 'gratitude_bubble_entries_v1',
  );

  @override
  State<GratitudeBubbleScreen> createState() => _GratitudeBubbleScreenState();
}

class _GratitudeBubbleScreenState extends State<GratitudeBubbleScreen> {
  bool _deepGratitudeMode = false;
  bool _showExpressionStep = false;
  final Set<String> _selectedIds = <String>{};

  void _toggleMode() {
    setState(() {
      _deepGratitudeMode = !_deepGratitudeMode;
      _showExpressionStep = false;
      if (!_deepGratitudeMode) {
        _selectedIds.clear();
      }
    });
  }

  void _resetMode() {
    if (!mounted) return;
    setState(() {
      _deepGratitudeMode = false;
      _showExpressionStep = false;
      _selectedIds.clear();
    });
  }

  void _handleBubbleTap(BubbleEntry entry) {
    if (!_deepGratitudeMode || _showExpressionStep) return;
    setState(() {
      if (_selectedIds.contains(entry.id)) {
        _selectedIds.remove(entry.id);
      } else {
        _selectedIds.add(entry.id);
      }
    });
  }

  BubbleVisualSpec _bubbleVisual(
    BuildContext context,
    BubbleEntry entry,
    BubbleBoardController controller,
    BubbleVisualSpec defaults,
  ) {
    if (!_deepGratitudeMode) return defaults;
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedIds.contains(entry.id);
    return BubbleVisualSpec(
      color: selected
          ? scheme.primary.withValues(alpha: 0.34)
          : defaults.color.withValues(alpha: 0.88),
      glowStrength: selected ? 0.76 : defaults.glowStrength * 0.9,
      opacity: selected ? 1 : 0.92,
      badgeText: selected ? '✦' : null,
      badgeBackgroundColor: selected
          ? scheme.primary.withValues(alpha: 0.92)
          : null,
    );
  }

  void _goToExpressionStep() {
    if (_selectedIds.isEmpty) return;
    setState(() => _showExpressionStep = true);
  }

  void _backToSelectionStep() {
    if (!mounted) return;
    setState(() => _showExpressionStep = false);
  }

  Future<void> _openJournal() async {
    _resetMode();
    if (!mounted) return;
    context.push('/journals/new');
  }

  Future<void> _openCarousel(BubbleBoardController controller) async {
    final seededTexts = controller.entries
        .where((entry) => _selectedIds.contains(entry.id))
        .map((entry) => entry.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    _resetMode();
    if (!mounted) return;
    context.push(
      '/gratitude-carousel',
      extra: <String, dynamic>{'seededBubbleTexts': seededTexts},
    );
  }

  @override
  Widget build(BuildContext context) {
    return BubbleBoardScreen(
      title: 'Gratitude Bubble',
      storage: GratitudeBubbleScreen._localStorage,
      centerPromptText: 'What is making you feel blessed today ✨',
      editSheetHintText: 'What is making you feel blessed right now?',
      saveButtonText: 'Keep Gratitude',
      clearAllDialogTitle: 'Clear all gratitude bubbles?',
      deleteSnackBarText: 'Gratitude bubble cleared...',
      floatingHintKey: 'hint_gratitude_bubble',
      floatingHintText: 'Long press to pop. Tap to edit. Drag to move.',
      bubbleVisualBuilder: _bubbleVisual,
      appBarActionsBuilder: (context, controller) => <Widget>[
        MbGlowIconButton(
          icon: Icons.photo_library_outlined,
          onPressed: () => context.push('/gratitude-carousel/history'),
        ),
      ],
      onBubbleTap: (context, entry, controller) {
        if (_deepGratitudeMode) {
          _handleBubbleTap(entry);
          return;
        }
        controller.showEditSheet(entry);
      },
      topOverlayBuilder: (context, controller) => _DeepGratitudeCard(
        enabled: _deepGratitudeMode,
        onToggle: _toggleMode,
      ),
      bottomOverlayBuilder: (context, controller) {
        if (!_deepGratitudeMode) {
          return const SizedBox.shrink();
        }
        if (!_showExpressionStep) {
          return _GratitudeSelectionCard(
            selectedCount: _selectedIds.length,
            onNext: _goToExpressionStep,
          );
        }
        return _GratitudeExpressionCard(
          onBack: _backToSelectionStep,
          onJournal: _openJournal,
          onCarousel: () => _openCarousel(controller),
        );
      },
    );
  }
}

class _DeepGratitudeCard extends StatelessWidget {
  const _DeepGratitudeCard({
    required this.enabled,
    required this.onToggle,
  });

  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  enabled
                      ? 'Which of these makes you feel the most blessed ?'
                      : 'Deep Gratitude Mode',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch.adaptive(value: enabled, onChanged: (_) => onToggle()),
            ],
          ),
        ],
      ),
    );
  }
}

class _GratitudeSelectionCard extends StatelessWidget {
  const _GratitudeSelectionCard({
    required this.selectedCount,
    required this.onNext,
  });

  final int selectedCount;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Which of these makes you feel the most blessed ?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedCount == 0
                ? 'Tap the gratitude bubbles you want to hold onto a little longer.'
                : '$selectedCount selected. You can still choose more before you continue.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: selectedCount == 0 ? null : onNext,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GratitudeExpressionCard extends StatelessWidget {
  const _GratitudeExpressionCard({
    required this.onBack,
    required this.onJournal,
    required this.onCarousel,
  });

  final VoidCallback onBack;
  final VoidCallback onJournal;
  final VoidCallback onCarousel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How would you like to express this gratitude?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Choose again'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: onJournal,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Journal Bubble'),
              ),
              FilledButton.tonalIcon(
                onPressed: onCarousel,
                icon: const Icon(Icons.view_carousel_outlined),
                label: const Text('Gratitude Carousel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
