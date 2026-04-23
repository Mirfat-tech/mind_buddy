import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'log_table_screen.dart';
import 'create_templates_screen.dart';
import 'package:mind_buddy/router.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'package:mind_buddy/features/templates/template_preview_store.dart';
import 'package:mind_buddy/features/templates/data/repository/custom_templates_repository.dart';

enum _CustomTemplateAction { edit, delete }

class _TemplateDeleteResult {
  const _TemplateDeleteResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  bool loading = true;
  List<Map<String, dynamic>> templates = [];
  bool _showHidden = false;
  Set<String> _hiddenTemplateIds = {};
  bool _isPending = false;
  late final _TrialBannerController _trialBannerController;
  final GlobalKey _templateListItemKey = GlobalKey();
  final GlobalKey _hideToggleKey = GlobalKey();
  final GlobalKey _addTemplateButtonKey = GlobalKey();
  final Set<String> _deletingTemplateIds = <String>{};
  static const _hiddenPrefsKey = 'hidden_template_ids_local';

  @override
  void initState() {
    super.initState();
    _trialBannerController = _TrialBannerController()..init();
    _load();
  }

  @override
  void dispose() {
    GuideManager.dismissActiveGuideForPage('templates');
    _searchController.dispose();
    super.dispose();
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  String _tableNameForTemplateKey(String templateKey) {
    final key = templateKey.toLowerCase();
    switch (key) {
      case 'goals':
        return 'goal_logs';
      case 'water':
        return 'water_logs';
      case 'sleep':
        return 'sleep_logs';
      case 'medication':
        return 'medication_logs';
      case 'meals':
        return 'meals_logs';
      case 'cycle':
        return 'menstrual_logs';
      case 'books':
        return 'book_logs';
      case 'income':
        return 'income_logs';
      case 'wishlist':
        return 'wishlist';
      case 'restaurants':
        return 'restaurant_logs';
      case 'movies':
        return 'movie_logs';
      case 'bills':
        return 'bill_logs';
      case 'expenses':
        return 'expense_logs';
      case 'places':
        return 'place_logs';
      case 'tasks':
        return 'task_logs';
      case 'fast':
        return 'fast_logs';
      case 'meditation':
        return 'meditation_logs';
      case 'skin_care':
        return 'skin_care_logs';
      case 'social':
        return 'social_logs';
      case 'study':
        return 'study_logs';
      case 'workout':
        return 'workout_logs';
      case 'tv_log':
        return 'tv_logs';
      case 'mood':
        return 'mood_logs';
      case 'symptoms':
        return 'symptom_logs';
      default:
        return '${key}_logs';
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final info = await SubscriptionLimits.fetchForCurrentUser();
      _isPending = info.isPending;
      final prefs = await SharedPreferences.getInstance();
      _hiddenTemplateIds =
          prefs.getStringList(_hiddenPrefsKey)?.toSet() ?? <String>{};
      final repo = ref.read(customTemplatesRepositoryProvider);
      final records = await repo.loadTemplates(userId: user.id);
      final all = records
          .where((t) => t.templateKey != 'habits')
          .map(
            (t) => <String, dynamic>{
              'id': t.id,
              'name': t.name,
              'template_key': t.templateKey,
              'user_id': t.userId,
              'is_built_in': t.isBuiltIn,
            },
          )
          .toList(growable: false);

      if (mounted) {
        setState(() {
          final sorted = List<Map<String, dynamic>>.from(all)
            ..sort(
              (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              ),
            );
          templates = _showHidden
              ? sorted
                    .where(
                      (t) => _hiddenTemplateIds.contains(
                        (t['id'] ?? '').toString(),
                      ),
                    )
                    .toList()
              : sorted
                    .where(
                      (t) => !_hiddenTemplateIds.contains(
                        (t['id'] ?? '').toString(),
                      ),
                    )
                    .toList();
          loading = false;
        });
        _scheduleGuideAutoStart();
      }
    } catch (e) {
      debugPrint('Load error: $e');
      if (mounted) setState(() => loading = false);
      _scheduleGuideAutoStart();
    }
  }

  Future<_TemplateDeleteResult> _deleteTemplate(
    Map<String, dynamic> template, {
    required String templateKey,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const _TemplateDeleteResult(
        success: false,
        message: 'You need to be signed in to delete templates.',
      );
    }

    final templateId = (template['id'] ?? '').toString();
    final ownerId = (template['user_id'] ?? '').toString();
    if (templateId.isEmpty || ownerId != user.id) {
      return const _TemplateDeleteResult(
        success: false,
        message: 'Only templates you created can be deleted.',
      );
    }

    try {
      final repo = ref.read(customTemplatesRepositoryProvider);
      final existingTemplate = await repo.loadTemplateById(
        templateId: templateId,
        userId: user.id,
      );
      if (existingTemplate == null) {
        return const _TemplateDeleteResult(
          success: true,
          message: 'That template is already gone.',
        );
      }
      try {
        await TemplatePreviewStore.saveEntries(
          userId: user.id,
          tableName: _tableNameForTemplateKey(templateKey),
          entries: const <Map<String, dynamic>>[],
        );
      } catch (_) {
        // Keep the local deletion successful even if preview cleanup fails.
      }
      await repo.deleteTemplate(
        templateId: templateId,
        templateKey: templateKey,
        userId: user.id,
      );
      _hiddenTemplateIds.remove(templateId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _hiddenPrefsKey,
        _hiddenTemplateIds.toList(growable: false),
      );
      await _load();
      return const _TemplateDeleteResult(success: true);
    } catch (e) {
      debugPrint('Delete failed: $e');
      return _TemplateDeleteResult(
        success: false,
        message: _deleteFailureMessage(e),
      );
    }
  }

  String _deleteFailureMessage(Object error) {
    return error.toString();
  }

  Future<void> _setHidden(String templateId, bool hidden) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = Set<String>.from(_hiddenTemplateIds);
      if (hidden) {
        next.add(templateId);
      } else {
        next.remove(templateId);
      }
      await prefs.setStringList(_hiddenPrefsKey, next.toList(growable: false));
      if (!mounted) return;
      setState(() => _hiddenTemplateIds = next);
      await _load();
    } catch (e) {
      debugPrint('Hide failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hide failed: $e')));
      }
    }
  }

  Future<void> _openEditTemplate(Map<String, dynamic> template) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => themed(
          CreateLogTemplateScreen(
            templateId: (template['id'] ?? '').toString(),
          ),
        ),
      ),
    );
    if (ok == true) {
      await _load();
    }
  }

  Future<void> _confirmDeleteTemplate(Map<String, dynamic> template) async {
    final user = supabase.auth.currentUser;
    final templateId = (template['id'] ?? '').toString();
    final ownerId = (template['user_id'] ?? '').toString();
    final title = (template['name'] ?? template['template_key'] ?? 'template')
        .toString();
    if (user == null || templateId.isEmpty || ownerId != user.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only templates you created can be deleted.'),
        ),
      );
      return;
    }

    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this template?'),
        content: const Text(
          'This will delete the template and the logs connected to it. Older entries will not be recoverable after this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _deletingTemplateIds.add(templateId));

    final result = await _deleteTemplate(
      template,
      templateKey: (template['template_key'] ?? '').toString(),
    );
    if (!mounted) return;
    setState(() => _deletingTemplateIds.remove(templateId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Custom template deleted.'
              : 'Could not delete "$title": ${result.message ?? 'Please try again.'}',
        ),
      ),
    );
  }

  IconData _getIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('menstrual') || t.contains('cycle')) return Icons.water_drop;
    if (t.contains('sleep')) return Icons.bedtime_outlined;
    if (t.contains('medication')) return Icons.medication_outlined;
    if (t.contains('meal')) return Icons.restaurant_menu_outlined;
    if (t.contains('bill')) return Icons.receipt_long_outlined;
    if (t.contains('income')) return Icons.payments_outlined;
    if (t.contains('expense')) return Icons.shopping_cart_outlined;
    if (t.contains('task')) return Icons.task_alt_outlined;
    if (t.contains('wishlist')) return Icons.card_giftcard_outlined;
    if (t.contains('music')) return Icons.music_note_outlined;
    if (t.contains('mood')) return Icons.mood_outlined;
    if (t.contains('water')) return Icons.water_drop_outlined;
    if (t.contains('movie')) return Icons.movie_outlined;
    if (t.contains('tv log')) return Icons.tv_outlined;
    if (t.contains('place')) return Icons.place_outlined;
    if (t.contains('restaurant')) return Icons.restaurant_outlined;
    if (t.contains('book')) return Icons.book_outlined;
    if (t.contains('workout')) return Icons.fitness_center_outlined;
    if (t.contains('fast')) return Icons.hourglass_bottom_outlined;
    if (t.contains('skin care')) return Icons.spa_outlined;
    if (t.contains('meditation')) return Icons.self_improvement_outlined;
    if (t.contains('study')) return Icons.school_outlined;
    if (t.contains('goals')) return Icons.emoji_events_outlined;
    return Icons.table_chart_outlined;
  }

  Future<void> _showGuideIfNeeded({bool force = false}) async {
    final steps = <GuideStep>[
      if (templates.isNotEmpty)
        GuideStep(
          key: _templateListItemKey,
          title: 'Need a little declutter?',
          body: 'Swipe a template to hide or bring it back.',
          align: GuideAlign.top,
        ),
      GuideStep(
        key: _addTemplateButtonKey,
        title: 'Ready to check in?',
        body: 'Tap + to log using this template.',
        align: GuideAlign.bottom,
      ),
      GuideStep(
        key: _hideToggleKey,
        title: 'Looking for something tucked away?',
        body: 'Use the toggle to reveal hidden templates.',
        align: GuideAlign.top,
      ),
    ];
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'templates',
      force: force,
      steps: steps,
      requireAllTargetsVisible: true,
    );
  }

  void _scheduleGuideAutoStart() {
    if (!mounted || loading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || loading) return;
      Future<void>.delayed(const Duration(milliseconds: 24), () {
        if (!mounted || loading) return;
        _showGuideIfNeeded();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? templates
        : templates
              .where(
                (t) =>
                    (t['name'] ?? '').toString().toLowerCase().contains(query),
              )
              .toList();

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        leading: MbGlowBackButton(onPressed: () => Navigator.pop(context)),
        title: Text('Templates (${templates.length})'),
        centerTitle: true,
        actions: [
          MbGlowIconButton(
            key: _addTemplateButtonKey,
            icon: Icons.add,
            onPressed: _openAddMenu,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_templates',
        text: 'Search or tap a template. Swipe to hide.',
        iconText: '✨',
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_isPending && _trialBannerController.visible)
                    _TrialBanner(
                      onUpgrade: () => context.go('/subscription'),
                      onSkip: () async {
                        await _trialBannerController.dismiss();
                        if (mounted) setState(() {});
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withOpacity(0.08),
                            blurRadius: 15,
                            spreadRadius: 0,
                          ),
                        ],
                        border: Border.all(
                          color: scheme.outline.withOpacity(0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search templates...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    key: _hideToggleKey,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Switch(
                          value: _showHidden,
                          onChanged: (v) => setState(() {
                            _showHidden = v;
                            _load();
                          }),
                        ),
                        const SizedBox(width: 6),
                        const Text('Show hidden'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final t = filtered[i];
                        final title = (t['name'] ?? t['template_key'] ?? '')
                            .toString();
                        final templateId = t['id'].toString();
                        final currentUserId =
                            supabase.auth.currentUser?.id ?? '';
                        final ownerId = (t['user_id'] ?? '').toString();
                        final isOwnedByCurrentUser =
                            ownerId.isNotEmpty && ownerId == currentUserId;
                        final isCustom = isOwnedByCurrentUser;
                        final isDeleting = _deletingTemplateIds.contains(
                          templateId,
                        );

                        final isHidden = _hiddenTemplateIds.contains(
                          templateId,
                        );
                        final tileContent = Container(
                          key: i == 0 ? _templateListItemKey : null,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withOpacity(0.08),
                                blurRadius: 15,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: isDeleting
                                  ? null
                                  : () async {
                                      if (isHidden) {
                                        final unhide = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text(
                                              'Unhide template?',
                                            ),
                                            content: const Text(
                                              'This will show it in your list again.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: Text(
                                                  'Unhide',
                                                  style: TextStyle(
                                                    color: scheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (unhide == true) {
                                          await _setHidden(templateId, false);
                                        }
                                        return;
                                      }
                                      GuideManager.dismissActiveGuideForPage(
                                        'templates',
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => themed(
                                            LogTableScreen(
                                              templateId: templateId,
                                              templateKey: t['template_key'],
                                              dayId: _today(),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: scheme.primary.withOpacity(0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: scheme.primary.withOpacity(
                                            0.35,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        _getIcon(title),
                                        size: 18,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isDeleting)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: scheme.primary,
                                          ),
                                        ),
                                      ),
                                    if (isCustom)
                                      PopupMenuButton<_CustomTemplateAction>(
                                        tooltip: 'Template options',
                                        enabled: !isDeleting,
                                        onSelected: (action) {
                                          switch (action) {
                                            case _CustomTemplateAction.edit:
                                              _openEditTemplate(t);
                                            case _CustomTemplateAction.delete:
                                              _confirmDeleteTemplate(t);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: _CustomTemplateAction.edit,
                                            child: Text('Edit template'),
                                          ),
                                          PopupMenuItem(
                                            value: _CustomTemplateAction.delete,
                                            child: Text('Delete template'),
                                          ),
                                        ],
                                      ),
                                    if (isHidden)
                                      IconButton(
                                        tooltip: 'Unhide',
                                        icon: const Icon(Icons.visibility),
                                        onPressed: () =>
                                            _setHidden(templateId, false),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        return Dismissible(
                          key: ValueKey(templateId),
                          direction: isDeleting
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            final isUnhideAction = isHidden || _showHidden;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(
                                  isUnhideAction
                                      ? 'Unhide template?'
                                      : 'Hide template?',
                                ),
                                content: const Text(
                                  'You can change this later from the list.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(
                                      isUnhideAction ? 'Unhide' : 'Hide',
                                      style: TextStyle(color: scheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            return ok == true;
                          },
                          onDismissed: (_) => _setHidden(
                            templateId,
                            isHidden || _showHidden ? false : true,
                          ),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isHidden || _showHidden
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: scheme.primary,
                            ),
                          ),
                          child: tileContent,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openAddMenu() async {
    GuideManager.dismissActiveGuideForPage('templates');
    final info = await SubscriptionLimits.fetchForCurrentUser();
    if (info.isPending) {
      if (mounted) {
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => context.go('/subscription'),
        );
      }
      return;
    }
    if (!mounted) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => themed(const CreateLogTemplateScreen()),
      ),
    );
    if (!mounted) return;
    if (ok == true) _load();
  }
}

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
              'Choose your mode to finish setup. Templates and journaling save normally once your account setup is complete.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onSkip, child: const Text('Skip for now')),
          const SizedBox(width: 6),
          FilledButton(onPressed: onUpgrade, child: const Text('See plans')),
        ],
      ),
    );
  }
}

class _TrialBannerController {
  static const _prefsKey = 'trial_banner_dismissed';
  bool visible = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    visible = !(prefs.getBool(_prefsKey) ?? false);
  }

  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    visible = false;
  }
}
