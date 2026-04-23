import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:mind_buddy/common/mb_app_bar_circle_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/features/journal/journal_canvas_layer.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';
import 'package:mind_buddy/features/journal/journal_drawing_canvas.dart';
import 'package:mind_buddy/features/journal/journal_folder_support.dart';
import 'package:mind_buddy/features/journal/journal_local_repository.dart';
import 'package:mind_buddy/features/journal/journal_page_codec.dart';
import 'package:mind_buddy/features/journal/journal_page_widgets.dart';
import 'package:mind_buddy/features/journal/journal_upload_pipeline.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'package:mind_buddy/features/journal/journal_sticker_catalog.dart';
import 'package:mind_buddy/services/journal_canvas_objects.dart';
import 'package:mind_buddy/services/journal_document_codec.dart';
import 'package:mind_buddy/services/journal_doodle_service.dart';

enum _LeaveJournalAction { cancel, leave, saveAndLeave }

class EditJournalScreen extends StatefulWidget {
  const EditJournalScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<EditJournalScreen> createState() => _EditJournalScreenState();
}

class _EditJournalScreenState extends State<EditJournalScreen> {
  static const double _appBarEdgePadding = 16;
  final quill.QuillController _qc = quill.QuillController.basic();
  final TextEditingController _titleController = TextEditingController();
  bool _loading = true;
  String? _loadError;
  static const String _mediaBucket = 'journal-media';
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  final Uuid _uuid = const Uuid();
  String? _selectedFont;
  Color? _selectedColor;
  Color? _selectedHighlightColor;
  bool _editorHasFocus = false;
  bool _boldEnabled = false;
  JournalLineSpacing _selectedLineSpacing = JournalLineSpacing.fallback;
  bool _lineSpacingMixed = false;
  bool _showFormatBar = false;
  List<JournalMediaItem> _media = const [];
  final Map<String, double> _uploadProgressByPath = {};
  final Set<String> _uploadFailedPaths = {};
  final Map<String, String> _compressedCacheByPath = {};
  final Set<Future<void>> _pendingUploads = {};
  bool _isPickingMedia = false;
  bool _showPickSpinner = false;
  Timer? _pickSpinnerTimer;
  bool _removeMediaMode = false;
  _RemovedEmbed? _lastRemoved;
  String? _savedShareId;
  bool _hasSavedChanges = false;
  String _lastSavedDraftSignature = '';
  bool _isExitDialogOpen = false;
  final GlobalKey _backButtonKey = GlobalKey();
  final GlobalKey _deletePageButtonKey = GlobalKey();
  final GlobalKey _undoButtonKey = GlobalKey();
  final GlobalKey _imageUploadButtonKey = GlobalKey();
  final GlobalKey _videoUploadButtonKey = GlobalKey();
  final GlobalKey _saveTickButtonKey = GlobalKey();
  final GlobalKey _overflowButtonKey = GlobalKey();
  final GlobalKey _formattingDropdownKey = GlobalKey();
  final GlobalKey _folderPickerKey = GlobalKey();
  final GlobalKey _drawingBoundaryKey = GlobalKey();
  List<JournalFolder> _folders = const <JournalFolder>[];
  String? _selectedFolderId;
  List<JournalCanvasObject> _canvasObjects = const <JournalCanvasObject>[];
  String? _selectedCanvasObjectId;
  bool _canvasEditMode = false;
  bool _drawMode = false;
  DrawingTool _activeTool = DrawingTool.pen;
  Color _drawColor = Colors.black;
  double _strokeWidth = 4;
  DoodleBackgroundStyle _doodleBgStyle = DoodleBackgroundStyle.none;
  double _doodleBgSpacing = 24;
  final List<DrawingStroke> _strokes = [];
  final List<DrawingStroke> _redoStrokes = [];
  DrawingStroke? _activeStroke;
  String? _doodleImageUrl;
  String? _doodleStoragePath;
  bool _hasUnsavedDoodleChanges = false;
  final JournalLocalRepository _journalLocalRepository =
      JournalLocalRepository();
  final PageController _pageController = PageController();
  List<JournalEntryPageData> _pages = const <JournalEntryPageData>[];
  int _currentPageIndex = 0;

  static const List<String> _fonts = ['sans-serif', 'serif', 'monospace'];
  static const List<Color> _colors = [
    Colors.red,
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Colors.orange,
    Color(0xFFF59E0B),
    Colors.yellow,
    Colors.green,
    Color(0xFF22C55E),
    Color(0xFF10B981),
    Color(0xFF14B8A6),
    Colors.blue,
    Color(0xFF0EA5E9),
    Color(0xFF2563EB),
    Colors.purple,
    Color(0xFF7C3AED),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Colors.black,
    Color(0xFF1F2937),
  ];
  static const List<Color> _highlightColors = [
    Color(0xFFFFF59D),
    Color(0xFFFFEB3B),
    Color(0xFFFFD54F),
    Color(0xFFFFCC80),
    Color(0xFFFFAB91),
    Color(0xFFFF8A80),
    Color(0xFFEF9A9A),
    Color(0xFFB9F6CA),
    Color(0xFFC5E1A5),
    Color(0xFFE6EE9C),
    Color(0xFF80CBC4),
    Color(0xFF80DEEA),
    Color(0xFFB3E5FC),
    Color(0xFF90CAF9),
    Color(0xFFC5CAE9),
    Color(0xFFD1C4E9),
    Color(0xFFE1BEE7),
    Color(0xFFF8BBD0),
    Color(0xFFF48FB1),
    Color(0xFFD7BDE2),
    Color(0xFFE0E0E0),
  ];

