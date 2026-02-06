// lib/router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/features/templates/templates_screen.dart';
import 'package:mind_buddy/features/templates/template_screen.dart';

// screens
import 'features/splash/splash_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'package:mind_buddy/features/home/home_screen.dart';
import 'calendar/calendar_screen.dart';
import 'features/journal/new_journal_screen.dart';
import 'features/journal/journals_list_screen.dart';
import 'features/journal/journal_view_screen.dart';
import 'features/journal/journal_share_view_screen.dart';
import 'features/journal/edit_journal_screen.dart';
import 'features/day/daily_page_screen.dart';
import 'features/chat/chat_screen.dart';
import 'package:mind_buddy/features/templates/log_table_screen.dart';
import 'package:mind_buddy/features/insights/insights_gate_screen.dart';
import 'package:mind_buddy/features/onboarding/plan_selection_screen.dart';
//import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'package:mind_buddy/features/insights/manage_habits_screen.dart'
    show ManageHabitsScreen;
import 'package:mind_buddy/features/habits/habits_screen.dart';
import 'package:mind_buddy/features/insights/manage_habits_screen.dart';

//import 'package:mind_buddy/features/insights/habit_streaks_summary.dart';
import 'package:mind_buddy/features/templates/create_templates_screen.dart';

import 'features/pomodoro/pomodoro_screen.dart';

import 'package:mind_buddy/features/brain_fog/brain_fog_screen.dart';
import 'package:mind_buddy/features/chat/chat_archive_screen.dart';
import 'package:mind_buddy/features/subscription/subscription_screen.dart';
import 'package:mind_buddy/features/settings/settings_screen.dart';
import 'package:mind_buddy/features/settings/appearance_settings_screen.dart';
import 'package:mind_buddy/features/settings/notifications_settings_screen.dart';
import 'package:mind_buddy/features/settings/usage_settings_screen.dart';
import 'package:mind_buddy/features/settings/quiet_guide_screen.dart';

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

    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('log_templates_v2')
          .select('id, template_key')
          .eq('template_key', templateKey)
          .maybeSingle(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final tpl = snap.data;
        if (tpl == null) {
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
  return CupertinoPage<void>(
    key: state.pageKey,
    child: themed(child),
  );
}

GoRouter createRouter() {
  final supabase = Supabase.instance.client;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',

    // Re-run redirect when auth changes
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),

    redirect: (context, state) async {
      final session = supabase.auth.currentSession;

      final loggingIn = state.matchedLocation == '/signin';
      final onSplash = state.matchedLocation == '/splash';
      final onReset = state.matchedLocation == '/reset';
      final onOnboarding = state.matchedLocation == '/onboarding/plan';
      final onSubscription = state.matchedLocation == '/subscription';
      final onShare = state.matchedLocation.startsWith('/share/');

      // let splash/reset handle themselves
      if (onSplash || onReset || onShare) return null;

      // not logged in -> go signin
      if (session == null && !loggingIn) return '/signin';

      if (session != null) {
        // pending plan -> force onboarding choice
        final profile = await supabase
            .from('profiles')
            .select('subscription_tier')
            .eq('id', session.user.id)
            .maybeSingle();
        final tier =
            (profile?['subscription_tier'] ?? '').toString().trim().toLowerCase();
        final pending = tier.isEmpty || tier == 'pending';

        if (pending &&
            !onOnboarding &&
            !onSubscription &&
            !loggingIn) {
          return '/onboarding/plan';
        }

        // logged in but on signin -> go home
        if (loggingIn) return '/home';
      }

      return null;
    },

    routes: [
      // SPLASH
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            cupertinoPage(const SplashScreen(), state),
      ),

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
        path: '/onboarding/plan',
        pageBuilder: (context, state) =>
            cupertinoPage(const PlanSelectionScreen(), state),
      ),

      // HOME
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            cupertinoPage(const HomeScreen(), state),
      ),

      // CALENDAR
      GoRoute(
        path: '/calendar',
        pageBuilder: (context, state) =>
            cupertinoPage(const CalendarScreen(), state),
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
            cupertinoPage(const JournalsListScreen(), state),
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
          return cupertinoPage(JournalViewScreen(journalId: id), state);
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

      // CHAT (attached to a day)
      GoRoute(
        path: '/chat/:dayId/:chatId',
        pageBuilder: (context, state) {
          final dayId = state.pathParameters['dayId']!;
          final chatId = int.parse(state.pathParameters['chatId']!);
          return cupertinoPage(ChatScreen(dayId: dayId, chatId: chatId), state);
        },
      ),

      GoRoute(
        path: '/chat-archive/:dayId',
        pageBuilder: (context, state) {
          final dayId = state.pathParameters['dayId']!;
          // Add themed() here to match your other screens
          return cupertinoPage(ChatArchiveScreen(dayId: dayId), state);
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
        path: '/settings/notifications',
        pageBuilder: (context, state) =>
            cupertinoPage(const NotificationsSettingsScreen(), state),
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
