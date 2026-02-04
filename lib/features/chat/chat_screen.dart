import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

//import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/mind_buddy_api.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
//import 'package:mind_buddy/features/chat/chat_archive_screen.dart';
import 'package:mind_buddy/paper/themed_page.dart';
//import 'package:mind_buddy/features/chat/voice_input_widget.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  bool _isCreatingChat = false;

  // CHANGED: Remove the old API initialization
  late final MindBuddyEnhancedApi _api;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _api = MindBuddyEnhancedApi(); // uses Supabase.instance.client
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && mounted) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send() async {
    if (_busy) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _busy = true);
    _controller.clear();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final info = await SubscriptionLimits.fetchForCurrentUser();
      final isFull = info.isFull;
      if (info.isPending) {
        if (mounted) {
          await SubscriptionLimits.showTrialUpgradeDialog(
            context,
            onUpgrade: () => context.go('/subscription'),
          );
        }
        setState(() => _busy = false);
        return;
      }

      // Count today's user messages across all chats (local day)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final messageCountResponse = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .count();

      final totalMessageCount = messageCountResponse.count ?? 0;

      // Apply limits based on tier
      final messageLimit = info.messageLimit;

      if (totalMessageCount >= messageLimit - 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFull
                    ? 'You\'ve reached your 100 message limit for today (including replies). Come back tomorrow!'
                    : 'You\'ve reached your 10 message limit for today (including replies). Upgrade to Full Support 🏆 for 100 messages per day!',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        setState(() => _busy = false);
        return;
      }

      // Get conversation history for context (last 20 messages)
      final previousMessages = await Supabase.instance.client
          .from('chat_messages')
          .select('role, text') // ✅ Only select 'text'
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true)
          .limit(20);

      // Build conversation history - handle both 'text' and 'content' fields
      // Build conversation history
      final conversationHistory = (previousMessages as List)
          .map(
            (msg) => {
              'role': msg['role'] as String,
              'content': (msg['text'] ?? '') as String,
            },
          )
          .where((msg) => (msg['content'] as String).isNotEmpty)
          .toList();

      // 🔍 ADD THIS DEBUG LOG
      debugPrint('📤 Sending to API:');
      debugPrint('Message: $text');
      debugPrint('History: $conversationHistory');

      // Save user message to database first
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'role': 'user',
        'text': text,
        'user_id': user.id,
      });

      // Send message to enhanced API with conversation history
      final response = await _api.sendMessage(text, conversationHistory);
      // Save AI response to database
      await Supabase.instance.client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'role': 'assistant',
        'text': response,
        'user_id': user.id,
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint("Send failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startListening() async {
    debugPrint('🎤 START: _startListening called');
    debugPrint('🎤 Current _isListening: $_isListening');

    if (_isListening) return;

    debugPrint('🎤 Initializing speech...');
    bool available = await _speech.initialize(
      onError: (error) {
        debugPrint('❌ Speech error: $error');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        debugPrint('📊 Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );

    debugPrint('🎤 Speech available: $available');

    if (available) {
      debugPrint('✅ Starting to listen...');
      setState(() => _isListening = true);

      // ✅ FIXED: Use new API without deprecated parameters
      await _speech.listen(
        onResult: (result) {
          debugPrint('📝 Recognized: ${result.recognizedWords}');
          if (mounted) {
            setState(() {
              _controller.text = result.recognizedWords;
            });
          }
        },
        // Remove these deprecated parameters:
        // listenMode: stt.ListenMode.confirmation,
        // cancelOnError: true,
        // partialResults: true,
      );
    } else {
      debugPrint('❌ Speech not available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Speech recognition not available. Check permissions.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
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
          BoxShadow(color: scheme.primary.withOpacity(0.15), blurRadius: 20),
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

  Widget _buildChatDrawer(BuildContext context, ColorScheme scheme) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    final baseStream = supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    final chatStream = (user == null)
        ? const Stream<List<Map<String, dynamic>>>.empty()
        : baseStream.map(
            (rows) => rows
                .where(
                  (r) => r['is_archived'] == false && r['user_id'] == user.id,
                )
                .toList(),
          );

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface.withOpacity(0.98),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.08),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withOpacity(0.15),
                    scheme.primaryContainer.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: scheme.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: scheme.primary, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      "Chat History",
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                icon: _isCreatingChat
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(
                  _isCreatingChat ? "Starting..." : "New Conversation",
                ),
                onPressed: _isCreatingChat
                    ? null
                    : () async {
                        final user = supabase.auth.currentUser;
                        if (user == null) return;

                        setState(() => _isCreatingChat = true);

                        try {
                          final info =
                              await SubscriptionLimits.fetchForCurrentUser();
                          final isFull = info.isFull;
                          if (info.isPending) {
                            if (context.mounted) {
                              await SubscriptionLimits.showTrialUpgradeDialog(
                                context,
                                onUpgrade: () => context.go('/subscription'),
                              );
                            }
                            return;
                          }

                          // Debug log
                          debugPrint(
                            'User subscription tier: ${info.rawTier}',
                          );
                          debugPrint('Is Full: $isFull');

                          // 2. Label the current chat if it has no title
                          final currentTitle = await supabase
                              .from('chats')
                              .select('title')
                              .eq('id', widget.chatId)
                              .maybeSingle();

                          if (currentTitle != null &&
                              currentTitle['title'] == null) {
                            await supabase
                                .from('chats')
                                .update({
                                  'title':
                                      'Session ${DateTime.now().toString().substring(5, 16)}',
                                })
                                .eq('id', widget.chatId);
                          }

                          // 3. Light Support users only: Check if chat already exists for this day
                          if (!isFull) {
                            final existingChat = await supabase
                                .from('chats')
                                .select()
                                .eq('user_id', user.id)
                                .eq('day_id', widget.dayId)
                                .eq('is_archived', false)
                                .order('created_at', ascending: false)
                                .limit(1)
                                .maybeSingle();

                            if (existingChat != null) {
                              // Navigate to existing chat
                              if (context.mounted) {
                                Navigator.pop(context);
                                context.pushReplacement(
                                  '/chat/${widget.dayId}/${existingChat['id']}',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Light Support users can have 1 chat per day. Upgrade to Full Support 🏆 for unlimited chats!',
                                    ),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                              return;
                            }
                          }

                          // 4. Create new chat (Full Support always allowed, Light Support if none exists)
                          final newChat = await supabase
                              .from('chats')
                              .insert({
                                'user_id': user.id,
                                'day_id': widget.dayId,
                                'is_archived': false,
                              })
                              .select()
                              .single();

                          if (context.mounted) {
                            Navigator.pop(context);
                            context.pushReplacement(
                              '/chat/${widget.dayId}/${newChat['id']}',
                            );
                          }
                        } catch (e) {
                          debugPrint("Error: $e");
                          if (context.mounted) {
                            String msg = 'Failed to create chat.';
                            if (e is PostgrestException &&
                                e.code == '23505') {
                              msg =
                                  'Light Support allows only 1 chat per day. Upgrade to Full Support 🏆 for unlimited chats.';
                            } else if (e.toString().contains('23505')) {
                              msg =
                                  'Light Support allows only 1 chat per day. Upgrade to Full Support 🏆 for unlimited chats.';
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isCreatingChat = false);
                        }
                      },
              ),
            ),
            const Divider(indent: 20, endIndent: 20),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: chatStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final chats = snapshot.data!;
                  if (chats.isEmpty) {
                    return Center(
                      child: Text(
                        'No chats yet',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final chat = chats[i];
                      final isCurrent = chat['id'] == widget.chatId;

                      return Dismissible(
                        key: Key(chat['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Delete Chat?"),
                              content: const Text(
                                "This will permanently remove this conversation.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          try {
                            await supabase
                                .from('chats')
                                .delete()
                                .eq('id', chat['id']);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete chat: $e'),
                                ),
                              );
                            }
                          }
                        },
                        child: ListTile(
                          selected: isCurrent,
                          selectedTileColor: scheme.primary.withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: isCurrent
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          title: Text(
                            chat['title'] ?? 'New Conversation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrent
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context.pushReplacement(
                              '/chat/${chat['day_id']}/${chat['id']}',
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text("Upgrade to Full Support 🏆"),
              onTap: () {
                Navigator.pop(context);
                context.push('/subscription');
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text("View Archive"),
              onTap: () {
                Navigator.pop(context);
                context.push('/chat-archive/${widget.dayId}');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: false,
      drawer: _buildChatDrawer(context, scheme),
      appBar: AppBar(
        title: const Text('Mind Buddy'),
        centerTitle: true,
        leadingWidth: 100,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, size: 22),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: 150,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withOpacity(0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
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
                              color: scheme.surface.withOpacity(0.7),
                              border: Border(
                                bottom: BorderSide(
                                  color: scheme.primary.withOpacity(0.05),
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
                                  color: scheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Session: ${widget.dayId}',
                                  style: TextStyle(
                                    fontSize: 11,
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
                    if (_busy)
                      const Positioned(
                        bottom: 10,
                        left: 16,
                        child: _TypingIndicator(),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Microphone button (ONLY shows when text is empty)
                      if (_controller.text.trim().isEmpty && !_busy) ...[
                        GestureDetector(
                          onTap: () {
                            debugPrint('🎤 MIC BUTTON TAPPED!');
                            debugPrint('🎤 _isListening before: $_isListening');
                            if (_isListening) {
                              _stopListening();
                            } else {
                              _startListening();
                            }
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isListening
                                    ? [Colors.red.shade400, Colors.red.shade600]
                                    : [
                                        scheme.primary.withOpacity(0.8),
                                        scheme.primary,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (_isListening
                                              ? Colors.red
                                              : scheme.primary)
                                          .withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: _isListening ? 3 : 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening ? Icons.stop : Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Text input field (ALWAYS VISIBLE)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withOpacity(0.05),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: scheme.primary.withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            onChanged: (_) =>
                                setState(() {}), // Rebuild to show/hide mic
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? 'Listening...'
                                  : 'Type or tap mic to speak...',
                              hintStyle: TextStyle(
                                color: scheme.onSurface.withOpacity(0.3),
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

                      // Send button (ONE ONLY - using ListenableBuilder)
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
        duration: const Duration(milliseconds: 200),
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: _busy || !hasText ? scheme.surface : scheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            if (!_busy && hasText)
              BoxShadow(
                color: scheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                    : scheme.onSurface.withOpacity(0.2),
                size: 22,
              ),
      ),
    );
  }
}

class _MessagesList extends StatefulWidget {
  const _MessagesList({
    required this.chatId,
    required this.scroll,
    required this.onPainted,
  });

  final int chatId;
  final ScrollController scroll;
  final VoidCallback onPainted;

  @override
  State<_MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<_MessagesList> {
  int _lastLen = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final repo = HobonichiRepo(Supabase.instance.client);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.streamMessages(chatId: widget.chatId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final msgs = snapshot.data ?? const [];

        if (msgs.length > _lastLen) {
          _lastLen = msgs.length;
          widget.onPainted();
        }

        return ListView.builder(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(16, 70, 16, 80),
          itemCount: msgs.length,
          itemBuilder: (context, i) {
            final m = msgs[i];
            final isUser = m['role'] == 'user';
            final text = (m['text'] ?? m['content'] ?? '').toString();

            return Align(
              key: ValueKey(m['id']),
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  text,
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
          BoxShadow(color: scheme.primary.withOpacity(0.1), blurRadius: 10),
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
                  color: scheme.primary.withOpacity(0.2 + (value * 0.6)),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class MbScaffold extends StatelessWidget {
  const MbScaffold({
    super.key,
    required this.appBar,
    required this.body,
    required this.applyBackground,
    this.drawer,
  });

  final PreferredSizeWidget appBar;
  final Widget body;
  final bool applyBackground;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    return ThemedPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: drawer,
        appBar: appBar,
        body: body,
      ),
    );
  }
}

class HobonichiRepo {
  HobonichiRepo(this.supabase);
  final SupabaseClient supabase;

  Stream<List<Map<String, dynamic>>> streamMessages({required int chatId}) {
    return supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);
  }

  Future<void> addMessage({
    required int chatId,
    required String userId,
    required String role,
    required String content,
  }) async {
    await supabase.from('chat_messages').insert({
      'chat_id': chatId,
      'user_id': userId,
      'role': role,
      'text': content,
    });
  }
}
