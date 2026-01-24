// lib/features/insights/manage_habit_streaks.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/router.dart';

class ManageHabitsScreen extends StatefulWidget {
  const ManageHabitsScreen({super.key});

  @override
  State<ManageHabitsScreen> createState() => _ManageHabitsScreenState();
}

class _ManageHabitsScreenState extends State<ManageHabitsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
  final List<Map<String, dynamic>> _habits = [];
  final Map<String, ({int current, int best})> _streaksByHabitName = {};

  @override
  void initState() {
    super.initState();
    _loadHabits();
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
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        run++;
        if (run > best) best = run;
      } else if (dates[i].difference(dates[i - 1]).inDays > 1) {
        run = 1;
      }
    }
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    int current = 0;
    DateTime cursor = today;
    while (doneDates.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return (current: current, best: best);
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final rows = await supabase
          .from('user_habits')
          .select()
          .eq('user_id', user.id)
          .order('sort_order');
      _habits.clear();
      _habits.addAll(
        (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      await _loadStreaks();
    } catch (e) {
      debugPrint('Load error: $e');
    }
    if (mounted) setState(() => _loading = false);
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
      final data = Map<String, dynamic>.from(r['data'] ?? {});
      final habit = (data['habit'] ?? data['habit_name'] ?? data['name'] ?? '')
          .toString()
          .trim();
      if (habit.isEmpty || data['done'] != true) continue;

      final day = DateTime.parse(r['day'].toString());
      doneDatesByHabit
          .putIfAbsent(habit, () => <DateTime>{})
          .add(DateTime(day.year, day.month, day.day));
    }

    _streaksByHabitName.clear();
    for (final h in _habits) {
      final name = (h['name'] ?? '').toString().trim();
      _streaksByHabitName[name] = _computeStreak(doneDatesByHabit[name] ?? {});
    }
  }

  Future<void> _showHabitDialog({
    String? initialName,
    required String title,
    required Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialName);
    final scheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Morning Yoga',
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addHabit() async {
    await _showHabitDialog(
      title: 'Add Habit',
      onSave: (name) async {
        await supabase.from('user_habits').insert({
          'user_id': supabase.auth.currentUser!.id,
          'name': name,
          'sort_order': _habits.length,
          'is_active': true,
        });
        _loadHabits();
      },
    );
  }

  Future<void> _renameHabit(Map<String, dynamic> habit) async {
    await _showHabitDialog(
      initialName: habit['name'],
      title: 'Rename Habit',
      onSave: (name) async {
        await supabase
            .from('user_habits')
            .update({'name': name})
            .eq('id', habit['id']);
        _loadHabits();
      },
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> habit) async {
    await supabase
        .from('user_habits')
        .update({'is_active': !(habit['is_active'] == true)})
        .eq('id', habit['id']);
    _loadHabits();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        leading: _glowingIconButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/home'),
          scheme: scheme,
        ),
        title: const Text('Manage Habits'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Drag rows to reorder',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(
                              alpha: 0.7,
                            ), // Use .withValues for the latest Flutter
                          ),
                        ),
                      ),
                      _glowingIconButton(
                        icon: Icons.add,
                        onPressed: _addHabit,
                        scheme: scheme,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _habits.isEmpty
                      ? _buildEmptyState()
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          itemCount: _habits.length,
                          onReorder: (oldIndex, newIndex) async {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _habits.removeAt(oldIndex);
                              _habits.insert(newIndex, item);
                            });
                            for (int i = 0; i < _habits.length; i++) {
                              await supabase
                                  .from('user_habits')
                                  .update({'sort_order': i})
                                  .eq('id', _habits[i]['id']);
                            }
                          },
                          itemBuilder: (context, index) {
                            final h = _habits[index];
                            final active = h['is_active'] == true;
                            final streak =
                                _streaksByHabitName[h['name']] ??
                                (current: 0, best: 0);

                            return Padding(
                              key: ValueKey(h['id']),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary.withOpacity(0.05),
                                      blurRadius: 10,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: scheme.outline.withOpacity(0.1),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: Icon(
                                    Icons.drag_handle,
                                    color: scheme.outline,
                                  ),
                                  title: Text(
                                    h['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: active
                                          ? null
                                          : TextDecoration.lineThrough,
                                      color: active
                                          ? scheme.onSurface
                                          : scheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                  subtitle: _buildSubtitle(
                                    active,
                                    streak,
                                    scheme,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => _renameHabit(h),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          active
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () => _toggleActive(h),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
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
            onPressed: _addHabit,
            child: const Text('Add your first habit'),
          ),
        ],
      ),
    );
  }
}
