import 'package:flutter/material.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/templates/data/local/template_logs_local_data_source.dart';

import '../settings/settings_model.dart';

class TemplateReminderTarget {
  const TemplateReminderTarget({
    required this.spaceId,
    required this.title,
    required this.templateKey,
    this.templateId,
    this.isCustom = false,
  });

  final String spaceId;
  final String title;
  final String templateKey;
  final String? templateId;
  final bool isCustom;
}

const Map<String, String> supportedBuiltInTemplateReminderTitles = {
  'medication': 'Medication',
  'tasks': 'Tasks',
  'water': 'Water',
  'study': 'Study',
  'skin_care': 'Skincare',
  'meals': 'Meals',
  'meditation': 'Meditation',
};

bool isSupportedBuiltInTemplateReminder(String templateKey) {
  return supportedBuiltInTemplateReminderTitles.containsKey(
    templateKey.trim().toLowerCase(),
  );
}

String? builtInTemplateReminderTitle(String templateKey) {
  return supportedBuiltInTemplateReminderTitles[templateKey
      .trim()
      .toLowerCase()];
}

String templateReminderSpaceId({
  required String templateKey,
  String? templateId,
  required bool isCustom,
}) {
  if (isCustom) {
    return 'template:${templateId ?? templateKey}';
  }
  return templateKey.trim().toLowerCase();
}

Future<List<TemplateReminderTarget>> loadTemplateReminderTargetsLocal({
  required AppDatabase database,
  required String userId,
}) async {
  final targets = <TemplateReminderTarget>[];
  final seenSpaceIds = <String>{};
  final localDataSource = TemplateLogsLocalDataSource(database);
  await localDataSource.ensureBuiltInDefinitions();
  final definitions = await localDataSource.listTemplateDefinitions(
    userId: userId,
    includeBuiltIn: true,
  );

  for (final definition in definitions) {
    final templateId = definition.id;
    final templateKey = definition.templateKey.trim().toLowerCase();
    final name = definition.name.trim();
    final isCustom = !definition.isBuiltIn && definition.userId == userId;
    if (!isCustom && !isSupportedBuiltInTemplateReminder(templateKey)) {
      continue;
    }
    final title = isCustom
        ? (name.isEmpty ? 'Custom template' : name)
        : (builtInTemplateReminderTitle(templateKey) ?? name);
    final spaceId = templateReminderSpaceId(
      templateKey: templateKey,
      templateId: templateId,
      isCustom: isCustom,
    );
    if (seenSpaceIds.add(spaceId)) {
      targets.add(
        TemplateReminderTarget(
          spaceId: spaceId,
          title: title,
          templateKey: templateKey,
          templateId: templateId,
          isCustom: isCustom,
        ),
      );
    }
  }

  for (final entry in supportedBuiltInTemplateReminderTitles.entries) {
    final spaceId = templateReminderSpaceId(
      templateKey: entry.key,
      isCustom: false,
    );
    if (seenSpaceIds.add(spaceId)) {
      targets.add(
        TemplateReminderTarget(
          spaceId: spaceId,
          title: entry.value,
          templateKey: entry.key,
        ),
      );
    }
  }

  targets.sort((a, b) {
    if (a.isCustom != b.isCustom) {
      return a.isCustom ? 1 : -1;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return targets;
}

Future<TemplateReminderTarget?> loadTemplateReminderTargetBySpaceIdLocal({
  required AppDatabase database,
  required String userId,
  required String spaceId,
}) async {
  final normalizedSpaceId = spaceId.trim().toLowerCase();
  if (normalizedSpaceId.isEmpty) return null;
  final targets = await loadTemplateReminderTargetsLocal(
    database: database,
    userId: userId,
  );
  for (final target in targets) {
    if (target.spaceId.trim().toLowerCase() == normalizedSpaceId) {
      return target;
    }
  }
  return null;
}

Iterable<DateTime> expandTemplateReminderDatesInRange({
  required NotificationSpaceSetting setting,
  required DateTime start,
  required DateTime end,
}) sync* {
  if (!setting.enabled || setting.frequency == 'remember') return;
  var cursor = DateTime(start.year, start.month, start.day);
  while (!cursor.isAfter(end)) {
    if (_templateReminderOccursOnDate(setting: setting, date: cursor)) {
      yield cursor;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
}

List<String> templateReminderSettingTimes(NotificationSpaceSetting setting) {
  final times = setting.reminderTimes;
  return times.isEmpty ? const <String>['09:00'] : times;
}

bool templateReminderOccursOnDate({
  required NotificationSpaceSetting setting,
  required DateTime date,
}) {
  return _templateReminderOccursOnDate(
    setting: setting,
    date: DateTime(date.year, date.month, date.day),
  );
}

List<String> templateReminderTimes(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return const <String>['09:00'];
  }
  final normalized = <String>[];
  final seen = <String>{};
  for (final token in text.split(',')) {
    final value = token.trim();
    final parts = value.split(':');
    if (parts.length != 2) {
      continue;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      continue;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      continue;
    }
    final safe =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    if (seen.add(safe)) {
      normalized.add(safe);
    }
  }
  if (normalized.isEmpty) {
    return const <String>['09:00'];
  }
  normalized.sort();
  return normalized;
}

List<TimeOfDay> templateReminderTimesOfDay(NotificationSpaceSetting setting) {
  return templateReminderSettingTimes(setting)
      .map((value) {
        final parts = value.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      })
      .toList(growable: false);
}

bool _templateReminderOccursOnDate({
  required NotificationSpaceSetting setting,
  required DateTime date,
}) {
  switch (setting.frequency) {
    case 'monthly':
      return date.day == setting.dayOfMonth;
    case 'weekly':
    case 'certain':
      final days = setting.days.isEmpty ? const <String>['mon'] : setting.days;
      return days.contains(_weekdayKey(date.weekday));
    case 'remember':
      return false;
    case 'most':
    default:
      if (setting.skipWeekends) {
        return date.weekday >= DateTime.monday &&
            date.weekday <= DateTime.friday;
      }
      return true;
  }
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
    default:
      return '';
  }
}
