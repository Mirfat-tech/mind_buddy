import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  static const String _calendarReminderSpaceId = 'calendar_reminders';
  static const String _pomodoroAlertSpaceId = 'pomodoro_finished';
  static const List<int> _stopwatchReminderOptions = [0, 5, 10, 15, 30, 60];

  final _supabase = Supabase.instance.client;

  bool _loadingHabits = true;
  List<Map<String, dynamic>> _habits = const [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

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

  Future<void> _loadHabits() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _habits = const [];
        _loadingHabits = false;
      });
      return;
    }

    try {
      final rows = await _supabase
          .from('user_habits')
          .select('id, name, sort_order, category_id, habit_categories(name)')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('sort_order');

      final habits = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _habits = habits;
        _loadingHabits = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _habits = const [];
        _loadingHabits = false;
      });
    }
  }

  String _formatScheduleSummary(NotificationSpaceSetting space) {
    if (!space.enabled) return '';
    final time = (space.time == null || space.time!.isEmpty)
        ? '09:00'
        : space.time!;
    if (space.frequency == 'remember') {
      return 'Only when I open the app';
    }
    if (space.frequency == 'monthly') {
      return 'Once a month • ${space.dayOfMonth} • $time';
    }
    if (space.frequency == 'weekly') {
      final days = space.days.isEmpty ? ['Mon'] : _labelsForDays(space.days);
      return 'Once a week • ${days.join(' / ')} • $time';
    }
    if (space.frequency == 'certain') {
      final days = space.days.isEmpty ? ['Mon'] : _labelsForDays(space.days);
      return '${days.join(' / ')} • $time';
    }
    if (space.skipWeekends) {
      return 'Every day • $time • Skip weekends';
    }
    return 'Every day • $time';
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

  Future<void> _openScheduleSheet({
    required BuildContext context,
    required String title,
    required NotificationSpaceSetting initial,
    required Future<void> Function(NotificationSpaceSetting setting) onSave,
  }) async {
    var space = initial;

    final result = await showModalBottomSheet<NotificationSpaceSetting>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void apply(NotificationSpaceSetting next) {
              setSheetState(() => space = next);
            }

            final dayValues = List<int>.generate(28, (index) => index + 1);
            final safeDayValue = dayValues.contains(space.dayOfMonth)
                ? space.dayOfMonth
                : null;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.82,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
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
                                title: const Text('Every day'),
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
                                          final nextDays = List<String>.from(
                                            space.days,
                                          );
                                          if (value) {
                                            if (!nextDays.contains(entry[0])) {
                                              nextDays.add(entry[0]);
                                            }
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
                                    value: safeDayValue,
                                    hint: const Text('Select'),
                                    items: dayValues
                                        .map(
                                          (day) => DropdownMenuItem<int>(
                                            value: day,
                                            child: Text('$day'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      apply(space.copyWith(dayOfMonth: value));
                                    },
                                  ),
                                ),
                              ListTile(
                                title: const Text('Time'),
                                subtitle: Text(space.time ?? '09:00'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final current = space.time ?? '09:00';
                                  final next = await _pickTime(
                                    context,
                                    current,
                                  );
                                  if (next != null) {
                                    apply(space.copyWith(time: next));
                                  }
                                },
                              ),
                              if (space.frequency == 'most')
                                CheckboxListTile(
                                  value: space.skipWeekends,
                                  title: const Text('Skip weekends'),
                                  onChanged: (value) {
                                    apply(
                                      space.copyWith(
                                        skipWeekends: value == true,
                                      ),
                                    );
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
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(space),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    await onSave(result);
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    final parts = current.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
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

  NotificationSpaceSetting _effectiveEnabledSetting(
    NotificationSpaceSetting current,
    bool enabled,
  ) {
    return current.copyWith(
      enabled: enabled,
      time: current.time == null || current.time!.isEmpty
          ? '09:00'
          : current.time,
    );
  }

  Future<void> _saveHabitSetting(
    String habitId,
    NotificationSpaceSetting setting,
  ) async {
    final controller = ref.read(settingsControllerProvider);
    await controller.setNotificationSpaceSetting('habit:$habitId', setting);
  }

  Future<void> _setCalendarSetting(
    NotificationSpaceSetting setting,
    bool enabled,
  ) async {
    final controller = ref.read(settingsControllerProvider);
    final nextSpaces = Map<String, NotificationSpaceSetting>.from(
      ref.read(settingsControllerProvider).settings.notificationSpaceSettings,
    );
    nextSpaces[_calendarReminderSpaceId] = setting.copyWith(enabled: enabled);
    await controller.update(
      ref
          .read(settingsControllerProvider)
          .settings
          .copyWith(
            calendarRemindersEnabled: enabled,
            notificationSpaceSettings: nextSpaces,
          ),
    );
  }

  Future<void> _setPomodoroSetting(
    NotificationSpaceSetting setting,
    bool enabled,
  ) async {
    final controller = ref.read(settingsControllerProvider);
    final nextSpaces = Map<String, NotificationSpaceSetting>.from(
      ref.read(settingsControllerProvider).settings.notificationSpaceSettings,
    );
    nextSpaces[_pomodoroAlertSpaceId] = setting.copyWith(enabled: enabled);
    await controller.update(
      ref
          .read(settingsControllerProvider)
          .settings
          .copyWith(
            pomodoroAlertsEnabled: enabled,
            notificationSpaceSettings: nextSpaces,
          ),
    );
  }

  Widget _buildCoreTile({
    required BuildContext context,
    required String title,
    required bool enabled,
    required NotificationSpaceSetting space,
    bool showSummaryWhenEnabled = true,
    bool showEditHint = true,
    required ValueChanged<bool> onToggle,
    required VoidCallback onEditTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showEditHint) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onEditTap,
                  child: Text(
                    'Tap to edit dates and times',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (enabled) ...[
                if (showSummaryWhenEnabled) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatScheduleSummary(space),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  'Notification off',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
          trailing: Switch(value: enabled, onChanged: onToggle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).settings;
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final backTarget = _resolveBackTarget(context, from: from);

    final calendarSpace =
        settings.notificationSpaceSettings[_calendarReminderSpaceId] ??
        NotificationSpaceSetting.defaults();
    final pomodoroSpace =
        settings.notificationSpaceSettings[_pomodoroAlertSpaceId] ??
        NotificationSpaceSetting.defaults();

    final groupedHabits = <String, List<Map<String, dynamic>>>{};
    for (final habit in _habits) {
      final group =
          (habit['habit_categories']?['name'] ?? 'Uncategorized')
              .toString()
              .trim()
              .isEmpty
          ? 'Uncategorized'
          : (habit['habit_categories']?['name'] ?? 'Uncategorized')
                .toString()
                .trim();
      groupedHabits.putIfAbsent(group, () => []).add(habit);
    }

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
          Text('Habit Tracker', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_loadingHabits)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_habits.isEmpty)
            Text(
              'No active habits yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...groupedHabits.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...entry.value.map((habit) {
                    final habitId = (habit['id'] ?? '').toString();
                    final title = (habit['name'] ?? '').toString().trim();
                    final space =
                        settings.notificationSpaceSettings['habit:$habitId'] ??
                        NotificationSpaceSetting.defaults();
                    return _buildCoreTile(
                      context: context,
                      title: title,
                      enabled: space.enabled,
                      space: space,
                      onToggle: (value) {
                        unawaited(
                          _saveHabitSetting(
                            habitId,
                            _effectiveEnabledSetting(space, value),
                          ),
                        );
                      },
                      onEditTap: () {
                        _openScheduleSheet(
                          context: context,
                          title: '$title reminder',
                          initial: _effectiveEnabledSetting(space, true),
                          onSave: (setting) =>
                              _saveHabitSetting(habitId, setting),
                        );
                      },
                    );
                  }),
                ],
              );
            }),
          const SizedBox(height: 20),
          Text(
            'Calendar Reminders',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildCoreTile(
            context: context,
            title: 'Calendar Reminders',
            enabled: settings.calendarRemindersEnabled,
            space: calendarSpace.copyWith(
              enabled: settings.calendarRemindersEnabled,
            ),
            showSummaryWhenEnabled: false,
            showEditHint: false,
            onToggle: (value) {
              unawaited(
                _setCalendarSetting(
                  _effectiveEnabledSetting(calendarSpace, value),
                  value,
                ),
              );
            },
            onEditTap: () {
              _openScheduleSheet(
                context: context,
                title: 'Calendar reminder settings',
                initial: _effectiveEnabledSetting(
                  calendarSpace.copyWith(
                    enabled: settings.calendarRemindersEnabled,
                  ),
                  true,
                ),
                onSave: (setting) => _setCalendarSetting(
                  setting,
                  settings.calendarRemindersEnabled,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Pomodoro Finished Alerts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildCoreTile(
            context: context,
            title: 'Pomodoro Finished Alerts',
            enabled: settings.pomodoroAlertsEnabled,
            space: pomodoroSpace.copyWith(
              enabled: settings.pomodoroAlertsEnabled,
            ),
            showSummaryWhenEnabled: false,
            showEditHint: false,
            onToggle: (value) {
              unawaited(
                _setPomodoroSetting(
                  _effectiveEnabledSetting(pomodoroSpace, value),
                  value,
                ),
              );
            },
            onEditTap: () {
              _openScheduleSheet(
                context: context,
                title: 'Pomodoro finished alert settings',
                initial: _effectiveEnabledSetting(
                  pomodoroSpace.copyWith(
                    enabled: settings.pomodoroAlertsEnabled,
                  ),
                  true,
                ),
                onSave: (setting) => _setPomodoroSetting(
                  setting,
                  settings.pomodoroAlertsEnabled,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Stopwatch Alerts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text('Show stopwatch running notification'),
            subtitle: Text(
              settings.stopwatchAlertsEnabled
                  ? 'Keep a subtle stopwatch status notification while it runs.'
                  : 'Stopwatch notifications are off.',
            ),
            value: settings.stopwatchAlertsEnabled,
            onChanged: (value) {
              unawaited(
                ref
                    .read(settingsControllerProvider)
                    .setStopwatchAlertsEnabled(value),
              );
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text('Running reminder'),
            subtitle: Text(
              settings.stopwatchReminderMinutes <= 0
                  ? 'Off'
                  : 'Remind me every ${settings.stopwatchReminderMinutes} min while running',
            ),
            trailing: DropdownButton<int>(
              value:
                  _stopwatchReminderOptions.contains(
                    settings.stopwatchReminderMinutes,
                  )
                  ? settings.stopwatchReminderMinutes
                  : 0,
              items: _stopwatchReminderOptions
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text(minutes == 0 ? 'Off' : '$minutes min'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                unawaited(
                  ref
                      .read(settingsControllerProvider)
                      .setStopwatchReminderMinutes(value),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
