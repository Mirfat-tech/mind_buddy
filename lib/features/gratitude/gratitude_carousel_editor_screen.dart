import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import 'package:mind_buddy/features/journal/journal_sticker_catalog.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

import 'gratitude_carousel_models.dart';
import 'gratitude_carousel_storage.dart';

class GratitudeCarouselEditorScreen extends StatefulWidget {
  const GratitudeCarouselEditorScreen({
    super.key,
    this.entryId,
    this.seededBubbleTexts = const <String>[],
    this.storage,
    this.onOpenHistory,
  });

  final String? entryId;
  final List<String> seededBubbleTexts;
  final GratitudeCarouselEntryStorage? storage;
  final VoidCallback? onOpenHistory;

  @override
  State<GratitudeCarouselEditorScreen> createState() =>
      _GratitudeCarouselEditorScreenState();
}

class _GratitudeCarouselEditorScreenState
    extends State<GratitudeCarouselEditorScreen> {
  final Uuid _uuid = const Uuid();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.86);
  final Map<String, String?> _selectedStickerIds = <String, String?>{};
  final Map<String, TextEditingController> _captionControllers =
      <String, TextEditingController>{};
  GratitudeCarouselEntry? _entry;
  bool _loading = true;
  bool _saving = false;
  bool _isEditMode = true;
  int _pageIndex = 0;
  Timer? _draftSaveDebounce;

  GratitudeCarouselEntryStorage get _storage =>
      widget.storage ?? GratitudeCarouselStorage.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _draftSaveDebounce?.cancel();
    _titleController.dispose();
    _pageController.dispose();
    for (final controller in _captionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    GratitudeCarouselEntry entry;
    bool opensInPreview = false;
    if (widget.entryId != null) {
      final existing = await _storage.getEntry(widget.entryId!);
      if (existing != null) {
        entry = existing;
        opensInPreview = true;
      } else {
        entry = _createDraft(widget.seededBubbleTexts);
      }
    } else {
      entry = _createDraft(widget.seededBubbleTexts);
      await _storage.saveEntry(entry);
    }
    entry = _normalizeEntry(entry);
    if (!mounted) return;
    _titleController.text = entry.title;
    _syncCaptionControllers(entry.items);
    setState(() {
      _entry = entry;
      _loading = false;
      _isEditMode = !opensInPreview;
      _pageIndex = 0;
    });
  }

  GratitudeCarouselEntry _createDraft(List<String> seededBubbleTexts) {
    final now = DateTime.now();
    return GratitudeCarouselEntry(
      id: _uuid.v4(),
      date: DateTime(now.year, now.month, now.day),
      title: seededBubbleTexts.isNotEmpty
          ? 'A grateful little memory'
          : 'A soft grateful memory',
      createdAt: now,
      updatedAt: now,
      seededBubbleTexts: seededBubbleTexts,
      items: <GratitudeCarouselItem>[_emptyPolaroid()],
    );
  }

  GratitudeCarouselEntry _normalizeEntry(GratitudeCarouselEntry entry) {
    final mediaItems = entry.items
        .where(
          (item) =>
              item.type == GratitudeCarouselItemType.photo ||
              item.type == GratitudeCarouselItemType.video,
        )
        .toList();
    final legacyText = entry.items
        .where((item) => item.type == GratitudeCarouselItemType.text)
        .map((item) => item.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    if (mediaItems.isEmpty) {
      return entry.copyWith(
        items: <GratitudeCarouselItem>[_emptyPolaroid(caption: legacyText)],
      );
    }
    if (legacyText.isNotEmpty && mediaItems.first.caption.trim().isEmpty) {
      mediaItems[0] = mediaItems.first.copyWith(caption: legacyText);
    }
    return entry.copyWith(items: mediaItems);
  }

  GratitudeCarouselItem _emptyPolaroid({String caption = ''}) {
    return GratitudeCarouselItem(
      id: _uuid.v4(),
      type: GratitudeCarouselItemType.photo,
      caption: caption,
      filePath: null,
    );
  }

  void _syncCaptionControllers(List<GratitudeCarouselItem> items) {
    final validIds = items.map((item) => item.id).toSet();
    final toRemove = _captionControllers.keys
        .where((id) => !validIds.contains(id))
        .toList();
    for (final id in toRemove) {
      _captionControllers.remove(id)?.dispose();
    }
    for (final item in items) {
      final existing = _captionControllers[item.id];
      if (existing == null) {
        _captionControllers[item.id] = TextEditingController(
          text: item.caption,
        );
      } else if (existing.text != item.caption) {
        existing.value = TextEditingValue(
          text: item.caption,
          selection: TextSelection.collapsed(offset: item.caption.length),
        );
      }
    }
  }

  void _replaceEntry(GratitudeCarouselEntry next, {bool queueDraft = true}) {
    final normalized = _normalizeEntry(next);
    _syncCaptionControllers(normalized.items);
    setState(() => _entry = normalized);
    if (queueDraft) {
      _queueDraftSave();
    }
  }

  Future<void> _queueDraftSave() async {
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 260), () async {
      await _save(showFeedback: false);
    });
  }

  Future<void> _save({bool showFeedback = true}) async {
    final entry = _entry;
    if (entry == null) return;
    setState(() => _saving = true);
    final updated = entry.copyWith(
      title: _titleController.text.trim().isEmpty
          ? 'A soft grateful memory'
          : _titleController.text.trim(),
      updatedAt: DateTime.now(),
    );
    await _storage.saveEntry(updated);
    if (!mounted) return;
    setState(() {
      _entry = updated;
      _saving = false;
    });
    if (showFeedback) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gratitude Carousel saved')));
    }
  }

  void _enterEditMode() {
    if (!mounted) return;
    setState(() => _isEditMode = true);
  }

  Future<void> _pickDate() async {
    final entry = _entry;
    if (entry == null) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    _replaceEntry(
      entry.copyWith(
        date: DateTime(selected.year, selected.month, selected.day),
      ),
    );
  }

  Future<void> _setPhotoForCurrentSlide() async {
    final entry = _entry;
    if (entry == null || entry.items.isEmpty) return;
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final item = entry.items[_pageIndex];
    _updateItem(
      item.copyWith(
        type: GratitudeCarouselItemType.photo,
        filePath: image.path,
      ),
    );
  }

  Future<void> _setVideoForCurrentSlide() async {
    final entry = _entry;
    if (entry == null || entry.items.isEmpty) return;
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    final item = entry.items[_pageIndex];
    _updateItem(
      item.copyWith(
        type: GratitudeCarouselItemType.video,
        filePath: video.path,
      ),
    );
  }

  void _addPolaroid() {
    final entry = _entry;
    if (entry == null) return;
    final nextItems = <GratitudeCarouselItem>[...entry.items, _emptyPolaroid()];
    _replaceEntry(entry.copyWith(items: nextItems));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nextIndex = nextItems.length - 1;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _deleteCurrentPolaroid() {
    final entry = _entry;
    if (entry == null || entry.items.isEmpty) return;
    final items = [...entry.items];
    final removed = items.removeAt(_pageIndex);
    _captionControllers.remove(removed.id)?.dispose();
    if (items.isEmpty) {
      items.add(_emptyPolaroid());
    }
    final nextIndex = _pageIndex.clamp(0, items.length - 1);
    _replaceEntry(entry.copyWith(items: items));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.jumpToPage(nextIndex);
      setState(() => _pageIndex = nextIndex);
    });
  }

  void _updateItem(GratitudeCarouselItem item) {
    final entry = _entry;
    if (entry == null) return;
    final nextItems = entry.items
        .map((existing) => existing.id == item.id ? item : existing)
        .toList();
    _replaceEntry(entry.copyWith(items: nextItems));
  }

  Future<void> _addSticker(GratitudeCarouselItem item) async {
    final selected = await showModalBottomSheet<JournalStickerDefinition>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _StickerPickerSheet(
        stickers: JournalStickerCatalog.starterPack,
      ),
    );
    if (selected == null) return;
    final nextStickers = <GratitudeCarouselSticker>[
      ...item.stickers,
      GratitudeCarouselSticker(
        id: _uuid.v4(),
        stickerId: selected.id,
        stickerPackId: JournalStickerCatalog.starterPackId,
        x: 0.76,
        y: 0.20,
        scale: 1.0,
        rotation: 0,
      ),
    ];
    _updateItem(item.copyWith(stickers: nextStickers));
  }

  void _updateSticker(
    GratitudeCarouselItem item,
    GratitudeCarouselSticker sticker,
  ) {
    final nextStickers = item.stickers
        .map((existing) => existing.id == sticker.id ? sticker : existing)
        .toList();
    _updateItem(item.copyWith(stickers: nextStickers));
  }

  void _deleteSticker(GratitudeCarouselItem item, String stickerId) {
    final nextStickers = item.stickers
        .where((sticker) => sticker.id != stickerId)
        .toList();
    _selectedStickerIds[item.id] = null;
    _updateItem(item.copyWith(stickers: nextStickers));
  }

  Future<void> _deleteEntry() async {
    final entry = _entry;
    if (entry == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text(
          'This will remove the whole Gratitude Carousel entry from your saved memories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await _storage.deleteEntry(entry.id);
    if (!mounted) return;
    context.pop();
  }

  String _dateLabel(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Consumer(
      builder: (context, ref, _) {
        final themeId = ref.watch(settingsControllerProvider).settings.themeId;
        final style = styleById(themeId);
        final scheme = Theme.of(context).colorScheme;
        final isDark =
            ThemeData.estimateBrightnessForColor(style.paper) ==
            Brightness.dark;
        final accent = style.accent;
        final chipFill = Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.18 : 0.10),
          style.boxFill.withValues(alpha: 0.96),
        );
        final mediaWellColor = Color.alphaBlend(
          style.border.withValues(alpha: isDark ? 0.22 : 0.16),
          style.paper,
        );
        return Scaffold(
          backgroundColor: style.paper,
          appBar: AppBar(
            title: const Text('Gratitude Carousel'),
            foregroundColor: style.text,
            iconTheme: IconThemeData(color: accent),
            actionsIconTheme: IconThemeData(color: accent),
            actions: [
              IconButton(
                tooltip: 'View memories',
                onPressed:
                    widget.onOpenHistory ??
                    () => context.push('/gratitude-carousel/history'),
                icon: const Icon(Icons.photo_library_outlined),
              ),
              if (!_loading && !_isEditMode && widget.entryId != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: accent),
                  onPressed: _enterEditMode,
                  child: const Text('Edit'),
                ),
              if (_isEditMode)
                IconButton(
                  tooltip: 'Save',
                  onPressed: _loading ? null : () => _save(),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                ),
              if (entry != null && _isEditMode)
                IconButton(
                  tooltip: 'Delete memory',
                  onPressed: _deleteEntry,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: ColoredBox(
            color: style.paper,
            child: _loading || entry == null
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_isEditMode) ...[
                                  Text(
                                    'A memory scrapbook for the moments you want to keep close',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (_isEditMode)
                                  TextField(
                                    controller: _titleController,
                                    onChanged: (_) => _queueDraftSave(),
                                    decoration: const InputDecoration(
                                      labelText: 'Title',
                                      hintText:
                                          'What would you call this memory?',
                                    ),
                                  )
                                else
                                  Text(
                                    _titleController.text.trim().isEmpty
                                        ? 'A soft grateful memory'
                                        : _titleController.text.trim(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                const SizedBox(height: 12),
                                if (_isEditMode)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: _pickDate,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 18,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _dateLabel(entry.date),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 18,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _dateLabel(entry.date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                if (_isEditMode &&
                                    entry.seededBubbleTexts.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Text(
                                    'Started from these gratitude bubbles',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: entry.seededBubbleTexts
                                        .map(
                                          (text) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: chipFill,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: accent.withValues(
                                                  alpha: isDark ? 0.28 : 0.18,
                                                ),
                                              ),
                                            ),
                                            child: Text(text),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 560,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 22,
                                        right: 22,
                                        top: 10,
                                        child: _FairyLightsDivider(
                                          style: style,
                                        ),
                                      ),
                                      Positioned.fill(
                                        top: 32,
                                        child: PageView.builder(
                                          controller: _pageController,
                                          itemCount: entry.items.length,
                                          onPageChanged: (index) => setState(
                                            () => _pageIndex = index,
                                          ),
                                          itemBuilder: (context, index) {
                                            final item = entry.items[index];
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 8,
                                                  ),
                                              child: _PolaroidSlide(
                                                style: style,
                                                mediaWellColor: mediaWellColor,
                                                item: item,
                                                isEditing: _isEditMode,
                                                selectedStickerId:
                                                    _selectedStickerIds[item
                                                        .id],
                                                captionController:
                                                    _captionControllers[item
                                                        .id]!,
                                                label: 'Polaroid ${index + 1}',
                                                onAddPhotos:
                                                    _setPhotoForCurrentSlide,
                                                onAddVideos:
                                                    _setVideoForCurrentSlide,
                                                onAddSticker: () =>
                                                    _addSticker(item),
                                                onCaptionChanged: (text) =>
                                                    _updateItem(
                                                      item.copyWith(
                                                        caption: text,
                                                      ),
                                                    ),
                                                onSelectSticker: (stickerId) {
                                                  setState(() {
                                                    _selectedStickerIds[item
                                                            .id] =
                                                        stickerId;
                                                  });
                                                },
                                                onUpdateSticker: (sticker) =>
                                                    _updateSticker(
                                                      item,
                                                      sticker,
                                                    ),
                                                onDeleteSticker: (stickerId) =>
                                                    _deleteSticker(
                                                      item,
                                                      stickerId,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isEditMode &&
                                    entry.seededBubbleTexts.isNotEmpty) ...[
                                  const SizedBox(height: 26),
                                  Text(
                                    'Started from these gratitude bubbles',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: entry.seededBubbleTexts
                                        .map(
                                          (text) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: chipFill,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: accent.withValues(
                                                  alpha: isDark ? 0.28 : 0.18,
                                                ),
                                              ),
                                            ),
                                            child: Text(text),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                if (_isEditMode) ...[
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: _addPolaroid,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Polaroid'),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.tonalIcon(
                                        onPressed: entry.items.isEmpty
                                            ? null
                                            : _deleteCurrentPolaroid,
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete Polaroid'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class GratitudeCarouselHistoryScreen extends StatefulWidget {
  const GratitudeCarouselHistoryScreen({super.key});

  @override
  State<GratitudeCarouselHistoryScreen> createState() =>
      _GratitudeCarouselHistoryScreenState();
}

class _GratitudeCarouselHistoryScreenState
    extends State<GratitudeCarouselHistoryScreen> {
  bool _loading = true;
  List<GratitudeCarouselEntry> _entries = const <GratitudeCarouselEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await GratitudeCarouselStorage.fetchEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  String _dateLabel(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Gratitude Carousel')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/gratitude-carousel'),
        label: const Text('New memory'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No carousel memories yet.\nWhen one of your gratitude bubbles wants to become a scrapbook moment, it will show up here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final polaroidCount = entry.items.length;
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => context
                      .push(
                        '/gratitude-carousel',
                        extra: <String, dynamic>{'entryId': entry.id},
                      )
                      .then((_) => _load()),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              _dateLabel(entry.date),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _HistoryChip(
                              label: '$polaroidCount polaroids',
                              icon: Icons.view_carousel_outlined,
                            ),
                            if (entry.seededBubbleTexts.isNotEmpty)
                              _HistoryChip(
                                label:
                                    '${entry.seededBubbleTexts.length} gratitude bubbles',
                                icon: Icons.auto_awesome_outlined,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _PolaroidSlide extends StatelessWidget {
  const _PolaroidSlide({
    required this.style,
    required this.mediaWellColor,
    required this.item,
    required this.isEditing,
    required this.selectedStickerId,
    required this.captionController,
    required this.label,
    required this.onAddPhotos,
    required this.onAddVideos,
    required this.onAddSticker,
    required this.onCaptionChanged,
    required this.onSelectSticker,
    required this.onUpdateSticker,
    required this.onDeleteSticker,
  });

  final PaperStyle style;
  final Color mediaWellColor;
  final GratitudeCarouselItem item;
  final bool isEditing;
  final String? selectedStickerId;
  final TextEditingController captionController;
  final String label;
  final VoidCallback onAddPhotos;
  final VoidCallback onAddVideos;
  final VoidCallback onAddSticker;
  final ValueChanged<String> onCaptionChanged;
  final ValueChanged<String?> onSelectSticker;
  final ValueChanged<GratitudeCarouselSticker> onUpdateSticker;
  final ValueChanged<String> onDeleteSticker;

  bool get _hasMedia => item.filePath != null && item.filePath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(style.paper) == Brightness.dark;
    final accent = style.accent;
    final labelChipColor = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.18 : 0.10),
      style.boxFill.withValues(alpha: 0.96),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: labelChipColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                ),
              ),
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 2,
                    child: Row(
                      children: [
                        _PolaroidClip(style: style),
                        const SizedBox(width: 78),
                        _PolaroidClip(style: style),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Container(
                      width: width,
                      decoration: BoxDecoration(
                        color: style.boxFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: style.border.withValues(
                            alpha: isDark ? 0.36 : 0.22,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 22,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 11,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        color: mediaWellColor,
                                        child: _hasMedia
                                            ? switch (item.type) {
                                                GratitudeCarouselItemType
                                                    .video =>
                                                  _VideoPreview(
                                                    filePath: item.filePath,
                                                    accentColor: accent,
                                                  ),
                                                _ => _PhotoPreview(
                                                  filePath: item.filePath,
                                                ),
                                              }
                                            : _PolaroidEmptyMediaState(
                                                style: style,
                                                isEditing: isEditing,
                                                onAddPhotos: onAddPhotos,
                                                onAddVideos: onAddVideos,
                                              ),
                                      ),
                                    ),
                                  ),
                                  ...item.stickers.map((sticker) {
                                    final definition =
                                        JournalStickerCatalog.byId(
                                          sticker.stickerId,
                                        );
                                    if (definition == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return _FrameSticker(
                                      key: ValueKey(sticker.id),
                                      sticker: sticker,
                                      definition: definition,
                                      cardHeight: height * 0.88,
                                      cardWidth: width,
                                      selected:
                                          isEditing &&
                                          selectedStickerId == sticker.id,
                                      onTap: isEditing
                                          ? () => onSelectSticker(sticker.id)
                                          : null,
                                      onChanged: (next) => onUpdateSticker(
                                        _sanitizeSticker(next),
                                      ),
                                      onDelete: () =>
                                          onDeleteSticker(sticker.id),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (isEditing) ...[
                              Row(
                                children: [
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      foregroundColor: accent,
                                      backgroundColor: Color.alphaBlend(
                                        accent.withValues(
                                          alpha: isDark ? 0.22 : 0.14,
                                        ),
                                        style.boxFill,
                                      ),
                                    ),
                                    onPressed: onAddSticker,
                                    icon: const Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Sticker'),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _hasMedia
                                        ? 'Add a note'
                                        : 'Add media first',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: style.mutedText),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: captionController,
                                onChanged: onCaptionChanged,
                                minLines: 2,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: _hasMedia
                                      ? 'Add a note'
                                      : 'Your note can live here after you add a photo or video',
                                  border: InputBorder.none,
                                ),
                              ),
                            ] else if (item.caption.trim().isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  item.caption.trim(),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: style.text,
                                        height: 1.45,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  GratitudeCarouselSticker _sanitizeSticker(GratitudeCarouselSticker sticker) {
    return sticker.copyWith(
      x: sticker.x.clamp(0.12, 0.88).toDouble(),
      y: sticker.y.clamp(0.08, 0.92).toDouble(),
      scale: sticker.scale.clamp(0.72, 1.85).toDouble(),
    );
  }
}

class _PolaroidEmptyMediaState extends StatelessWidget {
  const _PolaroidEmptyMediaState({
    required this.style,
    required this.isEditing,
    required this.onAddPhotos,
    required this.onAddVideos,
  });

  final PaperStyle style;
  final bool isEditing;
  final VoidCallback onAddPhotos;
  final VoidCallback onAddVideos;

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(style.paper) == Brightness.dark;
    final accent = style.accent;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_back_outlined,
            size: 42,
            color: accent.withValues(alpha: 0.92),
          ),
          const SizedBox(height: 16),
          if (isEditing) ...[
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                foregroundColor: accent,
                backgroundColor: Color.alphaBlend(
                  accent.withValues(alpha: isDark ? 0.22 : 0.14),
                  style.boxFill,
                ),
              ),
              onPressed: onAddPhotos,
              child: const Text('Add photos'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                foregroundColor: accent,
                backgroundColor: Color.alphaBlend(
                  accent.withValues(alpha: isDark ? 0.22 : 0.14),
                  style.boxFill,
                ),
              ),
              onPressed: onAddVideos,
              child: const Text('Add videos'),
            ),
          ] else
            Text(
              'A quiet little empty Polaroid',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: style.mutedText),
            ),
        ],
      ),
    );
  }
}

class _PolaroidClip extends StatelessWidget {
  const _PolaroidClip({required this.style});

  final PaperStyle style;

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(style.paper) == Brightness.dark;
    return Container(
      width: 28,
      height: 16,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          style.accent.withValues(alpha: isDark ? 0.10 : 0.06),
          style.boxFill,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: style.border.withValues(alpha: isDark ? 0.26 : 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: style.accent.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _StickerPickerSheet extends StatelessWidget {
  const _StickerPickerSheet({required this.stickers});

  final List<JournalStickerDefinition> stickers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a little sticker',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                itemCount: stickers.length,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final sticker = stickers[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(sticker),
                    borderRadius: BorderRadius.circular(22),
                    child: Column(
                      children: [
                        Expanded(child: JournalStickerArt(definition: sticker)),
                        const SizedBox(height: 6),
                        Text(
                          sticker.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrameSticker extends StatefulWidget {
  const _FrameSticker({
    super.key,
    required this.sticker,
    required this.definition,
    required this.cardHeight,
    required this.cardWidth,
    required this.selected,
    required this.onTap,
    required this.onChanged,
    required this.onDelete,
  });

  final GratitudeCarouselSticker sticker;
  final JournalStickerDefinition definition;
  final double cardHeight;
  final double cardWidth;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<GratitudeCarouselSticker> onChanged;
  final VoidCallback onDelete;

  @override
  State<_FrameSticker> createState() => _FrameStickerState();
}

class _FrameStickerState extends State<_FrameSticker> {
  late GratitudeCarouselSticker _workingSticker;
  late GratitudeCarouselSticker _startSticker;
  late Offset _startFocalPoint;
  late Offset _startPointerToCenterOffset;

  @override
  void initState() {
    super.initState();
    _workingSticker = widget.sticker;
    _startSticker = widget.sticker;
    _startFocalPoint = Offset.zero;
    _startPointerToCenterOffset = Offset.zero;
  }

  @override
  void didUpdateWidget(covariant _FrameSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sticker != widget.sticker) {
      _workingSticker = widget.sticker;
      _startSticker = widget.sticker;
      _startPointerToCenterOffset = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.cardWidth * _workingSticker.x;
    final top = widget.cardHeight * _workingSticker.y;
    final size = 60 * _workingSticker.scale;
    return Positioned(
      left: left - (size / 2),
      top: top - (size / 2),
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: (details) {
          if (widget.onTap == null) return;
          widget.onTap?.call();
          _startFocalPoint = details.focalPoint;
          _startSticker = _workingSticker;
          final size = 60 * _workingSticker.scale;
          _startPointerToCenterOffset =
              details.localFocalPoint - Offset(size / 2, size / 2);
        },
        onScaleUpdate: (details) {
          if (widget.onTap == null) return;
          final dx =
              (details.focalPoint.dx - _startFocalPoint.dx) / widget.cardWidth;
          final dy =
              (details.focalPoint.dy - _startFocalPoint.dy) / widget.cardHeight;
          final anchorDx = _startPointerToCenterOffset.dx / widget.cardWidth;
          final anchorDy = _startPointerToCenterOffset.dy / widget.cardHeight;
          final next = _startSticker.copyWith(
            x: _startSticker.x + dx + anchorDx,
            y: _startSticker.y + dy + anchorDy,
            scale: _startSticker.scale * details.scale,
            rotation: _startSticker.rotation + details.rotation,
          );
          setState(() => _workingSticker = next);
          widget.onChanged(next);
        },
        child: Transform.rotate(
          angle: _workingSticker.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: JournalStickerArt(definition: widget.definition),
              ),
              if (widget.selected)
                Positioned(
                  top: -8,
                  right: -8,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.definition.iconColor.withValues(
                            alpha: 0.38,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: widget.definition.iconColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FairyLightsDivider extends StatefulWidget {
  const _FairyLightsDivider({required this.style});

  final PaperStyle style;

  @override
  State<_FairyLightsDivider> createState() => _FairyLightsDividerState();
}

class _FairyLightsDividerState extends State<_FairyLightsDivider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 42),
          painter: _FairyLightsPainter(
            glowAmount: _controller.value,
            style: widget.style,
          ),
        );
      },
    );
  }
}

class _FairyLightsPainter extends CustomPainter {
  const _FairyLightsPainter({required this.glowAmount, required this.style});

  final double glowAmount;
  final PaperStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark =
        ThemeData.estimateBrightnessForColor(style.paper) == Brightness.dark;
    final wirePaint = Paint()
      ..color = style.accent.withValues(alpha: isDark ? 0.28 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final wirePath = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.82,
        size.width,
        size.height * 0.38,
      );
    canvas.drawPath(wirePath, wirePaint);

    const bulbs = 7;
    for (int i = 0; i < bulbs; i++) {
      final t = i / (bulbs - 1);
      final x = size.width * t;
      final y = size.height * (0.42 + math.sin((t * math.pi * 2) + 0.3) * 0.12);
      final bulbColor = Color.lerp(
        style.accent.withValues(alpha: isDark ? 0.7 : 0.56),
        style.boxFill.withValues(alpha: 0.96),
        ((i % 3) / 3) + (glowAmount * 0.18),
      )!;
      final glowPaint = Paint()
        ..color = bulbColor.withValues(alpha: 0.22 + (glowAmount * 0.14))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(x, y), 8 + (glowAmount * 2), glowPaint);
      final bulbPaint = Paint()..color = bulbColor;
      canvas.drawCircle(Offset(x, y), 4.2, bulbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FairyLightsPainter oldDelegate) {
    return oldDelegate.glowAmount != glowAmount || oldDelegate.style != style;
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.filePath});

  final String? filePath;

  @override
  Widget build(BuildContext context) {
    if (filePath == null || filePath!.isEmpty) {
      return const SizedBox.shrink();
    }
    final file = File(filePath!);
    if (!file.existsSync()) {
      return const Center(child: Icon(Icons.image_not_supported_outlined));
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.filePath, required this.accentColor});

  final String? filePath;
  final Color accentColor;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _disposeController();
      _load();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _load() async {
    final path = widget.filePath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(0);
    await controller.play();
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        const Center(child: SizedBox.shrink()),
        Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            size: 44,
            color: widget.accentColor.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }
}
