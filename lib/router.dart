// lib/router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/features/templates/templates_screen.dart';
import 'package:mind_buddy/features/templates/template_screen.dart';

// screens
import 'features/splash/splash_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'package:mind_buddy/features/home/home_screen.dart';
import 'calendar/calendar_screen.dart';
import 'features/journal/new_journal_screen.dart';
//import 'features/day/daily_page_screen.dart';
import 'features/chat/chat_screen.dart';
import 'package:mind_buddy/features/templates/log_table_screen.dart';
import 'package:mind_buddy/features/insights/insights_screen.dart';
//import 'package:mind_buddy/features/insights/habit_month_grid.dart';
import 'package:mind_buddy/features/insights/manage_habits_screen.dart'
    show ManageHabitsScreen;
import 'package:mind_buddy/features/habits/habits_screen.dart';
import 'package:mind_buddy/features/insights/manage_habits_screen.dart';

//import 'package:mind_buddy/features/insights/habit_streaks_summary.dart';
import 'package:mind_buddy/features/templates/create_templates_screen.dart';

import 'features/pomodoro/pomodoro_screen.dart';
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

GoRouter createRouter() {
  final supabase = Supabase.instance.client;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',

    // Re-run redirect when auth changes
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),

    redirect: (context, state) {
      final session = supabase.auth.currentSession;

      final loggingIn = state.matchedLocation == '/signin';
      final onSplash = state.matchedLocation == '/splash';
      final onReset = state.matchedLocation == '/reset';

      // let splash/reset handle themselves
      if (onSplash || onReset) return null;

      // not logged in -> go signin
      if (session == null && !loggingIn) return '/signin';

      // logged in but on signin -> go home
      if (session != null && loggingIn) return '/home';

      return null;
    },

    routes: [
      // SPLASH
      GoRoute(
        path: '/splash',
        builder: (_, __) => themed(const SplashScreen()),
      ),

      // AUTH
      GoRoute(
        path: '/signin',
        builder: (_, __) => themed(const SignInScreen()),
      ),
      GoRoute(
        path: '/reset',
        builder: (_, __) => themed(const ResetPasswordScreen()),
      ),

      // HOME
      GoRoute(path: '/home', builder: (_, __) => themed(const HomeScreen())),

      // CALENDAR
      GoRoute(
        path: '/calendar',
        builder: (_, __) => themed(const CalendarScreen()),
      ),

      // JOURNAL
      GoRoute(
        path: '/journal/new',
        builder: (_, __) => themed(const NewJournalScreen()),
      ),

      // DAY PAGE
      //GoRoute(
      // path: '/day/:dayId',
      //builder: (context, state) {
      //final dayId = state.pathParameters['dayId']!;
      //return themed(DailyPageScreen(dayId: dayId));
      //},
      //),

      // CHAT (attached to a day)
      GoRoute(
        path: '/chat/:dayId/:chatId',
        builder: (context, state) {
          final dayId = state.pathParameters['dayId']!;
          final chatId = int.parse(state.pathParameters['chatId']!);
          return themed(ChatScreen(dayId: dayId, chatId: chatId));
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
        builder: (_, __) => themed(const TemplatesScreen()),
      ),

      GoRoute(
        path: '/pomodoro',
        builder: (context, state) => themed(const PomodoroScreen()),
      ),

      // TEMPLATE DETAIL
      GoRoute(
        path: '/templates/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return themed(TemplateScreen(templateId: id));
        },
      ),

      // TEMPLATE LOGS (for a specific day)
      GoRoute(
        path: '/templates/by-key/:templateKey/logs/:dayId',
        builder: (context, state) {
          final templateKey = state.pathParameters['templateKey']!;
          final dayId = state.pathParameters['dayId']!;
          return themed(
            TemplateLogsLoaderScreen(templateKey: templateKey, dayId: dayId),
          );
        },
      ),

      // TEMPLATE LOGS (no dayId yet -> default today)
      GoRoute(
        path: '/templates/by-key/:templateKey/logs',
        builder: (context, state) {
          final templateKey = state.pathParameters['templateKey']!;
          final now = DateTime.now();
          final y = now.year.toString().padLeft(4, '0');
          final m = now.month.toString().padLeft(2, '0');
          final d = now.day.toString().padLeft(2, '0');
          final dayId = '$y-$m-$d';

          return themed(
            TemplateLogsLoaderScreen(templateKey: templateKey, dayId: dayId),
          );
        },
      ),

      GoRoute(
        path: '/insights',
        builder: (context, state) => themed(const InsightsScreen()),
      ),

      GoRoute(
        path: '/habits',
        builder: (context, state) => themed(const HabitsScreen()),
      ),

      GoRoute(
        path: '/habits/manage',
        builder: (context, state) => themed(const ManageHabitsScreen()),
      ),

      GoRoute(
        path: '/templates/create',
        builder: (context, state) => themed(const CreateLogTemplateScreen()),
      ),

      GoRoute(
        path: '/templates/log',
        builder: (context, state) {
          final templateId = state.uri.queryParameters['templateId']!;
          final templateKey = state.uri.queryParameters['templateKey']!;
          final dayId = state.uri.queryParameters['dayId']!;
          return themed(LogTableScreen(
            templateId: templateId,
            templateKey: templateKey,
            dayId: dayId,
          ));
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
