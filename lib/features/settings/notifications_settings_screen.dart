import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/core/database/database_providers.dart';
import 'package:mind_buddy/features/settings/data/local/notifications_local_data_source.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/features/templates/template_reminder_support.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  static const String _pomodoroAlertSpaceId = 'pomodoro_finished';
  static const List<int> _stopwatchReminderOptions = [0, 5, 10, 15, 30, 60];

  final _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _reminderSectionKeys = <String, GlobalKey>{};

  bool _loadingHabits = true;
  List<Map<String, dynamic>> _habits = const [];
  bool _loadingTemplateReminders = true;
  List<TemplateReminderTarget> _templateReminderTargets =
      const <TemplateReminderTarget>[];
  String? _lastFocusedSpaceId;
  bool _focusScrollCompleted = false;
  String? _highlightedSpaceId;
  AnimationStatusListener? _routeAnimationListener;
  ModalRoute<dynamic>? _cachedRoute;
  Animation<double>? _cachedRouteAnimation;

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _loadTemplateReminderTargets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheRouteReferences();
    final focus = _currentFocusSpaceId();
    if (focus != _lastFocusedSpaceId) {
      _lastFocusedSpaceId = focus;
      _focusScrollCompleted = false;
      _highlightedSpaceId = null;
    }
    _scheduleFocusWhenRouteReady();
  }

  @override
  void dispose() {
    if (_cachedRouteAnimation != null && _routeAnimationListener != null) {
      _cachedRouteAnimation!.removeStatusListener(_routeAnimationListener!);
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _cacheRouteReferences() {
    final route = ModalRoute.of(context);
    if (route == _cachedRoute) return;
    if (_cachedRouteAnimation != null && _routeAnimationListener != null) {
      _cachedRouteAnimation!.removeStatusListener(_routeAnimationListener!);
    }
    _cachedRoute = route;
    _cachedRouteAnimation = route?.animation;
    _routeAnimationListener = null;
  }

  String _resolveBackTarget(BuildContext context, {String? from}) {
    switch (from) {
      case 'templates':
        return '/templates';
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
      final localDataSource = NotificationsLocalDataSource(
        ref.read(appDatabaseProvider),
      );
      final habits = (await localDataSource.loadHabitSnapshot(userId: user.id))
          .map(
            (habit) => <String, dynamic>{
              'id': habit.id,
              'name': habit.name,
              'sort_order': habit.sortOrder,
              'habit_categories': <String, dynamic>{
                'name': habit.categoryName ?? 'Uncategorized',
              },
            },
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _habits = habits;
        _loadingHabits = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToFocusIfNeeded(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _habits = const [];
        _loadingHabits = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToFocusIfNeeded(),
      );
    }
  }

  GlobalKey _reminderSectionKey(String spaceId) {
    return _reminderSectionKeys.putIfAbsent(spaceId, GlobalKey.new);
  }

  String? _currentFocusSpaceId() {
    final focus = GoRouterState.of(context).uri.queryParameters['focus'];
    if (focus == null || focus.isEmpty) return null;
    return focus.trim().toLowerCase();
  }

  void _scheduleFocusWhenRouteReady() {
    final focus = _currentFocusSpaceId();
    if (focus == null || _focusScrollCompleted) return;

    final animation = _cachedRouteAnimation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToFocusIfNeeded(),
      );
      return;
    }

    if (_routeAnimationListener != null) {
      animation.removeStatusListener(_routeAnimationListener!);
    }
    _routeAnimationListener = (status) {
      if (status != AnimationStatus.completed) return;
      if (_routeAnimationListener != null) {
        animation.removeStatusListener(_routeAnimationListener!);
        _routeAnimationListener = null;
      }
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToFocusIfNeeded(),
      );
    };
    animation.addStatusListener(_routeAnimationListener!);
  }

  void _scrollToFocusIfNeeded() {
    final focus = _currentFocusSpaceId();
    if (focus == null || _focusScrollCompleted) return;
    unawaited(_scrollToFocusIfNeededWithRetry(focus));
  }

  Future<void> _scrollToFocusIfNeededWithRetry(
    String focus, [
    int attempt = 0,
  ]) async {
    if (!mounted) return;
    await _ensureFocusedTargetPresent(focus);
    if (!mounted) return;
    if (_loadingHabits || _loadingTemplateReminders) {
      if (attempt >= 12) {
        debugPrint(
          '[NotificationsFocus] Timed out waiting for sections to load for "$focus".',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      await _scrollToFocusIfNeededWithRetry(focus, attempt + 1);
      return;
    }
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      if (attempt >= 12) {
        debugPrint(
          '[NotificationsFocus] Scroll view never became ready for "$focus".',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      await _scrollToFocusIfNeededWithRetry(focus, attempt + 1);
      return;
    }
    final targetContext = _reminderSectionKey(focus).currentContext;
    if (targetContext != null) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;

      for (var ensureAttempt = 0; ensureAttempt < 3; ensureAttempt++) {
        final activeContext = _reminderSectionKey(focus).currentContext;
        if (activeContext == null) break;
        if (!activeContext.mounted) break;
        await Scrollable.ensureVisible(
          activeContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        if (_isSectionVisible(focus)) {
          _focusScrollCompleted = true;
          _highlightFocusedSection(focus);
          return;
        }
      }

      if (attempt >= 12) {
        debugPrint(
          '[NotificationsFocus] Section "$focus" never became visible after repeated ensureVisible calls.',
        );
        await _fallbackScrollForMissingFocus(focus);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      await _scrollToFocusIfNeededWithRetry(focus, attempt + 1);
      return;
    }
    if (attempt >= 12) {
      debugPrint(
        '[NotificationsFocus] Could not find reminder section for "$focus".',
      );
      await _fallbackScrollForMissingFocus(focus);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _scrollToFocusIfNeededWithRetry(focus, attempt + 1);
  }

  bool _isSectionVisible(String focus) {
    final targetContext = _reminderSectionKey(focus).currentContext;
    if (targetContext == null) return false;
    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return false;
    final position = _scrollController.position;
    final revealTop = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    final revealBottom = viewport.getOffsetToReveal(renderObject, 1.0).offset;
    final visibleTop = position.pixels;
    final visibleBottom = position.pixels + position.viewportDimension;
    return revealBottom >= visibleTop && revealTop <= visibleBottom;
  }

  Future<void> _fallbackScrollForMissingFocus(String focus) async {
    if (!_scrollController.hasClients) return;
    final fallbackOffset = _scrollController.position.minScrollExtent;
    debugPrint(
      '[NotificationsFocus] Falling back to top of Notifications for "$focus".',
    );
    await _scrollController.animateTo(
      fallbackOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  bool _hasReminderTarget(String focus) {
    return _templateReminderTargets.any(
      (target) => target.spaceId.trim().toLowerCase() == focus,
    );
  }

  Future<void> _ensureFocusedTargetPresent(String focus) async {
    if (_loadingTemplateReminders) return;
    if (_hasReminderTarget(focus)) return;

    TemplateReminderTarget? injected;
    if (!focus.startsWith('template:')) {
      final title = builtInTemplateReminderTitle(focus);
      if (title != null) {
        injected = TemplateReminderTarget(
          spaceId: focus,
          title: title,
          templateKey: focus,
        );
      }
    } else {
      final templateId = focus.substring('template:'.length);
      final user = _supabase.auth.currentUser;
      if (user != null && templateId.isNotEmpty) {
        injected = await loadTemplateReminderTargetBySpaceIdLocal(
          database: ref.read(appDatabaseProvider),
          userId: user.id,
          spaceId: focus,
        );
      }
    }

    if (injected == null) {
      debugPrint(
        '[NotificationsFocus] No reminder target source found for "$focus".',
      );
      return;
    }
    if (!mounted || _hasReminderTarget(focus)) return;
    final nextTargets =
        <TemplateReminderTarget>[..._templateReminderTargets, injected]
          ..sort((a, b) {
            if (a.isCustom != b.isCustom) {
              return a.isCustom ? 1 : -1;
            }
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
    setState(() {
      _templateReminderTargets = nextTargets;
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  void _highlightFocusedSection(String focus) {
    if (!mounted) return;
    setState(() => _highlightedSpaceId = focus);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_highlightedSpaceId != focus) return;
      setState(() => _highlightedSpaceId = null);
    });
  }

  String _formatTimeList(List<String> times) {
    if (times.isEmpty) return '09:00';
    return times.join(' • ');
  }

  List<String> _normalizedScheduleTimes(NotificationSpaceSetting space) {
    final times = space.reminderTimes;
    return times.isEmpty ? const <String>['09:00'] : times;
  }

  Future<void> _loadTemplateReminderTargets() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _templateReminderTargets = const <TemplateReminderTarget>[];
        _loadingTemplateReminders = false;
      });
      return;
    }

    try {
      final targets = await loadTemplateReminderTargetsLocal(
        database: ref.read(appDatabaseProvider),
        userId: user.id,
      );

      if (!mounted) return;
      setState(() {
        _templateReminderTargets = targets;
        _loadingTemplateReminders = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToFocusIfNeeded(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _templateReminderTargets = const <TemplateReminderTarget>[];
        _loadingTemplateReminders = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToFocusIfNeeded(),
      );
    }
  }

  String _formatScheduleSummary(NotificationSpaceSetting space) {
    if (!space.enabled) return '';
    final timeLabel = _formatTimeList(_normalizedScheduleTimes(space));
    if (space.frequency == 'remember') {
      return 'Only when I open the app';
    }
    if (space.frequency == 'monthly') {
      return 'Once a month • ${space.dayOfMonth} • $timeLabel';
    }
    if (space.frequency == 'weekly') {
      final days = space.days.isEmpty ? ['Mon'] : _labelsForDays(space.days);
      return 'Once a week • ${days.join(' / ')} • $timeLabel';
    }
    if (space.frequency == 'certain') {
      final days = space.days.isEmpty ? ['Mon'] : _labelsForDays(space.days);
      return '${days.join(' / ')} • $timeLabel';
    }
    if (space.skipWeekends) {
      return 'Every day • $timeLabel • Skip weekends';
    }
    return 'Every day • $timeLabel';
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
    bool allowMultipleTimes = false,
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
            final reminderTimes = _normalizedScheduleTimes(space);

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
                              if (space.frequency != 'remember' &&
                                  allowMultipleTimes) ...[
                                Text(
                                  'Reminder times',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                ...reminderTimes.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final reminderTime = entry.value;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('Reminder ${index + 1}'),
                                    subtitle: Text(reminderTime),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit time',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () async {
                                            final next = await _pickTime(
                                              context,
                                              reminderTime,
                                            );
                                            if (next == null) return;
                                            final nextTimes = List<String>.from(
                                              reminderTimes,
                                            );
                                            nextTimes[index] = next;
                                            apply(
                                              space.copyWith(times: nextTimes),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Delete time',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: reminderTimes.length <= 1
                                              ? null
                                              : () {
                                                  final nextTimes =
                                                      List<String>.from(
                                                        reminderTimes,
                                                      )..removeAt(index);
                                                  apply(
                                                    space.copyWith(
                                                      times: nextTimes,
                                                    ),
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final next = await _pickTime(
                                        context,
                                        reminderTimes.isEmpty
                                            ? '09:00'
                                            : reminderTimes.last,
                                      );
                                      if (next == null) return;
                                      final nextTimes = List<String>.from(
                                        reminderTimes,
                                      )..add(next);
                                      apply(space.copyWith(times: nextTimes));
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add reminder time'),
                                  ),
                                ),
                              ] else if (space.frequency != 'remember')
                                ListTile(
                                  title: const Text('Time'),
                                  subtitle: Text(space.primaryTime ?? '09:00'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    final current =
                                        space.primaryTime ?? '09:00';
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
    final normalizedTimes = _normalizedScheduleTimes(current);
    return current.copyWith(
      enabled: enabled,
      times: normalizedTimes,
      time: normalizedTimes.first,
    );
  }

  Future<void> _saveHabitSetting(
    String habitId,
    NotificationSpaceSetting setting,
  ) async {
    final controller = ref.read(settingsControllerProvider);
    await controller.setNotificationSpaceSetting('habit:$habitId', setting);
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

  Future<void> _setTemplateReminderSetting(
    String spaceId,
    NotificationSpaceSetting setting,
    bool enabled,
  ) async {
    final controller = ref.read(settingsControllerProvider);
    final current = controller.settings;
    final nextSpaces = Map<String, NotificationSpaceSetting>.from(
      current.notificationSpaceSettings,
    );
    final nextCategories = Map<String, bool>.from(
      current.notificationCategories,
    );
    nextSpaces[spaceId] = setting.copyWith(enabled: enabled);
    nextCategories[spaceId] = enabled;
    await controller.update(
      current.copyWith(
        notificationCategories: nextCategories,
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
        controller: _scrollController,
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
            'Template Reminders',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_loadingTemplateReminders)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_templateReminderTargets.isEmpty)
            Text(
              'No reminder-supported templates available yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ..._templateReminderTargets.map((target) {
              final space =
                  settings.notificationSpaceSettings[target.spaceId] ??
                  NotificationSpaceSetting.defaults();
              final isHighlighted = _highlightedSpaceId == target.spaceId;
              return Container(
                key: _reminderSectionKey(target.spaceId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _buildCoreTile(
                    context: context,
                    title: '${target.title} reminders',
                    enabled: space.enabled,
                    space: space.copyWith(enabled: space.enabled),
                    onToggle: (value) {
                      unawaited(
                        _setTemplateReminderSetting(
                          target.spaceId,
                          _effectiveEnabledSetting(space, value),
                          value,
                        ),
                      );
                    },
                    onEditTap: () {
                      _openScheduleSheet(
                        context: context,
                        title: '${target.title} reminder settings',
                        initial: _effectiveEnabledSetting(
                          space.copyWith(enabled: true),
                          true,
                        ),
                        allowMultipleTimes: true,
                        onSave: (setting) => _setTemplateReminderSetting(
                          target.spaceId,
                          setting,
                          true,
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
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
