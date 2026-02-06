import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';
import 'package:mind_buddy/services/notification_catalog.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  String _resolveBackTarget(BuildContext context, {String? from}) {
    switch (from) {
      case 'templates':
        return '/templates';
      case 'calendar':
        return '/calendar';
      default:
        return '/settings';
    }
  }

  String _formatScheduleSummary(
    NotificationSpaceSetting space,
    List<String> dayKeys,
    List<String> dayLabels,
  ) {
    if (!space.enabled) return '';
    if (space.time == null || space.time!.isEmpty) {
      return 'Set a gentle time →';
    }
    final time = space.time!;
    if (space.frequency == 'remember') {
      return 'Only when I open the app';
    }
    if (space.frequency == 'monthly') {
      return 'Monthly • ${space.dayOfMonth} • $time';
    }
    if (space.frequency == 'weekly') {
      final days = space.days.isEmpty ? ['Mon'] : _labelsForDays(space.days);
      return 'Weekly • ${days.join(' / ')} • $time';
    }
    if (space.frequency == 'certain') {
      final days = space.days.isEmpty ? ['Mon'] : _labelsForDays(space.days);
      return '${days.join(' / ')} • $time';
    }
    if (space.skipWeekends) {
      return 'Weekdays • $time';
    }
    return 'Most days • $time';
  }

  List<String> _labelsForDays(List<String> days) {
    const map = {
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'sun': 'Sun',
    };
    return days.map((d) => map[d] ?? d).toList();
  }

  Future<void> _openSpaceSheet({
    required BuildContext context,
    required WidgetRef ref,
    required NotificationCategory category,
    required NotificationSpaceSetting initial,
  }) async {
    final controller = ref.read(settingsControllerProvider);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            NotificationSpaceSetting space = initial;

            void apply(NotificationSpaceSetting next) {
              space = next;
              setSheetState(() {});
              controller.setNotificationSpaceSetting(category.id, next);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${category.title} reminder',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This is a suggestion, not a rule.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Frequency',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  RadioListTile<String>(
                    value: 'most',
                    groupValue: space.frequency,
                    title: const Text('Most days'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(frequency: value));
                    },
                  ),
                  RadioListTile<String>(
                    value: 'certain',
                    groupValue: space.frequency,
                    title: const Text('Certain days'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(frequency: value));
                    },
                  ),
                  RadioListTile<String>(
                    value: 'weekly',
                    groupValue: space.frequency,
                    title: const Text('Once a week'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(frequency: value));
                    },
                  ),
                  RadioListTile<String>(
                    value: 'monthly',
                    groupValue: space.frequency,
                    title: const Text('Once a month'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(frequency: value));
                    },
                  ),
                  RadioListTile<String>(
                    value: 'remember',
                    groupValue: space.frequency,
                    title: const Text('Only when I open the app'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(frequency: value));
                    },
                  ),
                  if (space.frequency == 'certain' ||
                      space.frequency == 'weekly')
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in const [
                          ['mon', 'Mon'],
                          ['tue', 'Tue'],
                          ['wed', 'Wed'],
                          ['thu', 'Thu'],
                          ['fri', 'Fri'],
                          ['sat', 'Sat'],
                          ['sun', 'Sun'],
                        ])
                          FilterChip(
                            label: Text(entry[1]),
                            selected: space.days.contains(entry[0]),
                            onSelected: (value) {
                              final nextDays = List<String>.from(space.days);
                              if (value) {
                                nextDays.add(entry[0]);
                              } else {
                                nextDays.remove(entry[0]);
                              }
                              apply(space.copyWith(days: nextDays));
                            },
                          ),
                      ],
                    ),
                  if (space.frequency == 'monthly')
                    ListTile(
                      title: const Text('Day of month'),
                      trailing: DropdownButton<int>(
                        value: space.dayOfMonth,
                        items: List.generate(
                          28,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('${index + 1}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          apply(space.copyWith(dayOfMonth: value));
                        },
                      ),
                    ),
                  ListTile(
                    title: const Text('Time (optional)'),
                    subtitle: Text(space.time ?? 'Off'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final current = space.time ?? '09:00';
                      final next = await _pickTime(context, current);
                      if (next != null) {
                        apply(space.copyWith(time: next));
                      }
                    },
                  ),
                  CheckboxListTile(
                    value: space.skipWeekends,
                    title: const Text('Skip weekends'),
                    onChanged: (value) {
                      apply(space.copyWith(skipWeekends: value == true));
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Style',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  RadioListTile<String>(
                    value: 'soft',
                    groupValue: space.style,
                    title: const Text('Soft nudge'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(style: value));
                    },
                  ),
                  RadioListTile<String>(
                    value: 'quiet',
                    groupValue: space.style,
                    title: const Text('Quiet nudge'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(style: value));
                    },
                  ),
                  RadioListTile<String>(
                    value: 'simple',
                    groupValue: space.style,
                    title: const Text('No text preview'),
                    onChanged: (value) {
                      if (value == null) return;
                      apply(space.copyWith(style: value));
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    final parts = current.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return null;

    final h = picked.hour.toString().padLeft(2, '0');
    final m = picked.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
    final dayKeys = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayLabels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final backTarget = _resolveBackTarget(context, from: from);

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(backTarget);
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'You do not have to set everything up at once.\nTurn on only what feels helpful.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'We will suggest something gently. You can change this anytime.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Global safety',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.quietHoursEnabled,
            title: const Text('Quiet Hours'),
            subtitle: const Text('Pause reminders during this window'),
            onChanged: (value) => controller.setQuietHours(
              enabled: value,
              start: settings.quietStart,
              end: settings.quietEnd,
            ),
          ),
          ListTile(
            title: const Text('Quiet start'),
            subtitle: Text(settings.quietStart),
            trailing: const Icon(Icons.chevron_right),
            onTap: settings.quietHoursEnabled
                ? () async {
                    final next = await _pickTime(context, settings.quietStart);
                    if (next != null) {
                      await controller.setQuietHours(
                        enabled: settings.quietHoursEnabled,
                        start: next,
                        end: settings.quietEnd,
                      );
                    }
                  }
                : null,
          ),
          ListTile(
            title: const Text('Quiet end'),
            subtitle: Text(settings.quietEnd),
            trailing: const Icon(Icons.chevron_right),
            onTap: settings.quietHoursEnabled
                ? () async {
                    final next = await _pickTime(context, settings.quietEnd);
                    if (next != null) {
                      await controller.setQuietHours(
                        enabled: settings.quietHoursEnabled,
                        start: settings.quietStart,
                        end: next,
                      );
                    }
                  }
                : null,
          ),
          ListTile(
            title: const Text('Max reminders per day'),
            subtitle: const Text('Many days can be quiet'),
            trailing: DropdownButton<int>(
              value: settings.maxNotificationsPerDay,
              items: const [
                DropdownMenuItem(value: 0, child: Text('0')),
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 2, child: Text('2')),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.setMaxNotificationsPerDay(value);
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Spaces',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Each space can nudge you in its own way. Nothing is daily unless you want it to be.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...notificationCategories.map((category) {
            final space = settings.notificationSpaceSettings[category.id] ??
                NotificationSpaceSetting.defaults();
            final summary =
                _formatScheduleSummary(space, dayKeys, dayLabels);
            return ListTile(
              onTap: () => _openSpaceSheet(
                context: context,
                ref: ref,
                category: category,
                initial: space,
              ),
              title: Text(category.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.description),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tap to edit dates and times',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  ),
                  if (space.enabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        summary,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            ),
                      ),
                    ),
                ],
              ),
              trailing: Switch(
                value: space.enabled,
                onChanged: (value) {
                  controller.setNotificationSpaceSetting(
                    category.id,
                    space.copyWith(enabled: value),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 16),
          Text(
            'Extras',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.calendarRemindersEnabled,
            title: const Text('Calendar reminders'),
            subtitle: const Text('Use reminder titles in notifications'),
            onChanged: (value) => controller.setCalendarRemindersEnabled(value),
          ),
          SwitchListTile(
            value: settings.pomodoroAlertsEnabled,
            title: const Text('Pomodoro finished alerts'),
            subtitle: const Text('Show a system notification at the end'),
            onChanged: (value) => controller.setPomodoroAlertsEnabled(value),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
