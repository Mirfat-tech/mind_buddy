import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';

class JournalViewScreen extends StatefulWidget {
  const JournalViewScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<JournalViewScreen> createState() => _JournalViewScreenState();
}

class _JournalViewScreenState extends State<JournalViewScreen> {
  late Future<Map<String, dynamic>?> _future;
  Map<String, dynamic>? _loaded;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final row = await Supabase.instance.client
        .from('journals')
        .select()
        .eq('id', widget.journalId)
        .maybeSingle();
    final data = row == null ? null : Map<String, dynamic>.from(row as Map);
    _loaded = data;
    return data;
  }

  Future<void> _share() async {
    final row = _loaded;
    if (row == null) return;

    final wasShared = row['is_shared'] == true;
    final shareId = (row['share_id'] ?? const Uuid().v4()).toString();

    if (!wasShared || row['share_id'] == null) {
      await Supabase.instance.client
          .from('journals')
          .update({'is_shared': true, 'share_id': shareId})
          .eq('id', row['id']);
      _loaded = {...row, 'is_shared': true, 'share_id': shareId};
    }

    const baseUrl = 'mindbuddy://share';
    final link = '$baseUrl/$shareId';
    await Share.share(link, subject: 'Shared Journal Entry');
  }

  Future<void> _toggleShare() async {
    final row = _loaded;
    if (row == null) return;

    final next = !(row['is_shared'] == true);
    final nextShareId = const Uuid().v4();
    await Supabase.instance.client
        .from('journals')
        .update({
          'is_shared': next,
          if (!next) 'share_id': nextShareId,
        })
        .eq('id', row['id']);

    if (mounted) {
      setState(() {
        _loaded = {
          ...row,
          'is_shared': next,
          if (!next) 'share_id': nextShareId,
        };
      });
    }
  }

  Future<void> _deleteEntry() async {
    final row = _loaded;
    if (row == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await Supabase.instance.client
        .from('journals')
        .delete()
        .eq('id', row['id']);

    if (!mounted) return;
    context.pop(true);
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
        title: const Text('Journal Entry'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/journals'),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final updated =
                  await context.push<bool>('/journals/edit/${widget.journalId}');
              if (updated == true && mounted) {
                setState(() {
                  _future = _load();
                });
              }
            },
          ),
          IconButton(
            tooltip: 'Share link',
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'Toggle sharing',
            icon: Icon(
              (_loaded?['is_shared'] == true)
                  ? Icons.link_off_outlined
                  : Icons.link_outlined,
            ),
            onPressed: _toggleShare,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteEntry,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data == null) {
            return const Center(child: Text('Entry not found.'));
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
