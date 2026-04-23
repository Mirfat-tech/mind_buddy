import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:mind_buddy/features/journal/journal_canvas_layer.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/services/journal_document_codec.dart';

class JournalPageControls extends StatelessWidget {
  const JournalPageControls({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.isBookmarked,
    this.onAddPage,
    this.onDeletePage,
    this.onToggleBookmark,
  });

  final int currentPage;
  final int pageCount;
  final bool isBookmarked;
  final VoidCallback? onAddPage;
  final VoidCallback? onDeletePage;
  final VoidCallback? onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Page ${currentPage + 1} of $pageCount',
            style: bodySmall,
          ),
        ),
        if (onAddPage != null)
          TextButton.icon(
            onPressed: onAddPage,
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text('Add page'),
          ),
        if (onToggleBookmark != null)
          IconButton(
            tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark page',
            onPressed: onToggleBookmark,
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          )
        else if (isBookmarked)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.bookmark, size: 20),
          ),
        if (onDeletePage != null)
          IconButton(
            tooltip: 'Delete page',
            onPressed: onDeletePage,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }
}

class JournalReadOnlyPagePreview extends StatelessWidget {
  const JournalReadOnlyPagePreview({
    super.key,
    required this.body,
    required this.editorStyles,
  });

  final String body;
  final quill.DefaultStyles editorStyles;

  @override
  Widget build(BuildContext context) {
    final content = JournalDocumentCodec.decodeContent(body);
    final controller = quill.QuillController(
      document: content.document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: quill.QuillEditor.basic(
            controller: controller,
            config: quill.QuillEditorConfig(
              expands: true,
              autoFocus: false,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              customStyles: editorStyles,
              embedBuilders: const [
                LocalImageEmbedBuilder(),
                LocalVideoEmbedBuilder(),
              ],
            ),
          ),
        ),
        if (content.canvasObjects.isNotEmpty)
          Positioned.fill(
            child: JournalCanvasLayer(
              objects: content.canvasObjects,
              selectedObjectId: null,
              onSelectObject: (_) {},
              onUpdateObject: (_) {},
              onDeleteObject: (_) {},
            ),
          ),
      ],
    );
  }
}
