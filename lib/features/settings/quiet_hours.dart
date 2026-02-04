import 'settings_model.dart';

bool isWithinQuietHours(SettingsModel settings, DateTime now) {
  if (!settings.quietHoursEnabled) return false;

  final startParts = settings.quietStart.split(':');
  final endParts = settings.quietEnd.split(':');

  if (startParts.length < 2 || endParts.length < 2) return false;

  final startHour = int.tryParse(startParts[0]) ?? 0;
  final startMinute = int.tryParse(startParts[1]) ?? 0;
  final endHour = int.tryParse(endParts[0]) ?? 0;
  final endMinute = int.tryParse(endParts[1]) ?? 0;

  final start = DateTime(
    now.year,
    now.month,
    now.day,
    startHour,
    startMinute,
  );
  var end = DateTime(
    now.year,
    now.month,
    now.day,
    endHour,
    endMinute,
  );

  if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
    end = end.add(const Duration(days: 1));
  }

  if (now.isBefore(start)) {
    final prevStart = start.subtract(const Duration(days: 1));
    final prevEnd = end.subtract(const Duration(days: 1));
    return now.isAfter(prevStart) && now.isBefore(prevEnd);
  }

  return now.isAfter(start) && now.isBefore(end);
}
