import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/services/notification_catalog.dart';

Future<void> applyOnboardingAnswers(
  WidgetRef ref,
  OnboardingAnswers answers,
) async {
  final controller = ref.read(settingsControllerProvider);
  final current = controller.settings;

  final spaces = <String, NotificationSpaceSetting>{
    for (final category in notificationCategories)
      category.id:
          current.notificationSpaceSettings[category.id] ??
          NotificationSpaceSetting.defaults(),
  };
  final categories = <String, bool>{
    for (final category in notificationCategories)
      category.id: current.notificationCategories[category.id] ?? false,
  };

  void enableSpace(
    String id, {
    String? frequency,
    List<String>? days,
    String? time,
    bool? skipWeekends,
    int? dayOfMonth,
    String? style,
  }) {
    final base = spaces[id] ?? NotificationSpaceSetting.defaults();
    spaces[id] = base.copyWith(
      enabled: true,
      frequency: frequency ?? base.frequency,
      days: days ?? base.days,
      time: time ?? base.time,
      skipWeekends: skipWeekends ?? base.skipWeekends,
      dayOfMonth: dayOfMonth ?? base.dayOfMonth,
      style: style ?? base.style,
    );
    categories[id] = true;
  }

  void disableAll() {
    for (final id in spaces.keys) {
      final base = spaces[id] ?? NotificationSpaceSetting.defaults();
      spaces[id] = base.copyWith(enabled: false);
      categories[id] = false;
    }
  }

  var maxPerDay = current.maxNotificationsPerDay;
  var lockMinimal = false;

  if (answers.slipFirst.contains('nothing')) {
    disableAll();
    maxPerDay = 0;
    lockMinimal = true;
  } else if (answers.slipFirst.contains('everything')) {
    disableAll();
    enableSpace('mood', style: 'quiet');
    enableSpace('brainfog', style: 'quiet');
    maxPerDay = 1;
    lockMinimal = true;
  } else {
    for (final answer in answers.slipFirst) {
      switch (answer) {
        case 'mental':
          enableSpace('brainfog', style: 'quiet');
          enableSpace('mood', style: 'quiet');
          enableSpace('journal', style: 'quiet');
          maxPerDay = maxPerDay == 0 ? 0 : 1;
          break;
        case 'admin':
          enableSpace('bills', frequency: 'monthly', dayOfMonth: 1);
          enableSpace('expenses', frequency: 'remember');
          maxPerDay = 0;
          break;
        case 'body':
          enableSpace('water', frequency: 'remember');
          enableSpace('sleep', frequency: 'most', time: '21:30');
          maxPerDay = maxPerDay == 0 ? 0 : 1;
          break;
        default:
          break;
      }
    }
  }

  if (!lockMinimal) {
    for (final answer in answers.expressionStyle) {
      switch (answer) {
        case 'colors':
          enableSpace('journal', style: 'soft');
          break;
        case 'photos':
        case 'videos':
          enableSpace('journal_memory', style: 'soft');
          break;
        case 'all':
          enableSpace('journal', style: 'soft');
          enableSpace('journal_memory', style: 'soft');
          break;
        default:
          break;
      }
    }

    for (final answer in answers.lookingBack) {
      switch (answer) {
        case 'patterns':
          enableSpace(
            'insights',
            frequency: 'weekly',
            days: const ['sun'],
            time: '09:00',
            style: 'quiet',
          );
          break;
        case 'scrapbook':
          enableSpace('journal_memory', style: 'soft');
          break;
        case 'reflection':
          final base = spaces['journal'] ?? NotificationSpaceSetting.defaults();
          spaces['journal'] = base.copyWith(time: '21:30');
          categories['journal'] = true;
          break;
        case 'mix':
          enableSpace('insights', frequency: 'weekly', days: const ['sun']);
          enableSpace('journal_memory', style: 'soft');
          break;
        default:
          break;
      }
    }
  }

  if (answers.skippedPersonalization) {
    disableAll();
    enableSpace('mood', style: 'quiet');
    enableSpace('journal', style: 'soft');
    maxPerDay = 1;
  }

  final next = current.copyWith(
    notificationSpaceSettings: spaces,
    notificationCategories: categories,
    maxNotificationsPerDay: maxPerDay,
  );

  await controller.update(next);
}
