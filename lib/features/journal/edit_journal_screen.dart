import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';
import 'package:flutter/foundation.dart';

class EditJournalScreen extends StatefulWidget {
  const EditJournalScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<EditJournalScreen> createState() => _EditJournalScreenState();
}

class _EditJournalScreenState extends State<EditJournalScreen> {
  final quill.QuillController _qc = quill.QuillController.basic();
  final TextEditingController _titleController = TextEditingController();
  bool _loading = true;
  static const String _mediaBucket = 'journal-media';
  final FocusNode _editorFocus = FocusNode();
  String? _selectedFont;
  Color? _selectedColor;
  bool _showFormatBar = false;
  List<JournalMediaItem> _media = const [];

  static const List<String> _fonts = [
    'sans-serif',
    'serif',
    'monospace',
  ];
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
    _qc.removeListener(_refreshMedia);
    _qc.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _qc.addListener(_refreshMedia);
  }

  void _refreshMedia() {
    final items = extractMediaFromController(_qc);
    if (listEquals(items, _media)) return;
    setState(() => _media = items);
  }

  Future<void> _load() async {
    final row = await Supabase.instance.client
        .from('journals')
        .select()
        .eq('id', widget.journalId)
        .maybeSingle();

    if (row != null) {
      final title = (row['title'] as String?) ?? '';
      final raw = row['text']?.toString() ?? '';
      _titleController.text = title;

      final doc = _parseDoc(raw);
      _qc.document = doc;
      _qc.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  quill.Document _parseDoc(String raw) {
    try {
      final jsonData = jsonDecode(raw);
      if (jsonData is List) {
        return quill.Document.fromJson(
          jsonData.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
      }
    } catch (_) {}
    return quill.Document()..insert(0, raw);
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    final upload = await _uploadMedia(
      File(img.path),
      img.name,
      folder: 'images',
    );
    if (upload == null) return;

    final index = _qc.selection.baseOffset;
    _qc.document.insert(index, quill.BlockEmbed.image(upload));
    _qc.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  Future<void> _insertVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'm4v'],
    );
    if (res == null || res.files.single.path == null) return;

    final path = res.files.single.path!;
    final filename = res.files.single.name;
    final upload = await _uploadMedia(
      File(path),
      filename,
      folder: 'videos',
    );
    if (upload == null) return;

    final index = _qc.selection.baseOffset;
    _qc.document.insert(index, quill.BlockEmbed.video(upload));
    _qc.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
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

  Future<String?> _uploadMedia(
    File file,
    String filename, {
    required String folder,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final ext = filename.contains('.') ? filename.split('.').last : 'bin';
    final path = '${user.id}/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext';

    try {
      await Supabase.instance.client.storage.from(_mediaBucket).upload(
            path,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _save() async {
    final deltaJson = jsonEncode(_qc.document.toDelta().toJson());
    final title = _titleController.text.trim();

    try {
      await Supabase.instance.client.from('journals').update({
        'title': title.isEmpty ? null : title,
        'text': deltaJson,
      }).eq('id', widget.journalId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Updated')),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Edit Journal'),
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/journals'),
        ),
        actions: [
          MbGlowIconButton(
            tooltip: 'Remove media at cursor',
            icon: Icons.delete_outline,
            onPressed: _removeEmbedAtCursor,
          ),
          MbGlowIconButton(
            tooltip: 'Add photo',
            icon: Icons.photo,
            onPressed: _insertImage,
          ),
          MbGlowIconButton(
            tooltip: 'Add video',
            icon: Icons.videocam,
            onPressed: _insertVideo,
          ),
          MbGlowIconButton(
            tooltip: 'Save',
            icon: Icons.check,
            onPressed: _save,
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_journal_edit',
        text: 'Edit gently. You can add or remove media.',
        iconText: '✨',
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
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
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Formatting'),
                        initiallyExpanded: _showFormatBar,
                        onExpansionChanged: (v) =>
                            setState(() => _showFormatBar = v),
                        children: [
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String?>(
                            value: _selectedFont,
                            decoration:
                                const InputDecoration(labelText: 'Font'),
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
  });

  final List<JournalMediaItem> items;
  final ValueChanged<int> onTap;

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
          final thumb = item.type == 'video'
              ? _VideoThumb(
                  file: file,
                  url: url,
                )
              : _ImageThumb(
                  file: file,
                  url: url,
                );
          return GestureDetector(
            onTap: () => onTap(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 96, height: 96, child: thumb),
            ),
          );
        },
      ),
    );
  }
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
        Container(
          color: Colors.black26,
        ),
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
    final displayColor =
        color ?? Theme.of(context).colorScheme.onSurface;
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
