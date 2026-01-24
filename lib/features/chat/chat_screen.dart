import 'dart:async';
import 'dart:math';
import 'dart:ui';
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
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

    try {
      await repo.addMessage(
        chatId: widget.chatId,
        userId: user.id,
        role: 'user',
        content: text,
      );

      final res = await _api.sendMessage(message: text, chatId: widget.chatId);

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

  Widget _glowingIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          icon: Icon(icon, color: scheme.primary, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        title: const Text('Mind Buddy Chat'),
        centerTitle: true,
        leading: _glowingIconButton(
          icon: Icons.arrow_back,
          scheme: scheme,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Stack(
        children: [
          // 1. Ambient Background Glow Layer
          Positioned(
            bottom: 200,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _MessagesList(
                      chatId: widget.chatId,
                      scroll: _scroll,
                      onPainted: _scrollToBottom,
                    ),

                    // 2. Glassmorphism Header (Blurs content underneath)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.7),
                              border: Border(
                                bottom: BorderSide(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Journal Entry: ${widget.dayId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. Typing Indicator
                    if (_busy)
                      Positioned(
                        bottom: 10,
                        left: 16,
                        child: const _TypingIndicator(),
                      ),
                  ],
                ),
              ),

              // 4. Glowy Input Bar
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.08),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _busy ? null : _send(),
                            decoration: InputDecoration(
                              hintText: 'Share your thoughts...',
                              hintStyle: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.3),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) => _buildSendButton(scheme),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ColorScheme scheme) {
    final hasText = _controller.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: _busy || !hasText ? null : _send,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: _busy || !hasText ? scheme.surface : scheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            if (!_busy && hasText)
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
          ],
        ),
        child: _busy
            ? Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              )
            : Icon(
                Icons.send_rounded,
                color: hasText
                    ? scheme.onPrimary
                    : scheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
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
    final repo = HobonichiRepo(Supabase.instance.client);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.streamMessages(chatId: chatId),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final msgs = snapshot.data ?? const [];
        onPainted();

        return ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            16,
            70,
            16,
            80,
          ), // Extra top padding for Glass header
          itemCount: msgs.length,
          itemBuilder: (context, i) {
            final m = msgs[i];
            final isUser = m['role'] == 'user';

            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isUser ? scheme.primary : scheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  m['content'] ?? '',
                  style: TextStyle(
                    color: isUser ? scheme.onPrimary : scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = i * 0.2;
              final value = (sin((_controller.value * 2 * pi) - delay) + 1) / 2;
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.2 + (value * 0.6)),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
