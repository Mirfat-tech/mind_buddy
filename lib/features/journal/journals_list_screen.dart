import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'journals_provider.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JournalsListScreen extends ConsumerWidget {
  const JournalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalsAsync = ref.watch(journalsProvider);
    final filter = ref.watch(_sharedFilterProvider);
    final search = ref.watch(_searchQueryProvider);
    Future<void> handleAdd() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final info = await SubscriptionLimits.fetchForCurrentUser();
      if (info.isPending) {
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => context.go('/subscription'),
        );
        return;
      }
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final countResponse = await Supabase.instance.client
          .from('journals')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .count();
      final used = countResponse.count ?? 0;
      if (used >= info.journalLimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              info.isFull
                  ? 'You\'ve reached your 10 journal entries for today.'
                  : 'You\'ve reached your 3 journal entries for today. Upgrade to Full Support for 10 per day.',
            ),
          ),
        );
        return;
      }
      context.go('/journals/new');
    }

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Journal'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_journals_list',
        text: 'Search to filter. Tap an entry to open.',
        iconText: '🫧',
        child: journalsAsync.when(
            data: (rows) {
          final sharedCount =
              rows.where((r) => r['is_shared'] == true).length;
          final filtered = switch (filter) {
            _SharedFilter.shared =>
              rows.where((r) => r['is_shared'] == true).toList(),
            _SharedFilter.unshared =>
              rows.where((r) => r['is_shared'] != true).toList(),
            _SharedFilter.all => rows,
          };

          final query = search.trim().toLowerCase();
          final searched = query.isEmpty
              ? filtered
              : filtered.where((r) {
                  final title = (r['title'] ?? '').toString().toLowerCase();
                  final text = (r['text'] ?? '').toString().toLowerCase();
                  return title.contains(query) || text.contains(query);
                }).toList();

          return Column(
            children: [
              if ((ref.watch(_pendingTierProvider).valueOrNull ?? false))
                _TrialBanner(
                  onUpgrade: () => context.go('/subscription'),
                  onSkip: () => ref
                      .read(_trialBannerControllerProvider.notifier)
                      .dismiss(),
                ),
              _SearchBar(
                value: search,
                onChanged: (v) =>
                    ref.read(_searchQueryProvider.notifier).state = v,
              ),
              Expanded(
                child: searched.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty
                              ? 'No entries yet.'
                              : 'No matches for "$query".',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: searched.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final row = searched[i];
                          final title =
                              (row['title'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? row['title'] as String
                                  : 'Untitled entry';
                          final createdAtRaw = row['created_at']?.toString();
                          final createdAt = createdAtRaw != null
                              ? DateFormat('MMM d, yyyy • h:mm a').format(
                                  DateTime.parse(createdAtRaw).toLocal(),
                                )
                              : '';
                          final id = row['id'].toString();
                          final isShared = row['is_shared'] == true;

                          return _GlowCard(
                            onTap: () => context.go('/journals/view/$id'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _highlightText(
                                              title,
                                              query,
                                              Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                          ),
                                          if (isShared)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'Shared',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (createdAt.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            createdAt,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete entry?'),
                                        content: const Text(
                                          'This cannot be undone.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;
                                    await Supabase.instance.client
                                        .from('journals')
                                        .delete()
                                        .eq('id', id);
                                    ref.invalidate(journalsProvider);
                                  },
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'open') {
                                      context.go('/journals/view/$id');
                                    }
                                    if (value == 'unshare') {
                                      await Supabase.instance.client
                                          .from('journals')
                                          .update({'is_shared': false})
                                          .eq('id', id);
                                      ref.invalidate(journalsProvider);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'open',
                                      child: Text('Open'),
                                    ),
                                    if (isShared)
                                      const PopupMenuItem(
                                        value: 'unshare',
                                        child: Text('Unshare'),
                                      ),
                                  ],
                                  icon: const Icon(Icons.more_vert),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load journals: $e')),
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: handleAdd,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _SharedFilterBar(
        value: filter,
        sharedCount: journalsAsync.maybeWhen(
          data: (rows) => rows.where((r) => r['is_shared'] == true).length,
          orElse: () => 0,
        ),
        onChanged: (v) => ref.read(_sharedFilterProvider.notifier).state = v,
      ),
    );
  }
}

final _trialBannerControllerProvider =
    StateNotifierProvider<_TrialBannerController, bool>((ref) {
  return _TrialBannerController();
});

class _TrialBannerController extends StateNotifier<bool> {
  _TrialBannerController() : super(true) {
    _load();
  }

  static const _prefsKey = 'trial_banner_dismissed';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = !(prefs.getBool(_prefsKey) ?? false);
  }

  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    state = false;
  }

  Future<void> show() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
    state = true;
  }
}

final _pendingTierProvider = FutureProvider<bool>((ref) async {
  final info = await SubscriptionLimits.fetchForCurrentUser();
  return info.isPending;
});

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.onUpgrade, required this.onSkip});

  final VoidCallback onUpgrade;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Trial mode: explore freely. Nothing is saved until you choose a plan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onSkip,
            child: const Text('Skip for now'),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: onUpgrade, child: const Text('Choose plan')),
        ],
      ),
    );
  }
}

enum _SharedFilter { all, shared, unshared }

final _sharedFilterProvider =
    StateProvider<_SharedFilter>((ref) => _SharedFilter.all);
final _searchQueryProvider = StateProvider<String>((ref) => '');

class _SharedFilterBar extends StatelessWidget {
  const _SharedFilterBar({
    required this.value,
    required this.sharedCount,
    required this.onChanged,
  });

  final _SharedFilter value;
  final int sharedCount;
  final ValueChanged<_SharedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withOpacity(0.25)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  selected: value == _SharedFilter.all,
                  label: const Text('All'),
                  onSelected: (_) => onChanged(_SharedFilter.all),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: value == _SharedFilter.shared,
                  label: Text('Shared ($sharedCount)'),
                  onSelected: (_) => onChanged(_SharedFilter.shared),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: value == _SharedFilter.unshared,
                  label: const Text('Unshared'),
                  onSelected: (_) => onChanged(_SharedFilter.unshared),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              switch (value) {
                _SharedFilter.shared => 'Showing shared entries',
                _SharedFilter.unshared => 'Showing unshared entries',
                _SharedFilter.all => 'All entries',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search journals',
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _GlowCard extends StatelessWidget {
  const _GlowCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline.withOpacity(0.25)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

RichText _highlightText(String text, String query, TextStyle? style) {
  if (query.isEmpty) {
    return RichText(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <TextSpan>[];
  int start = 0;

  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: style));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: style));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + lowerQuery.length),
        style: style?.copyWith(
          backgroundColor: Colors.yellow.withOpacity(0.35),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    start = index + lowerQuery.length;
  }

  return RichText(
    text: TextSpan(children: spans, style: style),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
