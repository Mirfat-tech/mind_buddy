import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/features/auth/device_session_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).settings;
    final themeStyle = styleById(settings.themeId);
    final userEmail =
        Supabase.instance.client.auth.currentUser?.email ?? 'Signed out';

    final quietLabel = settings.quietHoursEnabled
        ? '${settings.quietStart}–${settings.quietEnd}'
        : 'Off';

    final checkInLabel = settings.dailyCheckInEnabled
        ? settings.dailyCheckInTime
        : 'Off';

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsHeader(email: userEmail),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Appearance',
            children: [
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: themeStyle.name,
                onTap: () => context.go('/settings/appearance'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Usage',
            children: [
              _SettingsTile(
                icon: Icons.bolt_outlined,
                title: 'Usage & Plan',
                subtitle: 'Messages and chats today',
                onTap: () => context.go('/settings/usage'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Notifications',
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Quiet Hours',
                subtitle: quietLabel,
                onTap: () => context.go('/settings/notifications'),
              ),
              _SettingsTile(
                icon: Icons.alarm_outlined,
                title: 'Daily Check-In',
                subtitle: checkInLabel,
                onTap: () => context.go('/settings/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Subscription',
                subtitle: 'Manage your plan',
                onTap: () => context.go('/subscription'),
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: 'Log out of this device',
                onTap: () => _confirmSignOut(context),
              ),
              _SettingsTile(
                icon: Icons.logout_outlined,
                title: 'Sign out everywhere',
                subtitle: 'Sign out of all devices',
                onTap: () => _confirmGlobalSignOut(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Devices',
            children: [
              _DevicesList(),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    context.go('/signin');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign out failed: $e')),
    );
  }
}

Future<void> _confirmGlobalSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out everywhere'),
      content: const Text(
        'This will sign you out of all devices. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sign out everywhere'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await Supabase.instance.client.auth.signOut(
      scope: SignOutScope.global,
    );
    if (!context.mounted) return;
    context.go('/signin');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign out failed: $e')),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withOpacity(0.15),
            child: Icon(Icons.person, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed in as',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DevicesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DeviceListData>(
      future: _loadDeviceListData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No devices found.'),
          );
        }

        final data = snapshot.data!;
        if (data.sessions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No devices found.'),
          );
        }

        return Column(
          children: [
            for (final session in data.sessions)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.devices),
                title: Text(session.deviceName),
                subtitle: Text(
                  '${session.platform} • ${session.lastSeen}',
                ),
                trailing: session.deviceId == data.localDeviceId
                    ? const Chip(label: Text('This device'))
                    : null,
              ),
          ],
        );
      },
    );
  }
}

Future<_DeviceListData> _loadDeviceListData() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return const _DeviceListData(localDeviceId: '', sessions: []);
  }

  final localDeviceId = await DeviceSessionService.getOrCreateDeviceId();
  final rows = await Supabase.instance.client
      .from('user_sessions')
      .select('device_id, device_name, platform, last_seen_at')
      .eq('user_id', user.id)
      .order('last_seen_at', ascending: false);

  final sessions = (rows as List)
      .map(
        (row) => _DeviceSession(
          deviceId: (row['device_id'] ?? '').toString(),
          deviceName: (row['device_name'] ?? 'Unknown').toString(),
          platform: (row['platform'] ?? 'Unknown').toString(),
          lastSeen: _formatLastSeen(row['last_seen_at']),
        ),
      )
      .toList();

  return _DeviceListData(
    localDeviceId: localDeviceId,
    sessions: sessions,
  );
}

String _formatLastSeen(dynamic value) {
  if (value == null) return 'Unknown';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return 'Unknown';
  final local = parsed.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

class _DeviceListData {
  const _DeviceListData({required this.localDeviceId, required this.sessions});

  final String localDeviceId;
  final List<_DeviceSession> sessions;
}

class _DeviceSession {
  const _DeviceSession({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSeen,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String lastSeen;
}
