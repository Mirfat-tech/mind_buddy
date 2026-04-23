import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'package:mind_buddy/features/journal/journal_folder_support.dart';
import 'journals_provider.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:mind_buddy/services/block_service.dart';
import 'package:mind_buddy/services/username_resolver_service.dart';
import 'package:mind_buddy/services/journal_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JournalsListScreen extends ConsumerStatefulWidget {
  JournalsListScreen({super.key});

  @override
  ConsumerState<JournalsListScreen> createState() => _JournalsListScreenState();
}

class _JournalsListScreenState extends ConsumerState<JournalsListScreen> {
  final GlobalKey _selectSquareButtonKey = GlobalKey();
  final GlobalKey _journalListItemKey = GlobalKey();
  final GlobalKey _deleteIconKey = GlobalKey();
  final GlobalKey _addJournalButtonKey = GlobalKey();
  final GlobalKey _categoryTabsScrollKey = GlobalKey();
  final JournalRepository _journalRepository = JournalRepository();

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
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showGuideIfNeeded(context),
    );
    final journalsAsync = ref.watch(journalsProvider);
    final sharedWithMeAsync = ref.watch(sharedWithMeProvider);
    final foldersAsync = ref.watch(journalFoldersProvider);
    final blockedAsync = ref.watch(blockedUsersProvider);
    final filter = ref.watch(_sharedFilterProvider);
    final search = ref.watch(_searchQueryProvider);
    final selectionMode = ref.watch(_selectionModeProvider);
    final selectedIds = ref.watch(_selectedIdsProvider);
    final selectedFolderId = ref.watch(_selectedFolderIdProvider);
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
      final localEntries = await ref
          .read(journalLocalRepositoryProvider)
          .loadOwnedJournals();
      final used = localEntries.where((entry) {
        final createdAt = DateTime.tryParse(
          (entry['created_at'] ?? '').toString(),
        )?.toLocal();
        if (createdAt == null) return false;
        return !createdAt.isBefore(startOfDay) && createdAt.isBefore(endOfDay);
      }).length;
      if (info.journalLimit >= 0 && used >= info.journalLimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily journal limit reached for ${info.planName}.'),
          ),
        );
        return;
      }
      context.go('/journals/new');
    }

    Future<void> openBlockUserSheet() async {
      final controller = TextEditingController();
      final focus = FocusNode();
      List<Map<String, dynamic>> suggestions = const <Map<String, dynamic>>[];
      Map<String, dynamic>? selected;
      String? errorText;
      bool busy = false;
      Timer? debounce;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (focus.canRequestFocus) focus.requestFocus();
          });
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final insets = MediaQuery.of(ctx).viewInsets.bottom;
              return Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, insets + 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Block user',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        focusNode: focus,
                        autofocus: true,
                        onChanged: (raw) {
                          selected = null;
                          debounce?.cancel();
                          debounce = Timer(
                            const Duration(milliseconds: 200),
                            () async {
                              final query = raw.trim();
                              if (query.isEmpty) {
                                setSheetState(() {
                                  suggestions = const <Map<String, dynamic>>[];
                                  errorText = null;
                                });
                                return;
                              }
                              final rows = await UsernameResolverService
                                  .instance
                                  .searchUsernames(query, maxResults: 8);
                              setSheetState(() {
                                suggestions = rows;
                                errorText = null;
                              });
                            },
                          );
                        },
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: '@username',
                          errorText: errorText,
                        ),
                      ),
                      if (suggestions.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              final row = suggestions[index];
                              final username = (row['username'] ?? '')
                                  .toString();
                              final id = row['id']?.toString() ?? '';
                              if (username.isEmpty || id.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return ListTile(
                                dense: true,
                                title: Text('@$username'),
                                trailing: selected?['id']?.toString() == id
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () {
                                  controller.text = '@$username';
                                  controller.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: controller.text.length,
                                        ),
                                      );
                                  setSheetState(() {
                                    selected = {'id': id, 'username': username};
                                    suggestions =
                                        const <Map<String, dynamic>>[];
                                    errorText = null;
                                  });
                                  focus.requestFocus();
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: busy ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final typed = controller.text.trim();
                                    if (typed.isEmpty) {
                                      setSheetState(
                                        () => errorText = 'Select a user',
                                      );
                                      return;
                                    }
                                    setSheetState(() => busy = true);
                                    final selectedUsername =
                                        selected?['username']?.toString();
                                    final useInput = selectedUsername == null
                                        ? typed
                                        : '@$selectedUsername';
                                    final err = await BlockService.instance
                                        .blockByUsername(useInput);
                                    if (!ctx.mounted) return;
                                    if (err != null) {
                                      setSheetState(() {
                                        busy = false;
                                        errorText = err;
                                      });
                                      return;
                                    }
                                    ref.invalidate(blockedUsersProvider);
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('User blocked.'),
                                      ),
                                    );
                                  },
                            child: const Text('Block'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      debounce?.cancel();
      controller.dispose();
      focus.dispose();
    }

    Future<void> archiveAllVisible(List<Map<String, dynamic>> items) async {
      if (items.isEmpty) return;
      final ids = items.map((e) => e['id']).toList();
      await ref
          .read(journalLocalRepositoryProvider)
          .setArchived(ids.map((id) => id.toString()), true);
      ref.invalidate(journalsProvider);
    }

    Future<void> restoreAllVisible(List<Map<String, dynamic>> items) async {
      if (items.isEmpty) return;
      final ids = items.map((e) => e['id']).toList();
      await ref
          .read(journalLocalRepositoryProvider)
          .setArchived(ids.map((id) => id.toString()), false);
      ref.invalidate(journalsProvider);
    }

    Future<void> archiveSelected() async {
      if (selectedIds.isEmpty) return;
      await ref
          .read(journalLocalRepositoryProvider)
          .setArchived(selectedIds, true);
      ref.read(_selectedIdsProvider.notifier).state = {};
      ref.read(_selectionModeProvider.notifier).state = false;
      ref.invalidate(journalsProvider);
    }

    Future<void> restoreSelected() async {
      if (selectedIds.isEmpty) return;
      await ref
          .read(journalLocalRepositoryProvider)
          .setArchived(selectedIds, false);
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
      for (final id in selectedIds) {
        await ref.read(journalLocalRepositoryProvider).deleteJournal(id);
      }
      ref.read(_selectedIdsProvider.notifier).state = {};
      ref.read(_selectionModeProvider.notifier).state = false;
      ref.invalidate(journalsProvider);
    }

    return journalsAsync.when(
      data: (rows) {
        final viewerUserId =
            Supabase.instance.client.auth.currentUser?.id ?? '';
        developer.log(
          'journal_share event=journals_list_fetch_start data={tab: ${filter.name}, search: ${search.trim()}, viewer_user_id: $viewerUserId}',
          name: 'journal_share',
        );
        final sharedWithMeRows = sharedWithMeAsync.when(
          data: (r) => r,
          loading: () => <Map<String, dynamic>>[],
          error: (_, __) => <Map<String, dynamic>>[],
        );
        final blockedRows = blockedAsync.when(
          data: (r) => r,
          loading: () => <Map<String, dynamic>>[],
          error: (_, __) => <Map<String, dynamic>>[],
        );
        final folders = foldersAsync.when(
          data: (value) => value,
          loading: () => const <JournalFolder>[],
          error: (_, __) => const <JournalFolder>[],
        );
        final ownedRows = List<Map<String, dynamic>>.from(rows);
        final sharedCards = sharedWithMeRows
            .map((raw) {
              final journal = raw['journal'] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(
                      raw['journal'] as Map<String, dynamic>,
                    )
                  : <String, dynamic>{};
              final journalId =
                  (raw['journal_id']?.toString() ??
                          journal['id']?.toString() ??
                          '')
                      .trim();
              if (journalId.isEmpty) return <String, dynamic>{};
              journal['id'] = journalId;
              return <String, dynamic>{
                ...raw,
                'journal': journal,
                'id': journalId,
                'source': 'shared_with_me',
              };
            })
            .where((r) => r.isNotEmpty)
            .toList();
        final sharedOwnedRows = ownedRows
            .where((r) => r['is_shared'] == true && r['is_archived'] != true)
            .toList();
        final archivedCount = ownedRows
            .where((r) => r['is_archived'] == true)
            .length;
        final activeCount = ownedRows
            .where((r) => r['is_archived'] != true)
            .length;
        debugPrint(
          'JOURNAL_ARCHIVE_FILTER_LOCAL archivedCount=$archivedCount activeCount=$activeCount',
        );
        final blockedCount = blockedRows.length;
        final sharedCount = sharedOwnedRows.length + sharedWithMeRows.length;
        final filtered = switch (filter) {
          _SharedFilter.shared => sharedOwnedRows,
          _SharedFilter.unshared =>
            ownedRows
                .where(
                  (r) => r['is_shared'] != true && r['is_archived'] != true,
                )
                .toList(),
          _SharedFilter.sharedWithMe => sharedCards,
          _SharedFilter.archived =>
            ownedRows.where((r) => r['is_archived'] == true).toList(),
          _SharedFilter.blocked => const <Map<String, dynamic>>[],
          _SharedFilter.all =>
            ownedRows.where((r) => r['is_archived'] != true).toList(),
        };
        final query = search.trim().toLowerCase();
        final searchedBase = query.isEmpty
            ? filtered
            : filtered.where((r) {
                final journal = r['journal'] is Map<String, dynamic>
                    ? (r['journal'] as Map<String, dynamic>)
                    : r;
                final title = (journal['title'] ?? '').toString().toLowerCase();
                final text = (journal['text'] ?? '').toString().toLowerCase();
                return title.contains(query) || text.contains(query);
              }).toList();
        final foldersEnabled = _supportsFolderLayout(filter);
        final visibleEntries = foldersEnabled && selectedFolderId != null
            ? searchedBase
                  .where(
                    (entry) =>
                        entry['folder_id']?.toString() == selectedFolderId,
                  )
                  .toList()
            : foldersEnabled
            ? searchedBase
                  .where(
                    (entry) => (entry['folder_id']?.toString() ?? '').isEmpty,
                  )
                  .toList()
            : searchedBase;
        if (foldersEnabled) {
          debugPrint(
            'JOURNAL_FOLDER_FILTER_LOCAL folderId=${selectedFolderId ?? '__none__'} count=${visibleEntries.length}',
          );
        }
        final folderCards = folders
            .map(
              (folder) => (
                folder: folder,
                count: searchedBase
                    .where(
                      (entry) => entry['folder_id']?.toString() == folder.id,
                    )
                    .length,
              ),
            )
            .where((item) => item.count > 0 || query.isEmpty)
            .toList();
        developer.log(
          'journal_share event=journals_list_render_count data={tab: ${filter.name}, filtered_count: ${filtered.length}, rendered_card_count: ${visibleEntries.length}}',
          name: 'journal_share',
        );

        return MbScaffold(
          applyBackground: true,
          appBar: AppBar(
            title: const Text('Journal'),
            centerTitle: true,
            leading: MbGlowBackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
            actions: [
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
                    final ids = visibleEntries
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
                        List<Map<String, dynamic>>.from(visibleEntries),
                      );
                    }
                    if (value == 'restore_all') {
                      await restoreAllVisible(
                        List<Map<String, dynamic>>.from(visibleEntries),
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
                      ? _buildBlockedList(blockedRows)
                      : _buildJournalBody(
                          context: context,
                          filter: filter,
                          query: query,
                          selectionMode: selectionMode,
                          selectedIds: selectedIds,
                          folders: folders,
                          foldersEnabled: foldersEnabled,
                          folderCards: folderCards,
                          foldersLoading: foldersAsync.isLoading,
                          selectedFolderId: selectedFolderId,
                          visibleEntries: visibleEntries,
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            key: _addJournalButtonKey,
            onPressed: filter == _SharedFilter.blocked
                ? openBlockUserSheet
                : handleAdd,
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: _SharedFilterBar(
            rowKey: _categoryTabsScrollKey,
            value: filter,
            sharedCount: sharedCount,
            archivedCount: archivedCount,
            blockedCount: blockedCount,
            onChanged: (v) {
              ref.read(_sharedFilterProvider.notifier).state = v;
              if (!_supportsFolderLayout(v)) {
                ref.read(_selectedFolderIdProvider.notifier).state = null;
              }
            },
          ),
        );
      },
      loading: () => MbScaffold(
        applyBackground: true,
        appBar: AppBar(
          title: const Text('Journal'),
          centerTitle: true,
          leading: MbGlowBackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
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
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        body: Center(child: Text('Failed to load journals: $e')),
      ),
    );
  }

  bool _supportsFolderLayout(_SharedFilter filter) {
    return filter == _SharedFilter.all ||
        filter == _SharedFilter.shared ||
        filter == _SharedFilter.unshared ||
        filter == _SharedFilter.archived;
  }

  Widget _buildBlockedList(List<Map<String, dynamic>> blockedRows) {
    if (blockedRows.isEmpty) {
      return const Center(child: Text('No blocked users.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: blockedRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final row = blockedRows[i];
        final username = (row['username'] ?? '').toString();
        final blockedId = row['blocked_id']?.toString() ?? '';
        return _GlowCard(
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
                    : () async {
                        await BlockService.instance.unblockUser(blockedId);
                        ref.invalidate(blockedUsersProvider);
                      },
                child: const Text('Unblock'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJournalBody({
    required BuildContext context,
    required _SharedFilter filter,
    required String query,
    required bool selectionMode,
    required Set<String> selectedIds,
    required List<JournalFolder> folders,
    required bool foldersEnabled,
    required List<({JournalFolder folder, int count})> folderCards,
    required bool foldersLoading,
    required String? selectedFolderId,
    required List<Map<String, dynamic>> visibleEntries,
  }) {
    if (visibleEntries.isEmpty && (!foldersEnabled || folderCards.isEmpty)) {
      return Center(
        child: Text(
          query.isEmpty ? 'No entries yet.' : 'No matches for "$query".',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
      children: [
        if (foldersEnabled)
          _FolderSection(
            folders: folderCards,
            selectedFolderId: selectedFolderId,
            searchQuery: query,
            isLoading: foldersLoading,
            onCreate: () => _createFolder(context),
            onSelectFolder: (folderId) {
              ref.read(_selectedFolderIdProvider.notifier).state = folderId;
            },
            onEdit: (folder) => _editFolder(context, folder),
            onDelete: (folder) => _deleteFolder(context, folder),
          ),
        if (foldersEnabled) const SizedBox(height: 18),
        if (foldersEnabled)
          _SectionHeader(
            title: selectedFolderId == null
                ? 'Unfiled entries'
                : _folderNameFor(folders, selectedFolderId),
            subtitle: selectedFolderId == null
                ? 'Entries waiting to be sorted.'
                : 'Entries inside this folder.',
          ),
        if (foldersEnabled) const SizedBox(height: 10),
        if (visibleEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text(
                selectedFolderId == null
                    ? 'No unfiled entries yet.'
                    : 'No entries in this folder yet.',
              ),
            ),
          )
        else
          ...List.generate(
            visibleEntries.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleEntries.length - 1 ? 0 : 10,
              ),
              child: _buildEntryCard(
                context: context,
                raw: visibleEntries[index],
                filter: filter,
                query: query,
                selectionMode: selectionMode,
                selectedIds: selectedIds,
                isFirst: index == 0,
                folders: folders,
              ),
            ),
          ),
      ],
    );
  }

  String _folderNameFor(List<JournalFolder> folders, String? folderId) {
    for (final folder in folders) {
      if (folder.id == folderId) {
        return folder.name;
      }
    }
    return 'Folder';
  }

  Future<void> _createFolder(BuildContext context) async {
    developer.log(
      'journal_folder event=create_dialog_open',
      name: 'journal_folder',
    );
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _FolderEditorDialog(),
    );
    if (created != true) return;
    ref.invalidate(journalFoldersProvider);
  }

  Future<void> _editFolder(BuildContext context, JournalFolder folder) async {
    developer.log(
      'journal_folder event=edit_dialog_open data={folder_id: ${folder.id}}',
      name: 'journal_folder',
    );
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _FolderEditorDialog(initialFolder: folder),
    );
    if (updated != true) return;
    ref.invalidate(journalFoldersProvider);
  }

  Future<void> _deleteFolder(BuildContext context, JournalFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${folder.name}?'),
        content: const Text(
          'Entries in this folder will move back to unfiled.',
        ),
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
    await JournalFolderSupport.deleteFolder(folder.id);
    if (ref.read(_selectedFolderIdProvider) == folder.id) {
      ref.read(_selectedFolderIdProvider.notifier).state = null;
    }
    ref.invalidate(journalsProvider);
    ref.invalidate(journalFoldersProvider);
  }

  Future<void> _pickEntryFolder(
    BuildContext context, {
    required String journalId,
    required String? currentFolderId,
    required List<JournalFolder> folders,
  }) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.inbox_rounded),
              title: const Text('No folder'),
              trailing: currentFolderId == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, null),
            ),
            for (final folder in folders)
              ListTile(
                leading: Icon(
                  JournalFolderSupport.styleFor(folder.iconStyle).icon,
                  color: JournalFolderSupport.paletteFor(folder.colorKey).color,
                ),
                title: Text(folder.name),
                trailing: currentFolderId == folder.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, folder.id),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == currentFolderId) return;
    await JournalFolderSupport.assignEntryToFolder(journalId, selected);
    ref.invalidate(journalsProvider);
    ref.invalidate(journalFoldersProvider);
  }

  Widget _buildEntryCard({
    required BuildContext context,
    required Map<String, dynamic> raw,
    required _SharedFilter filter,
    required String query,
    required bool selectionMode,
    required Set<String> selectedIds,
    required bool isFirst,
    required List<JournalFolder> folders,
  }) {
    final isSharedWithMe = filter == _SharedFilter.sharedWithMe;
    final journal = raw['journal'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw['journal'] as Map<String, dynamic>)
        : raw;
    final title = (journal['title'] as String?)?.trim().isNotEmpty == true
        ? journal['title'] as String
        : 'Untitled entry';
    final createdAtRaw = journal['created_at']?.toString();
    final createdAt = createdAtRaw != null
        ? DateFormat(
            'MMM d, yyyy • h:mm a',
          ).format(DateTime.parse(createdAtRaw).toLocal())
        : '';
    final openJournalId = isSharedWithMe
        ? (raw['journal_id']?.toString() ?? journal['id']?.toString() ?? '')
        : (journal['id']?.toString() ?? '');
    if (openJournalId.isEmpty) {
      return const SizedBox.shrink();
    }
    final isShared = journal['is_shared'] == true || isSharedWithMe;
    final isArchived = journal['is_archived'] == true;
    final sharedBy = (raw['owner_username'] ?? '').toString();
    final isSelected = selectedIds.contains(openJournalId);
    final folderId = journal['folder_id']?.toString();
    JournalFolder? folder;
    for (final item in folders) {
      if (item.id == folderId) {
        folder = item;
        break;
      }
    }

    return _GlowCard(
      key: isFirst ? _journalListItemKey : null,
      onTap: () {
        if (selectionMode) {
          final next = {...selectedIds};
          if (isSelected) {
            next.remove(openJournalId);
          } else {
            next.add(openJournalId);
          }
          ref.read(_selectedIdsProvider.notifier).state = next;
          return;
        }
        final source = isSharedWithMe ? 'shared' : 'owned';
        final entryPayload = Map<String, dynamic>.from(journal);
        entryPayload['id'] = openJournalId;
        context.go(
          '/journals/view/$openJournalId',
          extra: <String, dynamic>{
            'entry': entryPayload,
            'source': source,
            'share_row_id': raw['id'],
            'journal_id': raw['journal_id'],
          },
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          if (!selectionMode && filter != _SharedFilter.sharedWithMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete entry?'),
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
                      await ref
                          .read(journalLocalRepositoryProvider)
                          .deleteJournal(openJournalId);
                      ref.invalidate(journalsProvider);
                      ref.invalidate(journalFoldersProvider);
                    },
                  ),
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'open') {
                        final entryPayload = Map<String, dynamic>.from(journal);
                        entryPayload['id'] = openJournalId;
                        context.go(
                          '/journals/view/$openJournalId',
                          extra: <String, dynamic>{
                            'entry': entryPayload,
                            'source': 'owned',
                            'share_row_id': raw['id'],
                            'journal_id': raw['journal_id'],
                          },
                        );
                      }
                      if (value == 'move_folder') {
                        await _pickEntryFolder(
                          context,
                          journalId: openJournalId,
                          currentFolderId: (folderId ?? '').isEmpty
                              ? null
                              : folderId,
                          folders: folders,
                        );
                      }
                      if (value == 'remove_folder') {
                        await JournalFolderSupport.assignEntryToFolder(
                          openJournalId,
                          null,
                        );
                        ref.invalidate(journalsProvider);
                        ref.invalidate(journalFoldersProvider);
                      }
                      if (value == 'archive') {
                        await ref
                            .read(journalLocalRepositoryProvider)
                            .setArchived(<String>{openJournalId}, true);
                        ref.invalidate(journalsProvider);
                      }
                      if (value == 'unarchive') {
                        await ref
                            .read(journalLocalRepositoryProvider)
                            .setArchived(<String>{openJournalId}, false);
                        ref.invalidate(journalsProvider);
                      }
                      if (value == 'unshare') {
                        await _journalRepository.unshareAllForJournal(
                          openJournalId,
                        );
                        ref.invalidate(journalsProvider);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'open', child: Text('Open')),
                      const PopupMenuItem(
                        value: 'move_folder',
                        child: Text('Move to folder'),
                      ),
                      if ((folderId ?? '').isNotEmpty)
                        const PopupMenuItem(
                          value: 'remove_folder',
                          child: Text('Remove from folder'),
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
                  ),
                ],
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _highlightText(
                  title,
                  query,
                  Theme.of(context).textTheme.titleSmall,
                ),
                if (createdAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      createdAt,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (filter == _SharedFilter.sharedWithMe && sharedBy.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Shared by @$sharedBy',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (folder != null || isShared)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (folder != null) _FolderBadge(folder: folder),
                        if (isShared)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              filter == _SharedFilter.sharedWithMe
                                  ? 'Shared with me'
                                  : 'Shared',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
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
                  SubscriptionPlanCatalog.previewModeHelpText,
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
                  child: const Text('See plans'),
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
final _selectedFolderIdProvider = StateProvider<String?>((ref) => null);
final blockedUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      return BlockService.instance.listBlockedUsers();
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection({
    required this.folders,
    required this.selectedFolderId,
    required this.searchQuery,
    required this.isLoading,
    required this.onCreate,
    required this.onSelectFolder,
    required this.onEdit,
    required this.onDelete,
  });

  final List<({JournalFolder folder, int count})> folders;
  final String? selectedFolderId;
  final String searchQuery;
  final bool isLoading;
  final VoidCallback onCreate;
  final ValueChanged<String?> onSelectFolder;
  final ValueChanged<JournalFolder> onEdit;
  final ValueChanged<JournalFolder> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionHeader(
                title: 'Folders',
                subtitle:
                    'Create calm journal spaces for themes, moods, and chapters.',
              ),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New folder'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FolderFilterCard(
              title: 'Unfiled',
              subtitle: 'Loose entries',
              selected: selectedFolderId == null,
              color: Theme.of(context).colorScheme.secondaryContainer,
              tint: Theme.of(context).colorScheme.surface,
              icon: Icons.inbox_rounded,
              onTap: () => onSelectFolder(null),
            ),
            for (final item in folders)
              _FolderFilterCard(
                title: item.folder.name,
                subtitle: item.count == 1 ? '1 entry' : '${item.count} entries',
                selected: selectedFolderId == item.folder.id,
                color: JournalFolderSupport.paletteFor(
                  item.folder.colorKey,
                ).color,
                tint: JournalFolderSupport.paletteFor(
                  item.folder.colorKey,
                ).tint,
                icon: JournalFolderSupport.styleFor(item.folder.iconStyle).icon,
                onTap: () => onSelectFolder(item.folder.id),
                onEdit: () => onEdit(item.folder),
                onDelete: () => onDelete(item.folder),
              ),
            if (isLoading)
              const SizedBox(
                width: 120,
                height: 92,
                child: Center(child: CircularProgressIndicator()),
              ),
            if (folders.isEmpty && !isLoading && searchQuery.isEmpty)
              _FolderFilterCard(
                title: 'Create a folder',
                subtitle: 'Sort entries by topic, feeling, or season.',
                selected: false,
                color: Theme.of(context).colorScheme.primaryContainer,
                tint: Theme.of(context).colorScheme.surface,
                icon: Icons.auto_stories_rounded,
                onTap: onCreate,
              ),
          ],
        ),
      ],
    );
  }
}

