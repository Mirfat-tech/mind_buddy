// lib/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
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

  /// Stores day strings like "2026-01-05"
  final Set<String> _activeDays = <String>{};

  @override
  void initState() {
    super.initState();
    _loadMonthDots(_focusedDay);
  }

  Future<void> _loadMonthDots(DateTime month) async {
    setState(() => _loadingDots = true);

    try {
      // Month range
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);

      final startStr = _fmt.format(start);
      final endStr = _fmt.format(end);

      // Pull all rows in the month and extract unique day strings.
      // NOTE: This assumes log_entries has a column named `day` (DATE or ISO string).
      final rows = await supabase
          .from('log_entries')
          .select('day')
          .gte('day', startStr)
          .lte('day', endStr);

      final next = <String>{};
      for (final r in rows as List) {
        final v = (r as Map)['day'];
        if (v == null) continue;
        if (v is String) {
          // If it's like "2026-01-05" or "2026-01-05T..."
          next.add(v.length >= 10 ? v.substring(0, 10) : v);
        } else {
          next.add(v.toString());
        }
      }

      if (!mounted) return;
      setState(() {
        _activeDays
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      // Keep screen alive even if dots fail
    } finally {
      if (!mounted) return;
      setState(() => _loadingDots = false);
    }
  }

  bool _hasDot(DateTime day) {
    final id = _fmt.format(day);
    return _activeDays.contains(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_loadingDots) const LinearProgressIndicator(minHeight: 2),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Tip: dots mean you logged something that day.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                _selectedDay != null && isSameDay(_selectedDay, day),

            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });

              final dayId = _fmt.format(selected);

              // Push so back works nicely
              context.push('/day/$dayId');
            },

            onPageChanged: (newFocused) {
              _focusedDay = newFocused;
              _loadMonthDots(newFocused);
            },

            calendarStyle: const CalendarStyle(outsideDaysVisible: false),

            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (!_hasDot(day)) return null;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: Center(
            child: Text(
              _selectedDay == null
                  ? 'Select a day'
                  : 'Selected: ${_fmt.format(_selectedDay!)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ],
    );
  }
}
