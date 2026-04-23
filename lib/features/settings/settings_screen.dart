import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/core/database/database_providers.dart';
import 'package:mind_buddy/features/auth/device_state_repository.dart';
import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/services/username_resolver_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingsControllerProvider);
    final settings = controller.settings;
    final themeStyle = styleById(settings.themeId);
    final user = Supabase.instance.client.auth.currentUser;
    final userEmail = user?.email ?? 'Signed out';

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.loadError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${controller.loadError} Tap to retry.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(settingsControllerProvider).retryInit(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
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
                subtitle: 'Usage and plan details',
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
                title: 'Notifications',
                subtitle: 'Schedule • Quiet hours • Check-ins',
                onTap: () => context.go('/settings/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Feedback',
            children: [
              _SettingsTile(
                icon: Icons.vibration_outlined,
                title: 'Haptics',
                subtitle: 'Vibration feedback across the app',
                trailing: Switch(
                  value: ref
                      .watch(settingsControllerProvider)
                      .settings
                      .hapticsEnabled,
                  onChanged: (value) => ref
                      .read(settingsControllerProvider)
                      .setHapticsEnabled(value),
                ),
                onTap: () => ref
                    .read(settingsControllerProvider)
                    .setHapticsEnabled(
                      !ref
                          .read(settingsControllerProvider)
                          .settings
                          .hapticsEnabled,
                    ),
              ),
              _SettingsTile(
                icon: Icons.volume_up_outlined,
                title: 'Sounds',
                subtitle: 'Sound feedback across the app',
                trailing: Switch(
                  value: ref
                      .watch(settingsControllerProvider)
                      .settings
                      .soundsEnabled,
                  onChanged: (value) => ref
                      .read(settingsControllerProvider)
                      .setSoundsEnabled(value),
                ),
                onTap: () => ref
                    .read(settingsControllerProvider)
                    .setSoundsEnabled(
                      !ref
                          .read(settingsControllerProvider)
                          .settings
                          .soundsEnabled,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Guidance',
            children: [
              _SettingsTile(
                icon: Icons.bubble_chart_outlined,
                title: 'Quiet Guide',
                subtitle: 'Soft tips and gestures',
                onTap: () => context.go('/settings/guide'),
              ),
              _SettingsTile(
                icon: Icons.visibility_outlined,
                title: 'Keep instructions visible',
                subtitle: 'Show spotlight guides every time',
                trailing: Switch(
                  value: ref
                      .watch(settingsControllerProvider)
                      .settings
                      .keepInstructionsEnabled,
                  onChanged: (value) => ref
                      .read(settingsControllerProvider)
                      .setKeepInstructionsEnabled(value),
                ),
                onTap: () => ref
                    .read(settingsControllerProvider)
                    .setKeepInstructionsEnabled(
                      !ref
                          .read(settingsControllerProvider)
                          .settings
                          .keepInstructionsEnabled,
                    ),
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
                icon: Icons.block,
                title: 'Blocked users',
                subtitle: 'Manage people you’ve blocked',
                onTap: () => context.go('/settings/blocked'),
              ),
              _AccountActions(user: user),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(title: 'Devices', children: [_DevicesList()]),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Debug',
              children: [
                _SettingsTile(
                  icon: Icons.science_outlined,
                  title: 'Bubble Test Page',
                  subtitle: 'Soft prompt sphere and two bubble choices',
                  onTap: () => context.go('/test-page'),
                ),
                _SettingsTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Home sphere preview',
                  subtitle:
                      'Theme-driven mock-up preview for the new home look',
                  onTap: () => context.go('/settings/home-sphere-preview'),
                ),
                _SettingsTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Run RPC health check',
                  subtitle: 'Checks username RPC visibility in PostgREST',
                  onTap: () => _runRpcHealthCheck(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _runRpcHealthCheck(BuildContext context) async {
  final result = await UsernameResolverService.instance.runRpcHealthCheck();
  if (!context.mounted) return;
  final search = result['search_usernames'] ?? 'error';
  final batch = result['get_usernames_by_ids'] ?? 'error';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('RPC health: search=$search, batch=$batch')),
  );
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final showSignIn = user == null;

    if (showSignIn) {
      return Column(
        children: [
          _SettingsTile(
            icon: Icons.login,
            title: 'Sign in',
            subtitle: 'Continue onboarding and choose a plan',
            onTap: () => context.push('/auth'),
          ),
          _SettingsTile(
            icon: Icons.person_add_alt_1,
            title: 'Create account',
            subtitle: 'Start with email or social sign-in',
            onTap: () => context.push('/auth'),
          ),
        ],
      );
    }

    return Column(
      children: [
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
        _SettingsTile(
          icon: Icons.person_off_outlined,
          title: 'Deactivate account',
          subtitle: 'Temporarily disable until you sign in again',
          onTap: () => _confirmDeactivateAccount(context),
        ),
      ],
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
  }
}

Future<void> _confirmGlobalSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out everywhere'),
      content: const Text('This will sign you out of all devices. Continue?'),
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
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.global);
    if (!context.mounted) return;
    context.go('/signin');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
  }
}

Future<void> _confirmDeactivateAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Deactivate account'),
      content: const Text(
        'Your account will be inactive until you sign in again. '
        'You can reactivate anytime by logging back in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Deactivate'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_active': false})
          .eq('id', user.id);
    }
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    context.go('/signin');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deactivate failed: $e')));
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
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
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
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
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
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
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
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DevicesList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DevicesList> createState() => _DevicesListState();
}

class _DevicesListState extends ConsumerState<_DevicesList> {
  late Future<_DeviceListData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDeviceListDataFromLocal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshFromRemote();
    });
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = _loadDeviceListDataFromLocal();
    });
    _refreshFromRemote();
  }

  Future<void> _removeDevice(String deviceId) async {
    final repo = DeviceStateRepository(database: ref.read(appDatabaseProvider));
    await repo.removeDeviceAndRefresh(deviceId: deviceId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Device removed.')));
    setState(() {
      _future = _loadDeviceListDataFromLocal();
    });
  }

  Future<_DeviceListData> _loadDeviceListDataFromLocal() async {
    final repo = DeviceStateRepository(database: ref.read(appDatabaseProvider));
    final local = await repo.loadLocal();
    return _DeviceListData(
      localDeviceId: local.localDeviceId,
      sessions: local.sessions
          .map(
            (session) => _DeviceSession(
              deviceId: session.deviceId,
              deviceName: session.deviceName,
              platform: session.platform,
              lastSeen: session.lastSeen,
              sortKey: session.sortKey,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _refreshFromRemote() async {
    final repo = DeviceStateRepository(database: ref.read(appDatabaseProvider));
    try {
      final refreshed = await repo.refreshRemoteAuthoritative();
      if (!mounted) return;
      setState(() {
        _future = Future<_DeviceListData>.value(
          _DeviceListData(
            localDeviceId: refreshed.localDeviceId,
            sessions: refreshed.sessions
                .map(
                  (session) => _DeviceSession(
                    deviceId: session.deviceId,
                    deviceName: session.deviceName,
                    platform: session.platform,
                    lastSeen: session.lastSeen,
                    sortKey: session.sortKey,
                  ),
                )
                .toList(growable: false),
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _future = _loadDeviceListDataFromLocal();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DeviceListData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('We could not load your devices just yet.'),
                const SizedBox(height: 8),
                TextButton(onPressed: _refresh, child: const Text('Try again')),
              ],
            ),
          );
        }

        final data =
            snapshot.data ??
            const _DeviceListData(localDeviceId: '', sessions: []);
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
                subtitle: Text('${session.platform} • ${session.lastSeen}'),
                trailing: session.deviceId == data.localDeviceId
                    ? const Chip(label: Text('This device'))
                    : IconButton(
                        onPressed: () => _removeDevice(session.deviceId),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove device',
                      ),
              ),
          ],
        );
      },
    );
  }
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
    this.sortKey = '',
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String lastSeen;
  final String sortKey;
}
