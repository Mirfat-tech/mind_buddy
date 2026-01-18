import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class NewJournalScreen extends StatefulWidget {
  const NewJournalScreen({super.key});

  @override
  State<NewJournalScreen> createState() => _NewJournalScreenState();
}

class _NewJournalScreenState extends State<NewJournalScreen> {
  final quill.QuillController _qc = quill.QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _qc.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final saved = await File(
      img.path,
    ).copy('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${img.name}');

    final index = _qc.selection.baseOffset;
    _qc.document.insert(index, quill.BlockEmbed.image(saved.path));
    _qc.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  Future<void> _insertVideoLink() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'm4v'],
    );

    if (res == null || res.files.single.path == null) return;

    final path = res.files.single.path!;
    final index = _qc.selection.baseOffset;
    _qc.document.insert(index, "\n🎬 Video: $path\n");
  }

  Future<void> _save() async {
    final deltaJson = jsonEncode(_qc.document.toDelta().toJson());

    // TEMP so the warning goes away (remove later when you save to Supabase)
    debugPrint(deltaJson);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Journal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Add photo',
            icon: const Icon(Icons.photo),
            onPressed: _insertImage,
          ),
          IconButton(
            tooltip: 'Add video',
            icon: const Icon(Icons.videocam),
            onPressed: _insertVideoLink,
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body:
          //Column(
          //children: [
          // TOOLBAR
          //Container(
          //color: cs.surface,
          //child: quill.QuillToolbar.simple(
          // controller: _qc,
          // config: const quill.QuillSimpleToolbarConfig(),
          //),
          //),
          // EDITOR
          Expanded(
            child: quill.QuillEditor.basic(
              controller: _qc,
              config: const quill.QuillEditorConfig(
                autoFocus: true,
                expands: true,
                padding: EdgeInsets.all(12),
              ),
            ),
          ),

      // ],
      //  ),
    );
  }
}
