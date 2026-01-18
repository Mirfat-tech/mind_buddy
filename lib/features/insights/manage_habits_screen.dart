// lib/features/insights/manage_habit_streaks.dart
// lib/features/insights/manage_habits_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

// IMPORTANT: replace this import with YOUR MbScaffold import (same as chat_screen.dart)
import 'package:mind_buddy/common/mb_scaffold.dart';

class ManageHabitsScreen extends StatefulWidget {
  const ManageHabitsScreen({super.key});

  @override
  State<ManageHabitsScreen> createState() => _ManageHabitsScreenState();
}

class _ManageHabitsScreenState extends State<ManageHabitsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
  final List<Map<String, dynamic>> _habits = [];

  // Streaks: habit name -> (current, best)
  final Map<String, ({int current, int best})> _streaksByHabitName = {};

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  ({int current, int best}) _computeStreak(Set<DateTime> doneDates) {
    if (doneDates.isEmpty) return (current: 0, best: 0);

    final dates = doneDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();

    // best streak
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

    // current streak: today backwards
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final set = dates.toSet();
    int current = 0;
    DateTime cursor = today;
    while (set.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return (current: current, best: best);
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final rows = await supabase
          .from('user_habits')
          .select('id, name, sort_order, is_active')
          .eq('user_id', user.id)
          .order('sort_order');

      _habits
        ..clear()
        ..addAll(
          (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load habits: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    await _loadStreaks();
    if (!mounted) return;
    setState(() {}); // rebuild to show streak text
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
    final templateId = tpl['id'] as String;

    final from = DateTime.now().subtract(const Duration(days: 370));
    final fromStr = '${from.year.toString().padLeft(4, '0')}-'
        '${from.month.toString().padLeft(2, '0')}-'
        '${from.day.toString().padLeft(2, '0')}';

    final rows = await supabase
        .from('log_entries')
        .select('day, data')
        .eq('template_id', templateId)
        .gte('day', fromStr);

    final Map<String, Set<DateTime>> doneDatesByHabit = {};

    for (final r in (rows as List)) {
      final row = Map<String, dynamic>.from(r as Map);

      final dayVal = row['day'];
      final day = (dayVal is DateTime)
          ? DateTime(dayVal.year, dayVal.month, dayVal.day)
          : DateTime.parse(dayVal.toString());
      final dayOnly = DateTime(day.year, day.month, day.day);

      final dataRaw = row['data'];
      final data = (dataRaw is Map)
          ? Map<String, dynamic>.from(dataRaw as Map)
          : <String, dynamic>{};

      final habit = (data['habit'] ?? data['habit_name'] ?? data['name'] ?? '')
          .toString()
          .trim();
      if (habit.isEmpty) continue;

      final done = data['done'] == true ||
          (data['status'] ?? '').toString().toLowerCase().trim() == 'done' ||
          (data['state'] ?? '').toString().toLowerCase().trim() == 'done';

      if (!done) continue;

      doneDatesByHabit.putIfAbsent(habit, () => <DateTime>{});
      doneDatesByHabit[habit]!.add(dayOnly);
    }

    _streaksByHabitName.clear();
    for (final h in _habits) {
      final name = (h['name'] ?? '').toString().trim();
      final set = doneDatesByHabit[name] ?? <DateTime>{};
      _streaksByHabitName[name] = _computeStreak(set);
    }
  }

  Future<void> _addHabit() async {
    final controller = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'e.g. Lemon water'),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final nextOrder = _habits.length;
      await supabase.from('user_habits').insert({
        'user_id': user.id,
        'name': trimmed,
        'sort_order': nextOrder,
        'is_active': true,
      });

      await _loadHabits();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add habit: $e')),
      );
    }
  }

  Future<void> _renameHabit(Map<String, dynamic> habit) async {
    final controller = TextEditingController(
      text: (habit['name'] ?? '').toString(),
    );
    final newName = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final trimmed = (newName ?? '').trim();
    if (trimmed.isEmpty) return;

    try {
      await supabase
          .from('user_habits')
          .update({'name': trimmed}).eq('id', habit['id']);

      await _loadHabits();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename habit: $e')),
      );
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> habit) async {
    final current = habit['is_active'] == true;
    try {
      await supabase
          .from('user_habits')
          .update({'is_active': !current}).eq('id', habit['id']);

      await _loadHabits();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update habit: $e')),
      );
    }
  }

  Future<void> _persistOrder() async {
    try {
      for (int i = 0; i < _habits.length; i++) {
        await supabase
            .from('user_habits')
            .update({'sort_order': i}).eq('id', _habits[i]['id']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        title: const Text('Manage habits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Fallback if this screen was opened as a root route
              context.go('/home'); // or wherever your main screen is
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your habit rows (drag to reorder)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilledButton(
                        onPressed: _addHabit,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _habits.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Start your Hobonichi-style tracker by adding your first habit 🌸',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _addHabit,
                                  child: const Text('Add habit'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _habits.length,
                          onReorder: (oldIndex, newIndex) async {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _habits.removeAt(oldIndex);
                              _habits.insert(newIndex, item);
                            });
                            await _persistOrder();
                          },
                          itemBuilder: (context, index) {
                            final h = _habits[index];
                            final name = (h['name'] ?? '').toString();
                            final active = h['is_active'] == true;

                            final streak = _streaksByHabitName[name];
                            final current = streak?.current ?? 0;
                            final best = streak?.best ?? 0;

                            String subtitleText;

                            if (!active) {
                              subtitleText = best > 0
                                  ? 'Hidden • You’ve done this before — best was $best days 🌸'
                                  : 'Hidden • You can bring this back anytime 🌸';
                            } else {
                              if (current == 0 && best == 0) {
                                subtitleText =
                                    'Active • Start whenever you’re ready 🌸';
                              } else if (current == 0 && best > 0) {
                                subtitleText =
                                    'Active • A fresh start is still progress • Best: $best days 🌸';
                              } else if (current == 1) {
                                subtitleText = best > 1
                                    ? 'Active • Day 1 — you showed up 🌸 • Best: $best days'
                                    : 'Active • Day 1 — you showed up 🌸';
                              } else {
                                subtitleText = best > 0
                                    ? 'Active • You’re on a $current-day run 🌸 • Best: $best days'
                                    : 'Active • You’re on a $current-day run 🌸';
                              }
                            }

                            return Card(
                              key: ValueKey(h['id']),
                              child: ListTile(
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    decoration: active
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                subtitle: Text(subtitleText),
                                leading: const Icon(Icons.drag_handle),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Rename',
                                      onPressed: () => _renameHabit(h),
                                      icon: const Icon(Icons.edit),
                                    ),
                                    IconButton(
                                      tooltip: active ? 'Hide' : 'Show',
                                      onPressed: () => _toggleActive(h),
                                      icon: Icon(
                                        active
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ],
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
}
