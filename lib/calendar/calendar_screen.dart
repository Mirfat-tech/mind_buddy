import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.1),
                blurRadius: 15,
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: scheme.surface,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: scheme.primary, size: 20),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
        ),
      ),
      body: const _CalendarBody(),
    );
  }
}

class _CalendarBody extends StatefulWidget {
  const _CalendarBody();

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  final SupabaseClient supabase = Supabase.instance.client;
  final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  late List<String> _currentFilters;
  final List<String> _allPossibleTemplates = [
    'Reminders Only',
    'Habits',
    'Water',
    'Sleep',
    'Mood',
    'Menstrual Cycle',
    'Expenses',
    'Income',
    'Bills',
    'Tasks',
    'Wishlist',
    'Movie Log',
    'TV Log',
    'Places',
    'Restaurants',
    'Books',
  ];

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _loadingDots = false;
  bool _loadingData = false;

  final Set<String> _activeDays = <String>{};
  List<Map<String, dynamic>> _displayList = <Map<String, dynamic>>[];

  String _selectedTemplate = 'Reminders Only';

  @override
  void initState() {
    super.initState();
    // Initialize with something so the build doesn't crash before load finishes
    _currentFilters = ['Reminders Only'];
    _loadUserPreferences();
  }

  // --- NEW: LOAD FROM SUPABASE ---
  Future<void> _loadUserPreferences() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('user_calendar_preferences')
          .select('visible_filters')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && data['visible_filters'] != null) {
        setState(() {
          _currentFilters = List<String>.from(data['visible_filters']);
        });
      } else {
        setState(() => _currentFilters = List.from(_allPossibleTemplates));
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      setState(() => _currentFilters = List.from(_allPossibleTemplates));
    }
    _refreshAll();
  }

  // --- NEW: SAVE TO SUPABASE ---
  Future<void> _saveFilterPreferences() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('user_calendar_preferences').upsert({
        'user_id': user.id,
        'visible_filters': _currentFilters,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  void _refreshAll() {
    _loadFilteredDots(_focusedDay);
    _loadDataForSelectedDay(_selectedDay);
  }

  String _getTableName(String template) {
    switch (template) {
      case 'Habits':
        return 'habit_logs';
      case 'Water':
        return 'water_logs';
      case 'Sleep':
        return 'sleep_logs';
      case 'Mood':
        return 'mood_logs';
      case 'Menstrual Cycle':
        return 'menstrual_logs';
      case 'Expenses':
        return 'expense_logs';
      case 'Income':
        return 'income_logs';
      case 'Bills':
        return 'bill_logs';
      case 'Tasks':
        return 'task_logs';
      case 'Wishlist':
        return 'wishlist';
      case 'Movie Log':
        return 'movie_logs';
      case 'TV Log':
        return 'tv_logs';
      case 'Places':
        return 'place_logs';
      case 'Restaurants':
        return 'restaurant_logs';
      case 'Books':
        return 'book_logs';
      default:
        return 'reminders';
    }
  }

  Future<void> _loadFilteredDots(DateTime month) async {
    if (!mounted) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loadingDots = true;
      _activeDays.clear();
    });

    try {
      final tableName = _getTableName(_selectedTemplate);
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);

      final rows = await supabase
          .from(tableName)
          .select('day')
          .eq('user_id', user.id)
          .gte('day', _fmt.format(start))
          .lte('day', _fmt.format(end));

      final list = (rows as List).cast<dynamic>();
      final next = list
          .map((r) => r['day'].toString().substring(0, 10))
          .toSet()
          .cast<String>();

      if (!mounted) return;
      setState(() => _activeDays.addAll(next));
    } catch (e) {
      debugPrint('Dot Load Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loadingDots = false);
    }
  }

  Future<void> _loadDataForSelectedDay(DateTime day) async {
    if (!mounted) return;

    setState(() => _loadingData = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _displayList = <Map<String, dynamic>>[]);
        return;
      }

      final dayKey = _fmt.format(day);

      if (_selectedTemplate == 'Habits') {
        final rows = await supabase
            .from('habit_logs')
            .select('habit_name, is_completed, day')
            .eq('user_id', user.id)
            .eq('day', dayKey)
            .eq('is_completed', true)
            .not('habit_name', 'is', null);

        final result = List<Map<String, dynamic>>.from(rows);

        result.sort((a, b) {
          final an = (a['habit_name'] ?? '').toString();
          final bn = (b['habit_name'] ?? '').toString();
          return an.compareTo(bn);
        });

        if (!mounted) return;
        setState(() => _displayList = result);
        return;
      }

      if (_selectedTemplate == 'Sleep') {
        final rows = await supabase
            .from('sleep_logs')
            .select(
              'id, day, hours_slept, quality, wake_up_time, bedtime, notes',
            )
            .eq('user_id', user.id)
            .eq('day', dayKey)
            .order('id', ascending: false);

        final data = List<Map<String, dynamic>>.from(rows);

        if (!mounted) return;
        setState(() => _displayList = data);
        return;
      }

      final tableName = _getTableName(_selectedTemplate);
      final rows = await supabase
          .from(tableName)
          .select()
          .eq('user_id', user.id)
          .eq('day', dayKey);

      if (!mounted) return;
      setState(() => _displayList = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (!mounted) return;
      setState(() => _displayList = <Map<String, dynamic>>[]);
    } finally {
      if (!mounted) return;
      setState(() => _loadingData = false);
    }
  }

  void _showFilterManagement(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Manage Filters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: _allPossibleTemplates.map((t) {
                        final isVisible = _currentFilters.contains(t);
                        return CheckboxListTile(
                          title: Text(t),
                          value: isVisible,
                          activeColor: cs.primary,
                          onChanged: (bool? checked) {
                            // 1. Update UI inside Modal
                            setModalState(() {
                              if (checked == true) {
                                _currentFilters.add(t);
                              } else {
                                if (_currentFilters.length > 1) {
                                  _currentFilters.remove(t);
                                }
                              }
                              _currentFilters.sort(
                                (a, b) => _allPossibleTemplates
                                    .indexOf(a)
                                    .compareTo(
                                      _allPossibleTemplates.indexOf(b),
                                    ),
                              );
                            });

                            // 2. Update Main Calendar Screen UI
                            setState(() {
                              // If current active template was hidden, reset to the first available one
                              if (!_currentFilters.contains(
                                _selectedTemplate,
                              )) {
                                _selectedTemplate = _currentFilters.first;
                                _refreshAll();
                              }
                            });

                            // 3. PERSIST TO DB
                            _saveFilterPreferences();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // 1) FILTER CHIPS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ..._currentFilters.map((t) {
                // Using _currentFilters here
                final isSelected = _selectedTemplate == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t),
                    selected: isSelected,
                    onSelected: (val) {
                      if (!val) return;
                      setState(() => _selectedTemplate = t);
                      _refreshAll();
                    },
                    selectedColor: cs.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: const StadiumBorder(),
                  ),
                );
              }),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                onPressed: () => _showFilterManagement(context),
                tooltip: 'Manage Filters',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Optional: tiny indicator so _loadingDots isn't "unused"
        if (_loadingDots)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox(height: 2, child: LinearProgressIndicator()),
          ),

        // 2) CALENDAR
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _loadDataForSelectedDay(selected);
            },
            onPageChanged: (newFocused) {
              setState(() => _focusedDay = newFocused);
              _loadFilteredDots(newFocused);
            },
            calendarBuilders: CalendarBuilders(
              selectedBuilder: (context, day, focusedDay) => Container(
                margin: const EdgeInsets.all(6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              defaultBuilder: (context, day, focusedDay) {
                final hasData = _activeDays.contains(_fmt.format(day));
                return Opacity(
                  opacity: hasData ? 1.0 : 0.25,
                  child: Center(child: Text('${day.day}')),
                );
              },
              markerBuilder: (context, day, events) {
                if (!_activeDays.contains(_fmt.format(day))) return null;
                return Positioned(
                  bottom: 6,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ),

        // 3) BOTTOM DATA LIST
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(_selectedDay),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(_selectedTemplate, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: _loadingData
                      ? const Center(child: CircularProgressIndicator())
                      : _displayList.isEmpty
                      ? Center(
                          child: Text(
                            'No entries found',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _displayList.length,
                          itemBuilder: (context, i) =>
                              _buildAdaptiveTile(_displayList[i], cs),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdaptiveTile(Map<String, dynamic> item, ColorScheme cs) {
    String title = 'Logged Entry';
    String trailing = '';

    switch (_selectedTemplate) {
      case 'Habits':
        title = (item['habit_name'] ?? item['name'] ?? '').toString().trim();
        if (title.isEmpty) title = 'Unnamed habit';

        final bool isDone = item['is_completed'] == true;
        trailing = isDone ? 'Done' : 'Pending';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDone
                  ? Colors.green.withValues(alpha: 0.3)
                  : cs.primary.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone
                    ? Colors.green
                    : cs.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? cs.onSurface.withValues(alpha: 0.5)
                        : cs.onSurface,
                  ),
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  color: isDone ? Colors.green : cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case 'Water':
        title = '${item['amount_ml'] ?? item['amount'] ?? '0'} ml';
        trailing = 'Water';
        break;

      case 'Sleep':
        final hrs = (item['hours_slept'] as num?)?.toDouble() ?? 0.0;
        final quality = item['quality'];

        title = '${hrs.toStringAsFixed(1)} hrs';
        trailing = 'Quality: ${quality ?? '-'}';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(Icons.bedtime, color: cs.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case 'Mood':
        final mood =
            (item['mood_type'] ??
                    item['mood'] ??
                    item['feeling'] ??
                    item['type'] ??
                    item['label'] ??
                    '')
                .toString()
                .trim();

        final intensity = item['intensity'];

        title = mood.isEmpty ? 'Mood: Logged' : 'Mood: $mood';
        trailing = 'Intensity: ${intensity ?? '-'}';
        break;

      case 'Menstrual Cycle':
        title = 'Flow: ${item['flow'] ?? 'Logged'}';
        trailing = (item['symptoms'] ?? '').toString();
        break;

      case 'Tasks':
        title = (item['task'] ?? item['task_name'] ?? item['title'] ?? 'Task')
            .toString()
            .trim();

        final bool done =
            item['is_done'] == true ||
            item['is_completed'] == true ||
            item['completed'] == true;

        trailing = done ? 'Done' : 'Pending';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done
                  ? Colors.green.withValues(alpha: 0.3)
                  : cs.primary.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done
                    ? Colors.green
                    : cs.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done
                        ? cs.onSurface.withValues(alpha: 0.5)
                        : cs.onSurface,
                  ),
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  color: done ? Colors.green : cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case 'Wishlist':
        title = (item['item_name'] ?? 'Item').toString();
        trailing = item['price'] != null ? '£${item['price']}' : '';
        break;

      case 'Expenses':
        {
          final category = (item['category'] ?? item['title'] ?? 'Expense')
              .toString();

          final num? valueNum =
              item['cost'] as num? ??
              item['amount'] as num? ??
              item['price'] as num?;

          final currency = (item['currency'] ?? '£').toString();

          title = category;
          trailing = valueNum == null
              ? ''
              : '$currency${valueNum.toStringAsFixed(2)}';
          break;
        }

      case 'Income':
        {
          final category = (item['category'] ?? item['title'] ?? 'Income')
              .toString();

          final num? valueNum =
              item['amount'] as num? ??
              item['value'] as num? ??
              item['price'] as num?;

          final currency = (item['currency'] ?? '£').toString();

          title = category;
          trailing = valueNum == null
              ? ''
              : '$currency${valueNum.toStringAsFixed(2)}';
          break;
        }

      case 'Places':
        {
          final name = (item['place_name'] ?? item['name'] ?? '')
              .toString()
              .trim();

          title = name.isEmpty ? 'Place visited' : name;

          final rating = item['rating'];
          trailing = (rating is num && rating > 0)
              ? ('⭐' * rating.toInt())
              : '';
          break;
        }

      case 'Books':
        {
          final name = (item['book_title'] ?? item['title'] ?? '')
              .toString()
              .trim();

          title = name.isEmpty ? 'Books' : name;

          final rating = item['rating'];
          trailing = (rating is num && rating > 0)
              ? ('⭐' * rating.toInt())
              : '';
          break;
        }

      case 'Bills':
        title = (item['category'] ?? item['title'] ?? 'Finance').toString();
        trailing = item['amount'] != null ? '£${item['amount']}' : '';
        break;

      case 'Restaurants':
        {
          final name =
              (item['restaurant_name'] ??
                      item['name'] ??
                      item['place_name'] ??
                      '')
                  .toString()
                  .trim();

          title = name.isEmpty ? 'Restaurant visit' : name;

          final cuisine = item['cuisine_type'];
          trailing = (cuisine != null && cuisine.toString().isNotEmpty)
              ? cuisine.toString()
              : '';
          break;
        }

      case 'TV Log':
        {
          final titleText = (item['tv_title'] ?? item['title'] ?? '')
              .toString()
              .trim();

          title = titleText.isEmpty ? 'TV Log' : titleText;

          final rating = item['rating'];
          trailing = (rating is num && rating > 0)
              ? ('⭐' * rating.toInt())
              : '';
          break;
        }

      case 'Movie Log':
        {
          final titleText = (item['movie_title'] ?? item['title'] ?? '')
              .toString()
              .trim();

          title = titleText.isEmpty ? 'Movie' : titleText;

          final rating = item['rating'];
          trailing = (rating is num && rating > 0)
              ? ('⭐' * rating.toInt())
              : '';
          break;
        }

      default:
        title =
            (item['title'] ??
                    item['task_name'] ??
                    item['place_name'] ??
                    'Entry')
                .toString();
        trailing = (item['time'] ?? '').toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              color: cs.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
