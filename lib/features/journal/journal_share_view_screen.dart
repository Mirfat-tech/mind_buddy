import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/journal/journal_canvas_layer.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';
import 'package:mind_buddy/services/journal_access_service.dart';
import 'package:mind_buddy/services/journal_document_codec.dart';

class JournalShareViewScreen extends StatefulWidget {
  const JournalShareViewScreen({super.key, required this.shareId});

  final String shareId;

  @override
  State<JournalShareViewScreen> createState() => _JournalShareViewScreenState();
}

class _JournalShareViewScreenState extends State<JournalShareViewScreen> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final row = await Supabase.instance.client
        .from('journals')
        .select()
        .eq('share_id', widget.shareId)
        .eq('is_shared', true)
        .maybeSingle();
    final data = row == null ? null : Map<String, dynamic>.from(row as Map);
    if (data != null) {
      final entryId = data['id']?.toString();
      if (entryId == null || entryId.isEmpty) {
        return null;
      }
      final allowed = await JournalAccessService.canAccessEntry(entryId);
      if (!allowed) {
        return null;
      }
      try {
        data['text'] = await JournalAccessService.hydrateMediaSignedUrls(
          entryId: entryId,
          rawText: data['text']?.toString() ?? '',
        );
      } catch (_) {}
      final path = data['doodle_storage_path']?.toString();
      final updatedRaw = data['doodle_updated_at']?.toString();
      final updatedAt = updatedRaw == null
          ? null
          : DateTime.tryParse(updatedRaw);
      data['doodle_preview_url'] = await JournalAccessService.resolveDoodleUrl(
        entryId: entryId,
        storagePath: path,
        updatedAt: updatedAt,
      );
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Shared Journal'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data == null) {
            return const Center(child: Text('This entry is not available.'));
          }

          final row = snap.data!;
          final title = (row['title'] as String?)?.trim().isNotEmpty == true
              ? row['title'] as String
              : 'Untitled entry';
          final createdAtRaw = row['created_at']?.toString();
          final createdAt = createdAtRaw != null
              ? DateFormat(
                  'MMM d, yyyy • h:mm a',
                ).format(DateTime.parse(createdAtRaw).toLocal())
              : null;
          final raw = row['text']?.toString() ?? '';
          final doodleUrl = row['doodle_preview_url']?.toString();
          final content = JournalDocumentCodec.decodeContent(raw);
          final doc = content.document;
          final controller = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: true,
          );
          final media = extractMediaFromDelta(
            controller.document.toDelta().toJson(),
          );
          final editorStyles = JournalDocumentCodec.buildEditorStyles(context);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox.expand(
              child: _GlowPanel(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            createdAt,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                          if (doodleUrl != null && doodleUrl.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Image.network(
                                  doodleUrl,
                                  fit: BoxFit.fill,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          quill.QuillEditor.basic(
                            controller: controller,
                            config: quill.QuillEditorConfig(
                              expands: true,
                              padding: EdgeInsets.all(12),
                              autoFocus: false,
                              customStyles: editorStyles,
                              embedBuilders: [
                                LocalImageEmbedBuilder(),
                                LocalVideoEmbedBuilder(),
                              ],
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
                      ),
                    ),
                    _MediaPreviewStrip(
                      items: media,
                      onTap: (index) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JournalMediaViewer(
                              items: media,
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
          );
        },
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
  const _MediaPreviewStrip({required this.items, required this.onTap});

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
          final thumb = item.type == 'video'
              ? _VideoThumb(item: item)
              : _ImageThumb(item: item);
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
  const _ImageThumb({required this.item});

  final JournalMediaItem item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'share_view_image_thumb'),
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
      future: resolveJournalMedia(item, debugContext: 'share_view_video_thumb'),
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