class _FolderFilterCard extends StatelessWidget {
  const _FolderFilterCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.tint,
    required this.icon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final Color tint;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 182,
      child: Material(
        color: selected ? tint : scheme.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? color : scheme.outline.withOpacity(0.2),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const Spacer(),
                    if (onEdit != null || onDelete != null)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') onEdit?.call();
                          if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        icon: const Icon(Icons.more_horiz),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderBadge extends StatelessWidget {
  const _FolderBadge({required this.folder});

  final JournalFolder folder;

  @override
  Widget build(BuildContext context) {
    final palette = JournalFolderSupport.paletteFor(folder.colorKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            JournalFolderSupport.styleFor(folder.iconStyle).icon,
            size: 14,
            color: palette.color,
          ),
          const SizedBox(width: 4),
          Text(
            folder.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderEditorDialog extends StatefulWidget {
  const _FolderEditorDialog({this.initialFolder});

  final JournalFolder? initialFolder;

  @override
  State<_FolderEditorDialog> createState() => _FolderEditorDialogState();
}

class _FolderEditorDialogState extends State<_FolderEditorDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late String _colorKey;
  late String _iconStyle;
  String? _errorText;
  bool _submitting = false;

  bool get _isEditing => widget.initialFolder != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialFolder?.name ?? '');
    _focusNode = FocusNode();
    _colorKey =
        widget.initialFolder?.colorKey ??
        JournalFolderSupport.palette.first.key;
    _iconStyle =
        widget.initialFolder?.iconStyle ??
        JournalFolderSupport.styles.first.key;
    developer.log(
      'journal_folder event=dialog_init data={mode: ${_isEditing ? 'edit' : 'create'}}',
      name: 'journal_folder',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    developer.log(
      'journal_folder event=dialog_dispose data={mode: ${_isEditing ? 'edit' : 'create'}, submitting: $_submitting}',
      name: 'journal_folder',
    );
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a folder name');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    developer.log(
      'journal_folder event=submit_start data={mode: ${_isEditing ? 'edit' : 'create'}, name: $name, color: $_colorKey, icon: $_iconStyle}',
      name: 'journal_folder',
    );

    try {
      if (_isEditing) {
        await JournalFolderSupport.updateFolder(
          widget.initialFolder!.id,
          name: name,
          colorKey: _colorKey,
          iconStyle: _iconStyle,
        );
      } else {
        await JournalFolderSupport.createFolder(
          name: name,
          colorKey: _colorKey,
          iconStyle: _iconStyle,
        );
      }
      developer.log(
        'journal_folder event=submit_success data={mode: ${_isEditing ? 'edit' : 'create'}}',
        name: 'journal_folder',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      developer.log(
        'journal_folder event=submit_error data={mode: ${_isEditing ? 'edit' : 'create'}, error: $error}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      final debugMessage = JournalFolderSupport.userFacingError(error);
      setState(() {
        _submitting = false;
        _errorText = debugMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit folder' : 'Create folder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Folder name',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            Text('Colour', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in JournalFolderSupport.palette)
                  ChoiceChip(
                    selected: _colorKey == item.key,
                    label: Text(item.key),
                    avatar: CircleAvatar(backgroundColor: item.color),
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _colorKey = item.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Style', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in JournalFolderSupport.styles)
                  ChoiceChip(
                    selected: _iconStyle == style.key,
                    label: Text(style.label),
                    avatar: Icon(style.icon, size: 18),
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _iconStyle = style.key),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
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
