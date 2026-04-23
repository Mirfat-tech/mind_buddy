import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/services/daily_quote_service.dart';
import 'package:mind_buddy/services/notification_service.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

class QuoteBubbleScreen extends ConsumerStatefulWidget {
  const QuoteBubbleScreen({super.key});

  @override
  ConsumerState<QuoteBubbleScreen> createState() => _QuoteBubbleScreenState();
}

class _QuoteBubbleScreenState extends ConsumerState<QuoteBubbleScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  DailyQuoteSettings _quoteSettings = DailyQuoteSettings.defaults();
  SubscriptionInfo? _subscriptionInfo;
  bool _loading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await DailyQuoteService.load();
    final subscription = await SubscriptionLimits.fetchForCurrentUser();
    if (!mounted) return;
    setState(() {
      _quoteSettings = settings;
      _subscriptionInfo = subscription;
      _loading = false;
    });
  }

  bool get _isPlus => _subscriptionInfo?.isPlus == true;

  Future<void> _persist(DailyQuoteSettings next) async {
    await DailyQuoteService.save(next);
    final settings = ref.read(settingsControllerProvider).settings;
    await NotificationService.instance.rescheduleAll(settings);
    if (!mounted) return;
    setState(() {
      _quoteSettings = next;
      final pageCount = _quoteSettings.allQuotes.length;
      if (_currentPage >= pageCount && pageCount > 0) {
        _currentPage = pageCount - 1;
      }
    });
  }

  Future<void> _showUpgradePrompt({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              context.go('/subscription');
            },
            child: const Text('See plans'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReminderSheet() async {
    if (!mounted) return;
    final result = await showModalBottomSheet<_ReminderSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _QuoteReminderSheet(
        initialTimes: _quoteSettings.notificationTimes,
        isPlus: _isPlus,
      ),
    );
    if (!mounted || result == null) return;
    if (result.requiresUpgrade) {
      await _showUpgradePrompt(
        title: 'A few more quote moments?',
        message:
            'Free Mode can hold one gentle quote reminder each day. Plus Support Mode opens the door to more little quote check-ins.',
      );
      return;
    }
    await _persist(_quoteSettings.copyWith(notificationTimes: result.times));
  }

  Future<void> _openAddQuoteSheet() async {
    if (!_isPlus) {
      await _showUpgradePrompt(
        title: 'Want your own words here too?',
        message:
            'Make Your Own Quotes is part of the Quotes feature set in Plus Support Mode.',
      );
      return;
    }
    if (!mounted) return;
    final quote = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const _AddQuoteSheet(),
    );
    final trimmed = (quote ?? '').trim();
    if (!mounted || trimmed.isEmpty) return;
    final nextQuotes = {..._quoteSettings.customQuotes, trimmed}.toList();
    await _persist(_quoteSettings.copyWith(customQuotes: nextQuotes));
    if (!mounted) return;
    setState(() {
      _currentPage = _quoteSettings.allQuotes.length - 1;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _removeCustomQuote(String quote) async {
    final next = List<String>.from(_quoteSettings.customQuotes)..remove(quote);
    await _persist(_quoteSettings.copyWith(customQuotes: next));
  }

  Future<void> _setStyle(String styleId) async {
    if (styleId == _quoteSettings.styleId) return;
    await _persist(_quoteSettings.copyWith(styleId: styleId));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allQuotes = _quoteSettings.allQuotes;
    final quoteTheme = _quoteThemeFor(_quoteSettings.styleId, cs);

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Daily quotes'),
        leading: MbGlowBackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          IconButton(
            tooltip: 'Quote reminder times',
            onPressed: _openReminderSheet,
            icon: const Icon(Icons.schedule_rounded),
          ),
          IconButton(
            tooltip: 'Make your own quote',
            onPressed: _openAddQuoteSheet,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                SizedBox(
                  height: 332,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: allQuotes.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final isCustom =
                          index >= DailyQuoteService.defaultQuotes.length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _QuoteCard(
                          quote: allQuotes[index],
                          label: isCustom ? 'Your quote' : 'Daily quote',
                          palette: quoteTheme.paletteFor(index),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    allQuotes.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _currentPage ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == _currentPage
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _QuoteStyleSelector(
                  selectedId: _quoteSettings.styleId,
                  onSelect: _setStyle,
                ),
                if (_quoteSettings.notificationTimes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quoteSettings.notificationTimes
                        .map(
                          (time) =>
                              _InfoPill(label: _formatTime(context, time)),
                        )
                        .toList(),
                  ),
                ],
                if (!_isPlus) ...[
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      'Make Your Own Quotes is available in Plus Support Mode.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ],
                if (_quoteSettings.customQuotes.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Make Your Own Quotes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _quoteSettings.customQuotes
                        .map(
                          (quote) => _CustomQuoteRow(
                            quote: quote,
                            onDelete: () => _removeCustomQuote(quote),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
    );
  }
}

String _formatTime(BuildContext context, String time) {
  final parts = time.split(':');
  if (parts.length != 2) return time;
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = int.tryParse(parts.last) ?? 0;
  return TimeOfDay(hour: hour, minute: minute).format(context);
}

class _QuoteStyleSelector extends StatelessWidget {
  const _QuoteStyleSelector({required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  static const List<({String id, String label})> styles = [
    (id: 'soft', label: 'Soft'),
    (id: 'dreamy', label: 'Dreamy'),
    (id: 'glowy', label: 'Glowy'),
    (id: 'sheer', label: 'Sheer'),
    (id: 'calming', label: 'Calming'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bubble mood',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the look that feels nicest today.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: styles
                .map(
                  (style) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => onSelect(style.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: style.id == selectedId
                              ? cs.primary.withValues(alpha: 0.16)
                              : cs.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: style.id == selectedId
                                ? cs.primary.withValues(alpha: 0.32)
                                : cs.outline.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          style.label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: style.id == selectedId
                                    ? cs.primary
                                    : cs.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.label,
    required this.palette,
  });

  final String quote;
  final String label;
  final _QuoteCardPalette palette;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        gradient: LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 18,
            right: 20,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.highlight.withValues(alpha: 0.42),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 26,
            left: 24,
            child: Icon(
              Icons.format_quote_rounded,
              size: 38,
              color: palette.labelColor.withValues(alpha: 0.34),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 68, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  quote,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CustomQuoteRow extends StatelessWidget {
  const _CustomQuoteRow({required this.quote, required this.onDelete});

  final String quote;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              quote,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _AddQuoteSheet extends StatefulWidget {
  const _AddQuoteSheet();

  @override
  State<_AddQuoteSheet> createState() => _AddQuoteSheetState();
}

class _AddQuoteSheetState extends State<_AddQuoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add your own quote',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'A little line you want future-you to hear again.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'Write a quote that feels like a soft return to yourself…',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_controller.text),
              child: const Text('Keep quote'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteReminderSheet extends StatefulWidget {
  const _QuoteReminderSheet({required this.initialTimes, required this.isPlus});

  final List<String> initialTimes;
  final bool isPlus;

  @override
  State<_QuoteReminderSheet> createState() => _QuoteReminderSheetState();
}

class _QuoteReminderSheetState extends State<_QuoteReminderSheet> {
  late List<String> _times;

  @override
  void initState() {
    super.initState();
    _times = List<String>.from(widget.initialTimes)..sort();
  }

  Future<void> _addTime() async {
    if (!widget.isPlus && _times.isNotEmpty) {
      Navigator.of(context).pop(
        const _ReminderSheetResult(times: <String>[], requiresUpgrade: true),
      );
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (!mounted || picked == null) return;
    final encoded =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _times = {..._times, encoded}.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select the time you want to be notified of your inspiring quotes for the day',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (_times.isEmpty)
                Text(
                  'No quote times set yet. Add one whenever you want a soft little nudge to arrive.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _times
                      .map(
                        (time) => _TimeChip(
                          label: _formatTime(context, time),
                          onRemove: () {
                            setState(() {
                              _times = List<String>.from(_times)..remove(time);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: _addTime,
                    child: const Text('Add time'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(_ReminderSheetResult(times: _times));
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderSheetResult {
  const _ReminderSheetResult({
    required this.times,
    this.requiresUpgrade = false,
  });

  final List<String> times;
  final bool requiresUpgrade;
}

class _QuoteThemeStyle {
  const _QuoteThemeStyle({required this.id, required this.buildPalette});

  final String id;
  final _QuoteCardPalette Function(int index) buildPalette;

  _QuoteCardPalette paletteFor(int index) => buildPalette(index);
}

class _QuoteCardPalette {
  const _QuoteCardPalette({
    required this.gradient,
    required this.border,
    required this.shadow,
    required this.highlight,
    required this.labelColor,
  });

  final List<Color> gradient;
  final Color border;
  final Color shadow;
  final Color highlight;
  final Color labelColor;
}

_QuoteThemeStyle _quoteThemeFor(String id, ColorScheme cs) {
  _QuoteCardPalette heroLike({
    required Color accent,
    required Color secondary,
  }) {
    return _QuoteCardPalette(
      gradient: [
        accent.withValues(alpha: 0.18),
        cs.surface.withValues(alpha: 0.96),
        secondary.withValues(alpha: 0.14),
      ],
      border: accent.withValues(alpha: 0.16),
      shadow: accent.withValues(alpha: 0.12),
      highlight: secondary,
      labelColor: accent.withValues(alpha: 0.82),
    );
  }

  _QuoteCardPalette airy({required Color accent, required Color tint}) {
    return _QuoteCardPalette(
      gradient: [
        Colors.white.withValues(alpha: 0.94),
        Color.lerp(accent, Colors.white, 0.82)!.withValues(alpha: 0.96),
        tint.withValues(alpha: 0.12),
      ],
      border: accent.withValues(alpha: 0.18),
      shadow: accent.withValues(alpha: 0.16),
      highlight: tint,
      labelColor: accent.withValues(alpha: 0.86),
    );
  }

  return switch (id) {
    'dreamy' => _QuoteThemeStyle(
      id: id,
      buildPalette: (index) => index.isEven
          ? heroLike(accent: cs.primary, secondary: cs.secondary)
          : airy(accent: cs.secondary, tint: cs.tertiary),
    ),
    'glowy' => _QuoteThemeStyle(
      id: id,
      buildPalette: (index) => index.isEven
          ? airy(accent: cs.primary, tint: cs.primary)
          : heroLike(accent: cs.primary, secondary: cs.tertiary),
    ),
    'sheer' => _QuoteThemeStyle(
      id: id,
      buildPalette: (index) => _QuoteCardPalette(
        gradient: [
          Colors.white.withValues(alpha: 0.78),
          cs.surface.withValues(alpha: 0.7),
          cs.secondary.withValues(alpha: index.isEven ? 0.10 : 0.18),
        ],
        border: cs.primary.withValues(alpha: 0.10),
        shadow: cs.primary.withValues(alpha: 0.08),
        highlight: cs.primary.withValues(alpha: 0.22),
        labelColor: cs.primary.withValues(alpha: 0.76),
      ),
    ),
    'calming' => _QuoteThemeStyle(
      id: id,
      buildPalette: (index) => index.isEven
          ? airy(accent: cs.tertiary, tint: cs.secondary)
          : heroLike(accent: cs.secondary, secondary: cs.primary),
    ),
    _ => _QuoteThemeStyle(
      id: 'soft',
      buildPalette: (index) => index.isEven
          ? airy(accent: cs.primary, tint: cs.secondary)
          : heroLike(accent: cs.primary, secondary: cs.secondary),
    ),
  };
}