  @override
  void dispose() {
    _pickSpinnerTimer?.cancel();
    _qc.removeListener(_refreshMedia);
    _qc.removeListener(_refreshLineSpacingState);
    _qc.removeListener(_refreshInlineStyleState);
    _editorFocus.removeListener(_handleEditorFocusChanged);
    _qc.dispose();
    _editorFocus.dispose();
    _editorScrollController.dispose();
    _pageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _qc.addListener(_refreshMedia);
    _qc.addListener(_refreshLineSpacingState);
    _qc.addListener(_refreshInlineStyleState);
    _editorFocus.addListener(_handleEditorFocusChanged);
    _ensurePlainTypingDefaults();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGuideIfNeeded());
  }

  bool get _hasUnsavedChanges =>
      !_loading && _captureDraftSignature() != _lastSavedDraftSignature;

  String _captureDraftSignature() {
    final doodleState = <String, dynamic>{
      'storage_path': _doodleStoragePath,
      'bg_style': _bgStyleToString(_doodleBgStyle),
      'bg_spacing': _doodleBgSpacing,
      'strokes': _strokes.map(_serializeStroke).toList(),
      'active_stroke': _activeStroke == null
          ? null
          : _serializeStroke(_activeStroke!),
    };
    return jsonEncode(<String, dynamic>{
      'title': _titleController.text,
      'folder_id': _selectedFolderId,
      'pages': JournalPageCodec.encode(
        pages: _pagesForSave(),
        currentPageId: _currentPageId,
      ),
      'doodle': doodleState,
    });
  }

  String get _currentPageId => _pages[_currentPageIndex].id;

  List<JournalEntryPageData> _pagesForSave() {
    if (_pages.isEmpty) {
      return <JournalEntryPageData>[_buildBlankPage()];
    }
    return _pages
        .asMap()
        .entries
        .map(
          (entry) => entry.key == _currentPageIndex
              ? entry.value.copyWith(body: _encodeCurrentPageBody())
              : entry.value,
        )
        .toList(growable: false);
  }

  String _encodeCurrentPageBody() {
    return JournalDocumentCodec.encode(
      document: _qc.document,
      canvasObjects: _canvasObjects,
    );
  }

  JournalEntryPageData _buildBlankPage() {
    final document = quill.Document()..insert(0, '\n');
    return JournalEntryPageData(
      id: 'page-${_uuid.v4()}',
      body: JournalDocumentCodec.encode(document: document),
    );
  }

  void _loadPageIntoEditor(int index) {
    final page = _pages[index];
    final content = JournalDocumentCodec.decodeContent(page.body);
    _qc.document = content.document;
    _qc.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
    _canvasObjects = content.canvasObjects;
    _ensurePlainTypingDefaults();
  }

  void _persistCurrentPageDraft() {
    if (_pages.isEmpty) return;
    _pages = _pages
        .asMap()
        .entries
        .map(
          (entry) => entry.key == _currentPageIndex
              ? entry.value.copyWith(body: _encodeCurrentPageBody())
              : entry.value,
        )
        .toList(growable: false);
  }

  void _handlePageChanged(int index) {
    setState(() {
      _persistCurrentPageDraft();
      _currentPageIndex = index;
      _loadPageIntoEditor(index);
    });
  }

  Future<void> _addPage() async {
    setState(() {
      _persistCurrentPageDraft();
      final insertIndex = _currentPageIndex + 1;
      _pages = <JournalEntryPageData>[
        ..._pages.take(insertIndex),
        _buildBlankPage(),
        ..._pages.skip(insertIndex),
      ];
      _currentPageIndex = insertIndex;
      _loadPageIntoEditor(insertIndex);
    });
    await _pageController.animateToPage(
      _currentPageIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _deleteCurrentPage() async {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one page in this entry.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this page?'),
        content: const Text('This page will be removed from the entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final nextIndex = (_currentPageIndex == _pages.length - 1)
        ? _currentPageIndex - 1
        : _currentPageIndex;
    setState(() {
      _persistCurrentPageDraft();
      _pages = _pages
          .where((page) => page.id != _currentPageId)
          .toList(growable: false);
      _currentPageIndex = nextIndex.clamp(0, _pages.length - 1);
      _loadPageIntoEditor(_currentPageIndex);
    });
    _pageController.jumpToPage(_currentPageIndex);
  }

  void _toggleBookmarkPage() {
    setState(() {
      _persistCurrentPageDraft();
      final current = _pages[_currentPageIndex];
      _pages = _pages
          .asMap()
          .entries
          .map(
            (entry) => entry.key == _currentPageIndex
                ? current.copyWith(isBookmarked: !current.isBookmarked)
                : entry.value,
          )
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _serializeStroke(DrawingStroke stroke) {
    return <String, dynamic>{
      'points': stroke.points
          .map((point) => <double>[point.dx, point.dy])
          .toList(),
      'color': stroke.color.toARGB32(),
      'width': stroke.width,
      'tool': stroke.tool.name,
    };
  }

  Future<_LeaveJournalAction> _showLeaveDialog() async {
    final action = await showDialog<_LeaveJournalAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave without saving?'),
          content: const Text(
            'You have unsaved changes. If you leave now, your changes will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveJournalAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveJournalAction.leave),
              child: const Text('Leave'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_LeaveJournalAction.saveAndLeave),
              child: const Text('Save & leave'),
            ),
          ],
        );
      },
    );
    return action ?? _LeaveJournalAction.cancel;
  }

  void _exitScreen() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(_hasSavedChanges);
      return;
    }
    context.go('/journals');
  }

  Future<void> _handleExitRequest() async {
    if (_isExitDialogOpen) return;
    if (!_hasUnsavedChanges) {
      _exitScreen();
      return;
    }
    _isExitDialogOpen = true;
    final action = await _showLeaveDialog();
    _isExitDialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case _LeaveJournalAction.cancel:
        return;
      case _LeaveJournalAction.leave:
        _exitScreen();
        return;
      case _LeaveJournalAction.saveAndLeave:
        final saved = await _save();
        if (!mounted || !saved) return;
        _exitScreen();
        return;
    }
  }

  Future<bool> _handleWillPop() async {
    await _handleExitRequest();
    return false;
  }

  void _handleEditorFocusChanged() {
    if (!mounted || _editorHasFocus == _editorFocus.hasFocus) return;
    setState(() => _editorHasFocus = _editorFocus.hasFocus);
  }

  Color _withOpacity(Color color, double opacity) {
    return color.withAlpha((255 * opacity).round().clamp(0, 255));
  }

  BoxDecoration _journalCanvasDecoration(ColorScheme colorScheme) {
    final accent = colorScheme.primary;
    final isActive = _editorHasFocus || _drawMode;
    return BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: _withOpacity(accent, isActive ? 0.34 : 0.2),
        width: isActive ? 1.5 : 1.15,
      ),
      boxShadow: [
        BoxShadow(
          color: _withOpacity(accent, isActive ? 0.18 : 0.1),
          blurRadius: isActive ? 26 : 18,
          spreadRadius: isActive ? 2.5 : 1.2,
        ),
        BoxShadow(
          color: _withOpacity(accent, isActive ? 0.09 : 0.05),
          blurRadius: isActive ? 48 : 34,
          spreadRadius: isActive ? 4.5 : 2.2,
        ),
      ],
    );
  }

  int get _nextCanvasObjectZIndex {
    var maxZ = -1;
    for (final object in _canvasObjects) {
      if (object.zIndex > maxZ) maxZ = object.zIndex;
    }
    return maxZ + 1;
  }

  Offset _defaultCanvasPlacement({
    required double width,
    required double height,
  }) {
    final slot = _canvasObjects.length % 5;
    final dx = 0.12 + (slot * 0.045);
    final dy = 0.12 + (slot * 0.04);
    return Offset(
      dx.clamp(0.04, 1 - width - 0.04),
      dy.clamp(0.04, 1 - height - 0.04),
    );
  }

  void _selectCanvasObject(String? objectId) {
    if (objectId == null) {
      setState(() => _selectedCanvasObjectId = null);
      return;
    }
    final elevated = _canvasObjects.map((object) {
      if (object.id != objectId) return object;
      return object.copyWith(zIndex: _nextCanvasObjectZIndex);
    }).toList()..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    setState(() {
      _canvasObjects = elevated;
      _selectedCanvasObjectId = objectId;
      _canvasEditMode = true;
      _drawMode = false;
    });
  }

  void _updateCanvasObject(JournalCanvasObject updated) {
    final next = _canvasObjects.map((object) {
      return object.id == updated.id ? updated : object;
    }).toList()..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    setState(() => _canvasObjects = next);
  }

  void _deleteCanvasObject(String objectId) {
    JournalCanvasObject? removed;
    for (final object in _canvasObjects) {
      if (object.id == objectId) {
        removed = object;
        break;
      }
    }
    final removedPath = removed?.path;
    if (removedPath != null && removedPath.isNotEmpty) {
      _uploadProgressByPath.remove(removedPath);
      _uploadFailedPaths.remove(removedPath);
    }
    setState(() {
      _canvasObjects = _canvasObjects
          .where((object) => object.id != objectId)
          .toList();
      if (_selectedCanvasObjectId == objectId) {
        _selectedCanvasObjectId = null;
      }
      if (_canvasObjects.isEmpty) {
        _canvasEditMode = false;
      }
    });
  }

  void _toggleCanvasEditMode() {
    setState(() {
      _canvasEditMode = !_canvasEditMode;
      if (_canvasEditMode) {
        _drawMode = false;
      } else {
        _selectedCanvasObjectId = null;
      }
    });
  }

  JournalCanvasObject _buildCanvasMediaObject({
    required JournalCanvasObjectType type,
    required String localPath,
  }) {
    const width = 0.34;
    const height = 0.24;
    final placement = _defaultCanvasPlacement(width: width, height: height);
    return JournalCanvasObject(
      id: _uuid.v4(),
      type: type,
      x: placement.dx,
      y: placement.dy,
      width: width,
      height: height,
      rotation: 0,
      zIndex: _nextCanvasObjectZIndex,
      path: localPath,
      bucket: _mediaBucket,
    );
  }

  JournalCanvasObject _buildStickerObject(JournalStickerDefinition sticker) {
    const size = 0.22;
    final placement = _defaultCanvasPlacement(width: size, height: size);
    return JournalCanvasObject(
      id: _uuid.v4(),
      type: JournalCanvasObjectType.sticker,
      x: placement.dx,
      y: placement.dy,
      width: size,
      height: size,
      rotation: 0,
      zIndex: _nextCanvasObjectZIndex,
      stickerId: sticker.id,
      stickerPackId: JournalStickerCatalog.starterPackId,
    );
  }

  void _addCanvasObject(JournalCanvasObject object) {
    setState(() {
      _canvasObjects = [..._canvasObjects, object]
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      _selectedCanvasObjectId = object.id;
      _canvasEditMode = true;
      _drawMode = false;
    });
  }

  void _replaceCanvasObjectSource({
    required String objectId,
    required String remotePath,
  }) {
    JournalCanvasObject? match;
    for (final object in _canvasObjects) {
      if (object.id == objectId) {
        match = object;
        break;
      }
    }
    if (match == null) return;
    _updateCanvasObject(
      match.copyWith(path: remotePath, bucket: _mediaBucket, clearUrl: true),
    );
  }

  Future<void> _insertSticker() async {
    final selected = await showModalBottomSheet<JournalStickerDefinition>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sticker drawer',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Soft scrapbook stickers for journals now, with room to grow into custom packs later.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.92,
                        ),
                    itemCount: JournalStickerCatalog.starterPack.length,
                    itemBuilder: (context, index) {
                      final sticker = JournalStickerCatalog.starterPack[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(sheetContext).pop(sticker),
                        child: JournalStickerArt(
                          definition: sticker,
                          showLabel: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    _addCanvasObject(_buildStickerObject(selected));
  }

  Future<void> _loadFolders() async {
    final folders = await JournalFolderSupport.fetchFolders();
    if (!mounted) return;
    setState(() => _folders = folders);
  }

  String get _selectedFolderLabel {
    if (_selectedFolderId == null) return 'No folder';
    for (final folder in _folders) {
      if (folder.id == _selectedFolderId) {
        return folder.name;
      }
    }
    return 'No folder';
  }

  Future<void> _pickFolder() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('No folder'),
                trailing: _selectedFolderId == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, null),
              ),
              for (final folder in _folders)
                ListTile(
                  leading: Icon(
                    JournalFolderSupport.styleFor(folder.iconStyle).icon,
                    color: JournalFolderSupport.paletteFor(
                      folder.colorKey,
                    ).color,
                  ),
                  title: Text(folder.name),
                  trailing: _selectedFolderId == folder.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, folder.id),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => _selectedFolderId = selected);
  }

  Future<void> _showGuideIfNeeded({bool force = false}) async {
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'journalEntry',
      force: force,
      steps: [
        GuideStep(
          key: _backButtonKey,
          title: 'Floating back?',
          body: 'Use back to return to your journal list.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _undoButtonKey,
          title: 'Oops?',
          body: 'Undo your last change anytime.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _imageUploadButtonKey,
          title: 'Add a memory',
          body: 'Upload photos or videos to bring your page to life.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _formattingDropdownKey,
          title: 'Make it yours',
          body: 'Open formatting to style your words.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _saveTickButtonKey,
          title: 'Seal the bubble',
          body: 'Tap the tick to save your entry safely.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _deletePageButtonKey,
          title: 'Ready to release it?',
          body: 'Use the bin to permanently delete this page.',
          align: GuideAlign.bottom,
        ),
      ],
    );
  }

  void _refreshMedia() {
    final items = extractMediaFromController(_qc);
    if (listEquals(items, _media)) return;
    setState(() => _media = items);
  }

  void _toggleRemoveMediaMode() {
    setState(() => _removeMediaMode = !_removeMediaMode);
  }

  int get _activeUploads =>
      _uploadProgressByPath.values.where((v) => v >= 0 && v < 1).length;

  void _startPickIndicator() {
    _pickSpinnerTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPickingMedia = true;
        _showPickSpinner = false;
      });
    } else {
      _isPickingMedia = true;
      _showPickSpinner = false;
    }
    _pickSpinnerTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_isPickingMedia) return;
      setState(() => _showPickSpinner = true);
    });
  }

  void _stopPickIndicator() {
    _pickSpinnerTimer?.cancel();
    _pickSpinnerTimer = null;
    if (mounted) {
      setState(() {
        _isPickingMedia = false;
        _showPickSpinner = false;
      });
    } else {
      _isPickingMedia = false;
      _showPickSpinner = false;
    }
  }

  void _trackPendingUpload(Future<void> task) {
    _pendingUploads.add(task);
    task.whenComplete(() => _pendingUploads.remove(task));
  }

  String _filenameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? 'file.bin' : parts.last;
  }

  String? _findCurrentEmbedPayload({
    required String type,
    required String localPath,
  }) {
    final delta = _qc.document.toDelta().toJson();
    for (final op in delta) {
      if (op['insert'] is! Map) continue;
      final insert = Map<String, dynamic>.from(op['insert'] as Map);
      final rawPayload = insert[type]?.toString();
      if (rawPayload == null || rawPayload.isEmpty) continue;
      final parsed = _parseEmbedPayload(rawPayload);
      if (parsed.path == localPath || parsed.url == localPath) {
        return rawPayload;
      }
    }
    return null;
  }

  _EmbedPayload _parseEmbedPayload(String data) {
    if (data.isEmpty) return const _EmbedPayload();
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        return _EmbedPayload(
          url: map['url']?.toString(),
          path: map['path']?.toString(),
        );
      }
    } catch (_) {}
    return _EmbedPayload(url: data, path: data);
  }

  bool _embedMatchesItem({
    required String embedType,
    required String payload,
    required JournalMediaItem item,
  }) {
    if (embedType != item.type) return false;
    final parsed = _parseEmbedPayload(payload);
    final candidates = <String>{
      if (parsed.url != null) parsed.url!,
      if (parsed.path != null) parsed.path!,
    };
    if (item.url != null) candidates.add(item.url!);
    if (item.path != null) candidates.add(item.path!);
    return candidates.isNotEmpty &&
        ((item.url != null && candidates.contains(item.url!)) ||
            (item.path != null && candidates.contains(item.path!)));
  }

  void _removeMediaAtIndex(int mediaIndex) {
    final delta = _qc.document.toDelta().toJson();
    int offset = 0;
    int mediaCounter = 0;
    _RemovedEmbed? target;

    for (final op in delta) {
      if (op['insert'] is Map) {
        final insert = Map<String, dynamic>.from(op['insert'] as Map);
        if (insert.containsKey('image')) {
          final payload = insert['image']?.toString() ?? '';
          if (mediaCounter == mediaIndex) {
            target = _RemovedEmbed(
              type: 'image',
              payload: payload,
              offset: offset,
            );
            break;
          }
          mediaCounter += 1;
          offset += 1;
          continue;
        }
        if (insert.containsKey('video')) {
          final payload = insert['video']?.toString() ?? '';
          if (mediaCounter == mediaIndex) {
            target = _RemovedEmbed(
              type: 'video',
              payload: payload,
              offset: offset,
            );
            break;
          }
          mediaCounter += 1;
          offset += 1;
          continue;
        }
      }

      final insert = (op is Map) ? op['insert'] : null;
      if (insert is String) {
        offset += insert.length;
      } else if (insert != null) {
        offset += 1;
      }
    }

    if (target == null) return;
    _qc.document.delete(target.offset, 1);
    _lastRemoved = target;
    final newOffset = target.offset.clamp(0, _qc.document.length - 1);
    _qc.updateSelection(
      TextSelection.collapsed(offset: newOffset),
      quill.ChangeSource.local,
    );
  }

  Future<void> _confirmRemove(int mediaIndex) async {
    if (!mounted) return;
    if (mediaIndex < 0 || mediaIndex >= _media.length) return;
    final item = _media[mediaIndex];
    final label = item.type == 'video' ? 'video' : 'photo';
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $label?'),
        content: const Text('You can undo this right after removing it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      _removeMediaAtIndex(mediaIndex);
      if (!mounted || _lastRemoved == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${label[0].toUpperCase()}${label.substring(1)} removed',
          ),
          action: SnackBarAction(label: 'Undo', onPressed: _undoLastRemove),
        ),
      );
    }
  }

  void _undoLastRemove() {
    final removed = _lastRemoved;
    if (removed == null) return;
    final offset = removed.offset.clamp(0, _qc.document.length);
    if (removed.type == 'image') {
      _qc.document.insert(offset, quill.BlockEmbed.image(removed.payload));
    } else {
      _qc.document.insert(offset, quill.BlockEmbed.video(removed.payload));
    }
    _qc.updateSelection(
      TextSelection.collapsed(offset: offset + 1),
      quill.ChangeSource.local,
    );
    _lastRemoved = null;
  }

  Future<void> _load() async {
    unawaited(_loadFolders());
    try {
      final row = await _journalLocalRepository.loadJournalForEditor(
        widget.journalId,
      );

      if (row != null) {
        final title = (row['title'] as String?) ?? '';
        final raw = row['text']?.toString() ?? '';
        _titleController.text = title;
        _selectedFolderId = row['folder_id']?.toString();
        _savedShareId = row['share_id']?.toString();
        final pagesData = JournalPageCodec.decode(raw);
        _pages = pagesData.pages.isEmpty
            ? <JournalEntryPageData>[_buildBlankPage()]
            : pagesData.pages;
        final restoredIndex = pagesData.currentPageId == null
            ? 0
            : _pages.indexWhere((page) => page.id == pagesData.currentPageId);
        _currentPageIndex = restoredIndex >= 0 ? restoredIndex : 0;
        _loadPageIntoEditor(_currentPageIndex);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(_currentPageIndex);
        });
        _lastSavedDraftSignature = _captureDraftSignature();
      }
    } catch (error) {
      _loadError = 'Unable to open this journal right now: $error';
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _insertImage() async {
    if (_activeUploads > 0 || _isPickingMedia) return;
    final picker = ImagePicker();
    _startPickIndicator();
    List<XFile> images = const [];
    try {
      images = await picker.pickMultiImage();
    } finally {
      _stopPickIndicator();
    }
    if (images.isEmpty) return;

    final tasks = <Future<void>>[];
    for (final image in images) {
      final object = _buildCanvasMediaObject(
        type: JournalCanvasObjectType.image,
        localPath: image.path,
      );
      _addCanvasObject(object);
      _uploadProgressByPath[image.path] = 0.03;
      _uploadFailedPaths.remove(image.path);
      if (mounted) setState(() {});
      tasks.add(_uploadImageInBackground(image: image, objectId: object.id));
    }
    if (mounted) setState(() {});
    _trackPendingUpload(Future.wait(tasks));
  }

  Future<void> _uploadImageInBackground({
    required XFile image,
    String? objectId,
    String? localPayload,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    PreparedJournalImage? prepared;
    Uint8List? uploadBytes;
    String extension = JournalUploadPipeline.extensionFromFilename(
      image.name,
      fallback: 'jpg',
    );
    String contentType = JournalUploadPipeline.contentTypeFromExtension(
      extension,
    );

    try {
      final ext = JournalUploadPipeline.extensionFromFilename(image.name);
      if (!JournalUploadPipeline.isSupportedImageExtension(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported image type: .$ext')),
          );
        }
        _uploadFailedPaths.add(image.path);
        _uploadProgressByPath.remove(image.path);
        if (mounted) setState(() {});
        return;
      }

      _uploadProgressByPath[image.path] = 0.2;
      if (mounted) setState(() {});

      // Compression is optional: if plugin is unavailable, continue with original bytes.
      try {
        prepared = await JournalUploadPipeline.prepareImageForUpload(
          File(image.path),
          image.name,
        );
      } on MissingPluginException catch (_) {
        prepared = null;
      } catch (_) {
        prepared = null;
      }

      if (prepared != null) {
        _compressedCacheByPath[image.path] = prepared.cachedPath;
        uploadBytes = prepared.bytes;
        extension = prepared.extension;
        contentType = prepared.contentType;
      } else {
        uploadBytes = await File(image.path).readAsBytes();
      }

      if (uploadBytes.isEmpty) {
        _uploadFailedPaths.add(image.path);
        _uploadProgressByPath.remove(image.path);
        if (mounted) setState(() {});
        return;
      }

      _uploadProgressByPath[image.path] = 0.45;
      if (mounted) setState(() {});

      final storagePath =
          '${user.id}/images/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}.$extension';
      _uploadProgressByPath[image.path] = 0.75;
      if (mounted) setState(() {});

      try {
        await JournalUploadPipeline.uploadBinaryWithRetry(
          bucket: _mediaBucket,
          path: storagePath,
          bytes: uploadBytes,
          contentType: contentType,
        );
      } catch (e) {
        _uploadFailedPaths.add(image.path);
        _uploadProgressByPath.remove(image.path);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
        }
        return;
      }

      if (objectId != null) {
        _replaceCanvasObjectSource(objectId: objectId, remotePath: storagePath);
      } else if (localPayload != null) {
        _replaceEmbedPayload(
          type: 'image',
          oldPayload: localPayload,
          newPayload: jsonEncode({'bucket': _mediaBucket, 'path': storagePath}),
        );
      }

      _uploadProgressByPath[image.path] = 1.0;
      _uploadFailedPaths.remove(image.path);
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 500));
      _uploadProgressByPath.remove(image.path);
    } catch (_) {
      _uploadFailedPaths.add(image.path);
      _uploadProgressByPath.remove(image.path);
      if (mounted) setState(() {});
    } finally {
      final cachePath = _compressedCacheByPath.remove(image.path);
      if (cachePath != null) {
        final cached = File(cachePath);
        if (await cached.exists()) {
          await cached.delete();
        }
      }
      if (mounted) setState(() {});
    }
  }

  void _replaceEmbedPayload({
    required String type,
    required String oldPayload,
    required String newPayload,
  }) {
    final delta = _qc.document.toDelta().toJson();
    final patched = <Map<String, dynamic>>[];
    var replaced = false;

    for (final raw in delta) {
      final op = Map<String, dynamic>.from(raw);
      if (!replaced && op['insert'] is Map) {
        final insert = Map<String, dynamic>.from(op['insert'] as Map);
        if (insert[type]?.toString() == oldPayload) {
          insert[type] = newPayload;
          op['insert'] = insert;
          replaced = true;
        }
      }
      patched.add(op);
    }

    if (!replaced) return;
    final currentOffset = _qc.selection.baseOffset.clamp(
      0,
      _qc.document.length,
    );
    _qc.document = quill.Document.fromJson(patched);
    _qc.updateSelection(
      TextSelection.collapsed(offset: currentOffset),
      quill.ChangeSource.local,
    );
  }

  Future<void> _insertVideo() async {
    if (_activeUploads > 0 || _isPickingMedia) return;
    _startPickIndicator();
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'm4v'],
      );
    } finally {
      _stopPickIndicator();
    }
    if (res == null || res.files.single.path == null) return;

    final path = res.files.single.path!;
    final object = _buildCanvasMediaObject(
      type: JournalCanvasObjectType.video,
      localPath: path,
    );
    _addCanvasObject(object);

    _uploadProgressByPath[path] = 0.03;
    _uploadFailedPaths.remove(path);
    if (mounted) setState(() {});

    final task = _uploadVideoInBackground(
      localPath: path,
      filename: res.files.single.name,
      objectId: object.id,
    );
    _trackPendingUpload(task);
  }

  Future<void> _insertGif() async {
    if (_activeUploads > 0 || _isPickingMedia) return;
    _startPickIndicator();
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gif'],
      );
    } finally {
      _stopPickIndicator();
    }
    if (res == null || res.files.single.path == null) return;

    final path = res.files.single.path!;
    final object = _buildCanvasMediaObject(
      type: JournalCanvasObjectType.gif,
      localPath: path,
    );
    _addCanvasObject(object);
    _uploadProgressByPath[path] = 0.03;
    _uploadFailedPaths.remove(path);
    if (mounted) setState(() {});

    final task = _uploadGifInBackground(
      localPath: path,
      filename: res.files.single.name,
      objectId: object.id,
    );
    _trackPendingUpload(task);
  }

  Future<void> _uploadVideoInBackground({
    required String localPath,
    required String filename,
    String? objectId,
    String? localPayload,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final ext = JournalUploadPipeline.extensionFromFilename(
        filename,
        fallback: 'mp4',
      );
      _uploadProgressByPath[localPath] = 0.35;
      if (mounted) setState(() {});

      final bytes = await File(localPath).readAsBytes();
      final storagePath =
          '${user.id}/videos/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}.$ext';
      _uploadProgressByPath[localPath] = 0.75;
      if (mounted) setState(() {});

      await JournalUploadPipeline.uploadBinaryWithRetry(
        bucket: _mediaBucket,
        path: storagePath,
        bytes: bytes,
        contentType: JournalUploadPipeline.contentTypeFromExtension(ext),
      );

      if (objectId != null) {
        _replaceCanvasObjectSource(objectId: objectId, remotePath: storagePath);
      } else if (localPayload != null) {
        _replaceEmbedPayload(
          type: 'video',
          oldPayload: localPayload,
          newPayload: jsonEncode({'bucket': _mediaBucket, 'path': storagePath}),
        );
      }

      _uploadProgressByPath[localPath] = 1.0;
      _uploadFailedPaths.remove(localPath);
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 500));
      _uploadProgressByPath.remove(localPath);
    } catch (e) {
      _uploadFailedPaths.add(localPath);
      _uploadProgressByPath.remove(localPath);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Video upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _uploadGifInBackground({
    required String localPath,
    required String filename,
    required String objectId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      _uploadProgressByPath[localPath] = 0.35;
      if (mounted) setState(() {});
      final bytes = await File(localPath).readAsBytes();
      final storagePath =
          '${user.id}/gifs/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}.gif';
      _uploadProgressByPath[localPath] = 0.75;
      if (mounted) setState(() {});

      await JournalUploadPipeline.uploadBinaryWithRetry(
        bucket: _mediaBucket,
        path: storagePath,
        bytes: bytes,
        contentType: 'image/gif',
      );
      _replaceCanvasObjectSource(objectId: objectId, remotePath: storagePath);
      _uploadProgressByPath[localPath] = 1.0;
      _uploadFailedPaths.remove(localPath);
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 500));
      _uploadProgressByPath.remove(localPath);
    } catch (e) {
      _uploadFailedPaths.add(localPath);
      _uploadProgressByPath.remove(localPath);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('GIF upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _retryFailedUpload(JournalMediaItem item) async {
    final localPath = item.path;
    if (localPath == null || localPath.isEmpty) return;
    if (_activeUploads > 0) return;
    final payload = _findCurrentEmbedPayload(
      type: item.type,
      localPath: localPath,
    );
    if (payload == null) return;

    _uploadFailedPaths.remove(localPath);
    _uploadProgressByPath[localPath] = 0.03;
    if (mounted) setState(() {});

    late final Future<void> task;
    if (item.type == 'image') {
      task = _uploadImageInBackground(
        image: XFile(localPath, name: _filenameFromPath(localPath)),
        localPayload: payload,
      );
    } else {
      task = _uploadVideoInBackground(
        localPath: localPath,
        filename: _filenameFromPath(localPath),
        localPayload: payload,
      );
    }
    _trackPendingUpload(task);
  }

  void _removeEmbedAtCursor() {
    final selection = _qc.selection;
    if (!selection.isValid) return;

    final candidates = <int>[selection.baseOffset, selection.baseOffset - 1];
    for (final offset in candidates) {
      if (offset < 0) continue;
      final segment = _qc.document.querySegmentLeafNode(offset);
      final node = segment.leaf;
      if (node is quill.Embed) {
        _qc.document.delete(offset, 1);
        _qc.updateSelection(
          TextSelection.collapsed(offset: offset),
          quill.ChangeSource.local,
        );
        return;
      }
    }
  }

  void _applyFont(String? font) {
    _editorFocus.requestFocus();
    setState(() => _selectedFont = font);
    if (font == null) {
      _qc.formatSelection(quill.Attribute.font);
      return;
    }
    final attr = quill.Attribute.fromKeyValue('font', font);
    if (attr != null) _qc.formatSelection(attr);
  }

  void _applyColor(Color? color) {
    _editorFocus.requestFocus();
    setState(() => _selectedColor = color);
    if (color == null) {
      _qc.formatSelection(quill.Attribute.color);
      return;
    }
    final hex = _colorToHex(color);
    final attr = quill.Attribute.fromKeyValue('color', hex);
    if (attr != null) _qc.formatSelection(attr);
  }

  void _applyHighlight(Color? color) {
    _editorFocus.requestFocus();
    setState(() => _selectedHighlightColor = color);
    if (color == null) {
      _qc.formatSelection(quill.Attribute.background);
      return;
    }
    final hex = _colorToHex(color);
    final attr = quill.Attribute.fromKeyValue('background', hex);
    if (attr != null) _qc.formatSelection(attr);
  }

  bool get _isBoldActive =>
      _qc.getSelectionStyle().attributes.containsKey(quill.Attribute.bold.key);

  void _toggleBold() {
    _editorFocus.requestFocus();
    final next = _isBoldActive
        ? quill.Attribute.clone(quill.Attribute.bold, null)
        : quill.Attribute.bold;
    _qc.formatSelection(next);
    _refreshInlineStyleState();
  }

  void _refreshInlineStyleState() {
    final next = _isBoldActive;
    final attrs = _qc.getSelectionStyle().attributes;
    final nextColor = _colorFromAttributeValue(
      attrs[quill.Attribute.color.key],
    );
    final nextHighlight = _colorFromAttributeValue(
      attrs[quill.Attribute.background.key],
    );
    if (!mounted) {
      _boldEnabled = next;
      _selectedColor = nextColor;
      _selectedHighlightColor = nextHighlight;
      return;
    }
    if (_boldEnabled != next ||
        _selectedColor != nextColor ||
        _selectedHighlightColor != nextHighlight) {
      setState(() {
        _boldEnabled = next;
        _selectedColor = nextColor;
        _selectedHighlightColor = nextHighlight;
      });
    }
  }

  void _ensurePlainTypingDefaults() {
    if (_isBoldActive) {
      _qc.formatSelection(quill.Attribute.clone(quill.Attribute.bold, null));
    }
    _refreshInlineStyleState();
  }

  String? get _activeListValue => _qc
      .getSelectionStyle()
      .attributes[quill.Attribute.list.key]
      ?.value
      ?.toString();

  bool _isListActive(String listValue) => _activeListValue == listValue;

  bool get _isChecklistActive {
    final value = _activeListValue;
    return value == quill.Attribute.checked.value ||
        value == quill.Attribute.unchecked.value;
  }

  void _toggleList(quill.Attribute<String?> attribute) {
    _editorFocus.requestFocus();
    final current = _activeListValue;
    final target = attribute.value;
    if (target == null) return;
    final next =
        current == target ||
            (_isChecklistActive &&
                (target == quill.Attribute.checked.value ||
                    target == quill.Attribute.unchecked.value))
        ? quill.Attribute.clone(quill.Attribute.list, null)
        : attribute;
    _qc.formatSelection(next);
    setState(() {});
  }

  Future<void> _pickLineSpacing() async {
    final selected = await showModalBottomSheet<JournalLineSpacing>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in JournalLineSpacing.values)
              ListTile(
                title: Text(option.label),
                trailing: !_lineSpacingMixed && option == _selectedLineSpacing
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    _qc.formatSelection(selected.attribute);
    _editorFocus.requestFocus();
  }

  void _refreshLineSpacingState() {
    final spacings = _selectedParagraphLineSpacings();
    final nextMixed = spacings.length > 1;
    final nextSpacing = spacings.isEmpty
        ? JournalLineSpacing.fallback
        : (nextMixed ? JournalLineSpacing.fallback : spacings.first);
    if (!mounted) {
      _lineSpacingMixed = nextMixed;
      _selectedLineSpacing = nextSpacing;
      return;
    }
    setState(() {
      _lineSpacingMixed = nextMixed;
      _selectedLineSpacing = nextSpacing;
    });
  }

  Set<JournalLineSpacing> _selectedParagraphLineSpacings() {
    final selection = _qc.selection;
    final documentLength = _qc.document.length;
    if (documentLength <= 0) return {JournalLineSpacing.fallback};

    final start = selection.start.clamp(0, documentLength - 1);
    final end = selection.isCollapsed
        ? start
        : (selection.end > start ? selection.end - 1 : start);

    final spacings = <JournalLineSpacing>{};
    final delta = _qc.document.toDelta().toJson();
    var offset = 0;
    var lineStart = 0;

    for (final rawOp in delta) {
      final op = Map<String, dynamic>.from(rawOp);
      final insert = op['insert'];
      if (insert is String) {
        final attrs = op['attributes'] is Map
            ? Map<String, dynamic>.from(op['attributes'] as Map)
            : const <String, dynamic>{};
        for (var i = 0; i < insert.length; i++) {
          if (insert[i] == '\n') {
            final lineEnd = offset;
            if (lineEnd >= start && lineStart <= end) {
              spacings.add(
                JournalLineSpacing.fromLineHeightValue(attrs['line-height']),
              );
            }
            lineStart = offset + 1;
          }
          offset += 1;
        }
      } else {
        offset += 1;
      }
    }

    return spacings.isEmpty ? {JournalLineSpacing.fallback} : spacings;
  }

  String _colorToHex(Color color) {
    final value = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${value.substring(2)}';
  }

  Color? _colorFromAttributeValue(dynamic attribute) {
    final value = switch (attribute) {
      quill.Attribute<dynamic> attr => attr.value,
      _ => attribute,
    };
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final hex = raw.startsWith('#') ? raw.substring(1) : raw;
    if (hex.length != 6 && hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return hex.length == 6 ? Color(0xFF000000 | parsed) : Color(parsed);
  }

  String _bgStyleLabel(DoodleBackgroundStyle style) {
    switch (style) {
      case DoodleBackgroundStyle.none:
        return 'None';
      case DoodleBackgroundStyle.dots:
        return 'Dots';
      case DoodleBackgroundStyle.lines:
        return 'Lines';
      case DoodleBackgroundStyle.grid:
        return 'Grid';
    }
  }

  String _bgStyleToString(DoodleBackgroundStyle style) {
    return style.name;
  }

  DoodleBackgroundStyle _bgStyleFromString(String value) {
    return DoodleBackgroundStyle.values.firstWhere(
      (style) => style.name == value,
      orElse: () => DoodleBackgroundStyle.none,
    );
  }

  Future<void> _openShareForSavedEntry() async {
    await context.push('/journals/view/${widget.journalId}');
  }

  void _toggleDrawMode() {
    final willEnable = !_drawMode;
    if (willEnable) {
      _editorFocus.unfocus();
    }
    setState(() {
      _drawMode = willEnable;
      if (willEnable) {
        _canvasEditMode = false;
        _selectedCanvasObjectId = null;
      }
    });
    if (!willEnable) {
      unawaited(_saveDoodleIfPossible(showSuccessMessage: false));
    }
  }

  Future<void> _pickDoodleBackground() async {
    var selectedStyle = _doodleBgStyle;
    var spacing = _doodleBgSpacing;
    final selected = await showModalBottomSheet<DoodleBackgroundStyle>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        const options = DoodleBackgroundStyle.values;
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...options.map(
                    (style) => ListTile(
                      title: Text(_bgStyleLabel(style)),
                      trailing: style == selectedStyle
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => setSheetState(() => selectedStyle = style),
                    ),
                  ),
                  Row(
                    children: [
                      const Text('Spacing'),
                      Expanded(
                        child: Slider(
                          min: 12,
                          max: 48,
                          value: spacing,
                          onChanged: (value) =>
                              setSheetState(() => spacing = value),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(selectedStyle),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      _doodleBgStyle = selected;
      _doodleBgSpacing = spacing;
      _hasUnsavedDoodleChanges = true;
    });
  }

  Future<void> _pickDrawColor() async {
    var tempColor = _drawColor;
    final shouldApply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: tempColor,
                  onColorChanged: (value) => tempColor = value,
                  enableAlpha: false,
                  pickerAreaHeightPercent: 0.55,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  labelTypes: const [],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Use Color'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldApply == true) {
      setState(() => _drawColor = tempColor);
    }
  }

  Future<void> _refreshDoodleFromDb() async {
    if (JournalDoodleService.isLocalPrivateJournalId(widget.journalId)) {
      debugPrint(
        'JOURNAL_PRIVATE_DOODLE_REMOTE_BLOCKED id=${widget.journalId}',
      );
      return;
    }
    final doodle = await JournalDoodleService.fetchDoodle(widget.journalId);
    if (!mounted) return;
    setState(() {
      _doodleStoragePath = doodle.storagePath;
      _doodleImageUrl = doodle.previewUrl;
      if (doodle.bgStyle != null) {
        _doodleBgStyle = _bgStyleFromString(doodle.bgStyle!);
      }
    });
  }

  void _startStroke(Offset point) {
    final tool = _activeTool;
    final color = tool == DrawingTool.eraser ? Colors.transparent : _drawColor;
    setState(() {
      _activeStroke = DrawingStroke(
        points: [point],
        color: color,
        width: _strokeWidth,
        tool: tool,
      );
      _redoStrokes.clear();
      _hasUnsavedDoodleChanges = true;
    });
  }

  void _appendStrokePoint(Offset point) {
    final active = _activeStroke;
    if (active == null) return;
    setState(() => active.points.add(point));
  }

  void _endStroke() {
    final active = _activeStroke;
    if (active == null) return;
    setState(() {
      _strokes.add(active);
      _activeStroke = null;
    });
  }

  void _undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() {
      _redoStrokes.add(_strokes.removeLast());
      _hasUnsavedDoodleChanges = true;
    });
  }

  void _redoStroke() {
    if (_redoStrokes.isEmpty) return;
    setState(() {
      _strokes.add(_redoStrokes.removeLast());
      _hasUnsavedDoodleChanges = true;
    });
  }

  void _clearDoodleSession() {
    setState(() {
      _strokes.clear();
      _redoStrokes.clear();
      _activeStroke = null;
      _doodleImageUrl = null;
      _doodleStoragePath = null;
      _hasUnsavedDoodleChanges = true;
    });
  }

  Future<Uint8List?> _captureDoodlePngBytes() async {
    final boundary =
        _drawingBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ratio = View.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: ratio.clamp(1, 3));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<bool> _saveDoodleIfPossible({bool showSuccessMessage = true}) async {
    if (JournalDoodleService.isLocalPrivateJournalId(widget.journalId)) {
      debugPrint(
        'JOURNAL_PRIVATE_DOODLE_REMOTE_BLOCKED id=${widget.journalId}',
      );
      if (!mounted) return true;
      setState(() => _hasUnsavedDoodleChanges = false);
      return true;
    }
    try {
      if (_strokes.isEmpty && _doodleStoragePath == null) {
        await JournalDoodleService.clearDoodle(widget.journalId);
        if (!mounted) return false;
        setState(() {
          _doodleImageUrl = null;
          _doodleStoragePath = null;
          _hasUnsavedDoodleChanges = false;
        });
        if (showSuccessMessage) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Doodle cleared')));
        }
        return true;
      }

      final bytes = await _captureDoodlePngBytes();
      if (bytes == null) return false;
      await JournalDoodleService.saveDoodle(
        journalEntryId: widget.journalId,
        pngBytes: bytes,
        bgStyle: _bgStyleToString(_doodleBgStyle),
      );
      final doodle = await JournalDoodleService.fetchDoodle(widget.journalId);
      if (doodle.storagePath == null || doodle.storagePath!.isEmpty) {
        throw Exception('Doodle save failed: storage path was not persisted.');
      }
      if (doodle.previewUrl == null || doodle.previewUrl!.isEmpty) {
        throw Exception('Doodle save failed: could not resolve preview URL.');
      }
      if (!mounted) return false;
      setState(() {
        _doodleStoragePath = doodle.storagePath;
        _doodleImageUrl = doodle.previewUrl;
        _doodleBgStyle = _bgStyleFromString(doodle.bgStyle ?? 'none');
        _strokes.clear();
        _redoStrokes.clear();
        _activeStroke = null;
        _hasUnsavedDoodleChanges = false;
      });
      if (showSuccessMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Doodle saved')));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Doodle save failed: $e')));
      return false;
    }
  }

  Future<String?> _uploadMedia(
    File file,
    String filename, {
    required String folder,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final ext = filename.contains('.') ? filename.split('.').last : 'bin';
    final path =
        '${user.id}/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext';

    try {
      final bytes = await file.readAsBytes();
      await JournalUploadPipeline.uploadBinaryWithRetry(
        bucket: _mediaBucket,
        path: path,
        bytes: bytes,
        contentType: JournalUploadPipeline.contentTypeFromExtension(ext),
      );

      return jsonEncode({'bucket': _mediaBucket, 'path': path});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
      return null;
    }
  }

  Future<bool> _save() async {
    if (_pendingUploads.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finishing media uploads...')),
        );
      }
      await Future.wait(_pendingUploads.toList());
    }

    if (_uploadFailedPaths.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some media failed to upload. Remove or retry before saving.',
            ),
          ),
        );
      }
      return false;
    }

    _persistCurrentPageDraft();
    final deltaJson = JournalPageCodec.encode(
      pages: _pagesForSave(),
      currentPageId: _currentPageId,
    );
    final title = _titleController.text.trim();

    try {
      final updated = await _journalLocalRepository.saveJournal(
        journalId: widget.journalId,
        title: title,
        body: deltaJson,
        dayId: _buildDayId(DateTime.now()),
        folderId: _selectedFolderId,
        now: DateTime.now(),
      );
      if (mounted) {
        final row = Map<String, dynamic>.from(updated);
        setState(() {
          _savedShareId = row['share_id']?.toString();
          _hasSavedChanges = true;
        });
      }
      if (_hasUnsavedDoodleChanges ||
          _strokes.isNotEmpty ||
          _doodleStoragePath != null) {
        final doodleSaved = await _saveDoodleIfPossible(
          showSuccessMessage: false,
        );
        if (!doodleSaved) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Save failed')));
          }
          return false;
        }
      } else if (_doodleStoragePath == null) {
        await _refreshDoodleFromDb();
      }
      if (mounted) {
        setState(() => _lastSavedDraftSignature = _captureDraftSignature());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
      return false;
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Updated')));
    return true;
  }

  String _buildDayId(DateTime now) {
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildActionButtons({required bool compact}) {
    if (compact) {
      return <Widget>[
        MbAppBarCircleButton(
          key: _overflowButtonKey,
          icon: Icons.more_horiz,
          tooltip: 'More',
          onPressed: _openCompactActionsMenu,
        ),
        MbAppBarCircleButton(
          tooltip: _drawMode ? 'Exit draw mode' : 'Draw mode',
          icon: _drawMode ? Icons.edit_off : Icons.draw,
          onPressed: _toggleDrawMode,
        ),
        MbAppBarCircleButton(
          key: _saveTickButtonKey,
          tooltip: 'Save',
          icon: Icons.check,
          onPressed: _save,
        ),
      ];
    }
    return <Widget>[
      MbAppBarCircleButton(
        tooltip: _savedShareId == null ? 'Share' : 'Share (updated)',
        icon: Icons.share_outlined,
        onPressed: _openShareForSavedEntry,
      ),
      MbAppBarCircleButton(
        tooltip: 'Add page',
        icon: Icons.note_add_outlined,
        onPressed: _addPage,
      ),
      MbAppBarCircleButton(
        tooltip: _pages[_currentPageIndex].isBookmarked
            ? 'Remove bookmark'
            : 'Bookmark page',
        icon: _pages[_currentPageIndex].isBookmarked
            ? Icons.bookmark
            : Icons.bookmark_border,
        onPressed: _toggleBookmarkPage,
      ),
      MbAppBarCircleButton(
        key: _deletePageButtonKey,
        tooltip: 'Delete page',
        icon: Icons.delete_outline,
        onPressed: _deleteCurrentPage,
      ),
      MbAppBarCircleButton(
        tooltip: _removeMediaMode ? 'Stop removing' : 'Remove media',
        icon: _removeMediaMode ? Icons.check_circle : Icons.remove_circle,
        onPressed: _toggleRemoveMediaMode,
      ),
      MbAppBarCircleButton(
        key: _undoButtonKey,
        tooltip: 'Undo remove',
        icon: Icons.undo,
        onPressed: _lastRemoved == null ? null : _undoLastRemove,
      ),
      MbAppBarCircleButton(
        key: _imageUploadButtonKey,
        tooltip: 'Add photo',
        icon: Icons.photo,
        onPressed: (_activeUploads > 0 || _isPickingMedia)
            ? null
            : _insertImage,
      ),
      MbAppBarCircleButton(
        key: _videoUploadButtonKey,
        tooltip: 'Add video',
        icon: Icons.videocam,
        onPressed: (_activeUploads > 0 || _isPickingMedia)
            ? null
            : _insertVideo,
      ),
      MbAppBarCircleButton(
        tooltip: 'Add GIF',
        icon: Icons.gif_box_outlined,
        onPressed: (_activeUploads > 0 || _isPickingMedia) ? null : _insertGif,
      ),
      MbAppBarCircleButton(
        tooltip: 'Add sticker',
        icon: Icons.auto_awesome,
        onPressed: _insertSticker,
      ),
      if (_canvasObjects.isNotEmpty)
        MbAppBarCircleButton(
          tooltip: _canvasEditMode ? 'Finish arranging' : 'Arrange items',
          icon: _canvasEditMode ? Icons.check_circle : Icons.open_with_rounded,
          onPressed: _toggleCanvasEditMode,
        ),
      MbAppBarCircleButton(
        tooltip: _drawMode ? 'Exit draw mode' : 'Draw mode',
        icon: _drawMode ? Icons.edit_off : Icons.draw,
        onPressed: _toggleDrawMode,
      ),
      MbAppBarCircleButton(
        key: _saveTickButtonKey,
        tooltip: 'Save',
        icon: Icons.check,
        onPressed: _save,
      ),
    ];
  }

  Future<void> _openCompactActionsMenu() async {
    final buttonContext = _overflowButtonKey.currentContext;
    if (buttonContext == null) return;
    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy,
        overlay.size.width - bottomRight.dx,
        0,
      ),
      items: [
        const PopupMenuItem<String>(value: 'share', child: Text('Share')),
        PopupMenuItem<String>(
          value: 'remove_mode',
          child: Text(_removeMediaMode ? 'Stop removing' : 'Remove media'),
        ),
        const PopupMenuItem<String>(value: 'undo', child: Text('Undo remove')),
        const PopupMenuItem<String>(value: 'photo', child: Text('Add photo')),
        const PopupMenuItem<String>(value: 'video', child: Text('Add video')),
        const PopupMenuItem<String>(value: 'gif', child: Text('Add GIF')),
        const PopupMenuItem<String>(
          value: 'sticker',
          child: Text('Add sticker'),
        ),
        if (_canvasObjects.isNotEmpty)
          PopupMenuItem<String>(
            value: 'arrange',
            child: Text(_canvasEditMode ? 'Finish arranging' : 'Arrange items'),
          ),
        PopupMenuItem<String>(
          value: 'draw_mode',
          child: Text(_drawMode ? 'Exit draw mode' : 'Draw mode'),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'share':
        await _openShareForSavedEntry();
        break;
      case 'remove_mode':
        _toggleRemoveMediaMode();
        break;
      case 'undo':
        if (_lastRemoved != null) _undoLastRemove();
        break;
      case 'photo':
        if (_activeUploads == 0 && !_isPickingMedia) {
          await _insertImage();
        }
        break;
      case 'video':
        if (_activeUploads == 0 && !_isPickingMedia) {
          await _insertVideo();
        }
        break;
      case 'gif':
        if (_activeUploads == 0 && !_isPickingMedia) {
          await _insertGif();
        }
        break;
      case 'sticker':
        await _insertSticker();
        break;
      case 'arrange':
        _toggleCanvasEditMode();
        break;
      case 'draw_mode':
        _toggleDrawMode();
        break;
    }
  }

  Widget _buildCanvasToolbar() {
    JournalCanvasObject? selected;
    final selectedId = _selectedCanvasObjectId;
    if (selectedId != null) {
      for (final object in _canvasObjects) {
        if (object.id == selectedId) {
          selected = object;
          break;
        }
      }
    }
    final selectedLabel = switch (selected?.type) {
      JournalCanvasObjectType.image => 'Photo selected',
      JournalCanvasObjectType.video => 'Video selected',
      JournalCanvasObjectType.sticker => 'Sticker selected',
      _ => null,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _insertSticker,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Stickers'),
        ),
        OutlinedButton.icon(
          onPressed: (_activeUploads > 0 || _isPickingMedia)
              ? null
              : _insertGif,
          icon: const Icon(Icons.gif_box_outlined),
          label: const Text('GIFs'),
        ),
        if (_canvasObjects.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _toggleCanvasEditMode,
            icon: Icon(
              _canvasEditMode
                  ? Icons.check_circle_rounded
                  : Icons.open_with_rounded,
            ),
            label: Text(_canvasEditMode ? 'Done arranging' : 'Arrange items'),
            style: OutlinedButton.styleFrom(
              backgroundColor: _canvasEditMode
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                  : null,
            ),
          ),
        if (_canvasObjects.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.layers_rounded, size: 18),
            label: Text('${_canvasObjects.length} creative item(s)'),
          ),
        if (selectedLabel != null)
          Chip(
            avatar: const Icon(Icons.touch_app_rounded, size: 18),
            label: Text(selectedLabel),
          ),
      ],
    );
  }

  Widget _buildDrawingToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeTool = DrawingTool.pen),
                icon: const Icon(Icons.edit),
                label: const Text('Pen'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _activeTool == DrawingTool.pen
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _activeTool = DrawingTool.eraser),
                icon: const Icon(Icons.auto_fix_off),
                label: const Text('Eraser'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _activeTool == DrawingTool.eraser
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickDoodleBackground,
                icon: const Icon(Icons.grid_on),
                label: Text(_bgStyleLabel(_doodleBgStyle)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickDrawColor,
                icon: Icon(Icons.color_lens, color: _drawColor),
                label: const Text('Color'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 9,
                  ),
                ),
                child: Slider(
                  min: 1,
                  max: 24,
                  value: _strokeWidth,
                  onChanged: (value) => setState(() => _strokeWidth = value),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StrokePreview(color: _drawColor, width: _strokeWidth),
          ],
        ),
      ],
    );
  }

  Widget _buildFormattingToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FormatToggleChip(
              label: 'Bold',
              icon: Icons.format_bold,
              selected: _boldEnabled,
              onPressed: _toggleBold,
            ),
            _FormatToggleChip(
              label: 'Bullet list',
              icon: Icons.format_list_bulleted,
              selected: _isListActive(quill.Attribute.ul.value!),
              onPressed: () => _toggleList(quill.Attribute.ul),
            ),
            _FormatToggleChip(
              label: 'Numbered list',
              icon: Icons.format_list_numbered,
              selected: _isListActive(quill.Attribute.ol.value!),
              onPressed: () => _toggleList(quill.Attribute.ol),
            ),
            _FormatToggleChip(
              label: 'Checklist',
              icon: Icons.checklist,
              selected: _isChecklistActive,
              onPressed: () => _toggleList(quill.Attribute.unchecked),
            ),
            OutlinedButton.icon(
              onPressed: _pickLineSpacing,
              icon: const Icon(Icons.format_line_spacing),
              label: Text(
                _lineSpacingMixed
                    ? 'Spacing: Mixed'
                    : 'Spacing: ${_selectedLineSpacing.label}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          initialValue: _selectedFont,
          decoration: const InputDecoration(labelText: 'Font'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Default'),
            ),
            ..._fonts.map(
              (f) => DropdownMenuItem<String?>(value: f, child: Text(f)),
            ),
          ],
          onChanged: _applyFont,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ColorDot(
                  color: null,
                  selected: _selectedColor == null,
                  onTap: () => _applyColor(null),
                ),
                ..._colors.map(
                  (c) => _ColorDot(
                    color: c,
                    selected: _selectedColor == c,
                    onTap: () => _applyColor(c),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Highlight',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.14),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ColorDot(
                color: null,
                selected: _selectedHighlightColor == null,
                onTap: () => _applyHighlight(null),
                label: 'Clear',
              ),
              ..._highlightColors.map(
                (c) => _ColorDot(
                  color: c,
                  selected: _selectedHighlightColor == c,
                  onTap: () => _applyHighlight(c),
                  isHighlight: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final editorStyles = JournalDocumentCodec.buildEditorStyles(context);

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: MbScaffold(
        applyBackground: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: LayoutBuilder(
            builder: (context, constraints) {
              final compactActions = constraints.maxWidth < 430;
              final actionButtons = _buildActionButtons(
                compact: compactActions,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _appBarEdgePadding,
                ),
                child: Row(
                  children: [
                    MbAppBarCircleButton(
                      key: _backButtonKey,
                      icon: Icons.arrow_back,
                      onPressed: _handleExitRequest,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: actionButtons,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        body: MbFloatingHintOverlay(
          hintKey: 'hint_journal_edit',
          text: 'Edit gently. You can add or remove media.',
          iconText: '✨',
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_loadError!, textAlign: TextAlign.center),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox.expand(
                    child: _GlowPanel(
                      child: Column(
                        children: [
                          OutlinedButton.icon(
                            key: _folderPickerKey,
                            onPressed: _pickFolder,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(_selectedFolderLabel),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              hintText: 'Give this entry a name',
                              filled: true,
                              fillColor: cs.surface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!_drawMode)
                            KeyedSubtree(
                              key: _formattingDropdownKey,
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Formatting'),
                                initiallyExpanded: _showFormatBar,
                                onExpansionChanged: (v) =>
                                    setState(() => _showFormatBar = v),
                                children: [
                                  const SizedBox(height: 8),
                                  _buildFormattingToolbar(),
                                ],
                              ),
                            ),
                          if (!_drawMode) const SizedBox(height: 8),
                          if (_drawMode) _buildDrawingToolbar(),
                          if (_drawMode || _canvasObjects.isNotEmpty)
                            const SizedBox(height: 8),
                          _buildCanvasToolbar(),
                          const SizedBox(height: 8),
                          JournalPageControls(
                            currentPage: _currentPageIndex,
                            pageCount: _pages.length,
                            isBookmarked:
                                _pages[_currentPageIndex].isBookmarked,
                            onAddPage: _addPage,
                            onDeletePage: _deleteCurrentPage,
                            onToggleBookmark: _toggleBookmarkPage,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              decoration: _journalCanvasDecoration(cs),
                              clipBehavior: Clip.antiAlias,
                              child: PageView.builder(
                                controller: _pageController,
                                onPageChanged: _handlePageChanged,
                                itemCount: _pages.length,
                                itemBuilder: (context, index) {
                                  if (index == _currentPageIndex) {
                                    return Stack(
                                      children: [
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            ignoring: _drawMode,
                                            child: quill.QuillEditor.basic(
                                              controller: _qc,
                                              focusNode: _editorFocus,
                                              scrollController:
                                                  _editorScrollController,
                                              config: quill.QuillEditorConfig(
                                                autoFocus: true,
                                                scrollable: true,
                                                expands: false,
                                                scrollBottomInset:
                                                    keyboardInset + 24,
                                                customStyles: editorStyles,
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      12,
                                                      12,
                                                      12,
                                                      24,
                                                    ),
                                                embedBuilders: const [
                                                  LocalImageEmbedBuilder(),
                                                  LocalVideoEmbedBuilder(),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: JournalCanvasLayer(
                                            objects: _canvasObjects,
                                            selectedObjectId:
                                                _selectedCanvasObjectId,
                                            editable: true,
                                            interactionEnabled:
                                                _canvasEditMode && !_drawMode,
                                            uploadProgressByPath:
                                                _uploadProgressByPath,
                                            failedPaths: _uploadFailedPaths,
                                            onSelectObject: _selectCanvasObject,
                                            onUpdateObject: _updateCanvasObject,
                                            onDeleteObject: _deleteCanvasObject,
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            ignoring: !_drawMode,
                                            child: JournalDrawingCanvas(
                                              repaintKey: _drawingBoundaryKey,
                                              strokes: _strokes,
                                              activeStroke: _activeStroke,
                                              baseImageUrl: _doodleImageUrl,
                                              backgroundStyle: _doodleBgStyle,
                                              backgroundSpacing:
                                                  _doodleBgSpacing,
                                              onStrokeStart: _startStroke,
                                              onStrokeUpdate:
                                                  _appendStrokePoint,
                                              onStrokeEnd: _endStroke,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return JournalReadOnlyPagePreview(
                                    body: _pages[index].body,
                                    editorStyles: editorStyles,
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_drawMode)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Draw mode is on. Text gestures are temporarily disabled.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ),
                          if (_canvasEditMode && !_drawMode)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Arrange mode is on. Drag items around the page, or pinch to resize and rotate them.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ),
                          _MediaPreviewStrip(
                            items: _media,
                            removeMode: _removeMediaMode,
                            uploadProgressByPath: _uploadProgressByPath,
                            failedPaths: _uploadFailedPaths,
                            onRetry: _retryFailedUpload,
                            onTap: (index) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => JournalMediaViewer(
                                    items: _media,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            onRemove: _confirmRemove,
                          ),
                          if (_showPickSpinner)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Opening media picker...',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          if (_media.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            if (_removeMediaMode)
                              Text(
                                'Tap a preview to remove',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.75),
                                    ),
                              ),
                            if (_activeUploads > 0)
                              Text(
                                'Uploading $_activeUploads media item(s) in background...',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlowPanel extends StatelessWidget {
  const _GlowPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FormatToggleChip extends StatelessWidget {
  const _FormatToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
            : null,
      ),
    );
  }
}

class _StrokePreview extends StatelessWidget {
  const _StrokePreview({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _StrokePreviewPainter(color: color, width: width),
      ),
    );
  }
}

class _StrokePreviewPainter extends CustomPainter {
  const _StrokePreviewPainter({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final radius = width.clamp(1, size.shortestSide / 2).toDouble() / 2;
    canvas.drawCircle(size.center(Offset.zero), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePreviewPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.width != width;
  }
}

class _MediaPreviewStrip extends StatelessWidget {
  const _MediaPreviewStrip({
    required this.items,
    required this.onTap,
    required this.onRemove,
    required this.removeMode,
    required this.uploadProgressByPath,
    required this.failedPaths,
    required this.onRetry,
  });

  final List<JournalMediaItem> items;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onRemove;
  final bool removeMode;
  final Map<String, double> uploadProgressByPath;
  final Set<String> failedPaths;
  final ValueChanged<JournalMediaItem> onRetry;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(top: 8),
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final pathKey = item.path ?? '';
          final progress = uploadProgressByPath[pathKey];
          final failed = failedPaths.contains(pathKey);
          final uploading = progress != null && progress < 1;
          final thumb = item.type == 'video'
              ? _VideoThumb(item: item)
              : _ImageThumb(item: item);
          return GestureDetector(
            onTap: uploading
                ? null
                : (removeMode ? () => onRemove(i) : () => onTap(i)),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(width: 96, height: 96, child: thumb),
                ),
                if (!removeMode && uploading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.32),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          value: (progress > 0 && progress < 1)
                              ? progress
                              : null,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                if (removeMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (!removeMode && uploading)
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                      ),
                    ),
                  ),
                if (!removeMode && failed)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (!removeMode && failed)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => onRetry(item),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.refresh,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

@immutable
class _EmbedPayload {
  const _EmbedPayload({this.url, this.path});

  final String? url;
  final String? path;
}

@immutable
class _RemovedEmbed {
  const _RemovedEmbed({
    required this.type,
    required this.payload,
    required this.offset,
  });

  final String type;
  final String payload;
  final int offset;
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.item});

  final JournalMediaItem item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'edit_entry_image_thumb'),
      builder: (context, snap) {
        final resolved = snap.data;
        if (resolved?.file != null) {
          return Image.file(resolved!.file!, fit: BoxFit.cover);
        }
        if (resolved?.url != null && resolved!.url!.isNotEmpty) {
          return Image.network(
            resolved.url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _thumbFallback('Photo'),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return _thumbFallback('Photo');
      },
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.item});

  final JournalMediaItem item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'edit_entry_video_thumb'),
      builder: (context, snap) {
        final resolved = snap.data;
        final child = resolved?.file != null
            ? Image.file(resolved!.file!, fit: BoxFit.cover)
            : (resolved?.url != null && resolved!.url!.isNotEmpty)
            ? Image.network(
                resolved.url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbFallback('Video'),
              )
            : snap.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _thumbFallback('Video');
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: child),
            Container(color: Colors.black26),
            const Icon(Icons.play_circle, color: Colors.white, size: 32),
          ],
        );
      },
    );
  }
}

Widget _thumbFallback(String label) {
  return Container(
    color: Colors.black12,
    alignment: Alignment.center,
    child: Text('$label unavailable'),
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
    this.isHighlight = false,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        width: label != null ? 62 : 28,
        height: 28,
        decoration: BoxDecoration(
          color: color == null ? Colors.transparent : displayColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.4),
            width: selected ? 2.4 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.18),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: label != null
            ? Center(
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : color == null
            ? Center(
                child: Text(
                  isHighlight ? '' : 'A',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
