import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/services/mind_buddy_api.dart'; // ✅ CHANGED

class ChatBoxWidget extends StatelessWidget {
  const ChatBoxWidget({
    super.key,
    required this.dayId,
    required this.box,
    required this.api, // ✅ ADDED - pass API from parent
  });

  final String dayId;
  final Map<String, dynamic> box;
  final MindBuddyEnhancedApi api; // ✅ ADDED

  int? _readChatId(Map<String, dynamic> content) {
    final raw = content['chat_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    final boxId = (box['id'] ?? '').toString();

    final contentRaw = box['content'];
    final content = (contentRaw is Map)
        ? contentRaw.cast<String, dynamic>()
        : <String, dynamic>{};

    final chatId = _readChatId(content);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
          color: Colors.white.withOpacity(0.08),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('Chat is attached to this day.\nOpen to continue…'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: user == null
                  ? null
                  : () async {
                      // ✅ CHANGED - use the passed API instead of creating HobonichiRepo
                      // ensure chatId exists
                      var ensuredChatId = chatId;
                      if (ensuredChatId == null) {
                        ensuredChatId = await api.createChat(userId: user.id);

                        final newContent = <String, dynamic>{
                          ...content,
                          'chat_id': ensuredChatId,
                        };

                        await api.updateBoxContent(
                          boxId: boxId,
                          content: newContent,
                        );
                      }

                      if (!context.mounted) return;
                      context.push('/day/$dayId/chat/$ensuredChatId');
                    },
              child: Text(chatId == null ? 'Create & Open' : 'Open'),
            ),
          ],
        ),
      ),
    );
  }
}
