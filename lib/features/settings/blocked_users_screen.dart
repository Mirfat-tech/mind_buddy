import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _blocks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _blocks = [];
        _loading = false;
      });
      return;
    }
    final rows = await Supabase.instance.client
        .from('journal_share_blocks')
        .select('id, blocked_id, created_at, blocked:blocked_id (username)')
        .eq('blocker_id', user.id)
        .order('created_at', ascending: false);
    setState(() {
      _blocks = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _unblock(String blockId) async {
    await Supabase.instance.client
        .from('journal_share_blocks')
        .delete()
        .eq('id', blockId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Blocked users'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocks.isEmpty
              ? const Center(child: Text('No blocked users'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blocks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final row = _blocks[i];
                    final username =
                        (row['blocked']?['username'] ?? '').toString();
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_off_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              username.isEmpty ? 'Unknown user' : '@$username',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _unblock(row['id'].toString()),
                            child: const Text('Unblock'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
