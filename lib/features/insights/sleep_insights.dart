import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SleepDayAgg {
  SleepDayAgg({required this.day});
  final String day;
  int entriesCount = 0;
  double hoursTotal = 0;

  void add(double hours) {
    entriesCount += 1;
    hoursTotal += hours;
  }
}

class SleepInsights extends StatelessWidget {
  const SleepInsights({super.key});

  String _dateOnly(DateTime d) => DateTime(
    d.year,
    d.month,
    d.day,
  ).toIso8601String().split('T').first; // 'YYYY-MM-DD'

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final since = _dateOnly(
      DateTime.now().subtract(const Duration(days: 14)),
    ); // change to 30 if you want

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('log_entries')
          .select('day,data')
          .eq('data->>type', 'sleep') // ✅ filter only sleep rows
          .gte('day', since) // ✅ last X days
          .order('day', ascending: false)
          .limit(200), // optional safety cap
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Text('No sleep data yet.');
        }

        // ---- group by day ----
        final Map<String, SleepDayAgg> byDay = {};

        for (final r in rows) {
          final day = (r['day'] ?? '')
              .toString(); // should already be 'YYYY-MM-DD'
          final data = (r['data'] is Map)
              ? Map<String, dynamic>.from(r['data'] as Map)
              : <String, dynamic>{};

          // ✅ your JSON uses "hours_slept": 10
          final hours = _toDouble(data['hours_slept']);

          byDay.putIfAbsent(day, () => SleepDayAgg(day: day)).add(hours);
        }

        final list = byDay.values.toList()
          ..sort((a, b) => b.day.compareTo(a.day)); // latest first

        return Column(
          children: list.map((s) {
            return Card(
              child: ListTile(
                title: Text(s.day),
                subtitle: Text(
                  'Entries: ${s.entriesCount} • Total: ${s.hoursTotal.toStringAsFixed(1)}h',
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
