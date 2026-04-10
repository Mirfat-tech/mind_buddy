import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'router.dart';
import 'features/auth/device_session_service.dart';
import 'features/settings/settings_provider.dart';
import 'features/settings/settings_model.dart';
import 'features/settings/settings_repository.dart';
import 'features/onboarding/onboarding_state.dart';
import 'services/notification_service.dart';
import 'services/startup_user_data_service.dart';
import 'services/auth_deep_link_handler.dart';
import 'services/journal_encryption_service.dart';
import 'services/oauth_sign_in_coordinator.dart';
import 'services/username_resolver_service.dart';
import 'features/habits/habit_home_widget_service.dart';

@pragma('vm:entry-point')
Future<void> _widgetInteractivityCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId(HabitHomeWidgetService.iOSAppGroupId);
  await HabitHomeWidgetService.ensureBackgroundInitialized();
  await HabitHomeWidgetService.handleInteractivityAction(uri);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const customSupabaseAuthDomain = 'https://auth.mybrainbubble.co.uk';

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional in dev; ignore if missing.
  }

  const supabaseUrl = customSupabaseAuthDomain;
  final supabaseAnonKey = dotenv.isInitialized
      ? (dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim().isNotEmpty == true
            ? dotenv.maybeGet('SUPABASE_ANON_KEY')!.trim()
            : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudGZ4bmpydGdsaXl6aGVmYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MjIzMDgsImV4cCI6MjA4MDQ5ODMwOH0.TgMtKwjswRTbMESjpep2FWq37_OG20Z8VCb6aR03Bo8')
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudGZ4bmpydGdsaXl6aGVmYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MjIzMDgsImV4cCI6MjA4MDQ5ODMwOH0.TgMtKwjswRTbMESjpep2FWq37_OG20Z8VCb6aR03Bo8';

  debugPrint('[Auth Config] Supabase URL: $supabaseUrl');

  // ✅ MUST happen before any Supabase.instance usage (router + auth listener)
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await HomeWidget.setAppGroupId(HabitHomeWidgetService.iOSAppGroupId);
  await HomeWidget.registerInteractivityCallback(_widgetInteractivityCallback);
  await HabitHomeWidgetService.flushPendingWidgetToggles();
  final settingsRepo = SettingsRepository(Supabase.instance.client);
  final SettingsModel? cachedSettings = await settingsRepo.loadLocal();

  // ✅ create router AFTER Supabase is initialized
  final appRouter = createRouter();
  //await dotenv.load();
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(cachedSettings)],
      child: _Bootstrap(router: appRouter),
    ),
  );
}

