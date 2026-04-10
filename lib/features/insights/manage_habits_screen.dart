// lib/features/insights/manage_habits_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/features/habits/habit_category_catalog.dart';

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
  bool _hideStreaks = false;
  bool _hasChanges = false;

  // ✅ MISSING STATE YOU REFERENCED IN UI
  bool _isSelectionMode = false;
  final Set<String> _selectedHabitIds = {};

  static const String _uncategorisedLabel = 'Uncategorised';

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
      _hideStreaks = prefs.getBool('habits_hide_streaks') ?? false;
    });
  }

  Future<void> _setHideStreaks(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('habits_hide_streaks', value);
    if (!mounted) return;
    setState(() => _hideStreaks = value);
  }

  Future<void> _dismissTrialBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trial_banner_dismissed', true);
    if (!mounted) return;
    setState(() => _trialBannerVisible = false);
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

  void _markChanged() {
    _hasChanges = true;
  }

  Future<void> _refreshStreaksOnly() async {
    await _loadStreaks();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadCategories() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    var rows = await supabase
        .from('habit_categories')
        .select()
        .eq('user_id', user.id)
        .order('sort_order');

    final existing = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final existingNames = existing
        .map((category) => _canonicalCategoryKey(category['name']?.toString()))
        .whereType<String>()
        .toSet();

    final missingDefaults = HabitCategoryCatalog.builtInCategories
        .where((preset) => !existingNames.contains(preset.name.toLowerCase()))
        .toList();

    if (missingDefaults.isNotEmpty) {
      await supabase.from('habit_categories').insert([
        for (final preset in missingDefaults)
          <String, dynamic>{
            'user_id': user.id,
            'name': preset.name,
            'icon': preset.icon,
            'sort_order': existing.length + preset.sortOrder,
          },
      ]);

      rows = await supabase
          .from('habit_categories')
          .select()
          .eq('user_id', user.id)
          .order('sort_order');
    }

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

    final fromStr = DateTime.now()
        .subtract(const Duration(days: 370))
        .toIso8601String()
        .substring(0, 10);

    final rows = await supabase
        .from('habit_logs')
        .select('habit_name, day, is_completed')
        .eq('user_id', user.id)
        .gte('day', fromStr)
        .eq('is_completed', true);

    final Map<String, Set<DateTime>> doneDatesByHabit = {};

    for (final r in (rows as List)) {
      final row = Map<String, dynamic>.from(r as Map);
      final habit = (row['habit_name'] ?? '').toString().trim();
      if (habit.isEmpty) continue;

      final day = DateTime.parse(row['day'].toString());
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
                  _markChanged();
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
              _markChanged();
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
    String? selectedCategoryId = _canonicalCategoryIdFor(initialCategoryId);
    final scheme = Theme.of(context).colorScheme;
    final categoryOptions = _dedupedCategoryOptions();

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
                initialValue: selectedCategoryId,
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
                    child: Text(_uncategorisedLabel),
                  ),
                  ...categoryOptions.map(
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

                if (habitId == null) {
                  final inserted = await supabase
                      .from('user_habits')
                      .insert({
                        'user_id': supabase.auth.currentUser!.id,
                        'name': nameController.text.trim(),
                        'category_id': selectedCategoryId,
                        'sort_order': _habits.length,
                        'is_active': true,
                        'start_date': DateTime.now().toIso8601String(),
                        'active_from': DateTime.now().toIso8601String(),
                      })
                      .select()
                      .single();
                  if (mounted) {
                    setState(() {
                      _habits.add(Map<String, dynamic>.from(inserted));
                    });
                  }
                } else {
                  final updated = await supabase
                      .from('user_habits')
                      .update({
                        'name': nameController.text.trim(),
                        'category_id': selectedCategoryId,
                      })
                      .eq('id', habitId)
                      .select()
                      .single();
                  if (mounted) {
                    setState(() {
                      final idx = _habits.indexWhere(
                        (habit) => habit['id'] == habitId,
                      );
                      if (idx != -1) {
                        _habits[idx] = Map<String, dynamic>.from(updated);
                      }
                    });
                  }
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _markChanged();
                await _refreshStreaksOnly();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> habit) async {
    final habitId = habit['id'];
    final nextActive = !(habit['is_active'] == true);
    final index = _habits.indexWhere((h) => h['id'] == habitId);
    Map<String, dynamic>? previous;

    if (index != -1 && mounted) {
      previous = Map<String, dynamic>.from(_habits[index]);
      setState(() {
        _habits[index] = {..._habits[index], 'is_active': nextActive};
      });
    }

    try {
      await supabase
          .from('user_habits')
          .update({
            'is_active': nextActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', habitId);
      _markChanged();
      await _refreshStreaksOnly();
    } catch (e) {
      if (index != -1 && previous != null && mounted) {
        setState(() {
          _habits[index] = previous!;
        });
      }
      debugPrint('Toggle habit active error: $e');
    }
  }

  // ✅ DELETE SELECTED HABITS (you referenced this in AppBar actions)
  Future<void> _deleteSelectedHabits() async {
    if (_selectedHabitIds.isEmpty) return;

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
        _habits.removeWhere(
          (habit) => _selectedHabitIds.contains((habit['id'] ?? '').toString()),
        );
        _selectedHabitIds.clear();
        _isSelectionMode = false;
      });

      _markChanged();
      await _refreshStreaksOnly();
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
      final String? catId = _canonicalCategoryIdFor(habit['category_id']?.toString());
      habitsByCategory.putIfAbsent(catId, () => []).add(habit);
    }

    final categoryOptions = _dedupedCategoryOptions();

    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        leading: _isSelectionMode
            ? MbGlowIconButton(
                icon: Icons.close,
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedHabitIds.clear();
                  });
                },
              )
            : MbGlowBackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop(_hasChanges);
                  } else {
                    context.go('/habits');
                  }
                },
              ),
        title: Text(
          _isSelectionMode
              ? '${_selectedHabitIds.length} Selected'
              : 'Manage Habits',
        ),
        centerTitle: true,
        actions: [
          if (_isSelectionMode)
            MbGlowIconButton(
              icon: Icons.delete_outline,
              iconColor: Colors.red,
              onPressed: _deleteSelectedHabits,
            )
          else
            MbGlowIconButton(
              icon: Icons.category,
              onPressed: () => _showCategoryDialog(),
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
                _buildDisplayOptionsCard(scheme),
                if (habitsByCategory[null]?.isNotEmpty ?? false)
                  _buildCategorySection(
                    categoryName: _uncategorisedLabel,
                    categoryIcon: '📋',
                    habits: habitsByCategory[null]!,
                    scheme: scheme,
                  ),
                for (final category in categoryOptions)
                  if (habitsByCategory[category['id']?.toString()]
                          ?.isNotEmpty ??
                      false)
                    _buildCategorySection(
                      categoryName: _displayCategoryName(
                        (category['name'] ?? '').toString(),
                      ),
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

  List<Map<String, dynamic>> _dedupedCategoryOptions() {
    final byCanonicalKey = <String, Map<String, dynamic>>{};
    for (final category in _categories) {
      final canonicalKey = _canonicalCategoryKey(category['name']?.toString());
      if (canonicalKey == null) continue;
      final existing = byCanonicalKey[canonicalKey];
      final normalized = Map<String, dynamic>.from(category);
      normalized['name'] = _displayCategoryName(
        (category['name'] ?? '').toString(),
      );
      if (existing == null) {
        byCanonicalKey[canonicalKey] = normalized;
        continue;
      }
      final existingSort = _asInt(existing['sort_order'], fallback: 999);
      final nextSort = _asInt(normalized['sort_order'], fallback: 999);
      if (nextSort < existingSort) {
        byCanonicalKey[canonicalKey] = normalized;
      }
    }
    final options = byCanonicalKey.values.toList()
      ..sort((a, b) {
        final bySort = _asInt(a['sort_order'], fallback: 999).compareTo(
          _asInt(b['sort_order'], fallback: 999),
        );
        if (bySort != 0) return bySort;
        return ((a['name'] ?? '').toString()).toLowerCase().compareTo(
          ((b['name'] ?? '').toString()).toLowerCase(),
        );
      });
    return options;
  }

  String? _canonicalCategoryIdFor(String? categoryId) {
    final raw = categoryId?.trim();
    if (raw == null || raw.isEmpty) return null;
    final category = _categories.where((cat) => (cat['id'] ?? '').toString() == raw);
    if (category.isEmpty) return raw;
    final canonicalKey = _canonicalCategoryKey(category.first['name']?.toString());
    if (canonicalKey == null) return raw;
    final matching = _dedupedCategoryOptions().where(
      (cat) => _canonicalCategoryKey(cat['name']?.toString()) == canonicalKey,
    );
    if (matching.isEmpty) return raw;
    return (matching.first['id'] ?? '').toString();
  }

  static String _displayCategoryName(String raw) {
    final key = _canonicalCategoryKey(raw);
    return switch (key) {
      'morning' => 'Morning',
      'day' || 'afternoon' => 'Day',
      'night' || 'evening' => 'Night',
      'work' => 'Work',
      'personal' || 'selfcare' => 'Personal',
      _ => _stripLeadingDecoration(raw.trim()),
    };
  }

  static String? _canonicalCategoryKey(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final noEmoji = _stripLeadingDecoration(text).toLowerCase();
    if (noEmoji.startsWith('morning')) return 'morning';
    if (noEmoji.startsWith('afternoon') || noEmoji == 'day' || noEmoji.startsWith('day ')) {
      return 'day';
    }
    if (noEmoji.startsWith('night') || noEmoji.startsWith('evening')) return 'night';
    if (noEmoji.startsWith('work')) return 'work';
    if (noEmoji.startsWith('personal') || noEmoji.startsWith('self-care') || noEmoji.startsWith('self care')) {
      return 'personal';
    }
    return noEmoji.replaceAll(RegExp(r'\s+routine$'), '').trim();
  }

  static String _stripLeadingDecoration(String value) {
    return value.replaceFirst(RegExp(r'^[^\w]+', unicode: true), '').trim();
  }

  static int _asInt(Object? value, {required int fallback}) {
    return switch (value) {
      int number => number,
      double number => number.round(),
      String text => int.tryParse(text) ?? fallback,
      _ => fallback,
    };
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
    if (_hideStreaks) {
      return Text(
        'Streaks hidden',
        style: TextStyle(
          color: scheme.onSurface.withOpacity(0.6),
          fontSize: 12,
        ),
      );
    }

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

  Widget _buildDisplayOptionsCard(ColorScheme scheme) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display options',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hide streaks',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Removes streak counts and streak badges. Your habits still save as normal.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(value: _hideStreaks, onChanged: _setHideStreaks),
            ],
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
              SubscriptionPlanCatalog.previewModeHelpText,
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
