import 'package:flutter/material.dart';

class MonthNavigator extends StatelessWidget {
  const MonthNavigator({
    super.key,
    required this.selectedMonth,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  String _monthName(int m) => _monthNames[m - 1];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        ),
        Expanded(
          child: Text(
            '${_monthName(selectedMonth.month)} ${selectedMonth.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          color: cs.primary,
        ),
      ],
    );
  }
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

Future<DateTime?> showMonthYearPicker({
  required BuildContext context,
  required DateTime initial,
}) async {
  int selectedMonth = initial.month;
  int selectedYear = initial.year;
  final now = DateTime.now();
  const startYear = 1980;
  final endYear = now.year + 5;
  final years = List.generate(
    endYear - startYear + 1,
    (index) => startYear + index,
  );

  final monthController = FixedExtentScrollController(
    initialItem: selectedMonth - 1,
  );
  final yearController = FixedExtentScrollController(
    initialItem: (selectedYear - startYear).clamp(0, years.length - 1),
  );

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose month',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: monthController,
                          itemExtent: 36,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() => selectedMonth = index + 1);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              if (index < 0 || index >= _monthNames.length) {
                                return null;
                              }
                              return Center(child: Text(_monthNames[index]));
                            },
                            childCount: _monthNames.length,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: yearController,
                          itemExtent: 36,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() => selectedYear = years[index]);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              if (index < 0 || index >= years.length) {
                                return null;
                              }
                              return Center(child: Text('${years[index]}'));
                            },
                            childCount: years.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                        onPressed: () {
                          Navigator.pop(
                            ctx,
                            DateTime(selectedYear, selectedMonth, 1),
                          );
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String _monthName(int m) => _monthNames[m - 1];
