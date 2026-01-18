import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitStreaks extends StatelessWidget {
  const HabitStreaks({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('v_habit_streaks')
          .select('habit,current_streak,longest_streak,last_done_day')
          .order('current_streak', ascending: false)
          .order('longest_streak', ascending: false)
          .order('habit', ascending: true),
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
          return const Text('No completed habits yet (status = Done).');
        }

        return Column(
          children: rows.map((r) {
            final habit = (r['habit'] ?? '').toString();
            final current = (r['current_streak'] ?? 0) as int;
            final longest = (r['longest_streak'] ?? 0) as int;
            final lastDone = (r['last_done_day'] ?? '').toString();

            return Card(
              child: ListTile(
                title: Text(habit),
                subtitle: Text(
                  'Current: $current days · Longest: $longest · Last done: $lastDone',
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
