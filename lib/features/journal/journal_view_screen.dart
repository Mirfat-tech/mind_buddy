import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/journal/quill_embeds.dart';
import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_media_viewer.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';

class JournalViewScreen extends StatefulWidget {
  const JournalViewScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<JournalViewScreen> createState() => _JournalViewScreenState();
}

class _JournalViewScreenState extends State<JournalViewScreen> {
  late Future<Map<String, dynamic>?> _future;
  Map<String, dynamic>? _loaded;
  bool _isOwner = true;
  bool _shareBusy = false;
  bool _recipientCanComment = false;
  bool _recipientMediaVisible = true;
  List<Map<String, dynamic>> _shareRecipients = [];
  List<Map<String, dynamic>> _replies = [];

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
    if (data != null) {
      final user = Supabase.instance.client.auth.currentUser;
      _isOwner = user != null && user.id == data['user_id'];
      try {
        await _loadShareState();
      } catch (_) {}
    }
    return data;
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

  Future<void> _loadShareState() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      if (_isOwner) {
        final rows = await Supabase.instance.client
            .from('journal_share_recipients')
            .select(
              'id, recipient_id, can_comment, media_visible, expires_at, '
              'profile:recipient_id(username, full_name, email)',
            )
            .eq('journal_id', widget.journalId)
            .order('created_at', ascending: true);
        _shareRecipients = (rows as List).cast<Map<String, dynamic>>();
      } else {
        final row = await Supabase.instance.client
            .from('journal_share_recipients')
            .select('can_comment, media_visible, expires_at')
            .eq('journal_id', widget.journalId)
            .eq('recipient_id', user.id)
            .maybeSingle();
        _recipientCanComment = row?['can_comment'] == true;
        _recipientMediaVisible = row?['media_visible'] != false;
      }
      await _loadReplies();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadReplies() async {
    final rows = await Supabase.instance.client
        .from('journal_share_replies')
        .select('id, text, created_at, author:author_id(username)')
        .eq('journal_id', widget.journalId)
        .order('created_at', ascending: true);
    _replies = (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _openShareSheet() async {
    if (!_isOwner) return;
    await _loadShareState();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final count = _shareRecipients.length;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Page Privacy',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                count == 0
                    ? 'Private (only you can see this page)'
                    : 'Shared with $count ${count == 1 ? 'person' : 'people'}',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (count > 0)
                Column(
                  children: _shareRecipients.map((r) {
                    final profile = r['profile'] as Map<String, dynamic>?;
                    final username =
                        (profile?['username'] ?? '').toString();
                    final canComment = r['can_comment'] == true;
                    final expiresAt = r['expires_at']?.toString();
                    final expiresLabel = expiresAt == null
                        ? 'Forever'
                        : DateFormat('MMM d').format(
                            DateTime.parse(expiresAt).toLocal(),
                          );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        username.isEmpty ? 'Unknown user' : '@$username',
                      ),
                      subtitle: Text(
                        '${canComment ? 'View + reply' : 'View only'} • $expiresLabel',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeRecipient(r['id']),
                      ),
                    );
                  }).toList(),
                ),
              if (count > 0) const Divider(),
              FilledButton.icon(
                onPressed: _shareBusy ? null : _addRecipient,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Share with someone'),
              ),
              const SizedBox(height: 8),
              Text(
                'Shared pages stay private inside MyBrainBubble.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              FutureBuilder<SubscriptionInfo>(
                future: SubscriptionLimits.fetchForCurrentUser(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  if (info == null) return const SizedBox.shrink();
                  return Text(
                    SubscriptionPlanCatalog.sharesPerDayHelpText(info.plan),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addRecipient() async {
    if (_shareBusy) return;
    final info = await SubscriptionLimits.fetchForCurrentUser();
    if (!info.plan.canShareEntries) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'FREE MODE can receive shares but cannot share entries.',
            ),
          ),
        );
      }
      return;
    }
    if (info.sharesPerDay >= 0) {
      final usedShares = await JournalShareUsageTracker.todayCount();
      if (usedShares >= info.sharesPerDay) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shares per day reached on ${info.planName}: ${info.sharesPerDay}/${info.sharesPerDay}.',
              ),
            ),
          );
        }
        return;
      }
    }
    final usernameController = TextEditingController();
    bool canComment = false;
    bool mediaVisible = true;
    String duration = '7d';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Share with someone'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: '@alex',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow replies'),
                  value: canComment,
                  onChanged: (v) => setState(() => canComment = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show photos & videos'),
                  value: mediaVisible,
                  onChanged: (v) => setState(() => mediaVisible = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: 'Time limit'),
                  items: const [
                    DropdownMenuItem(value: '24h', child: Text('24 hours')),
                    DropdownMenuItem(value: '7d', child: Text('7 days')),
                    DropdownMenuItem(value: 'forever', child: Text('Forever')),
                  ],
                  onChanged: (v) => setState(() => duration = v ?? '7d'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final username = usernameController.text.trim().toLowerCase();
                  if (username.isEmpty) return;
                  final profile = await Supabase.instance.client
                      .from('profiles')
                      .select('id, username, is_active')
                      .eq('username', username)
                      .maybeSingle();
                  if (profile == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User not found')),
                      );
                    }
                    return;
                  }
                  final recipientId = profile['id'].toString();
                  final ownerId =
                      Supabase.instance.client.auth.currentUser!.id;
                  final existing = await Supabase.instance.client
                      .from('journal_share_blocks')
                      .select('id')
                      .eq('blocker_id', ownerId)
                      .eq('blocked_id', recipientId)
                      .maybeSingle();
                  if (existing == null) {
                    await Supabase.instance.client
                        .from('journal_share_blocks')
                        .insert({
                      'blocker_id': ownerId,
                      'blocked_id': recipientId,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User blocked')),
                      );
                    }
                  } else {
                    await Supabase.instance.client
                        .from('journal_share_blocks')
                        .delete()
                        .eq('id', existing['id']);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User unblocked')),
                      );
                    }
                  }
                },
                child: const Text('Block / Unblock'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Share'),
              ),
            ],
          );
        });
      },
    );
    if (result != true) return;

    final username = usernameController.text.trim().toLowerCase();
    if (username.isEmpty) return;

    setState(() => _shareBusy = true);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, username, is_active')
          .eq('username', username)
          .maybeSingle();
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
        return;
      }
      final isActive = profile['is_active'] != false;
      if (!isActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This user\'s account is no longer active for sharing.'),
            ),
          );
        }
        return;
      }
      final recipientId = profile['id'].toString();
      final ownerId = Supabase.instance.client.auth.currentUser!.id;
      final blockedByYou = await Supabase.instance.client
          .from('journal_share_blocks')
          .select('id')
          .eq('blocker_id', ownerId)
          .eq('blocked_id', recipientId)
          .maybeSingle();
      if (blockedByYou != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have blocked this user. Unblock to share.'),
            ),
          );
        }
        return;
      }
      final blockedByThem = await Supabase.instance.client
          .from('journal_share_blocks')
          .select('id')
          .eq('blocker_id', recipientId)
          .eq('blocked_id', ownerId)
          .maybeSingle();
      if (blockedByThem != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This user isn’t accepting shares right now.'),
            ),
          );
        }
        return;
      }
      final expiresAt = duration == 'forever'
          ? null
          : DateTime.now().add(
              duration == '24h'
                  ? const Duration(hours: 24)
                  : const Duration(days: 7),
            );
      await Supabase.instance.client.from('journal_share_recipients').upsert({
        'journal_id': widget.journalId,
        'owner_id': Supabase.instance.client.auth.currentUser!.id,
        'recipient_id': recipientId,
        'can_comment': canComment,
        'media_visible': mediaVisible,
        'expires_at': expiresAt?.toIso8601String(),
      });
      await Supabase.instance.client
          .from('journals')
          .update({'is_shared': true})
          .eq('id', widget.journalId);
      await JournalShareUsageTracker.increment();
      await _loadShareState();
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _removeRecipient(dynamic recipientRowId) async {
    await Supabase.instance.client
        .from('journal_share_recipients')
        .delete()
        .eq('id', recipientRowId);
    await _loadShareState();
    if (_shareRecipients.isEmpty) {
      await Supabase.instance.client
          .from('journals')
          .update({'is_shared': false})
          .eq('id', widget.journalId);
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _addReply() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Share a gentle reply…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await Supabase.instance.client.from('journal_share_replies').insert({
      'journal_id': widget.journalId,
      'author_id': Supabase.instance.client.auth.currentUser!.id,
      'text': text,
    });
    await _loadReplies();
    if (mounted) setState(() {});
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
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/journals'),
        ),
        actions: [
          if (_isOwner)
            MbGlowIconButton(
              tooltip: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: () async {
                final updated = await context
                    .push<bool>('/journals/edit/${widget.journalId}');
                if (updated == true && mounted) {
                  setState(() {
                    _future = _load();
                  });
                }
              },
            ),
          if (_isOwner)
            MbGlowIconButton(
              tooltip: 'Share',
              icon: Icons.share_outlined,
              onPressed: _openShareSheet,
            ),
          if (_isOwner)
            MbGlowIconButton(
              tooltip: 'Delete',
              icon: Icons.delete_outline,
              onPressed: _deleteEntry,
            ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_journal_view',
        text: 'Use the menu to share or edit when you feel ready.',
        iconText: '✨',
        child: FutureBuilder<Map<String, dynamic>?>(
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
                    if (_isOwner && _shareRecipients.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: _openShareSheet,
                            child: Text(
                              'Shared with ${_shareRecipients.length} ${_shareRecipients.length == 1 ? 'person' : 'people'} 🤍',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    if (!_isOwner)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Shared Page',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: quill.QuillEditor.basic(
                          controller: controller,
                          config: quill.QuillEditorConfig(
                            expands: true,
                            padding: const EdgeInsets.all(12),
                            autoFocus: false,
                            embedBuilders: (_isOwner || _recipientMediaVisible)
                                ? const [
                                    LocalImageEmbedBuilder(),
                                    LocalVideoEmbedBuilder(),
                                  ]
                                : const [],
                          ),
                        ),
                      ),
                    ),
                    if (_isOwner || _recipientMediaVisible)
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
                    if (_replies.isNotEmpty || (!_isOwner && _recipientCanComment))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Replies',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            if (_replies.isNotEmpty)
                              ..._replies.map((r) {
                                final author = r['author'] is Map
                                    ? (r['author']['username'] ?? '').toString()
                                    : '';
                                final created =
                                    r['created_at']?.toString() ?? '';
                                final createdLabel = created.isEmpty
                                    ? ''
                                    : DateFormat('MMM d • h:mm a').format(
                                        DateTime.parse(created).toLocal(),
                                      );
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        author.isEmpty ? 'Reply' : '@$author',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (r['text'] ?? '').toString(),
                                      ),
                                      if (createdLabel.isNotEmpty)
                                        Text(
                                          createdLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            if (!_isOwner && _recipientCanComment)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _addReply,
                                  icon: const Icon(Icons.reply),
                                  label: const Text('Reply'),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
