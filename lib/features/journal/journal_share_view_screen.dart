import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';

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
    return row == null ? null : Map<String, dynamic>.from(row as Map);
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

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Shared Journal'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
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
          final title =
              (row['title'] as String?)?.trim().isNotEmpty == true
                  ? row['title'] as String
                  : 'Untitled entry';
          final createdAtRaw = row['created_at']?.toString();
          final createdAt = createdAtRaw != null
              ? DateFormat('MMM d, yyyy • h:mm a')
                  .format(DateTime.parse(createdAtRaw).toLocal())
              : null;
          final raw = row['text']?.toString() ?? '';
          final doc = _parseDoc(raw);
          final controller = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: true,
          );
          final media = extractMediaFromDelta(
            controller.document.toDelta().toJson(),
          );

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
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: quill.QuillEditor.basic(
                          controller: controller,
                          config: const quill.QuillEditorConfig(
                            expands: true,
                            padding: EdgeInsets.all(12),
                            autoFocus: false,
                            embedBuilders: [
                              LocalImageEmbedBuilder(),
                              LocalVideoEmbedBuilder(),
                            ],
                          ),
                        ),
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
