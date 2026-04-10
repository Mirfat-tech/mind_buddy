import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/common/money_format.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mind_buddy/services/subscription_plan_catalog.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/services/notification_service.dart';
import 'package:mind_buddy/guides/guide_manager.dart';

enum CalendarViewMode { month, week }

final calendarViewProvider = StateProvider<CalendarViewMode>(
  (ref) => CalendarViewMode.month,
);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final GlobalKey<_CalendarBodyState> _calendarKey =
      GlobalKey<_CalendarBodyState>();
  final GlobalKey _filterButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.calendar_month,
            tooltip: 'View',
            onPressed: () => _calendarKey.currentState?.showViewSheet(),
          ),
          MbGlowIconButton(
            icon: Icons.event_available,
            tooltip: 'Pick month',
            onPressed: () => _calendarKey.currentState?._showMonthYearPicker(),
          ),
          MbGlowIconButton(
            key: _filterButtonKey,
            icon: Icons.filter_alt_rounded,
            tooltip: 'Filters',
            onPressed: () => _calendarKey.currentState?.showFilterSheet(),
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_calendar',
        text: 'Tap a day to see entries. Filters live at the top.',
        iconText: '✨',
        child: _CalendarBody(
          key: _calendarKey,
          filterButtonKey: _filterButtonKey,
        ),
      ),
    );
  }
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({super.key, required this.filterButtonKey});

  final GlobalKey filterButtonKey;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  final SupabaseClient supabase = Supabase.instance.client;
  final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  static const int _maxReminderTimesPerDay = 50;

  late List<String> _currentFilters;
  final List<String> _allPossibleTemplates = [
    'Reminders Only',
    'Habits',
    'Water',
    'Sleep',
    'Mood',
    'Menstrual Cycle',
    'Fast',
    'Meditation',
    'Skincare',
    'Social',
    'Study',
    'Workout',
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
  bool _isPending = false;
  bool _trialBannerVisible = true;
  bool _savingReminder = false;

  final Set<String> _activeDays = <String>{};
  List<Map<String, dynamic>> _displayList = <Map<String, dynamic>>[];

  String _selectedTemplate = 'Reminders Only';
  static const String _lastTemplateKey = 'calendar_last_template';
  final GlobalKey _templateSelectorKey = GlobalKey();
  final GlobalKey _calendarGridKey = GlobalKey();
  final GlobalKey _completeCircleButtonKey = GlobalKey();
  final GlobalKey _editButtonKey = GlobalKey();
  final GlobalKey _deleteButtonKey = GlobalKey();

  String _expenseItemServiceLabel(Map<String, dynamic> item) {
    for (final key in <String>[
      'item_service',
      'title',
      'item',
      'service',
      'notes',
    ]) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '-';
  }

  @override
  void initState() {
    super.initState();
    // Initialize with something so the build doesn't crash before load finishes
    _currentFilters = ['Reminders Only'];
    _loadTrialBannerState();
    _loadUserPreferences();
  }

  Future<void> _loadTrialBannerState() async {
    final prefs = await SharedPreferences.getInstance();
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

  // --- NEW: LOAD FROM SUPABASE ---
  Future<void> _loadUserPreferences() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final info = await SubscriptionLimits.fetchForCurrentUser();
      _isPending = info.isPending;
      final prefs = await SharedPreferences.getInstance();
      final lastTemplate = prefs.getString(_lastTemplateKey);
      final data = await supabase
          .from('user_calendar_preferences')
          .select('visible_filters')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && data['visible_filters'] != null) {
        final savedFilters = List<String>.from(data['visible_filters']);
        final normalizedFilters = <String>[
          for (final filter in _allPossibleTemplates)
            if (savedFilters.contains(filter)) filter,
          for (final filter in _allPossibleTemplates)
            if (!savedFilters.contains(filter)) filter,
        ];
        setState(() {
          _currentFilters = normalizedFilters;
        });
      } else {
        setState(() => _currentFilters = List.from(_allPossibleTemplates));
      }
      if (lastTemplate != null && _currentFilters.contains(lastTemplate)) {
        setState(() => _selectedTemplate = lastTemplate);
      } else if (!_currentFilters.contains(_selectedTemplate)) {
        setState(() => _selectedTemplate = _currentFilters.first);
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      setState(() => _currentFilters = List.from(_allPossibleTemplates));
    }
    _refreshAll();
  }

  Future<void> _saveLastTemplate(String template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTemplateKey, template);
  }

  // --- NEW: SAVE TO SUPABASE ---
  Future<void> _saveFilterPreferences() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (_isPending) {
      if (mounted) {
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => context.go('/subscription'),
        );
      }
      return;
    }

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

  Future<void> showViewSheet() async {
    final current = ref.read(calendarViewProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewOption(
                label: 'Month',
                selected: current == CalendarViewMode.month,
                onTap: () {
                  ref.read(calendarViewProvider.notifier).state =
                      CalendarViewMode.month;
                  setState(() => _focusedDay = _selectedDay);
                  _loadFilteredDots(_focusedDay);
                  Navigator.pop(ctx);
                },
              ),
              _ViewOption(
                label: 'Week',
                selected: current == CalendarViewMode.week,
                onTap: () {
                  ref.read(calendarViewProvider.notifier).state =
                      CalendarViewMode.week;
                  setState(() => _focusedDay = _selectedDay);
                  _loadFilteredDots(_focusedDay);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMonthYearPicker() async {
    final now = DateTime.now();
    const minYear = 1980;
    final maxYear = now.year + 5;
    DateTime tempPicked = DateTime(_focusedDay.year, _focusedDay.month, 1);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose month',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    minimumYear: minYear,
                    maximumYear: maxYear,
                    initialDateTime: tempPicked,
                    onDateTimeChanged: (value) {
                      tempPicked = DateTime(value.year, value.month, 1);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, tempPicked),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _focusedDay = DateTime(picked.year, picked.month, 1);
        _selectedDay = DateTime(picked.year, picked.month, 1);
      });
      _refreshAll();
    }
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
      case 'Fast':
        return 'fast_logs';
      case 'Meditation':
        return 'meditation_logs';
      case 'Skincare':
        return 'skin_care_logs';
      case 'Social':
        return 'social_logs';
      case 'Study':
        return 'study_logs';
      case 'Workout':
        return 'workout_logs';
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
    if (_isPending) {
      setState(() {
        _loadingDots = false;
        _activeDays.clear();
      });
      return;
    }

    setState(() {
      _loadingDots = true;
      _activeDays.clear();
    });

    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);

      if (_selectedTemplate == 'Reminders Only') {
        final rows = await supabase
            .from('reminders')
            .select('id, day, repeat, repeat_days, end_day')
            .eq('user_id', user.id);
        final skipRows = await supabase
            .from('reminders_skips')
            .select('reminder_id, day')
            .eq('user_id', user.id)
            .gte('day', _fmt.format(start))
            .lte('day', _fmt.format(end));
        final skipped = (skipRows as List)
            .map((r) => '${r['reminder_id']}-${r['day']}')
            .toSet();
        final dates = _expandReminderDates(
          rows as List,
          start,
          end,
          skipped: skipped,
        );
        if (!mounted) return;
        setState(() => _activeDays.addAll(dates));
      } else {
        final tableName = _getTableName(_selectedTemplate);
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
      }
    } catch (e) {
      debugPrint('Dot Load Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loadingDots = false);
    }
  }

  Set<String> _expandReminderDates(
    List rows,
    DateTime start,
    DateTime end, {
    Set<String>? skipped,
  }) {
    final days = <String>{};
    for (final raw in rows) {
      final r = Map<String, dynamic>.from(raw as Map);
      final repeat = (r['repeat'] ?? 'never').toString().toLowerCase();
      final repeatDaysRaw = (r['repeat_days'] ?? '').toString().toLowerCase();
      final repeatDays = repeatDaysRaw
          .split(',')
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList();
      final dayStr = (r['day'] ?? '').toString();
      final endStr = (r['end_day'] ?? '').toString();
      final reminderId = (r['id'] ?? '').toString();
      if (dayStr.isEmpty) continue;
      final baseDate = DateTime.tryParse(dayStr);
      final endDate = endStr.isEmpty ? null : DateTime.tryParse(endStr);
      if (baseDate == null) continue;

      if (repeat == 'never') {
        if (baseDate.isBefore(start) || baseDate.isAfter(end)) continue;
        final key = '$reminderId-${_fmt.format(baseDate)}';
        if (skipped == null || !skipped.contains(key)) {
          days.add(_fmt.format(baseDate));
        }
        continue;
      }

      DateTime cursor = DateTime(start.year, start.month, start.day);
      while (!cursor.isAfter(end)) {
        bool match = false;
        switch (repeat) {
          case 'daily':
            match = !cursor.isBefore(baseDate);
            break;
          case 'weekly':
            match =
                cursor.isAfter(baseDate) || cursor.isAtSameMomentAs(baseDate)
                ? cursor.weekday == baseDate.weekday
                : false;
            break;
          case 'fortnightly':
            if (cursor.isBefore(baseDate)) {
              match = false;
            } else {
              final diff = cursor.difference(baseDate).inDays;
              match = diff % 14 == 0;
            }
            break;
          case 'monthly':
            match =
                cursor.day == baseDate.day &&
                (cursor.isAfter(baseDate) || cursor.isAtSameMomentAs(baseDate));
            break;
          case 'weekdays':
            match =
                cursor.weekday >= DateTime.monday &&
                cursor.weekday <= DateTime.friday &&
                !cursor.isBefore(baseDate);
            break;
          case 'weekends':
            match =
                (cursor.weekday == DateTime.saturday ||
                    cursor.weekday == DateTime.sunday) &&
                !cursor.isBefore(baseDate);
            break;
          case 'custom':
            final key = _weekdayKey(cursor.weekday);
            match = repeatDays.contains(key) && !cursor.isBefore(baseDate);
            break;
        }

        if (match) {
          if (endDate != null && cursor.isAfter(endDate)) {
            cursor = cursor.add(const Duration(days: 1));
            continue;
          }
          final key = '$reminderId-${_fmt.format(cursor)}';
          if (skipped == null || !skipped.contains(key)) {
            days.add(_fmt.format(cursor));
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return days;
  }

  String _weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
    }
    return '';
  }

  List<String> _parseReminderTimes(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.trim().isEmpty) return <String>[];
    final seen = <String>{};
    final parsed = <String>[];
    for (final token in text.split(',')) {
      final v = token.trim();
      final parts = v.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      if (h < 0 || h > 23 || m < 0 || m > 59) continue;
      final normalized =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      if (seen.add(normalized)) {
        parsed.add(normalized);
      }
    }
    parsed.sort();
    return parsed;
  }

  String _joinReminderTimes(List<String> times) {
    return _parseReminderTimes(
      times.join(','),
    ).take(_maxReminderTimesPerDay).join(',');
  }

  String _firstReminderTime(dynamic raw) {
    final times = _parseReminderTimes(raw);
    if (times.isEmpty) return '';
    return times.first;
  }

  bool _reminderOccursOnDate(Map<String, dynamic> r, DateTime date) {
    final repeat = (r['repeat'] ?? 'never').toString().toLowerCase();
    final repeatDaysRaw = (r['repeat_days'] ?? '').toString().toLowerCase();
    final repeatDays = repeatDaysRaw
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toSet();
    final dayStr = (r['day'] ?? '').toString();
    final endStr = (r['end_day'] ?? '').toString();
    final baseDate = DateTime.tryParse(dayStr);
    final endDate = endStr.isEmpty ? null : DateTime.tryParse(endStr);
    if (baseDate == null) return false;
    final target = DateTime(date.year, date.month, date.day);
    final base = DateTime(baseDate.year, baseDate.month, baseDate.day);

    if (repeat == 'never') {
      return target == base;
    }
    if (target.isBefore(base)) return false;
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      if (target.isAfter(end)) return false;
    }

    switch (repeat) {
      case 'daily':
        return true;
      case 'weekly':
        return target.weekday == base.weekday;
      case 'fortnightly':
        return target.difference(base).inDays % 14 == 0;
      case 'monthly':
        return target.day == base.day;
      case 'weekdays':
        return target.weekday >= DateTime.monday &&
            target.weekday <= DateTime.friday;
      case 'weekends':
        return target.weekday == DateTime.saturday ||
            target.weekday == DateTime.sunday;
      case 'custom':
        return repeatDays.contains(_weekdayKey(target.weekday));
      default:
        return false;
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
      if (_isPending) {
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

      if (_selectedTemplate == 'Reminders Only') {
        final rows = await supabase
            .from('reminders')
            .select('id, title, day, time, repeat, repeat_days, end_day')
            .eq('user_id', user.id);
        final doneRows = await supabase
            .from('reminders_done')
            .select('reminder_id, day')
            .eq('user_id', user.id)
            .eq('day', dayKey);
        final skipRows = await supabase
            .from('reminders_skips')
            .select('reminder_id, day')
            .eq('user_id', user.id)
            .eq('day', dayKey);
        final doneKeys = (doneRows as List)
            .map((r) => '${r['reminder_id']}-${r['day']}')
            .toSet();
        final skipped = (skipRows as List)
            .map((r) => '${r['reminder_id']}-${r['day']}')
            .toSet();
        final data = (rows as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .where((r) {
              final occurs = _reminderOccursOnDate(r, day);
              if (!occurs) return false;
              final key = '${r['id']}-$dayKey';
              return !skipped.contains(key);
            })
            .map((r) {
              final key = '${r['id']}-$dayKey';
              return {
                ...r,
                '_occurrence_day': dayKey,
                '_is_done_for_day': doneKeys.contains(key),
              };
            })
            .toList();
        data.sort((a, b) {
          final ta = _firstReminderTime(a['time']);
          final tb = _firstReminderTime(b['time']);
          return ta.compareTo(tb);
        });
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

  Future<void> _showReminderDialog({Map<String, dynamic>? existing}) async {
    if (_savingReminder) return;
    if (_isPending) {
      await SubscriptionLimits.showTrialUpgradeDialog(
        context,
        onUpgrade: () => context.go('/subscription'),
      );
      return;
    }
    final titleController = TextEditingController(
      text: (existing?['title'] ?? '').toString(),
    );
    final selectedTimes = _parseReminderTimes(existing?['time']);
    String repeat = (existing?['repeat'] ?? 'never').toString().toLowerCase();
    String customDays = (existing?['repeat_days'] ?? '')
        .toString()
        .toLowerCase();
    final selectedDays = <String>{
      for (final d in customDays.split(','))
        if (d.trim().isNotEmpty) d.trim(),
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add reminder' : 'Edit reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setTimesState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Times'),
                    const SizedBox(height: 8),
                    if (selectedTimes.isEmpty)
                      Text(
                        'No times selected',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (selectedTimes.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedTimes
                            .map(
                              (time) => InputChip(
                                label: Text(time),
                                onDeleted: () {
                                  setTimesState(() {
                                    selectedTimes.remove(time);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              selectedTimes.length >= _maxReminderTimesPerDay
                              ? null
                              : () async {
                                  final seed = selectedTimes.isNotEmpty
                                      ? selectedTimes.last
                                      : '09:00';
                                  final parts = seed.split(':');
                                  final h = int.tryParse(parts[0]) ?? 9;
                                  final m = int.tryParse(parts[1]) ?? 0;
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: TimeOfDay(hour: h, minute: m),
                                  );
                                  if (picked == null) return;
                                  final value =
                                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                  setTimesState(() {
                                    if (!selectedTimes.contains(value)) {
                                      selectedTimes.add(value);
                                      selectedTimes.sort();
                                    }
                                  });
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Add time'),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${selectedTimes.length}/$_maxReminderTimesPerDay',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (selectedTimes.length >= _maxReminderTimesPerDay)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Max 50 reminders per day',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setInnerState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: repeat,
                      decoration: const InputDecoration(labelText: 'Repeat'),
                      items: const [
                        DropdownMenuItem(value: 'never', child: Text('Never')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom days'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'fortnightly',
                          child: Text('Fortnightly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'weekdays',
                          child: Text('Weekdays only'),
                        ),
                        DropdownMenuItem(
                          value: 'weekends',
                          child: Text('Weekends only'),
                        ),
                      ],
                      onChanged: (v) =>
                          setInnerState(() => repeat = v ?? 'never'),
                    ),
                    if (repeat == 'custom') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children:
                            const [
                              'mon',
                              'tue',
                              'wed',
                              'thu',
                              'fri',
                              'sat',
                              'sun',
                            ].map((d) {
                              final label = d[0].toUpperCase() + d.substring(1);
                              return FilterChip(
                                label: Text(label),
                                selected: selectedDays.contains(d),
                                onSelected: (val) {
                                  setInnerState(() {
                                    if (val) {
                                      selectedDays.add(d);
                                    } else {
                                      selectedDays.remove(d);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final title = titleController.text.trim();
    final normalizedTimes = _parseReminderTimes(
      _joinReminderTimes(selectedTimes),
    );
    if (title.isEmpty) return;
    if (normalizedTimes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick at least one reminder time.')),
        );
      }
      return;
    }
    if (normalizedTimes.length > _maxReminderTimesPerDay) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max 50 reminders per day')),
        );
      }
      return;
    }
    if (repeat == 'custom' && selectedDays.isEmpty) return;

    setState(() => _savingReminder = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final payload = {
        'user_id': user.id,
        'day': _fmt.format(_selectedDay),
        'title': title,
        'time': normalizedTimes.join(','),
        'repeat': repeat,
        'repeat_days': repeat == 'custom' ? selectedDays.join(',') : null,
      };
      if (existing == null) {
        await supabase.from('reminders').insert(payload);
      } else {
        await supabase
            .from('reminders')
            .update(payload)
            .eq('id', existing['id']);
      }
      await _loadDataForSelectedDay(_selectedDay);
      await _loadFilteredDots(_focusedDay);
      final settings = ref.read(settingsControllerProvider).settings;
      await NotificationService.instance.rescheduleAll(settings);
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _deleteReminder(Map<String, dynamic> item) async {
    if (_isPending) {
      await SubscriptionLimits.showTrialUpgradeDialog(
        context,
        onUpgrade: () => context.go('/subscription'),
      );
      return;
    }
    final repeat = (item['repeat'] ?? 'never').toString().toLowerCase();
    final isRepeating = repeat != 'never';
    final ok = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isRepeating ? 'Delete repeating reminder?' : 'Delete reminder?',
        ),
        content: Text(
          isRepeating
              ? 'This will delete it for all future dates. To remove only one day, use “Skip this occurrence”.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          if (isRepeating)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'from_today'),
              child: const Text('Delete from today'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isRepeating ? 'Delete all' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == null || ok == false) return;
    if (ok == 'from_today') {
      final endDay = _fmt.format(
        _selectedDay.subtract(const Duration(days: 1)),
      );
      await supabase
          .from('reminders')
          .update({'end_day': endDay})
          .eq('id', item['id']);
    } else if (ok == true) {
      await supabase.from('reminders').delete().eq('id', item['id']);
    } else {
      return;
    }
    await _loadDataForSelectedDay(_selectedDay);
    await _loadFilteredDots(_focusedDay);
    final settings = ref.read(settingsControllerProvider).settings;
    await NotificationService.instance.rescheduleAll(settings);
  }

  Future<void> _skipReminderOccurrence(Map<String, dynamic> item) async {
    if (_isPending) {
      await SubscriptionLimits.showTrialUpgradeDialog(
        context,
        onUpgrade: () => context.go('/subscription'),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip this occurrence?'),
        content: const Text(
          'We will skip only this day. The reminder repeats as usual next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final dayKey = _fmt.format(_selectedDay);
    await supabase.from('reminders_skips').upsert({
      'user_id': user.id,
      'reminder_id': item['id'],
      'day': dayKey,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _loadDataForSelectedDay(_selectedDay);
    await _loadFilteredDots(_focusedDay);
    final settings = ref.read(settingsControllerProvider).settings;
    await NotificationService.instance.rescheduleAll(settings);
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
                      children: [
                        CheckboxListTile(
                          title: const Text('Select all'),
                          value:
                              _currentFilters.length ==
                              _allPossibleTemplates.length,
                          activeColor: cs.primary,
                          onChanged: (checked) {
                            setModalState(() {
                              if (checked == true) {
                                _currentFilters = List.from(
                                  _allPossibleTemplates,
                                );
                              } else {
                                _currentFilters = ['Reminders Only'];
                              }
                              _currentFilters.sort(
                                (a, b) => _allPossibleTemplates
                                    .indexOf(a)
                                    .compareTo(
                                      _allPossibleTemplates.indexOf(b),
                                    ),
                              );
                            });

                            setState(() {
                              if (!_currentFilters.contains(
                                _selectedTemplate,
                              )) {
                                _selectedTemplate = _currentFilters.first;
                                _refreshAll();
                              }
                            });

                            _saveFilterPreferences();
                          },
                        ),
                        const Divider(height: 12),
                        ..._allPossibleTemplates.map((t) {
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
                        }),
                      ],
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

  void showFilterSheet() {
    _showFilterManagement(context);
  }

  Future<void> showGuide({bool force = false}) async {
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'calendar',
      force: force,
      steps: [
        GuideStep(
          key: _templateSelectorKey,
          title: 'Choose your template',
          body: 'Select a template to view your monthly data.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _calendarGridKey,
          title: 'Spotted a dot?',
          body: 'Dots mean something was logged that day.',
          align: GuideAlign.bottom,
        ),
        GuideStep(
          key: _completeCircleButtonKey,
          title: 'Close the loop',
          body: 'Tap the empty circle to mark complete.',
          align: GuideAlign.top,
        ),
        GuideStep(
          key: _editButtonKey,
          title: 'Need to tweak something?',
          body: 'Use edit or delete to adjust the entry.',
          align: GuideAlign.top,
        ),
        GuideStep(
          key: widget.filterButtonKey,
          title: 'Too many bubbles?',
          body: 'Use filter to narrow your view.',
          align: GuideAlign.bottom,
        ),
      ],
    );
  }

  Widget _buildCalendarContainer(ColorScheme cs, Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }

  Widget _buildMonthWeekCalendar(ColorScheme cs, CalendarViewMode mode) {
    final format = mode == CalendarViewMode.week
        ? CalendarFormat.week
        : CalendarFormat.month;
    return TableCalendar(
      firstDay: DateTime.utc(1980, 1, 1),
      lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
      focusedDay: _focusedDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarFormat: format,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Month',
        CalendarFormat.week: 'Week',
      },
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
        headerTitleBuilder: (context, day) {
          return GestureDetector(
            onTap: _showMonthYearPicker,
            child: Text(
              DateFormat('MMMM yyyy').format(day),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          );
        },
        selectedBuilder: (context, day, focusedDay) => Container(
          margin: const EdgeInsets.all(6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewMode = ref.watch(calendarViewProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showGuide();
    });

    return Column(
      children: [
        if (_isPending && _trialBannerVisible)
          _TrialBanner(
            onUpgrade: () => context.go('/subscription'),
            onSkip: () => _dismissTrialBanner(),
          ),
        // 1) FILTER CHIPS
        SingleChildScrollView(
          key: _templateSelectorKey,
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
                      _saveLastTemplate(t);
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
        KeyedSubtree(
          key: _calendarGridKey,
          child: _buildCalendarContainer(
            cs,
            _buildMonthWeekCalendar(cs, viewMode),
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
                      if (_selectedTemplate == 'Reminders Only') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _savingReminder
                              ? null
                              : () => _showReminderDialog(),
                          tooltip: 'Add reminder',
                        ),
                      ],
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

      case 'Fast':
        {
          final hours = item['duration_hours'];
          final feeling = (item['feeling'] ?? '').toString().trim();
          title = hours == null ? 'Fast logged' : '$hours hours fasted';
          trailing = feeling.isEmpty ? '' : feeling;
          break;
        }

      case 'Meditation':
        {
          final minutesRaw = item['duration_minutes'];
          final technique = (item['technique'] ?? '').toString().trim();
          String durationLabel = 'Meditation logged';
          if (minutesRaw != null) {
            final minutes = minutesRaw is num
                ? minutesRaw.toDouble()
                : double.tryParse(minutesRaw.toString());
            if (minutes != null) {
              durationLabel =
                  '${minutes.toStringAsFixed(minutes % 1 == 0 ? 0 : 1)} min meditation';
            }
          }
          title = durationLabel;
          trailing = technique.isEmpty ? '' : technique;
          break;
        }

      case 'Skincare':
        {
          final routine = (item['routine_type'] ?? '').toString().trim();
          final condition = (item['skin_condition'] ?? '').toString().trim();
          title = routine.isEmpty ? 'Skincare logged' : routine;
          trailing = condition;
          break;
        }

      case 'Social':
        {
          final personEvent = (item['person_event'] ?? item['people'] ?? '')
              .toString()
              .trim();
          final activity = (item['activity_type'] ?? '').toString().trim();
          title = personEvent.isEmpty ? 'Social time logged' : personEvent;
          trailing = activity;
          break;
        }

      case 'Study':
        {
          final subject = (item['subject'] ?? '').toString().trim();
          final rating = item['focus_rating'];
          title = subject.isEmpty ? 'Study session logged' : subject;
          trailing = rating == null ? '' : 'Focus: $rating';
          break;
        }

      case 'Workout':
        {
          final exercise = (item['exercise'] ?? '').toString().trim();
          final sets = item['sets']?.toString() ?? '';
          final reps = item['reps']?.toString() ?? '';
          title = exercise.isEmpty ? 'Workout logged' : exercise;
          if (sets.isNotEmpty && reps.isNotEmpty) {
            trailing = '$sets sets x $reps reps';
          } else if (sets.isNotEmpty) {
            trailing = '$sets sets';
          } else if (reps.isNotEmpty) {
            trailing = '$reps reps';
          } else {
            trailing = '';
          }
          break;
        }

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
              IconButton(
                icon: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done
                      ? Colors.green
                      : cs.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
                tooltip: 'Mark done',
                onPressed: () async {
                  final id = item['id'];
                  if (id == null) return;
                  final user = supabase.auth.currentUser;
                  if (user == null) return;
                  final next = !done;
                  try {
                    await supabase
                        .from('task_logs')
                        .update({'is_done': next})
                        .eq('id', id)
                        .eq('user_id', user.id);
                    await _loadDataForSelectedDay(_selectedDay);
                    await _loadFilteredDots(_focusedDay);
                  } catch (_) {}
                },
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

        final rawStatus = (item['status'] ?? '').toString();
        final normalizedStatus = rawStatus
            .replaceAll(RegExp(r'[^a-zA-Z\\s]'), '')
            .toLowerCase()
            .trim();
        final bool done = normalizedStatus == 'received';

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
              IconButton(
                icon: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done
                      ? Colors.green
                      : cs.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
                tooltip: 'Mark done',
                onPressed: () async {
                  final id = item['id'];
                  if (id == null) return;
                  final user = supabase.auth.currentUser;
                  if (user == null) return;
                  try {
                    await supabase
                        .from('wishlist')
                        .update({'status': done ? 'Waiting' : 'Received'})
                        .eq('id', id)
                        .eq('user_id', user.id)
                        .select('id')
                        .maybeSingle();
                    await _loadDataForSelectedDay(_selectedDay);
                    await _loadFilteredDots(_focusedDay);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Update failed: $e')),
                      );
                    }
                  }
                },
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
              if (trailing.isNotEmpty)
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

      case 'Expenses':
        {
          final itemService = _expenseItemServiceLabel(item);
          final category = (item['category'] ?? 'Expense').toString().trim();

          final num? valueNum =
              item['cost'] as num? ??
              item['amount'] as num? ??
              item['price'] as num?;

          final currency = (item['currency'] ?? '£').toString();

          title = itemService != '-' ? itemService : category;
          final amountText = valueNum == null
              ? ''
              : formatCurrencyAmount(valueNum, currency);
          trailing = category.isEmpty || category == title
              ? amountText
              : '$category • $amountText';
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
              : formatCurrencyAmount(valueNum, currency);
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
        trailing = item['amount'] != null
            ? formatCurrencyAmount(
                item['amount'],
                (item['currency'] ?? 'GBP').toString(),
              )
            : '';
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

      case 'Reminders Only':
        title = (item['title'] ?? 'Reminder').toString().trim();
        if (title.isEmpty) title = 'Reminder';
        final reminderTimes = _parseReminderTimes(item['time']);
        final repeat = (item['repeat'] ?? 'never').toString().toLowerCase();
        if (reminderTimes.isEmpty) {
          trailing = '';
        } else if (reminderTimes.length == 1) {
          trailing = reminderTimes.first;
        } else {
          trailing = '${reminderTimes.first} (+${reminderTimes.length - 1})';
        }
        if (repeat != 'never') {
          trailing = trailing.isEmpty ? 'Repeats' : '$trailing · Repeats';
        }
        break;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (trailing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      trailing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_selectedTemplate == 'Reminders Only') ...[
            const SizedBox(width: 8),
            IconButton(
              key: item == _displayList.first ? _completeCircleButtonKey : null,
              icon: Icon(
                (item['_is_done_for_day'] == true)
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: (item['_is_done_for_day'] == true)
                    ? Colors.green
                    : cs.onSurface.withValues(alpha: 0.3),
              ),
              tooltip: 'Mark done',
              onPressed: () async {
                final next = !(item['_is_done_for_day'] == true);
                final user = supabase.auth.currentUser;
                if (user == null) return;
                final dayKey = _fmt.format(_selectedDay);
                if (next) {
                  await supabase.from('reminders_done').upsert({
                    'user_id': user.id,
                    'reminder_id': item['id'],
                    'day': dayKey,
                    'created_at': DateTime.now().toIso8601String(),
                  });
                } else {
                  await supabase
                      .from('reminders_done')
                      .delete()
                      .eq('user_id', user.id)
                      .eq('reminder_id', item['id'])
                      .eq('day', dayKey);
                }
                await _loadDataForSelectedDay(_selectedDay);
                await _loadFilteredDots(_focusedDay);
              },
            ),
            if ((item['repeat'] ?? 'never').toString().toLowerCase() != 'never')
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                tooltip: 'Skip this occurrence',
                onPressed: () => _skipReminderOccurrence(item),
              ),
            IconButton(
              key: item == _displayList.first ? _editButtonKey : null,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _showReminderDialog(existing: item),
            ),
            IconButton(
              key: item == _displayList.first ? _deleteButtonKey : null,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _deleteReminder(item),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewOption extends StatelessWidget {
  const _ViewOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: cs.primary)
          : Icon(Icons.circle_outlined, color: cs.outline),
      onTap: onTap,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
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
      ),
    );
  }
}
