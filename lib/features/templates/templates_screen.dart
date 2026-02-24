import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'log_table_screen.dart';
import 'create_templates_screen.dart';
import 'package:mind_buddy/router.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/guides/guide_manager.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  bool loading = true;
  List<Map<String, dynamic>> templates = [];
  bool _showHidden = false;
  Set<String> _hiddenTemplateIds = {};
  bool _canCreateCustomTemplates = false;
  bool _isPending = false;
  late final _TrialBannerController _trialBannerController;
  final GlobalKey _templateListItemKey = GlobalKey();
  final GlobalKey _hideToggleKey = GlobalKey();
  final GlobalKey _addTemplateButtonKey = GlobalKey();

  // Updated to match the template_keys we inserted via SQL
  final List<String> _builtInTemplates = [
    'menstrual',
    'cycle',
    'sleep',
    'bills',
    'income',
    'expenses',
    'tasks',
    'wishlist',
    'music',
    'mood',
    'water',
    'movies',
    'tv_log',
    'places',
    'restaurants',
    'books',
    'health',
    'workout',
    'fast',
    'study',
    'skin_care',
    'meditation',
    'social',
    'Goals/Resolutions',
    // 'symptoms',
    // 'habits',
    //'meal_prep'
  ];

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

  bool _isDeletable(Map<String, dynamic> t) {
    final name = (t['name'] ?? '').toString().toLowerCase();
    final key = (t['template_key'] ?? '').toString().toLowerCase();

    // If it matches our built-in list OR if user_id is null (System Template), don't delete
    final isBuiltIn = _builtInTemplates.any(
      (b) => name.contains(b) || key.contains(b),
    );
    if (isBuiltIn || t['user_id'] == null) return false;

    final user = supabase.auth.currentUser;
    return (t['user_id'] ?? '').toString() == user?.id;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final info = await SubscriptionLimits.fetchForCurrentUser();
      _canCreateCustomTemplates = info.supportsCustomTemplates;
      _isPending = info.isPending;

      final hiddenRows = await supabase
          .from('user_template_settings')
          .select('template_id')
          .eq('user_id', user.id)
          .eq('is_hidden', true);
      _hiddenTemplateIds = (hiddenRows as List)
          .map((r) => (r['template_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      // FIX: Fetch where user_id is the current user OR user_id is NULL (System Templates)
      final base = supabase
          .from('log_templates_v2')
          .select()
          .or('user_id.eq.${user.id},user_id.is.null');
      final rows = await base.order('name', ascending: true);

      debugPrint('--- TEMPLATE KEYS FROM DB (${rows.length}) ---');
      for (final r in rows) {
        debugPrint(
          'name=${r['name']}  key=${r['template_key']}  user_id=${r['user_id']}',
        );
      }
      debugPrint('--- END ---');

      if (mounted) {
        setState(() {
          // Filter out 'habits' if you want it hidden from this view
          final all = List<Map<String, dynamic>>.from(rows)
              .where((t) => (t['template_key'] ?? '') != 'habits')
              .where((t) => _canCreateCustomTemplates || t['user_id'] == null)
              .toList();
          templates = _showHidden
              ? all
                    .where(
                      (t) => _hiddenTemplateIds.contains(
                        (t['id'] ?? '').toString(),
                      ),
                    )
                    .toList()
              : all
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

  Future<void> _deleteTemplate(String templateId) async {
    try {
      await supabase.from('log_entries').delete().eq('template_id', templateId);
      await supabase
          .from('log_template_fields_v2')
          .delete()
          .eq('template_id', templateId);
      await supabase.from('log_templates_v2').delete().eq('id', templateId);
      _load();
    } catch (e) {
      debugPrint('Delete failed: $e');
    }
  }

  Future<void> _setHidden(String templateId, bool hidden) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      await supabase.from('user_template_settings').upsert({
        'user_id': user.id,
        'template_id': templateId,
        'is_hidden': hidden,
        'updated_at': DateTime.now().toIso8601String(),
      });
      _load();
    } catch (e) {
      debugPrint('Hide failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hide failed: $e')));
      }
    }
  }

  String _getEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('menstrual') || t.contains('cycle')) return '🩸';
    if (t.contains('sleep')) return '😴';
    if (t.contains('bill')) return '💸';
    if (t.contains('income')) return '💰';
    if (t.contains('expense')) return '📉';
    if (t.contains('task')) return '✅';
    if (t.contains('wishlist')) return '✨';
    if (t.contains('music')) return '🎵';
    if (t.contains('mood')) return '🎭';
    if (t.contains('water')) return '💧';
    if (t.contains('movie')) return '🍿';
    if (t.contains('tv log')) return '📺';
    if (t.contains('place')) return '📍';
    if (t.contains('restaurant')) return '🍽️';
    if (t.contains('book')) return '📖';
    //if (t.contains('health') || t.contains('symptoms')) return '🏥';
    if (t.contains('workout')) return '💪';
    if (t.contains('fast')) return '⏳';
    if (t.contains('skin care')) return '🧼';
    if (t.contains('meditation')) return '🧘';
    if (t.contains('study')) return '🧠';
    if (t.contains('goals')) return '🎊';
    // if (t.contains('meal prep')) return '🍱';
    return '📋';
  }

  IconData _getIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('menstrual') || t.contains('cycle')) return Icons.water_drop;
    if (t.contains('sleep')) return Icons.bedtime_outlined;
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
            icon: Icons.help_outline,
            onPressed: () => _showGuideIfNeeded(force: true),
          ),
          MbGlowIconButton(
            icon: Icons.notifications_outlined,
            onPressed: () =>
                context.push('/settings/notifications?from=templates'),
          ),
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
                        final isBuiltIn = t['user_id'] == null;

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
                              onTap: () async {
                                if (isHidden) {
                                  final unhide = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Unhide template?'),
                                      content: const Text(
                                        'This will show it in your list again.',
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
                          direction: DismissDirection.endToStart,
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
    if (!info.supportsCustomTemplates) {
      if (mounted) {
        final goUpgrade = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Custom templates are locked'),
            content: Text(
              '${info.planName} includes template preview mode. Upgrade to PLUS SUPPORT MODE or FULL SUPPORT MODE to create and save custom templates.\n\n${SubscriptionPlanCatalog.previewModeHelpText}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('View modes'),
              ),
            ],
          ),
        );
        if (goUpgrade == true && context.mounted) {
          context.go('/subscription');
        }
      }
      return;
    }

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => themed(const CreateLogTemplateScreen()),
      ),
    );
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
              'FREE MODE uses 24-hour preview mode for templates. Preview data disappears after 24 hours.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onSkip, child: const Text('Skip for now')),
          const SizedBox(width: 6),
          FilledButton(onPressed: onUpgrade, child: const Text('View modes')),
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
