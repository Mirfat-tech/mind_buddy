import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/services/block_service.dart';

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
    try {
      final rows = await BlockService.instance.listBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blocks = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _blocks = [];
        _loading = false;
      });
    }
  }

  Future<void> _unblock(String blockedId) async {
    await BlockService.instance.unblockUser(blockedId);
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
                    final username = (row['username'] ?? '').toString();
                    final blockedId = row['blocked_id']?.toString() ?? '';
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
                            onPressed: blockedId.isEmpty
                                ? null
                                : () => _unblock(blockedId),
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
