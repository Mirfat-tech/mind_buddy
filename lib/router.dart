// lib/router.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/features/templates/templates_screen.dart';
import 'package:mind_buddy/features/templates/template_screen.dart';
import 'package:mind_buddy/features/templates/built_in_log_templates.dart';
import 'package:mind_buddy/features/templates/data/template_local_first_support.dart';

// screens
import 'features/splash/bootstrap_gate_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/auth/auth_callback_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'package:mind_buddy/features/home/overall_features_page.dart';
import 'features/journal/new_journal_screen.dart';
import 'features/journal/journals_list_screen.dart';
import 'features/journal/journal_view_screen.dart';
import 'features/journal/journal_share_view_screen.dart';
import 'features/journal/edit_journal_screen.dart';
import 'features/day/daily_page_screen.dart';
import 'package:mind_buddy/features/templates/log_table_screen.dart';
import 'package:mind_buddy/features/insights/insights_gate_screen.dart';
import 'package:mind_buddy/features/onboarding/plan_selection_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_doorway_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_promise_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_auth_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_features_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_expression_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_lookback_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_confirm_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_feature_experience_screens.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_username_screen.dart';
//import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'package:mind_buddy/features/insights/manage_habits_screen.dart'
    show ManageHabitsScreen;
import 'package:mind_buddy/features/habits/habit_bubble_entry_screen.dart';
import 'package:mind_buddy/features/habits/habits_screen.dart';
import 'package:mind_buddy/features/insights/manage_habits_screen.dart';

//import 'package:mind_buddy/features/insights/habit_streaks_summary.dart';
import 'package:mind_buddy/features/templates/create_templates_screen.dart';

import 'features/pomodoro/pomodoro_screen.dart';

import 'package:mind_buddy/features/brain_fog/brain_fog_screen.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_launch_config.dart';
import 'package:mind_buddy/features/bubble_pool/bubble_pool_screen.dart';
import 'package:mind_buddy/features/gratitude/gratitude_bubble_screen.dart';
import 'package:mind_buddy/features/gratitude/gratitude_carousel_editor_screen.dart';
import 'package:mind_buddy/features/quotes/quote_bubble_screen.dart';
import 'package:mind_buddy/features/subscription/plus_feature_gate_screen.dart';
import 'package:mind_buddy/features/subscription/subscription_screen.dart';
import 'package:mind_buddy/features/settings/settings_screen.dart';
import 'package:mind_buddy/features/settings/appearance_settings_screen.dart';
import 'package:mind_buddy/features/settings/notifications_settings_screen.dart';
import 'package:mind_buddy/features/settings/theme_preview_screen.dart';
import 'package:mind_buddy/features/settings/custom_theme_builder_screen.dart';
import 'package:mind_buddy/features/settings/usage_settings_screen.dart';
import 'package:mind_buddy/features/settings/quiet_guide_screen.dart';
import 'package:mind_buddy/features/settings/blocked_users_screen.dart';
import 'package:mind_buddy/features/settings/pages/home_sphere_preview_screen.dart';
import 'package:mind_buddy/features/test_page/test_page.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';

//

// theming wrapper
import 'paper/themed_page.dart';

class TemplateLogsLoaderScreen extends StatelessWidget {
  const TemplateLogsLoaderScreen({
    super.key,
    required this.templateKey,
    required this.dayId,
  });

  final String templateKey; // 'sleep'
  final String dayId; // 'YYYY-MM-DD'

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final builtInTemplate = localFirstBuiltInTemplateForKey(templateKey);

    if (builtInTemplate != null) {
      return LogTableScreen(
        templateId: builtInTemplate.id,
        templateKey: builtInTemplate.templateKey,
        dayId: dayId,
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('log_templates_v2')
          .select('id, template_key')
          .eq('template_key', templateKey)
          .maybeSingle(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Log')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load template: ${snap.error}'),
              ),
            ),
          );
        }

        final tpl = snap.data;
        if (tpl == null) {
          final builtIn = builtInLogTemplateByKey(templateKey);
          if (builtIn != null) {
            return LogTableScreen(
              templateId: builtIn.id,
              templateKey: builtIn.templateKey,
              dayId: dayId,
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Log')),
            body: Center(child: Text('Template not found: $templateKey')),
          );
        }

        final tplId = tpl['id'] as String; // UUID

        return LogTableScreen(
          templateId: tplId,
          templateKey: templateKey,
          dayId: dayId,
        );
      },
    );
  }
}

