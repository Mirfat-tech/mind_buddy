import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'journals_provider.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JournalsListScreen extends ConsumerWidget {
  JournalsListScreen({super.key});

  final GlobalKey _selectSquareButtonKey = GlobalKey();
  final GlobalKey _journalListItemKey = GlobalKey();
  final GlobalKey _deleteIconKey = GlobalKey();
  final GlobalKey _addJournalButtonKey = GlobalKey();
  final GlobalKey _categoryTabsScrollKey = GlobalKey();

  Future<void> _showGuideIfNeeded(BuildContext context, {bool force = false}) {
    return GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'journalMain',
      force: force,
      steps: [
        GuideStep(
          key: _selectSquareButtonKey,
          title: 'Tidying up?',
          body: 'Tap the square to select entries for archive or delete.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _journalListItemKey,
          title: 'Revisit a moment',
          body: 'Tap any journal to view or edit.',
          align: GuideAlign.top,
        ),
        GuideStep(
          key: _deleteIconKey,
          title: 'Time to let go?',
          body: 'Use the bin to permanently remove an entry.',
          align: GuideAlign.top,
        ),
        GuideStep(
          key: _addJournalButtonKey,
          title: 'Something new to capture?',
          body: 'Tap + to create a fresh journal bubble.',
          align: GuideAlign.top,
        ),
        GuideStep(
          key: _categoryTabsScrollKey,
          title: 'Exploring your space?',
          body: 'Swipe below to switch between Shared, Archived and more.',
          align: GuideAlign.top,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showGuideIfNeeded(context),
    );
    final journalsAsync = ref.watch(journalsProvider);
    final sharedWithMeAsync = ref.watch(sharedWithMeProvider);
    final blockedAsync = ref.watch(blockedUsersProvider);
    final filter = ref.watch(_sharedFilterProvider);
    final search = ref.watch(_searchQueryProvider);
    final selectionMode = ref.watch(_selectionModeProvider);
    final selectedIds = ref.watch(_selectedIdsProvider);
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
      final used = countResponse.count;
      if (info.journalLimit >= 0 && used >= info.journalLimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Daily journal limit reached for ${info.planName}.',
            ),
          ),
        );
        return;
      }
      context.go('/journals/new');
    }

    Future<void> archiveAllVisible(List<Map<String, dynamic>> items) async {
      if (items.isEmpty) return;
      final ids = items.map((e) => e['id']).toList();
      await Supabase.instance.client
          .from('journals')
          .update({'is_archived': true})
          .inFilter('id', ids);
      ref.invalidate(journalsProvider);
    }

    Future<void> restoreAllVisible(List<Map<String, dynamic>> items) async {
      if (items.isEmpty) return;
      final ids = items.map((e) => e['id']).toList();
      await Supabase.instance.client
          .from('journals')
          .update({'is_archived': false})
          .inFilter('id', ids);
      ref.invalidate(journalsProvider);
    }

    Future<void> archiveSelected() async {
      if (selectedIds.isEmpty) return;
      await Supabase.instance.client
          .from('journals')
          .update({'is_archived': true})
          .inFilter('id', selectedIds.toList());
      ref.read(_selectedIdsProvider.notifier).state = {};
      ref.read(_selectionModeProvider.notifier).state = false;
      ref.invalidate(journalsProvider);
    }

    Future<void> restoreSelected() async {
      if (selectedIds.isEmpty) return;
      await Supabase.instance.client
          .from('journals')
          .update({'is_archived': false})
          .inFilter('id', selectedIds.toList());
      ref.read(_selectedIdsProvider.notifier).state = {};
      ref.read(_selectionModeProvider.notifier).state = false;
      ref.invalidate(journalsProvider);
    }

    Future<void> deleteSelected() async {
      if (selectedIds.isEmpty) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete selected entries?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await Supabase.instance.client
          .from('journals')
          .delete()
          .inFilter('id', selectedIds.toList());
      ref.read(_selectedIdsProvider.notifier).state = {};
      ref.read(_selectionModeProvider.notifier).state = false;
      ref.invalidate(journalsProvider);
    }

    return journalsAsync.when(
      data: (rows) {
        final sharedWithMeRows = sharedWithMeAsync.maybeWhen(
          data: (r) => r,
          orElse: () => [],
        );
        final blockedRows = blockedAsync.maybeWhen(
          data: (r) => r,
          orElse: () => [],
        );
        final sharedCount = rows
            .where((r) => r['is_shared'] == true && r['is_archived'] != true)
            .length;
        final archivedCount = rows
            .where((r) => r['is_archived'] == true)
            .length;
        final blockedCount = blockedRows.length;
        final filtered = switch (filter) {
          _SharedFilter.shared =>
            rows
                .where(
                  (r) => r['is_shared'] == true && r['is_archived'] != true,
                )
                .toList(),
          _SharedFilter.unshared =>
            rows
                .where(
                  (r) => r['is_shared'] != true && r['is_archived'] != true,
                )
                .toList(),
          _SharedFilter.sharedWithMe => sharedWithMeRows,
          _SharedFilter.archived =>
            rows.where((r) => r['is_archived'] == true).toList(),
          _SharedFilter.blocked => const <Map<String, dynamic>>[],
          _SharedFilter.all =>
            rows.where((r) => r['is_archived'] != true).toList(),
        };
        final query = search.trim().toLowerCase();
        final searched = query.isEmpty
            ? filtered
            : filtered.where((r) {
                final journal = r['journal'] is Map<String, dynamic>
                    ? (r['journal'] as Map<String, dynamic>)
                    : r;
                final title = (journal['title'] ?? '').toString().toLowerCase();
                final text = (journal['text'] ?? '').toString().toLowerCase();
                return title.contains(query) || text.contains(query);
              }).toList();

        return MbScaffold(
          applyBackground: true,
          appBar: AppBar(
            title: const Text('Journal'),
            centerTitle: true,
            leading: MbGlowBackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            actions: [
              IconButton(
                tooltip: 'Guide',
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showGuideIfNeeded(context, force: true),
              ),
              if (selectionMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedIds.length} selected',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              IconButton(
                key: _selectSquareButtonKey,
                tooltip: selectionMode ? 'Done selecting' : 'Select',
                icon: Icon(selectionMode ? Icons.check : Icons.select_all),
                onPressed: () {
                  final next = !selectionMode;
                  ref.read(_selectionModeProvider.notifier).state = next;
                  if (!next) {
                    ref.read(_selectedIdsProvider.notifier).state = {};
                  }
                },
              ),
              if (selectionMode)
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.done_all),
                  onPressed: () {
                    final ids = searched
                        .map(
                          (r) =>
                              (r['journal'] is Map<String, dynamic>
                                      ? r['journal']['id']
                                      : r['id'])
                                  .toString(),
                        )
                        .toSet();
                    ref.read(_selectedIdsProvider.notifier).state = ids;
                  },
                ),
              if (selectionMode)
                IconButton(
                  tooltip: filter == _SharedFilter.archived
                      ? 'Restore selected'
                      : 'Archive selected',
                  icon: Icon(
                    filter == _SharedFilter.archived
                        ? Icons.unarchive
                        : Icons.archive_outlined,
                  ),
                  onPressed: filter == _SharedFilter.archived
                      ? restoreSelected
                      : archiveSelected,
                ),
              if (selectionMode && filter != _SharedFilter.sharedWithMe)
                IconButton(
                  key: _deleteIconKey,
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: deleteSelected,
                ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'archive_all') {
                      await archiveAllVisible(
                        List<Map<String, dynamic>>.from(searched),
                      );
                    }
                    if (value == 'restore_all') {
                      await restoreAllVisible(
                        List<Map<String, dynamic>>.from(searched),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    if (filter != _SharedFilter.archived)
                      const PopupMenuItem(
                        value: 'archive_all',
                        child: Text('Archive all'),
                      ),
                    if (filter == _SharedFilter.archived)
                      const PopupMenuItem(
                        value: 'restore_all',
                        child: Text('Restore all'),
                      ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
            ],
          ),
          body: MbFloatingHintOverlay(
            hintKey: 'hint_journals_list',
            text: 'Search to filter. Tap an entry to open.',
            iconText: '🫧',
            child: Column(
              children: [
                if ((ref.watch(_pendingTierProvider).valueOrNull ?? false))
                  _TrialBanner(
                    onUpgrade: () {
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user == null) {
                        context.go('/signin?from=/subscription');
                      } else {
                        context.go('/subscription');
                      }
                    },
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
                  child: filter == _SharedFilter.blocked
                      ? (blockedRows.isEmpty
                            ? const Center(child: Text('No blocked users.'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: blockedRows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final row = blockedRows[i];
                                  final username =
                                      (row['blocked']?['username'] ?? '')
                                          .toString();
                                  return _GlowCard(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_off_outlined),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            username.isEmpty
                                                ? 'Unknown user'
                                                : '@$username',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            await Supabase.instance.client
                                                .from('journal_share_blocks')
                                                .delete()
                                                .eq('id', row['id']);
                                            ref.invalidate(
                                              blockedUsersProvider,
                                            );
                                          },
                                          child: const Text('Unblock'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ))
                      : (searched.isEmpty
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
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final raw = searched[i];
                                  final journal =
                                      raw['journal'] is Map<String, dynamic>
                                      ? (raw['journal'] as Map<String, dynamic>)
                                      : raw;
                                  final title =
                                      (journal['title'] as String?)
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? journal['title'] as String
                                      : 'Untitled entry';
                                  final createdAtRaw = journal['created_at']
                                      ?.toString();
                                  final createdAt = createdAtRaw != null
                                      ? DateFormat(
                                          'MMM d, yyyy • h:mm a',
                                        ).format(
                                          DateTime.parse(
                                            createdAtRaw,
                                          ).toLocal(),
                                        )
                                      : '';
                                  final id = journal['id'].toString();
                                  final isShared =
                                      journal['is_shared'] == true ||
                                      filter == _SharedFilter.sharedWithMe;
                                  final isArchived =
                                      journal['is_archived'] == true;
                                  final sharedBy = raw['owner'] is Map
                                      ? (raw['owner']['username'] ?? '')
                                            .toString()
                                      : '';

                                  final isSelected = selectedIds.contains(id);
                                  return _GlowCard(
                                    key: i == 0 ? _journalListItemKey : null,
                                    onTap: () {
                                      if (selectionMode) {
                                        final next = {...selectedIds};
                                        if (isSelected) {
                                          next.remove(id);
                                        } else {
                                          next.add(id);
                                        }
                                        ref
                                                .read(
                                                  _selectedIdsProvider.notifier,
                                                )
                                                .state =
                                            next;
                                        return;
                                      }
                                      context.go('/journals/view/$id');
                                    },
                                    child: Row(
                                      children: [
                                        if (selectionMode)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.check_circle
                                                  : Icons
                                                        .radio_button_unchecked,
                                              color: isSelected
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.outline,
                                            ),
                                          ),
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
                                                      Theme.of(
                                                        context,
                                                      ).textTheme.titleSmall,
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
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        filter ==
                                                                _SharedFilter
                                                                    .sharedWithMe
                                                            ? 'Shared with me'
                                                            : 'Shared',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (createdAt.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 6,
                                                      ),
                                                  child: Text(
                                                    createdAt,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              if (filter ==
                                                      _SharedFilter
                                                          .sharedWithMe &&
                                                  sharedBy.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    'Shared by @$sharedBy',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (!selectionMode &&
                                            filter !=
                                                _SharedFilter.sharedWithMe)
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                      title: const Text(
                                                        'Delete entry?',
                                                      ),
                                                      content: const Text(
                                                        'This cannot be undone.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Delete',
                                                          ),
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
                                        if (!selectionMode &&
                                            filter !=
                                                _SharedFilter.sharedWithMe)
                                          PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'open') {
                                                context.go(
                                                  '/journals/view/$id',
                                                );
                                              }
                                              if (value == 'archive') {
                                                await Supabase.instance.client
                                                    .from('journals')
                                                    .update({
                                                      'is_archived': true,
                                                    })
                                                    .eq('id', id);
                                                ref.invalidate(
                                                  journalsProvider,
                                                );
                                              }
                                              if (value == 'unarchive') {
                                                await Supabase.instance.client
                                                    .from('journals')
                                                    .update({
                                                      'is_archived': false,
                                                    })
                                                    .eq('id', id);
                                                ref.invalidate(
                                                  journalsProvider,
                                                );
                                              }
                                              if (value == 'unshare') {
                                                await Supabase.instance.client
                                                    .from('journals')
                                                    .update({
                                                      'is_shared': false,
                                                    })
                                                    .eq('id', id);
                                                ref.invalidate(
                                                  journalsProvider,
                                                );
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'open',
                                                child: Text('Open'),
                                              ),
                                              if (!isArchived)
                                                const PopupMenuItem(
                                                  value: 'archive',
                                                  child: Text('Archive'),
                                                ),
                                              if (isArchived)
                                                const PopupMenuItem(
                                                  value: 'unarchive',
                                                  child: Text('Unarchive'),
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
                              )),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            key: _addJournalButtonKey,
            onPressed: handleAdd,
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: _SharedFilterBar(
            rowKey: _categoryTabsScrollKey,
            value: filter,
            sharedCount: sharedCount,
            archivedCount: archivedCount,
            blockedCount: blockedCount,
            onChanged: (v) =>
                ref.read(_sharedFilterProvider.notifier).state = v,
          ),
        );
      },
      loading: () => MbScaffold(
        applyBackground: true,
        appBar: AppBar(
          title: const Text('Journal'),
          centerTitle: true,
          leading: MbGlowBackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => MbScaffold(
        applyBackground: true,
        appBar: AppBar(
          title: const Text('Journal'),
          centerTitle: true,
          leading: MbGlowBackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: Center(child: Text('Failed to load journals: $e')),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'FREE MODE uses 24-hour preview mode for templates. Preview data disappears after 24 hours.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onUpgrade,
                  child: const Text('View modes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SharedFilter { all, shared, unshared, archived, sharedWithMe, blocked }

final _sharedFilterProvider = StateProvider<_SharedFilter>(
  (ref) => _SharedFilter.all,
);
final _searchQueryProvider = StateProvider<String>((ref) => '');
final _selectionModeProvider = StateProvider<bool>((ref) => false);
final _selectedIdsProvider = StateProvider<Set<String>>((ref) => {});
final blockedUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];
      final rows = await Supabase.instance.client
          .from('journal_share_blocks')
          .select('id, blocked_id, blocked:blocked_id (username)')
          .eq('blocker_id', user.id)
          .order('created_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    });

class _SharedFilterBar extends StatelessWidget {
  const _SharedFilterBar({
    required this.value,
    required this.sharedCount,
    required this.archivedCount,
    required this.blockedCount,
    required this.onChanged,
    this.rowKey,
  });

  final _SharedFilter value;
  final int sharedCount;
  final int archivedCount;
  final int blockedCount;
  final ValueChanged<_SharedFilter> onChanged;
  final GlobalKey? rowKey;

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
            key: rowKey,
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
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: value == _SharedFilter.archived,
                  label: Text('Archived ($archivedCount)'),
                  onSelected: (_) => onChanged(_SharedFilter.archived),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: value == _SharedFilter.sharedWithMe,
                  label: const Text('Shared with me'),
                  onSelected: (_) => onChanged(_SharedFilter.sharedWithMe),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: value == _SharedFilter.blocked,
                  label: Text('Blocked ($blockedCount)'),
                  onSelected: (_) => onChanged(_SharedFilter.blocked),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(switch (value) {
              _SharedFilter.shared => 'Showing shared entries',
              _SharedFilter.unshared => 'Showing unshared entries',
              _SharedFilter.archived => 'Showing archived entries',
              _SharedFilter.sharedWithMe => 'Entries shared with you',
              _SharedFilter.blocked => 'People you blocked',
              _SharedFilter.all => 'All entries',
            }, style: Theme.of(context).textTheme.bodySmall),
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
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
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
  const _GlowCard({super.key, required this.child, this.onTap});

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
