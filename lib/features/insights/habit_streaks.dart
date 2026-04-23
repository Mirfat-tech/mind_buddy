import 'package:flutter/material.dart';

import 'package:mind_buddy/features/habits/habit_local_repository.dart';

class HabitStreaks extends StatelessWidget {
  const HabitStreaks({super.key});

  Future<List<HabitStreakRow>> _loadRows() {
    debugPrint('INSIGHTS_LOAD_LOCAL source=habit_streaks');
    return HabitLocalRepository().loadStreakRows();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HabitStreakRow>>(
      future: _loadRows(),
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
            final habit = r.habit;
            final current = r.currentStreak;
            final longest = r.longestStreak;
            final lastDone = r.lastDoneDay ?? '—';

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
