import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voice Input Widget
/// Tap to record, transcribes speech to text, then user can send
class VoiceInputButton extends StatefulWidget {
  final Function(String) onTextTranscribed;

  const VoiceInputButton({super.key, required this.onTextTranscribed});

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _transcribedText = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      // Stop listening
      await _speech.stop();
      setState(() => _isListening = false);

      // Send transcribed text to parent
      if (_transcribedText.isNotEmpty) {
        widget.onTextTranscribed(_transcribedText);
        setState(() => _transcribedText = '');
      }
    } else {
      // Start listening
      bool available = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: $error');
          setState(() => _isListening = false);
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            if (_transcribedText.isNotEmpty) {
              widget.onTextTranscribed(_transcribedText);
              setState(() => _transcribedText = '');
            }
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _transcribedText = '';
        });

        await _speech.listen(
          onResult: (result) {
            setState(() {
              _transcribedText = result.recognizedWords;
            });
          },
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        );
      } else {
        // Show error
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
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show transcribed text while listening
        if (_isListening && _transcribedText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.mic, color: scheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _transcribedText,
                    style: TextStyle(color: scheme.onSurface, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // Microphone button
        GestureDetector(
          onTap: _toggleListening,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _isListening
                  ? 1.0 + (_pulseController.value * 0.1)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isListening
                        ? LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade600],
                          )
                        : LinearGradient(
                            colors: [
                              scheme.primary.withOpacity(0.8),
                              scheme.primary,
                            ],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: _isListening
                            ? Colors.red.withOpacity(0.4)
                            : scheme.primary.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: _isListening ? 3 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),
        ),

        // Hint text
        const SizedBox(height: 8),
        Text(
          _isListening ? 'Tap to stop' : 'Tap to speak',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Updated Chat Input with Voice Button
/// Use this in your chat_screen.dart
class ChatInputWithVoice extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;

  const ChatInputWithVoice({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
  });

  @override
  State<ChatInputWithVoice> createState() => _ChatInputWithVoiceState();
}

class _ChatInputWithVoiceState extends State<ChatInputWithVoice> {
  bool _showVoiceButton = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkTextEmpty);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkTextEmpty);
    super.dispose();
  }

  void _checkTextEmpty() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    if (_showVoiceButton != isEmpty) {
      setState(() => _showVoiceButton = isEmpty);
    }
  }

  void _handleVoiceInput(String text) {
    setState(() {
      widget.controller.text = text;
      _showVoiceButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Voice button OR text field
            if (_showVoiceButton && !widget.isSending) ...[
              // Voice input button
              VoiceInputButton(onTextTranscribed: _handleVoiceInput),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap the mic to speak or type your message',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ] else ...[
              // Text input field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withOpacity(0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Send button
              GestureDetector(
                onTap: widget.isSending ? null : widget.onSend,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary.withOpacity(0.8), scheme.primary],
                    ),
                  ),
                  child: widget.isSending
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
