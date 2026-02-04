// lib/features/insights/manage_habits_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageHabitsScreen extends StatefulWidget {
  const ManageHabitsScreen({super.key});

  @override
  State<ManageHabitsScreen> createState() => _ManageHabitsScreenState();
}

class _ManageHabitsScreenState extends State<ManageHabitsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
  bool _isPending = false;
  bool _trialBannerVisible = true;
  final List<Map<String, dynamic>> _habits = [];
  final List<Map<String, dynamic>> _categories = [];
  final Map<String, ({int current, int best})> _streaksByHabitName = {};

  // ✅ MISSING STATE YOU REFERENCED IN UI
  bool _isSelectionMode = false;
  final Set<String> _selectedHabitIds = {};

  @override
  void initState() {
    super.initState();
    _loadTrialBannerState();
    _loadData();
  }

  Future<void> _loadTrialBannerState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _trialBannerVisible = !(prefs.getBool('trial_banner_dismissed') ?? false);
    });
  }

  Future<void> _dismissTrialBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trial_banner_dismissed', true);
    if (!mounted) return;
    setState(() => _trialBannerVisible = false);
  }

  // --- GLOWING UI HELPERS ---

  Widget _glowingIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          icon: Icon(icon, color: scheme.primary, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  // --- LOGIC METHODS ---

  ({int current, int best}) _computeStreak(Set<DateTime> doneDates) {
    if (doneDates.isEmpty) return (current: 0, best: 0);

    final dates = doneDates.toList()..sort();
    int best = 1;
    int run = 1;

    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > best) best = run;
      } else if (diff > 1) {
        run = 1;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int current = 0;
    DateTime cursor = today;

    while (doneDates.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return (current: current, best: best);
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final info = await SubscriptionLimits.fetchForCurrentUser();
      _isPending = info.isPending;
      await _loadCategories();
      await _loadHabits();
      await _loadStreaks();
    } catch (e) {
      debugPrint('Load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCategories() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final rows = await supabase
        .from('habit_categories')
        .select()
        .eq('user_id', user.id)
        .order('sort_order');

    _categories
      ..clear()
      ..addAll((rows as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<void> _loadHabits() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final rows = await supabase
        .from('user_habits')
        .select()
        .eq('user_id', user.id)
        .order('sort_order');

    _habits
      ..clear()
      ..addAll((rows as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  Future<void> _loadStreaks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final tpl = await supabase
        .from('log_templates_v2')
        .select('id')
        .eq('user_id', user.id)
        .eq('template_key', 'habits')
        .maybeSingle();
    if (tpl == null) return;

    final fromStr = DateTime.now()
        .subtract(const Duration(days: 370))
        .toIso8601String()
        .substring(0, 10);

    final rows = await supabase
        .from('log_entries')
        .select('day, data')
        .eq('template_id', tpl['id'])
        .gte('day', fromStr);

    final Map<String, Set<DateTime>> doneDatesByHabit = {};

    for (final r in (rows as List)) {
      final data = Map<String, dynamic>.from((r as Map)['data'] ?? {});
      final habit = (data['habit'] ?? data['habit_name'] ?? data['name'] ?? '')
          .toString()
          .trim();

      if (habit.isEmpty) continue;
      if (data['done'] != true) continue;

      final day = DateTime.parse((r)['day'].toString());
      final normalized = DateTime(day.year, day.month, day.day);

      doneDatesByHabit.putIfAbsent(habit, () => <DateTime>{}).add(normalized);
    }

    _streaksByHabitName.clear();
    for (final h in _habits) {
      final name = (h['name'] ?? '').toString().trim();
      _streaksByHabitName[name] = _computeStreak(doneDatesByHabit[name] ?? {});
    }
  }

  // --- CATEGORY DIALOGS ---

  Future<void> _showCategoryDialog({
    String? initialName,
    String? initialIcon,
    String? categoryId,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final iconController = TextEditingController(text: initialIcon);
    final scheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(categoryId == null ? 'Add Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Morning Routine',
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iconController,
              decoration: InputDecoration(
                labelText: 'Icon (emoji)',
                hintText: 'e.g. 🌅',
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (categoryId != null)
            TextButton(
              onPressed: () async {
                try {
                  // ✅ safer delete: uncategorize habits first (avoids FK constraint errors)
                  await supabase
                      .from('user_habits')
                      .update({'category_id': null})
                      .eq('category_id', categoryId);

                  await supabase
                      .from('habit_categories')
                      .delete()
                      .eq('id', categoryId);

                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                } catch (e) {
                  debugPrint('Delete category error: $e');
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: Text('Delete', style: TextStyle(color: scheme.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final info = await SubscriptionLimits.fetchForCurrentUser();
              if (info.isPending) {
                if (ctx.mounted) {
                  await SubscriptionLimits.showTrialUpgradeDialog(
                    ctx,
                    onUpgrade: () => ctx.go('/subscription'),
                  );
                }
                return;
              }

              if (categoryId == null) {
                await supabase.from('habit_categories').insert({
                  'user_id': supabase.auth.currentUser!.id,
                  'name': nameController.text.trim(),
                  'icon': iconController.text.trim(),
                  'sort_order': _categories.length,
                });
              } else {
                await supabase
                    .from('habit_categories')
                    .update({
                      'name': nameController.text.trim(),
                      'icon': iconController.text.trim(),
                    })
                    .eq('id', categoryId);
              }

              if (ctx.mounted) Navigator.pop(ctx);
              await _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- HABIT DIALOGS ---

  Future<void> _showHabitDialog({
    String? initialName,
    String? initialCategoryId,
    String? habitId,
  }) async {
    final nameController = TextEditingController(text: initialName);
    String? selectedCategoryId = initialCategoryId;
    final scheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(habitId == null ? 'Add Habit' : 'Edit Habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Habit Name',
                  hintText: 'e.g. Morning Yoga',
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ FIX: must be DropdownButtonFormField<String?> to allow null values
              DropdownButtonFormField<String?>(
                value: selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No Category'),
                  ),
                  ..._categories.map(
                    (cat) => DropdownMenuItem<String?>(
                      value: (cat['id'] ?? '').toString(),
                      child: Text(
                        '${cat['icon'] ?? '📁'} ${cat['name'] ?? ''}',
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedCategoryId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final info = await SubscriptionLimits.fetchForCurrentUser();
              if (info.isPending) {
                if (ctx.mounted) {
                  await SubscriptionLimits.showTrialUpgradeDialog(
                    ctx,
                    onUpgrade: () => ctx.go('/subscription'),
                  );
                }
                return;
              }

                if (habitId == null) {
                  await supabase.from('user_habits').insert({
                    'user_id': supabase.auth.currentUser!.id,
                    'name': nameController.text.trim(),
                    'category_id': selectedCategoryId,
                    'sort_order': _habits.length,
                    'is_active': true,
                  });
                } else {
                  await supabase
                      .from('user_habits')
                      .update({
                        'name': nameController.text.trim(),
                        'category_id': selectedCategoryId,
                      })
                      .eq('id', habitId);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                await _loadData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> habit) async {
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
    await supabase
        .from('user_habits')
        .update({'is_active': !(habit['is_active'] == true)})
        .eq('id', habit['id']);
    await _loadData();
  }

  // ✅ DELETE SELECTED HABITS (you referenced this in AppBar actions)
  Future<void> _deleteSelectedHabits() async {
    if (_selectedHabitIds.isEmpty) return;
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

    final scheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habits?'),
        content: Text(
          'This will delete ${_selectedHabitIds.length} habit(s). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('user_habits')
          .delete()
          .inFilter('id', _selectedHabitIds.toList());

      if (!mounted) return;
      setState(() {
        _selectedHabitIds.clear();
        _isSelectionMode = false;
      });

      await _loadData();
    } catch (e) {
      debugPrint('Delete selected habits error: $e');
    }
  }

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Group habits by category_id (including null)
    final Map<String?, List<Map<String, dynamic>>> habitsByCategory = {};
    for (final habit in _habits) {
      final String? catId = habit['category_id']?.toString();
      habitsByCategory.putIfAbsent(catId, () => []).add(habit);
    }

    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedHabitIds.clear();
                  });
                },
              )
            : _glowingIconButton(
                icon: Icons.arrow_back,
                onPressed: () => context.go('/habits'),
                scheme: scheme,
              ),
        title: Text(
          _isSelectionMode
              ? '${_selectedHabitIds.length} Selected'
              : 'Manage Habits',
        ),
        centerTitle: true,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteSelectedHabits,
            )
          else
            _glowingIconButton(
              icon: Icons.category,
              onPressed: () => _showCategoryDialog(),
              scheme: scheme,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showHabitDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isPending && _trialBannerVisible)
                  _TrialBanner(
                    onUpgrade: () => context.go('/subscription'),
                    onSkip: () => _dismissTrialBanner(),
                  ),
                if (habitsByCategory[null]?.isNotEmpty ?? false)
                  _buildCategorySection(
                    categoryName: 'Uncategorized',
                    categoryIcon: '📋',
                    habits: habitsByCategory[null]!,
                    scheme: scheme,
                  ),
                for (final category in _categories)
                  if (habitsByCategory[category['id']?.toString()]
                          ?.isNotEmpty ??
                      false)
                    _buildCategorySection(
                      categoryName: (category['name'] ?? '').toString(),
                      categoryIcon: (category['icon'] ?? '📁').toString(),
                      habits: habitsByCategory[category['id']?.toString()]!,
                      scheme: scheme,
                      categoryId: category['id']?.toString(),
                      onEditCategory: () => _showCategoryDialog(
                        initialName: category['name']?.toString(),
                        initialIcon: category['icon']?.toString(),
                        categoryId: category['id']?.toString(),
                      ),
                    ),
              ],
            ),
    );
  }

  Widget _buildCategorySection({
    required String categoryName,
    required String categoryIcon,
    required List<Map<String, dynamic>> habits,
    required ColorScheme scheme,
    String? categoryId,
    VoidCallback? onEditCategory,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Row(
            children: [
              Text(categoryIcon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                categoryName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              if (onEditCategory != null) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: onEditCategory,
                ),
              ],
            ],
          ),
        ),
        ...habits.map((habit) => _buildHabitTile(habit, scheme)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHabitTile(Map<String, dynamic> habit, ColorScheme scheme) {
    final active = habit['is_active'] == true;
    final habitId = habit['id'].toString();
    final isSelected = _selectedHabitIds.contains(habitId);
    final habitName = (habit['name'] ?? '').toString();
    final streak = _streaksByHabitName[habitName] ?? (current: 0, best: 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer.withOpacity(0.3)
              : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outline.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ListTile(
          onLongPress: () {
            setState(() {
              _isSelectionMode = true;
              _selectedHabitIds.add(habitId);
            });
          },
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedHabitIds.remove(habitId);
                } else {
                  _selectedHabitIds.add(habitId);
                }
                if (_selectedHabitIds.isEmpty) _isSelectionMode = false;
              });
            } else {
              _showHabitDialog(
                initialName: habitName,
                initialCategoryId: habit['category_id']?.toString(),
                habitId: habit['id']?.toString(),
              );
            }
          },
          leading: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  activeColor: scheme.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedHabitIds.add(habitId);
                      } else {
                        _selectedHabitIds.remove(habitId);
                      }
                      if (_selectedHabitIds.isEmpty) _isSelectionMode = false;
                    });
                  },
                )
              : null,
          title: Text(
            habitName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: active ? null : TextDecoration.lineThrough,
              color: active
                  ? scheme.onSurface
                  : scheme.onSurface.withOpacity(0.4),
            ),
          ),
          subtitle: _buildSubtitle(active, streak, scheme),
          trailing: _isSelectionMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        active
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => _toggleActive(habit),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(
    bool active,
    ({int current, int best}) streak,
    ColorScheme scheme,
  ) {
    if (!active) return const Text('Hidden • Tap eye to restore');

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: scheme.onSurface.withOpacity(0.6),
          fontSize: 12,
        ),
        children: [
          const TextSpan(text: 'Streak: '),
          TextSpan(
            text: '${streak.current} days',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: '  •  Best: '),
          TextSpan(text: '${streak.best} days'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌸', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          const Text(
            'No habits yet.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showHabitDialog(),
            child: const Text('Add your first habit'),
          ),
        ],
      ),
    );
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
      margin: const EdgeInsets.only(bottom: 12),
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