/// Bootstraps app-level init that needs Riverpod (theme load) + auth listener.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap({required this.router});

  final GoRouter router;

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  StreamSubscription<AuthState>? _authSub;
  bool _startupErrorShown = false;
  static bool _startupWarningShownOnce = false;
  static bool _usernameProbeRan = false;
  bool _deviceLimitSignOutInFlight = false;
  bool _suppressAutoHomeNavigation = false;
  VoidCallback? _oauthTimeoutListener;

  @override
  void initState() {
    super.initState();

    Future.microtask(_syncStartupUserData);
    Future.microtask(
      () => AuthDeepLinkHandler.instance.init(
        onSessionEstablished: () {
          if (!mounted) return;
          final session = Supabase.instance.client.auth.currentSession;
          debugPrint(
            'AuthDeepLinkHandler onSessionEstablished hasSession=${session != null} user=${session?.user.id}',
          );
          globalMessengerKey.currentState?.hideCurrentSnackBar();
          if (!_suppressAutoHomeNavigation) {
            widget.router.go('/bootstrap');
          }
        },
        onAuthError: (message) {
          if (!mounted) return;
          globalMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
        onWidgetLink: (uri) {
          _suppressAutoHomeNavigation = true;
          unawaited(_handleWidgetLink(uri));
        },
      ),
    );
    // Load settings (includes theme)
    Future.microtask(() => ref.read(settingsControllerProvider).init());
    NotificationService.instance.init();
    _oauthTimeoutListener = () {
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentSession != null) {
        return;
      }
      globalMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text(OAuthSignInCoordinator.timeoutMessage),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () async {
              final res = await OAuthSignInCoordinator.instance
                  .retryLastAttempt(forceFreshSession: true);
              if (!mounted || res.started) return;
              globalMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    res.message ?? 'Could not restart Google sign-in.',
                  ),
                ),
              );
            },
          ),
        ),
      );
    };
    OAuthSignInCoordinator.instance.timeoutSignalListenable.addListener(
      _oauthTimeoutListener!,
    );

    // If you're using Supabase Edge Function secrets for OpenAI,
    // no local .env warning is necessary.

    // Password recovery deep link handling
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint(
        'Auth event=${data.event} hasSession=${data.session != null} user=${data.session?.user.id}',
      );
      if (data.event == AuthChangeEvent.passwordRecovery) {
        widget.router.go('/reset');
      }
      if (data.event == AuthChangeEvent.signedIn) {
        OAuthSignInCoordinator.instance.markCompleted(
          reason: 'auth_state_signed_in',
        );
        StartupUserDataService.instance.invalidateCurrentUser();
        globalMessengerKey.currentState?.hideCurrentSnackBar();
        unawaited(OnboardingController.setAuthStageCompleted(true));
        if (mounted && !_suppressAutoHomeNavigation) {
          widget.router.go('/bootstrap');
        }
        unawaited(_enforceDeviceLimitOnSignIn());
      }
      if (data.event == AuthChangeEvent.signedOut) {
        OAuthSignInCoordinator.instance.markFailed(
          reason: 'auth_state_signed_out',
        );
        unawaited(OnboardingController.setAuthStageCompleted(false));
      }
      unawaited(JournalEncryptionService.instance.handleAuthScopeChanged());
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        StartupUserDataService.instance.invalidateCurrentUser();
        unawaited(HabitHomeWidgetService.flushPendingWidgetToggles());
        _maybeReactivateAccount();
        _syncStartupUserData();
      }
      ref.read(settingsControllerProvider).handleAuthChange();
    });
  }

  Future<void> _enforceDeviceLimitOnSignIn() async {
    if (_deviceLimitSignOutInFlight) return;
    final registration = await DeviceSessionService.registerDevice();
    if (!mounted) return;
    if (registration.allowed) {
      if (registration.entitlementCheckFailed) {
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not verify your subscription right now. Signed in with temporary access.',
            ),
          ),
        );
      }
      return;
    }
    if (!registration.shouldBlockForDeviceLimit) {
      return;
    }
    _deviceLimitSignOutInFlight = true;
    try {
      globalMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(registration.blockedMessage()),
          action: SnackBarAction(
            label: 'Manage devices',
            onPressed: () => widget.router.go('/settings'),
          ),
        ),
      );
      widget.router.go('/settings');
    } finally {
      _deviceLimitSignOutInFlight = false;
    }
  }

  Future<void> _syncStartupUserData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final bundle = await StartupUserDataService.instance
        .fetchCombinedForCurrentUser();
    if (!mounted) return;
    if (bundle.failedTables.isNotEmpty) {
      debugPrint(
        '[StartupSync] failed userId=${userId ?? 'none'} tables=${bundle.failedTables.join(',')} details=${bundle.failedDetails}',
      );
      // Non-blocking warning only; do not trap users in setup flows.
      if (_startupErrorShown || _startupWarningShownOnce) return;
      _startupErrorShown = true;
      _startupWarningShownOnce = true;
      globalMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text(
            'Some profile data is temporarily unavailable. You can keep using the app.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              _startupErrorShown = false;
              _syncStartupUserData();
              ref.read(settingsControllerProvider).retryInit();
            },
          ),
        ),
      );
      return;
    }
    _startupErrorShown = false;
    if (!_usernameProbeRan) {
      _usernameProbeRan = true;
      unawaited(
        UsernameResolverService.instance.debugProbe(
          knownUsername: bundle.profileRow?['username']?.toString(),
        ),
      );
    }
    unawaited(HabitHomeWidgetService.syncTodaySnapshot());
  }

  Future<void> _handleWidgetLink(Uri uri) async {
    if (!mounted) return;

    final path = uri.path.toLowerCase();
    if (path == '/habits' || path == '/view-all') {
      await HabitHomeWidgetService.flushPendingWidgetToggles();
      if (!mounted) return;
      widget.router.go('/habits');
      return;
    }
    // Ignore toggle deeplinks in foreground app; habit taps should be handled
    // through background interactivity without navigation.
  }

  Future<void> _maybeReactivateAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final bundle = await StartupUserDataService.instance.fetchCombinedForUser(
        user.id,
      );
      final profile = bundle.profileRow;
      final isActive = profile?['is_active'] != false;
      if (!isActive) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_active': true})
            .eq('id', user.id);
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Your account has been reactivated.')),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    final listener = _oauthTimeoutListener;
    if (listener != null) {
      OAuthSignInCoordinator.instance.timeoutSignalListenable.removeListener(
        listener,
      );
    }
    unawaited(AuthDeepLinkHandler.instance.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MindBuddyApp(router: widget.router);
  }
}
