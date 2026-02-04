import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

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

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Quiet Hours',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.quietHoursEnabled,
            title: const Text('Enable Quiet Hours'),
            subtitle: const Text('Pause reminders during this window'),
            onChanged: (value) => controller.setQuietHours(
              enabled: value,
              start: settings.quietStart,
              end: settings.quietEnd,
            ),
          ),
          ListTile(
            title: const Text('Start time'),
            subtitle: Text(settings.quietStart),
            trailing: const Icon(Icons.chevron_right),
            onTap: settings.quietHoursEnabled
                ? () async {
                    final next = await _pickTime(
                      context,
                      settings.quietStart,
                    );
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
            title: const Text('End time'),
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
          const SizedBox(height: 24),
          Text(
            'Daily Check-In',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.dailyCheckInEnabled,
            title: const Text('Enable Daily Check-In'),
            subtitle: const Text('A gentle reminder once a day'),
            onChanged: (value) => controller.setDailyCheckIn(
              enabled: value,
              time: settings.dailyCheckInTime,
            ),
          ),
          ListTile(
            title: const Text('Check-in time'),
            subtitle: Text(settings.dailyCheckInTime),
            trailing: const Icon(Icons.chevron_right),
            onTap: settings.dailyCheckInEnabled
                ? () async {
                    final next =
                        await _pickTime(context, settings.dailyCheckInTime);
                    if (next != null) {
                      await controller.setDailyCheckIn(
                        enabled: settings.dailyCheckInEnabled,
                        time: next,
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
