import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';
import 'package:mind_buddy/features/journal/journal_upload_pipeline.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:mind_buddy/guides/guide_manager.dart';

class NewJournalScreen extends StatefulWidget {
  const NewJournalScreen({super.key});

  @override
  State<NewJournalScreen> createState() => _NewJournalScreenState();
}

class _NewJournalScreenState extends State<NewJournalScreen> {
  final quill.QuillController _qc = quill.QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _editorFocus = FocusNode();
  static const String _mediaBucket = 'journal-media';
  String? _selectedFont;
  Color? _selectedColor;
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
  String? _savedJournalId;
  String? _savedShareId;
  bool _hasSavedChanges = false;
  final GlobalKey _backButtonKey = GlobalKey();
  final GlobalKey _deletePageButtonKey = GlobalKey();
  final GlobalKey _undoButtonKey = GlobalKey();
  final GlobalKey _imageUploadButtonKey = GlobalKey();
  final GlobalKey _videoUploadButtonKey = GlobalKey();
  final GlobalKey _saveTickButtonKey = GlobalKey();
  final GlobalKey _formattingDropdownKey = GlobalKey();

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

  @override
  void dispose() {
    _pickSpinnerTimer?.cancel();
    _qc.removeListener(_refreshMedia);
    _qc.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _qc.addListener(_refreshMedia);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGuideIfNeeded());
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
        // Other embeds count as length 1.
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

    var index = _qc.selection.baseOffset;
    if (index < 0) index = _qc.document.length - 1;

