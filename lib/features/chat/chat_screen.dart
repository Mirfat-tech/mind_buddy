import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';

import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
//import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/mind_buddy_api.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:mind_buddy/services/memory_service.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
//import 'package:mind_buddy/features/chat/chat_archive_screen.dart';
import 'package:mind_buddy/paper/themed_page.dart';
//import 'package:mind_buddy/features/chat/voice_input_widget.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.dayId, required this.chatId});

  final String dayId;
  final int chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _isCreatingChat = false;
  final Map<int, int> _chatMessageCounts = {};
  bool _cleaningEmptyChats = false;
  final GlobalKey _chatListKey = GlobalKey();
  final GlobalKey _chatItemKey = GlobalKey();

  // CHANGED: Remove the old API initialization
  late final MindBuddyEnhancedApi _api;
  late final stt.SpeechToText _speech;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isReviewingTranscript = false;
  String _liveTranscript = '';
  String? _selectedLocaleId;
  String? _speechEngineBanner;
  DateTime? _lastRetryErrorAt;
  DateTime? _lastSpeechErrorAt;
  int _retryErrorStreak = 0;
  bool _isRecoveringSpeechError = false;
  bool _isPhysicalIOSDevice = true;
  int _autoRetryCount = 0;
  static const int _maxAutoRetries = 1;
  static const Duration _speechStartCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _api = MindBuddyEnhancedApi(); // uses Supabase.instance.client
    _speech = stt.SpeechToText();
    unawaited(_detectIOSDeviceType());
    _initSpeech();
  }

  Future<void> _detectIOSDeviceType() async {
    if (!Platform.isIOS) return;
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      _isPhysicalIOSDevice = info.isPhysicalDevice;
    } catch (_) {
      // Assume physical device on detection failure.
      _isPhysicalIOSDevice = true;
    }
  }

  Future<void> _initSpeech({bool force = false}) async {
    try {
      if (force) {
        try {
          await _speech.stop();
          await _speech.cancel();
        } catch (_) {
          // Best effort cleanup before re-initialization.
        }
      }

      final micGranted = await _ensureMicrophonePermission(showMessage: false);
      if (!micGranted) {
        if (mounted) {
          setState(() => _speechReady = false);
        } else {
          _speechReady = false;
        }
        return;
      }

      final available = await _speech.initialize(
        onError: (error) {
          // Canonical error logging and handling happen in _handleSpeechError.
          unawaited(_handleSpeechError(error));
        },
        onStatus: (status) {
          debugPrint('📊 Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              debugPrint(
                'ℹ️ Listening ended quickly. If this is iOS simulator, test on a physical device microphone.',
              );
            }
            if (mounted) {
              setState(() {
                _isListening = false;
                _isReviewingTranscript = _liveTranscript.isNotEmpty;
              });
            }
          }
        },
      );
      final hasPermission = await _speech.hasPermission;
      final ready = available && hasPermission;
      if (mounted) {
        setState(() => _speechReady = ready);
      } else {
        _speechReady = ready;
      }
    } catch (e) {
      debugPrint('❌ Speech init failed: $e');
      if (mounted) setState(() => _speechReady = false);
    }
  }

  Future<void> _handleSpeechError(dynamic error) async {
    final now = DateTime.now();
    final rawMsg = '${error.errorMsg}'.toLowerCase();
    final isPermanent = '${error.permanent}' == 'true';
    debugPrint(
      '❌ Speech error @${now.toIso8601String()}: msg=$rawMsg permanent=$isPermanent',
    );
    final errorMsg = rawMsg;
    final isRetryError =
        errorMsg == 'error_retry' || errorMsg.contains('retry');
    _lastSpeechErrorAt = now;

    if (mounted) {
      setState(() {
        _isListening = false;
        _isReviewingTranscript = _liveTranscript.isNotEmpty;
      });
    }

    if (!isRetryError || !Platform.isIOS || _isRecoveringSpeechError) {
      if (!isRetryError) {
        _autoRetryCount = 0;
      }
      return;
    }

    if (_lastRetryErrorAt != null &&
        now.difference(_lastRetryErrorAt!) <= const Duration(seconds: 10)) {
      _retryErrorStreak += 1;
    } else {
      _retryErrorStreak = 1;
    }
    _lastRetryErrorAt = now;

    if (mounted) {
      setState(() {
        _speechEngineBanner =
            'Speech engine unavailable - try again in a moment.${!_isPhysicalIOSDevice ? ' iOS Simulator speech can fail; test on a physical device.' : ''}';
      });
      final simulatorHint = !_isPhysicalIOSDevice
          ? ' iOS Simulator speech can fail; test on a physical device.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Speech engine unavailable - try again in a moment.$simulatorHint',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (_retryErrorStreak >= 2 && mounted) {
      setState(() {
        _speechEngineBanner =
            'Speech recognition failed to start. Check: Settings -> Privacy & Security -> Speech Recognition enabled + internet connection. Try again.${!_isPhysicalIOSDevice ? ' iOS Simulator speech can fail; test on a physical device.' : ''}';
      });
    }

    try {
      await _speech.cancel();
    } catch (_) {
      // Best effort cleanup before retry.
    }

    if (_autoRetryCount >= _maxAutoRetries) {
      return;
    }

    _autoRetryCount += 1;
    _isRecoveringSpeechError = true;
    try {
      final jitterMs = 800 + Random().nextInt(401);
      await Future.delayed(Duration(milliseconds: jitterMs));
      await _initSpeech(force: true);
      await _startListening(isAutoRetry: true);
    } catch (e) {
      debugPrint('❌ Retry recovery failed: $e');
    } finally {
      _isRecoveringSpeechError = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    if (_speechReady) {
      unawaited(_speech.stop());
    }
    super.dispose();
  }

  Future<bool> _ensureMicrophonePermission({bool showMessage = true}) async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    PermissionStatus speechStatus = PermissionStatus.granted;
    if (Platform.isIOS) {
      speechStatus = await Permission.speech.status;
      if (!speechStatus.isGranted) {
        speechStatus = await Permission.speech.request();
      }
    }

    final granted =
        micStatus.isGranted && (Platform.isIOS ? speechStatus.isGranted : true);
    if (!granted && showMessage && mounted) {
      final blocked = micStatus.isPermanentlyDenied || micStatus.isRestricted;
      final speechBlocked =
          speechStatus.isPermanentlyDenied || speechStatus.isRestricted;
      if (blocked || speechBlocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone/Speech permission is blocked. Enable it in Settings.',
            ),
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission denied. Voice input cannot start.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    debugPrint(
      '🎤 Permission status: mic=$micStatus speech=$speechStatus granted=$granted',
    );
    return granted;
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

  Future<void> _showVentGuideIfNeeded({bool force = false}) async {
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'vent',
      force: force,
      steps: [
        GuideStep(
          key: _chatListKey,
          title: 'Clearing old conversations?',
          body: 'Swipe a chat to gently let it go.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _chatItemKey,
          title: 'Tap to open',
          body: 'Select any chat to continue your vent.',
          align: GuideAlign.top,
        ),
      ],
    );
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
          .eq('role', 'user')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .count();

      final totalMessageCount = messageCountResponse.count;

      final messageLimit = info.chatLimit;

      if (totalMessageCount >= messageLimit - 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You\'ve reached your $messageLimit AI chats for today on ${info.planName}.',
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
      // Ensure non-empty conversations get a label
      final existingTitle = await Supabase.instance.client
          .from('chats')
          .select('title')
          .eq('id', widget.chatId)
          .maybeSingle();
      if (existingTitle != null && existingTitle['title'] == null) {
        await Supabase.instance.client
            .from('chats')
            .update({
              'title': 'Session ${DateTime.now().toString().substring(5, 16)}',
            })
            .eq('id', widget.chatId);
      }

      String? memoryContext;
      if (info.supportsMemory) {
        final memoryController = ref.read(memoryControllerProvider);
        await memoryController.captureFromMessage(text);
        memoryContext = memoryController.buildMemoryContext();
      }

      // Send message to enhanced API with conversation history + memory
      final response = await _api.sendMessage(
        text,
        conversationHistory,
        memoryContext: memoryContext,
      );
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

  Future<void> _startListening({bool isAutoRetry = false}) async {
    debugPrint('🎤 START: _startListening called');
    debugPrint('🎤 Current _isListening: $_isListening');

    if (_isListening) return;
    if (!isAutoRetry &&
        _lastSpeechErrorAt != null &&
        DateTime.now().difference(_lastSpeechErrorAt!) < _speechStartCooldown) {
      if (mounted) {
        setState(() {
          _speechEngineBanner =
              'Speech engine unavailable - try again in a moment.${!_isPhysicalIOSDevice ? ' iOS Simulator speech can fail; test on a physical device.' : ''}';
        });
      }
      return;
    }

    final info = await SubscriptionLimits.fetchForCurrentUser();
    if (!info.supportsVoice) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice chats are available in FULL SUPPORT MODE only (20 voice chats per day).',
            ),
          ),
        );
      }
      return;
    }
    final usedVoiceChats = await VoiceUsageTracker.todayCount();
    if (usedVoiceChats >= info.voiceChatsPerDay) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Voice chats per day reached: ${info.voiceChatsPerDay}/${info.voiceChatsPerDay}.',
            ),
          ),
        );
      }
      return;
    }

    final micGranted = await _ensureMicrophonePermission();
    if (!micGranted) {
      return;
    }

    if (!_speechReady) {
      await _initSpeech(force: true);
    }

    final hasSpeechPermission = await _speech.hasPermission;
    if (!_speechReady || !hasSpeechPermission) {
      debugPrint(
        '🎤 Speech not ready after init: speechReady=$_speechReady hasSpeechPermission=$hasSpeechPermission',
      );
      return;
    }

    debugPrint('🎤 Speech ready: $_speechReady');
    if (!isAutoRetry) {
      _autoRetryCount = 0;
    }

    setState(() {
      _isListening = true;
      _isReviewingTranscript = false;
      _liveTranscript = '';
      _controller.text = '';
      _speechEngineBanner = null;
    });

    debugPrint('✅ Starting to listen...');

    if (Platform.isIOS) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
        await session.setActive(true);
        debugPrint('🎤 iOS audio session configured for speech');
      } catch (e) {
        debugPrint('❌ Failed to configure iOS audio session: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
            _isReviewingTranscript = _liveTranscript.isNotEmpty;
            _speechEngineBanner = 'Unable to configure speech audio session.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not start speech audio session. Please try again.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }
    await VoiceUsageTracker.increment();

    stt.LocaleName? systemLocale;
    List<stt.LocaleName> locales = const [];
    try {
      locales = await _speech.locales();
      systemLocale = await _speech.systemLocale();
      final fallbackLocaleId =
          systemLocale?.localeId ??
          (locales.isNotEmpty ? locales.first.localeId : null);
      final localeIdToUse = _selectedLocaleId ?? fallbackLocaleId;
      _selectedLocaleId = localeIdToUse;
      String? localeName;
      for (final locale in locales) {
        if (locale.localeId == localeIdToUse) {
          localeName = locale.name;
          break;
        }
      }

      debugPrint('🎤 Speech locales count=${locales.length}');
      debugPrint(
        '🎤 Speech systemLocale=${systemLocale?.localeId} ${systemLocale?.name}',
      );
      debugPrint(
        '🎤 Speech selected localeId=$localeIdToUse localeName=${localeName ?? 'unknown'}',
      );
    } catch (e) {
      debugPrint('❌ Locale diagnostics failed: $e');
    }

    // If testing in iOS simulator, voice may not work; test on physical device.
    await _speech.listen(
      onResult: (result) {
        debugPrint(
          '📝 onResult words="${result.recognizedWords}" '
          'final=${result.finalResult} confidence=${result.confidence}',
        );
        if (mounted) {
          setState(() {
            _liveTranscript = result.recognizedWords;
            _controller.value = TextEditingValue(
              text: _liveTranscript,
              selection: TextSelection.collapsed(
                offset: _liveTranscript.length,
              ),
            );
          });
        }
      },
      localeId: _selectedLocaleId ?? systemLocale?.localeId,
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 5),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    debugPrint('🎤 listen() started=${_speech.isListening}');
    if (!_speech.isListening && mounted) {
      setState(() {
        _isListening = false;
        _isReviewingTranscript = _liveTranscript.isNotEmpty;
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _isReviewingTranscript = _liveTranscript.isNotEmpty;
      });
    }
  }

  Future<void> _acceptTranscript() async {
    if (_isListening) {
      await _speech.stop();
    }
    if (!mounted) return;
    setState(() {
      _controller.value = TextEditingValue(
        text: _liveTranscript,
        selection: TextSelection.collapsed(offset: _liveTranscript.length),
      );
      _isListening = false;
      _isReviewingTranscript = false;
      _liveTranscript = '';
    });
  }

  Future<void> _refreshChatMeta(List<Map<String, dynamic>> chats) async {
    if (_cleaningEmptyChats || chats.isEmpty) return;
    _cleaningEmptyChats = true;
    try {
      final ids = chats.map((c) => c['id']).whereType<int>().toList();
      if (ids.isEmpty) return;

      final rows = await Supabase.instance.client
          .from('chat_messages')
          .select('chat_id')
          .inFilter('chat_id', ids);

      final counts = <int, int>{};
      for (final row in rows) {
        final chatId = row['chat_id'] as int?;
        if (chatId == null) continue;
        counts[chatId] = (counts[chatId] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _chatMessageCounts
          ..clear()
          ..addAll(counts);
      });

      // Auto-delete empty chats (except the current open one).
      final emptyIds = ids
          .where((id) => (counts[id] ?? 0) == 0 && id != widget.chatId)
          .toList();
      if (emptyIds.isNotEmpty) {
        await Supabase.instance.client
            .from('chats')
            .delete()
            .inFilter('id', emptyIds);
      }
    } catch (_) {
      // Silent on purpose: this runs in UI loop.
    } finally {
      _cleaningEmptyChats = false;
    }
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
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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

                          SubscriptionInfo? planInfo;
                          try {
                            final info =
                                await SubscriptionLimits.fetchForCurrentUser();
                            planInfo = info;
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
                            debugPrint('Plan: ${info.planName}');

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

                            final chatsToday = await supabase
                                .from('chats')
                                .select()
                                .eq('user_id', user.id)
                                .eq('day_id', widget.dayId)
                                .eq('is_archived', false)
                                .count();
                            final usedChats = chatsToday.count;
                            if (usedChats >= info.chatLimit) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${info.planName} allows ${info.chatLimit} chats per day.',
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                              return;
                            }

                            // Create a new conversation when daily limit allows it.
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
                                    '${planInfo?.planName ?? 'Current plan'} allows ${planInfo?.chatLimit ?? 0} chats per day.';
                              } else if (e.toString().contains('23505')) {
                                msg =
                                    '${planInfo?.planName ?? 'Current plan'} allows ${planInfo?.chatLimit ?? 0} chats per day.';
                              }
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isCreatingChat = false);
                            }
                          }
                        },
                ),
              ),
              const Divider(indent: 20, endIndent: 20),
              StreamBuilder<List<Map<String, dynamic>>>(
                key: _chatListKey,
                stream: chatStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final chats = snapshot.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _refreshChatMeta(chats);
                  });
                  if (chats.isEmpty) {
                    return Center(
                      child: Text(
                        'No chats yet',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    );
                  }

                  final hasCounts = _chatMessageCounts.isNotEmpty;
                  final visibleChats = hasCounts
                      ? chats.where((chat) {
                          final chatId = chat['id'] as int?;
                          final count = chatId == null
                              ? 0
                              : _chatMessageCounts[chatId];
                          return (count ?? 0) > 0 || chatId == widget.chatId;
                        }).toList()
                      : chats;

                  if (visibleChats.isEmpty) {
                    return Center(
                      child: Text(
                        'No chats yet',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleChats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final chat = visibleChats[i];
                      final isCurrent = chat['id'] == widget.chatId;
                      final chatId = chat['id'] as int;
                      final count = _chatMessageCounts[chatId] ?? 0;
                      final created = DateTime.tryParse(
                        chat['created_at']?.toString() ?? '',
                      );
                      final derivedTitle = count == 0
                          ? 'New Conversation'
                          : (chat['title']?.toString().trim().isNotEmpty == true
                                ? chat['title']
                                : 'Session ${created != null ? DateFormat('MM-dd • HH:mm').format(created.toLocal()) : ''}');

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
                          key: i == 0 ? _chatItemKey : null,
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
                            derivedTitle?.toString() ?? 'New Conversation',
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
              const Divider(),
              ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: const Text('Compare BrainBubble modes'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showVentGuideIfNeeded(),
    );

    return MbScaffold(
      applyBackground: false,
      drawer: _buildChatDrawer(context, scheme),
      appBar: AppBar(
        title: const Text('MyBrainBubble'),
        centerTitle: true,
        leadingWidth: 92,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            Builder(
              builder: (context) => MbGlowIconButton(
                icon: Icons.menu_rounded,
                margin: EdgeInsets.zero,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.help_outline,
            onPressed: () => _showVentGuideIfNeeded(force: true),
          ),
          MbGlowIconButton(
            icon: Icons.notifications_outlined,
            onPressed: () => context.push('/settings/notifications'),
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_chat',
        text: 'Open the menu to find past chats.',
        iconText: '🫧',
        child: Stack(
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
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: SafeArea(
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_speechEngineBanner != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.45),
                                ),
                              ),
                              child: Text(
                                _speechEngineBanner!,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Microphone button (ONLY shows when text is empty)
                              if (_controller.text.trim().isEmpty &&
                                  !_busy) ...[
                                if (_isListening || _isReviewingTranscript) ...[
                                  // Stop + Done buttons while listening/reviewing
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: _isListening
                                            ? _stopListening
                                            : null,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: _isListening
                                                  ? [
                                                      Colors.red.shade400,
                                                      Colors.red.shade600,
                                                    ]
                                                  : [
                                                      scheme
                                                          .surfaceContainerHighest,
                                                      scheme
                                                          .surfaceContainerHighest,
                                                    ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    (_isListening
                                                            ? Colors.red
                                                            : scheme.primary)
                                                        .withOpacity(0.15),
                                                blurRadius: 12,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.stop,
                                            color: _isListening
                                                ? Colors.white
                                                : scheme.onSurface.withOpacity(
                                                    0.4,
                                                  ),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _liveTranscript.trim().isEmpty
                                            ? null
                                            : () {
                                                debugPrint('✅ Done tapped');
                                                _acceptTranscript();
                                              },
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: scheme.primary,
                                            boxShadow: [
                                              BoxShadow(
                                                color: scheme.primary
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                ] else ...[
                                  // Mic button (idle)
                                  GestureDetector(
                                    onTap: () {
                                      if (_isListening) return;
                                      if (!_speechReady) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Voice chats are available in FULL SUPPORT MODE only (20/day).',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      debugPrint('🎤 MIC BUTTON TAPPED!');
                                      debugPrint(
                                        '🎤 _isListening before: $_isListening',
                                      );
                                      unawaited(_startListening());
                                    },
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: _speechReady
                                              ? [
                                                  scheme.primary.withOpacity(
                                                    0.8,
                                                  ),
                                                  scheme.primary,
                                                ]
                                              : [
                                                  scheme
                                                      .surfaceContainerHighest,
                                                  scheme
                                                      .surfaceContainerHighest,
                                                ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: scheme.primary.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: _speechReady
                                          ? const Icon(
                                              Icons.mic,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                          : const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ],

                              // Text input field (ALWAYS VISIBLE)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest
                                        .withOpacity(0.5),
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
                                    onChanged: (_) => setState(
                                      () {},
                                    ), // Rebuild to show/hide mic
                                    readOnly: _isListening,
                                    decoration: InputDecoration(
                                      hintText: _isListening
                                          ? 'Listening...'
                                          : 'Type your message (voice: FULL SUPPORT MODE only)...',
                                      hintStyle: TextStyle(
                                        color: scheme.onSurface.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                builder: (context, _) =>
                                    _buildSendButton(scheme),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          padding: EdgeInsets.fromLTRB(
            16,
            70,
            16,
            140 + MediaQuery.of(context).viewPadding.bottom,
          ),
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
