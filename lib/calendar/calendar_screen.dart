import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:ui';

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

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  bool _loadingDots = false;
  bool _loadingData = false;

  final Set<String> _activeDays = <String>{};
  List<Map<String, dynamic>> _displayList = [];

  // Updated template list to include Habits and clarify categories
  final List<String> _templates = [
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
    'Music History',
    'Movie Log',
    'TV Log',
    'Places',
    'Restaurants',
    'Books',
  ];

  String _selectedTemplate = 'Reminders Only';

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    _loadFilteredDots(_focusedDay);
    _loadDataForSelectedDay(_selectedDay ?? _focusedDay);
  }

  // --- REVISED SOURCE OF TRUTH: MAPPING UI TO DEDICATED SQL TABLES ---
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
      case 'Music History':
        return 'music_logs';
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
    setState(() {
      _loadingDots = true;
      _activeDays.clear();
    });
    try {
      final tableName = _getTableName(_selectedTemplate);
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);

      // Query the specific table for that category
      final rows = await supabase
          .from(tableName)
          .select('day')
          .gte('day', _fmt.format(start))
          .lte('day', _fmt.format(end));

      final next = (rows as List)
          .map((r) => r['day'].toString().substring(0, 10))
          .toSet();

      if (mounted) setState(() => _activeDays.addAll(next));
    } catch (e) {
      debugPrint("Dot Load Error: $e");
    } finally {
      if (mounted) setState(() => _loadingDots = false);
    }
  }

  Future<void> _loadDataForSelectedDay(DateTime day) async {
    if (!mounted) return;
    setState(() => _loadingData = true);
    try {
      final tableName = _getTableName(_selectedTemplate);
      final data = await supabase
          .from(tableName)
          .select()
          .eq('day', _fmt.format(day));

      if (mounted)
        setState(() => _displayList = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) setState(() => _displayList = []);
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // 1. FILTER CHIPS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: _templates.map((t) {
              final isSelected = _selectedTemplate == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedTemplate = t);
                      _refreshAll();
                    }
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
            }).toList(),
          ),
        ),

        // 2. CALENDAR
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2035),
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
              _focusedDay = newFocused;
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

        // 3. BOTTOM DATA LIST
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
                        DateFormat('EEEE, MMM d').format(_selectedDay!),
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

  // --- ADAPTIVE UI: Reading from direct columns instead of JSON ---
  Widget _buildAdaptiveTile(Map<String, dynamic> item, ColorScheme cs) {
    String title = 'Logged Entry';
    String trailing = '';

    switch (_selectedTemplate) {
      case 'Habits':
        title = item['habit_name'] ?? 'Habit';
        trailing = item['is_completed'] == true ? 'Done' : 'Pending';
        break;
      case 'Water':
        title = "${item['amount_ml'] ?? item['amount'] ?? '0'} ml";
        trailing = "Water";
        break;
      case 'Sleep':
        title = "${item['duration_hrs'] ?? '0'} hrs";
        trailing = "Quality: ${item['quality'] ?? 'N/A'}";
        break;
      case 'Mood':
        title = "Mood: ${item['mood_type'] ?? 'Logged'}";
        trailing = "Intensity: ${item['intensity'] ?? ''}";
        break;
      case 'Menstrual Cycle':
        title = "Flow: ${item['flow'] ?? 'Logged'}";
        trailing = item['symptoms'] ?? '';
        break;
      case 'Wishlist':
        title = item['item_name'] ?? 'Item';
        trailing = item['price'] != null ? '£${item['price']}' : '';
        break;
      case 'Expenses':
      case 'Income':
      case 'Bills':
        title = item['category'] ?? item['title'] ?? 'Finance';
        trailing = '£${item['amount']}';
        break;
      case 'Music History':
        title = item['song_name'] ?? 'Song';
        trailing = item['artist'] ?? '';
        break;
      case 'Movie Log':
        title = item['movie_title'] ?? 'Movie';
        trailing = "${item['rating'] ?? '0'}/5";
        break;
      default:
        title =
            item['title'] ?? item['task_name'] ?? item['place_name'] ?? 'Entry';
        trailing = item['time'] ?? '';
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
