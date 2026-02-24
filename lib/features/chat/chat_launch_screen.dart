import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatLaunchScreen extends StatefulWidget {
  const ChatLaunchScreen({super.key});

  @override
  State<ChatLaunchScreen> createState() => _ChatLaunchScreenState();
}

class _ChatLaunchScreenState extends State<ChatLaunchScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openChat();
  }

  String _todayId() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openChat() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Not signed in.';
        });
        return;
      }

      final dayId = _todayId();
      final existing = await _supabase
          .from('chats')
          .select('id')
          .eq('user_id', user.id)
          .eq('day_id', dayId)
          .eq('is_archived', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final int chatId;
      if (existing != null && existing['id'] != null) {
        chatId = (existing['id'] as num).toInt();
      } else {
        final inserted = await _supabase
            .from('chats')
            .insert({
              'user_id': user.id,
              'day_id': dayId,
              'is_archived': false,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        chatId = (inserted['id'] as num).toInt();
      }

      if (!mounted) return;
      context.go('/chat/$dayId/$chatId');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Could not open chat'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _openChat();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
