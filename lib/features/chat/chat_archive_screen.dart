import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
// Import your custom scaffold
import 'package:mind_buddy/features/chat/chat_screen.dart'; // Adjust path if needed

class ChatArchiveScreen extends StatelessWidget {
  const ChatArchiveScreen({super.key, required this.dayId});
  final String dayId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return MbScaffold(
      applyBackground: true, // This enables your themed background
      appBar: AppBar(
        title: const Text('Archived Chats'),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Fixes the "blocky" header
        elevation: 0,
        scrolledUnderElevation: 0, // Keeps it transparent when scrolling
        leading: _glowingBackButton(context, scheme),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('chats')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map(
              (rows) => rows
                  .where(
                    (r) => r['is_archived'] == true && r['user_id'] == user?.id,
                  )
                  .toList(),
            ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!;
          if (chats.isEmpty) {
            return Center(
              child: Text(
                "Your archive is empty.",
                style: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final chat = chats[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  // Use surface with low opacity for the glass effect
                  color: scheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.primary.withOpacity(0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    chat['title'] ?? 'Untitled Conversation',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Archived: ${chat['created_at'].toString().substring(0, 10)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.unarchive_outlined,
                          color: Colors.green,
                          size: 20,
                        ),
                        onPressed: () async {
                          await supabase
                              .from('chats')
                              .update({'is_archived': false})
                              .eq('id', chat['id']);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _deleteChat(supabase, chat['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _glowingBackButton(BuildContext context, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.1),
            blurRadius: 15,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.primary, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
    );
  }

  Future<void> _deleteChat(SupabaseClient supabase, dynamic id) async {
    await supabase.from('chats').delete().eq('id', id);
  }
}