    final tasks = <Future<void>>[];
    for (final image in images) {
      final localPayload = jsonEncode({
        'bucket': _mediaBucket,
        'path': image.path,
        'url': image.path,
      });
      _qc.document.insert(index, quill.BlockEmbed.image(localPayload));
      index += 1;
      _uploadProgressByPath[image.path] = 0.03;
      _uploadFailedPaths.remove(image.path);
      _refreshMedia();
      if (mounted) setState(() {});
      tasks.add(
        _uploadImageInBackground(image: image, localPayload: localPayload),
      );
    }
    _qc.updateSelection(
      TextSelection.collapsed(offset: index),
      quill.ChangeSource.local,
    );
    if (mounted) setState(() {});
    _trackPendingUpload(Future.wait(tasks));
  }

  Future<void> _uploadImageInBackground({
    required XFile image,
    required String localPayload,
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

      final publicUrl = Supabase.instance.client.storage
          .from(_mediaBucket)
          .getPublicUrl(storagePath);
      final remotePayload = jsonEncode({
        'bucket': _mediaBucket,
        'path': storagePath,
        'url': publicUrl,
      });
      _replaceEmbedPayload(
        type: 'image',
        oldPayload: localPayload,
        newPayload: remotePayload,
      );

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

  Future<void> _insertVideoLink() async {
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
    final localPayload = jsonEncode({
      'bucket': _mediaBucket,
      'path': path,
      'url': path,
    });
    final index = _qc.selection.baseOffset;
    _qc.document.insert(index, quill.BlockEmbed.video(localPayload));
    _refreshMedia();
    _qc.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );

    _uploadProgressByPath[path] = 0.03;
    _uploadFailedPaths.remove(path);
    if (mounted) setState(() {});

    final task = _uploadVideoInBackground(
      localPath: path,
      filename: res.files.single.name,
      localPayload: localPayload,
    );
    _trackPendingUpload(task);
  }

  Future<void> _uploadVideoInBackground({
    required String localPath,
    required String filename,
    required String localPayload,
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

      final publicUrl = Supabase.instance.client.storage
          .from(_mediaBucket)
          .getPublicUrl(storagePath);
      final remotePayload = jsonEncode({
        'bucket': _mediaBucket,
        'path': storagePath,
        'url': publicUrl,
      });
      _replaceEmbedPayload(
        type: 'video',
        oldPayload: localPayload,
        newPayload: remotePayload,
      );

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

      final publicUrl = Supabase.instance.client.storage
          .from(_mediaBucket)
          .getPublicUrl(path);

      return jsonEncode({
        'bucket': _mediaBucket,
        'path': path,
        'url': publicUrl,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
      return null;
    }
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

  String _colorToHex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0');
    return '#${value.substring(2)}';
  }

  Future<void> _openShareForSavedEntry() async {
    final journalId = _savedJournalId;
    if (journalId == null) return;
    await context.push('/journals/view/$journalId');
  }

  Future<void> _save() async {
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
      return;
    }

    final deltaJson = jsonEncode(_qc.document.toDelta().toJson());
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final dayId =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    try {
      final info = await SubscriptionLimits.fetchForCurrentUser();
      if (info.isPending) {
        if (mounted) {
          await SubscriptionLimits.showTrialUpgradeDialog(
            context,
            onUpgrade: () => context.go('/subscription'),
          );
        }
        return;
      }
      if (_savedJournalId == null) {
        final countResponse = await Supabase.instance.client
            .from('journals')
            .select()
            .eq('user_id', user.id)
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String())
            .count();
        final used = countResponse.count;
        if (info.journalLimit >= 0 && used >= info.journalLimit) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Daily journal limit reached for ${info.planName}.',
                ),
              ),
            );
          }
          return;
        }
      }

      Map<String, dynamic> savedRow;
      if (_savedJournalId == null) {
        final inserted = await Supabase.instance.client
            .from('journals')
            .insert({
              'user_id': user.id,
              'day_id': dayId,
              'title': _titleController.text.trim().isEmpty
                  ? null
                  : _titleController.text.trim(),
              'text': deltaJson,
              'created_at': now.toIso8601String(),
            })
            .select('id, share_id')
            .single();
        savedRow = Map<String, dynamic>.from(inserted);
      } else {
        final updated = await Supabase.instance.client
            .from('journals')
            .update({
              'day_id': dayId,
              'title': _titleController.text.trim().isEmpty
                  ? null
                  : _titleController.text.trim(),
              'text': deltaJson,
            })
            .eq('id', _savedJournalId!)
            .eq('user_id', user.id)
            .select('id, share_id')
            .single();
        savedRow = Map<String, dynamic>.from(updated);
      }

      if (mounted) {
        setState(() {
          _savedJournalId = savedRow['id']?.toString();
          _savedShareId = savedRow['share_id']?.toString();
          _hasSavedChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('New Journal'),
        leading: MbGlowBackButton(
          key: _backButtonKey,
          onPressed: () => context.canPop()
              ? context.pop(_hasSavedChanges)
              : context.go('/journals'),
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.help_outline,
            onPressed: () => _showGuideIfNeeded(force: true),
          ),
          if (_savedJournalId != null)
            MbGlowIconButton(
              tooltip: _savedShareId == null ? 'Share' : 'Share (updated)',
              icon: Icons.share_outlined,
              onPressed: _openShareForSavedEntry,
            ),
          MbGlowIconButton(
            key: _deletePageButtonKey,
            tooltip: _removeMediaMode ? 'Stop removing' : 'Remove media',
            icon: _removeMediaMode ? Icons.check_circle : Icons.remove_circle,
            onPressed: _toggleRemoveMediaMode,
          ),
          MbGlowIconButton(
            key: _undoButtonKey,
            tooltip: 'Undo remove',
            icon: Icons.undo,
            onPressed: _lastRemoved == null ? null : _undoLastRemove,
          ),
          MbGlowIconButton(
            key: _imageUploadButtonKey,
            tooltip: 'Add photo',
            icon: Icons.photo,
            onPressed: (_activeUploads > 0 || _isPickingMedia)
                ? null
                : _insertImage,
          ),
          MbGlowIconButton(
            key: _videoUploadButtonKey,
            tooltip: 'Add video',
            icon: Icons.videocam,
            onPressed: (_activeUploads > 0 || _isPickingMedia)
                ? null
                : _insertVideoLink,
          ),
          MbGlowIconButton(
            key: _saveTickButtonKey,
            tooltip: 'Save',
            icon: Icons.check,
            onPressed: _save,
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_journal_new',
        text: 'Write a little or a lot. Add media if it helps.',
        iconText: '🫧',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox.expand(
            child: _GlowPanel(
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Give this entry a name',
                      filled: true,
                      fillColor: cs.surface,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedFont,
                          decoration: const InputDecoration(labelText: 'Font'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Default'),
                            ),
                            ..._fonts.map(
                              (f) => DropdownMenuItem<String?>(
                                value: f,
                                child: Text(f),
                              ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: quill.QuillEditor.basic(
                        controller: _qc,
                        focusNode: _editorFocus,
                        config: const quill.QuillEditorConfig(
                          autoFocus: true,
                          expands: true,
                          padding: EdgeInsets.all(12),
                          embedBuilders: [
                            LocalImageEmbedBuilder(),
                            LocalVideoEmbedBuilder(),
                          ],
                        ),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Opening media picker...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  if (_media.isNotEmpty && _removeMediaMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Tap a preview to remove',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.75),
                        ),
                      ),
                    ),
                  if (_activeUploads > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Uploading $_activeUploads media item(s) in background...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
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
      padding: const EdgeInsets.all(12),
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
          final file = resolveMediaFile(item);
          final url = item.url ?? item.path ?? '';
          final pathKey = item.path ?? '';
          final progress = uploadProgressByPath[pathKey];
          final failed = failedPaths.contains(pathKey);
          final uploading = progress != null && progress < 1;
          final thumb = item.type == 'video'
              ? _VideoThumb(file: file, url: url)
              : _ImageThumb(file: file, url: url);
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
  const _ImageThumb({required this.file, required this.url});

  final File? file;
  final String url;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return Image.file(file!, fit: BoxFit.cover);
    }
    return Image.network(url, fit: BoxFit.cover);
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.file, required this.url});

  final File? file;
  final String url;

  @override
  Widget build(BuildContext context) {
    final child = file != null
        ? Image.file(file!, fit: BoxFit.cover)
        : Image.network(url, fit: BoxFit.cover);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: child),
        Container(color: Colors.black26),
        const Icon(Icons.play_circle, color: Colors.white, size: 32),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color == null ? Colors.transparent : displayColor,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: color == null
            ? Center(
                child: Text(
                  'A',
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