BuiltInLogTemplateDefinition? localFirstBuiltInTemplateForKey(
  String templateKey,
) {
  final builtIn = builtInLogTemplateByKey(templateKey);
  if (builtIn == null) return null;
  if (!isLocalFirstTemplateKey(templateKey)) return null;
  return builtIn;
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Forces GoRouter to re-run redirect logic whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Wrap every routed screen in your themed paper wrapper.
Widget themed(Widget child) => ThemedPage(child: child);

/// Use CupertinoPage so iOS back-swipe works consistently.
Page<void> cupertinoPage(Widget child, GoRouterState state) {
  return CupertinoPage<void>(key: state.pageKey, child: themed(child));
}

Page<void> cupertinoPlainPage(Widget child, GoRouterState state) {
  return CupertinoPage<void>(key: state.pageKey, child: child);
}

GoRouter createRouter() {
  final supabase = Supabase.instance.client;
  String? lastLoggedCompletionRouteUserId;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/bootstrap',

    // Re-run redirect when auth changes
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),

    redirect: (context, state) async {
      final incomingPath = state.uri.path.toLowerCase();
      if (incomingPath == '/toggle' || incomingPath == '/widget/toggle') {
        return '/';
      }
      final session = supabase.auth.currentSession;

      final onAuth = state.matchedLocation == '/auth';
      final loggingIn = state.matchedLocation == '/signin';
      final onSignup = state.matchedLocation == '/signup';
      final onSplash = state.matchedLocation == '/splash';
      final onBootstrap = state.matchedLocation == '/bootstrap';
      final onReset = state.matchedLocation == '/reset';
      final onAuthCallback = state.matchedLocation == '/auth/callback';
      final onOnboarding = state.matchedLocation.startsWith('/onboarding');
      final onOnboardingPlan = state.matchedLocation == '/onboarding/plan';
      final onOnboardingUsername =
          state.matchedLocation == '/onboarding/username';
      final onOnboardingDoorway =
          state.matchedLocation == '/onboarding/doorway';
      final onOnboardingExpression =
          state.matchedLocation == '/onboarding/expression';
      final onOnboardingLookback =
          state.matchedLocation == '/onboarding/lookback';
      final onOnboardingGratitudeExperience =
          state.matchedLocation == '/onboarding/experience/gratitude';
      final onOnboardingBrainFogExperience =
          state.matchedLocation == '/onboarding/experience/brain-fog';
      final onSetup = state.matchedLocation.startsWith('/setup/');
      final onSetupDoorway = state.matchedLocation == '/setup/doorway';
      final onShare = state.matchedLocation.startsWith('/share/');

      // let splash/reset handle themselves
      if (onSplash || onBootstrap || onReset || onAuthCallback || onShare) {
        return null;
      }

      if (session == null) {
        final seenLocally = await OnboardingController.hasSeenLocally();
        if (kDebugMode) {
          debugPrint(
            '[StartupGate] auth_user_present=false location=${state.matchedLocation} onboarding_seen_locally=$seenLocally',
          );
        }
        if (!seenLocally) {
          debugPrint('STARTUP_ROUTE_SIGNED_OUT_ONBOARDING');
          if (onOnboarding || onAuth || loggingIn || onSignup || onReset) {
            return null;
          }
          return '/onboarding/doorway';
        }
        debugPrint('STARTUP_ROUTE_SIGNED_OUT_AUTH_ALREADY_SEEN');
        if (onAuth || loggingIn || onSignup || onReset) {
          return null;
        }
        return '/auth';
      }

      final completion = await CompletionGateRepository.fetchForCurrentUser(
        preferCache: false,
      );
      final profileRow = StartupUserDataService.instance
          .peekCachedForCurrentUser()
          ?.profileRow;
      final subscriptionTier = (profileRow?['subscription_tier'] ?? '')
          .toString();
      final onQuestionsRoute =
          onOnboardingDoorway ||
          onOnboardingExpression ||
          onOnboardingLookback ||
          onOnboardingGratitudeExperience ||
          onOnboardingBrainFogExperience;
      final chosenInitialRoute = !completion.subscriptionCompleted
          ? '/onboarding/plan'
          : !completion.usernameCompleted
          ? '/onboarding/username'
          : '/';
      final routeReason = !completion.subscriptionCompleted
          ? 'subscription_incomplete'
          : !completion.usernameCompleted
          ? 'username_incomplete'
          : 'all_setup_complete';

      if (kDebugMode) {
        debugPrint('STARTUP_ROUTE_SIGNED_IN_SKIP_ONBOARDING');
        debugPrint(
          '[StartupGate] auth_user_present=true userId=${session.user.id} location=${state.matchedLocation} profile_loaded=${profileRow != null} onboarding_completed=${completion.onboardingCompleted} username_completed=${completion.usernameCompleted} subscription_completed=${completion.subscriptionCompleted} subscription_tier=$subscriptionTier final_route=$chosenInitialRoute reason=$routeReason',
        );
      }
      if (kDebugMode && lastLoggedCompletionRouteUserId != session.user.id) {
        lastLoggedCompletionRouteUserId = session.user.id;
        debugPrint(
          '[CompletionGate] userId=${session.user.id} onboarding_completed=${completion.onboardingCompleted} username_completed=${completion.usernameCompleted} subscription_completed=${completion.subscriptionCompleted} route=$chosenInitialRoute reason=$routeReason',
        );
      }

      if (chosenInitialRoute == '/onboarding/username' &&
          !onOnboardingUsername &&
          !onAuth &&
          !loggingIn &&
          !onSignup) {
        return '/onboarding/username';
      }

      if (chosenInitialRoute == '/onboarding/plan' &&
          !onOnboardingPlan &&
          !onAuth &&
          !loggingIn &&
          !onSignup) {
        return '/onboarding/plan';
      }

      if (chosenInitialRoute == '/' &&
          (loggingIn || onSignup || onAuth || onOnboarding)) {
        return '/';
      }

      if (onQuestionsRoute && !onAuth && !loggingIn && !onSignup) {
        return chosenInitialRoute;
      }

      if (onSetupDoorway || onSetup) return null;

      return null;
    },

    routes: [
      // SPLASH
      GoRoute(
        path: '/bootstrap',
        pageBuilder: (context, state) =>
            cupertinoPlainPage(const BootstrapGateScreen(), state),
      ),
      GoRoute(path: '/splash', redirect: (_, __) => '/bootstrap'),

      // AUTH
      GoRoute(
        path: '/signin',
        pageBuilder: (context, state) =>
            cupertinoPage(const SignInScreen(), state),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) =>
            cupertinoPage(const SignUpScreen(), state),
      ),
      GoRoute(
        path: '/reset',
        pageBuilder: (context, state) =>
            cupertinoPage(const ResetPasswordScreen(), state),
      ),
      GoRoute(
        path: '/auth/callback',
        pageBuilder: (context, state) =>
            cupertinoPage(const AuthCallbackScreen(), state),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingAuthScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/doorway',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingDoorwayScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/promise',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingPromiseScreen(), state),
      ),
      GoRoute(path: '/onboarding/auth', redirect: (_, __) => '/auth'),
      GoRoute(
        path: '/onboarding/features',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingFeaturesScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/expression',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingExpressionScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/experience/gratitude',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingGratitudeExperienceScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/experience/brain-fog',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingBrainFogExperienceScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/lookback',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingLookbackScreen(), state),
      ),
      GoRoute(
        path: '/setup/doorway',
        redirect: (_, __) => '/onboarding/doorway',
      ),
      GoRoute(
        path: '/setup/expression',
        redirect: (_, __) => '/onboarding/expression',
      ),
      GoRoute(
        path: '/setup/lookback',
        redirect: (_, __) => '/onboarding/lookback',
      ),
      GoRoute(
        path: '/onboarding/confirm',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingConfirmScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/username',
        pageBuilder: (context, state) =>
            cupertinoPage(const OnboardingUsernameScreen(), state),
      ),
      GoRoute(
        path: '/onboarding/plan',
        pageBuilder: (context, state) =>
            cupertinoPage(const PlanSelectionScreen(), state),
      ),

      // HOME
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            cupertinoPage(const HomeSpherePreviewScreen(), state),
      ),
      GoRoute(path: '/home', redirect: (_, __) => '/'),
      GoRoute(
        path: '/overall-features',
        pageBuilder: (context, state) =>
            cupertinoPage(const OverallFeaturesPage(), state),
      ),

      GoRoute(
        path: '/test-page',
        pageBuilder: (context, state) => cupertinoPage(const TestPage(), state),
      ),
      // JOURNAL
      GoRoute(
        path: '/journal/new',
        pageBuilder: (context, state) =>
            cupertinoPage(const NewJournalScreen(), state),
      ),
      GoRoute(
        path: '/journals',
        pageBuilder: (context, state) =>
            cupertinoPage(JournalsListScreen(), state),
      ),
      GoRoute(
        path: '/journals/new',
        pageBuilder: (context, state) =>
            cupertinoPage(const NewJournalScreen(), state),
      ),
      GoRoute(
        path: '/journals/view/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          Map<String, dynamic>? initialEntry;
          if (state.extra is Map) {
            final extra = Map<String, dynamic>.from(state.extra as Map);
            final rawEntry = extra['entry'];
            if (rawEntry is Map) {
              initialEntry = Map<String, dynamic>.from(rawEntry);
            }
          }
          return cupertinoPage(
            JournalViewScreen(journalId: id, initialEntry: initialEntry),
            state,
          );
        },
      ),
      GoRoute(
        path: '/journals/edit/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return cupertinoPage(EditJournalScreen(journalId: id), state);
        },
      ),
      GoRoute(
        path: '/share/:shareId',
        pageBuilder: (context, state) {
          final shareId = state.pathParameters['shareId']!;
          return cupertinoPage(JournalShareViewScreen(shareId: shareId), state);
        },
      ),

      //DAY PAGE
      GoRoute(
        path: '/day/:dayId',
        pageBuilder: (context, state) {
          final dayId = state.pathParameters['dayId']!;
          return cupertinoPage(DailyPageScreen(dayId: dayId), state);
        },
      ),

      // TODAY -> /day/yyyy-MM-dd
      // GoRoute(
      //path: '/today',
      //redirect: (_, __) {
      //final now = DateTime.now();
      // final y = now.year.toString().padLeft(4, '0');
      // final m = now.month.toString().padLeft(2, '0');
      // final d = now.day.toString().padLeft(2, '0');
      // return '/day/$y-$m-$d';
      // },
      // ),

      // TEMPLATES (list)
      GoRoute(
        path: '/templates',
        pageBuilder: (context, state) =>
            cupertinoPage(const TemplatesScreen(), state),
      ),
      GoRoute(
        path: '/subscription',
        pageBuilder: (context, state) =>
            cupertinoPage(const SubscriptionScreen(), state),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            cupertinoPage(const SettingsScreen(), state),
      ),
      GoRoute(
        path: '/settings/appearance',
        pageBuilder: (context, state) =>
            cupertinoPage(const AppearanceSettingsScreen(), state),
      ),
      GoRoute(
        path: '/settings/theme-preview/:themeId',
        pageBuilder: (context, state) {
          final themeId = state.pathParameters['themeId']!;
          return cupertinoPage(ThemePreviewScreen(themeId: themeId), state);
        },
      ),
      GoRoute(
        path: '/settings/custom-theme',
        pageBuilder: (context, state) =>
            cupertinoPage(const CustomThemeBuilderScreen(), state),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (context, state) =>
            cupertinoPage(const NotificationsSettingsScreen(), state),
      ),
      GoRoute(
        path: '/settings/blocked',
        pageBuilder: (context, state) =>
            cupertinoPage(const BlockedUsersScreen(), state),
      ),
      GoRoute(
        path: '/settings/usage',
        pageBuilder: (context, state) =>
            cupertinoPage(const UsageSettingsScreen(), state),
      ),
      GoRoute(
        path: '/settings/guide',
        pageBuilder: (context, state) =>
            cupertinoPage(const QuietGuideScreen(), state),
      ),
      GoRoute(
        path: '/settings/home-sphere-preview',
        pageBuilder: (context, state) =>
            cupertinoPage(const HomeSpherePreviewScreen(), state),
      ),
      GoRoute(
        path: '/pomodoro',
        pageBuilder: (context, state) =>
            cupertinoPage(const PomodoroScreen(), state),
      ),

      // TEMPLATE DETAIL
      GoRoute(
        path: '/templates/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return cupertinoPage(TemplateScreen(templateId: id), state);
        },
      ),

      // TEMPLATE LOGS (for a specific day)
      GoRoute(
        path: '/templates/by-key/:templateKey/logs/:dayId',
        pageBuilder: (context, state) {
          final templateKey = state.pathParameters['templateKey']!;
          final dayId = state.pathParameters['dayId']!;
          return cupertinoPage(
            TemplateLogsLoaderScreen(templateKey: templateKey, dayId: dayId),
            state,
          );
        },
      ),

      // TEMPLATE LOGS (no dayId yet -> default today)
      GoRoute(
        path: '/templates/by-key/:templateKey/logs',
        pageBuilder: (context, state) {
          final templateKey = state.pathParameters['templateKey']!;
          final now = DateTime.now();
          final y = now.year.toString().padLeft(4, '0');
          final m = now.month.toString().padLeft(2, '0');
          final d = now.day.toString().padLeft(2, '0');
          final dayId = '$y-$m-$d';

          return cupertinoPage(
            TemplateLogsLoaderScreen(templateKey: templateKey, dayId: dayId),
            state,
          );
        },
      ),

      GoRoute(
        path: '/insights',
        pageBuilder: (context, state) =>
            cupertinoPage(const InsightsGateScreen(), state),
      ),

      GoRoute(
        path: '/habits',
        pageBuilder: (context, state) =>
            cupertinoPage(const HabitBubbleEntryScreen(), state),
      ),

      GoRoute(
        path: '/habits/tracker',
        pageBuilder: (context, state) =>
            cupertinoPage(const HabitsScreen(), state),
      ),

      GoRoute(
        path: '/habits/manage',
        pageBuilder: (context, state) =>
            cupertinoPage(const ManageHabitsScreen(), state),
      ),

      GoRoute(
        path: '/templates/create',
        pageBuilder: (context, state) =>
            cupertinoPage(const CreateLogTemplateScreen(), state),
      ),

      GoRoute(
        path: '/brain-fog',
        pageBuilder: (context, state) =>
            cupertinoPage(const BrainFogScreen(), state),
      ),

      GoRoute(
        path: '/bubble-pool',
        pageBuilder: (context, state) =>
            cupertinoPage(const BubblePoolScreen(), state),
      ),
      GoRoute(
        path: '/coming-soon/:featureKey',
        pageBuilder: (context, state) {
          final featureKey =
              state.pathParameters['featureKey'] ?? 'bubble_pool';
          return cupertinoPage(buildBubbleComingSoonPage(featureKey), state);
        },
      ),

      GoRoute(
        path: '/gratitude-bubble',
        pageBuilder: (context, state) => cupertinoPage(
          const PlusFeatureGateScreen(
            title: 'Gratitude Bubble',
            message:
                'Gratitude Bubble is part of Plus Support Mode. See plans to unlock it.',
            child: GratitudeBubbleScreen(),
          ),
          state,
        ),
      ),

      GoRoute(
        path: '/gratitude-carousel',
        pageBuilder: (context, state) {
          String? entryId;
          List<String> seededBubbleTexts = const <String>[];
          if (state.extra is Map) {
            final extra = Map<String, dynamic>.from(state.extra as Map);
            entryId = extra['entryId']?.toString();
            final rawSeeded = extra['seededBubbleTexts'];
            if (rawSeeded is List) {
              seededBubbleTexts = rawSeeded
                  .map((item) => item.toString())
                  .where((item) => item.trim().isNotEmpty)
                  .toList();
            }
          }
          return cupertinoPage(
            PlusFeatureGateScreen(
              title: 'Gratitude Carousel',
              message:
                  'Gratitude Bubble and Gratitude Carousel are part of Plus Support Mode.',
              child: GratitudeCarouselEditorScreen(
                entryId: entryId,
                seededBubbleTexts: seededBubbleTexts,
              ),
            ),
            state,
          );
        },
      ),

      GoRoute(
        path: '/gratitude-carousel/history',
        pageBuilder: (context, state) => cupertinoPage(
          const PlusFeatureGateScreen(
            title: 'Gratitude Carousel',
            message:
                'Gratitude Bubble and Gratitude Carousel are part of Plus Support Mode.',
            child: GratitudeCarouselHistoryScreen(),
          ),
          state,
        ),
      ),

      GoRoute(
        path: '/quotes',
        pageBuilder: (context, state) =>
            cupertinoPage(const QuoteBubbleScreen(), state),
      ),

      GoRoute(
        path: '/templates/log',
        pageBuilder: (context, state) {
          final templateId = state.uri.queryParameters['templateId']!;
          final templateKey = state.uri.queryParameters['templateKey']!;
          final dayId = state.uri.queryParameters['dayId']!;
          return cupertinoPage(
            LogTableScreen(
              templateId: templateId,
              templateKey: templateKey,
              dayId: dayId,
            ),
            state,
          );
        },
      ),
    ],
  );
}

/// Simple placeholder so you can add routes now without building screens yet.
/// Replace this later with real template screens.
class TemplatePlaceholderScreen extends StatelessWidget {
  const TemplatePlaceholderScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Template: $templateId')),
      body: Center(
        child: Text(
          'Coming soon: $templateId',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
