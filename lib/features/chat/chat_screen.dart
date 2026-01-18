// lib/features/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/mind_buddy_api.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.dayId, required this.chatId});

  final String dayId;
  final int chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  bool _busy = false;

  static const String _baseUrl = 'http://127.0.0.1:3000';
  late final MindBuddyApi _api = MindBuddyApi(baseUrl: _baseUrl);

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final repo = HobonichiRepo(supabase);

    setState(() => _busy = true);
    _controller.clear();
    FocusScope.of(context).unfocus();

    try {
      // 1) Persist user message
      await repo.addMessage(
        chatId: widget.chatId,
        userId: user.id,
        role: 'user',
        content: text,
      );

      // 2) Get assistant reply
      final res = await _api.sendMessage(message: text, chatId: widget.chatId);

      // 3) Persist assistant message
      await repo.addMessage(
        chatId: res.chatId,
        userId: user.id,
        role: 'assistant',
        content: res.reply,
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MbScaffold(
      applyBackground: false, // ✅ IMPORTANT: let PaperCanvas show through
      appBar: AppBar(
        title: const Text('Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: Column(
        children: [
          // Day context card (matches theme)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DAY', style: textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          'This chat is attached to this day.',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.dayId,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _MessagesList(
              chatId: widget.chatId,
              scroll: _scroll,
              onPainted: _scrollToBottom,
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _busy ? null : _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: _busy ? null : _send,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.chatId,
    required this.scroll,
    required this.onPainted,
  });

  final int chatId;
  final ScrollController scroll;
  final VoidCallback onPainted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final supabase = Supabase.instance.client;
    final repo = HobonichiRepo(supabase);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.streamMessages(chatId: chatId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final msgs = snapshot.data ?? const [];
        if (msgs.isEmpty) {
          return Center(
            child: Text(
              'No messages yet. Say hi 👋',
              style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
            ),
          );
        }

        onPainted();

        return ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.all(12),
          itemCount: msgs.length,
          itemBuilder: (context, i) {
            final m = msgs[i];
            final role = (m['role'] ?? 'user').toString();
            final content = (m['content'] ?? '').toString();
            final isUser = role == 'user';

            final bubbleColor = isUser
                ? scheme.primary.withOpacity(0.18)
                : scheme.surface;

            final borderColor = isUser
                ? scheme.primary.withOpacity(0.35)
                : scheme.outline;

            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(content, style: TextStyle(color: scheme.onSurface)),
              ),
            );
          },
        );
      },
    );
  }
}
