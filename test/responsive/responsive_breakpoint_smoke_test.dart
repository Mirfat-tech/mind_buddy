import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/features/home/home_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_auth_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_expression_screen.dart';
import 'package:mind_buddy/features/auth/sign_in_screen.dart';
import 'package:mind_buddy/features/brain_fog/brain_fog_screen.dart';
import 'package:mind_buddy/features/gratitude/gratitude_bubble_screen.dart';
import 'package:mind_buddy/features/templates/templates_screen.dart';
import 'package:mind_buddy/features/templates/log_table_screen.dart';
import 'package:mind_buddy/features/chat/chat_screen.dart';
import 'package:mind_buddy/features/insights/insights_screen.dart';
import 'package:mind_buddy/features/settings/settings_screen.dart';
import 'package:mind_buddy/features/journal/journals_list_screen.dart';
import 'package:mind_buddy/features/journal/new_journal_screen.dart';
import 'package:mind_buddy/features/pomodoro/pomodoro_screen.dart';

class _DeviceConfig {
  const _DeviceConfig(this.name, this.size);
  final String name;
  final Size size;
}

class _MemoryLocalStorage extends LocalStorage {
  _MemoryLocalStorage();

  String? _session;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => _session != null;

  @override
  Future<String?> accessToken() async => _session;

  @override
  Future<void> persistSession(String persistSessionString) async {
    _session = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    _session = null;
  }
}

const _keyboardRelevantScreens = <String>{'Chat', 'SignIn', 'NewJournal'};

MediaQueryData _mqFor(
  _DeviceConfig device, {
  required double textScale,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MediaQueryData(
    size: device.size,
    textScaler: TextScaler.linear(textScale),
    padding: const EdgeInsets.only(top: 24, bottom: 16),
    viewInsets: viewInsets,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'keepInstructionsVisible': false,
      'pageGuideShown_home': true,
      'pageGuideShown_calendar': true,
      'pageGuideShown_brainFog': true,
      'pageGuideShown_habits': true,
      'pageGuideShown_vent': true,
      'pageGuideShown_journalMain': true,
      'pageGuideShown_journalEntry': true,
      'pageGuideShown_templates': true,
      'pageGuideShown_logTable': true,
      'pageGuideShown_insights': true,
      'pageGuideShown_chat': true,
    });
    try {
      await Supabase.initialize(
        url: 'https://jntfxnjrtgliyzhefayh.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudGZ4bmpydGdsaXl6aGVmYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MjIzMDgsImV4cCI6MjA4MDQ5ODMwOH0.TgMtKwjswRTbMESjpep2FWq37_OG20Z8VCb6aR03Bo8',
        authOptions: FlutterAuthClientOptions(
          localStorage: _MemoryLocalStorage(),
        ),
      );
    } catch (_) {
      // Already initialized in this test process.
    }
  });

  final devices = <_DeviceConfig>[
    const _DeviceConfig('iPhone SE 3', Size(375, 667)),
    const _DeviceConfig('iPhone 6.1', Size(393, 852)),
    const _DeviceConfig('iPhone 15 Pro Max', Size(430, 932)),
    const _DeviceConfig('iPad 10.9', Size(820, 1180)),
    const _DeviceConfig('iPad Pro 13', Size(1032, 1376)),
    const _DeviceConfig('iPad Split 50/50', Size(516, 1376)),
    const _DeviceConfig('iPad Split 1/3', Size(344, 1376)),
    const _DeviceConfig('Pixel 8', Size(412, 915)),
    const _DeviceConfig('Galaxy S24', Size(412, 915)),
    const _DeviceConfig('Galaxy S24 Ultra', Size(480, 1032)),
    const _DeviceConfig('Galaxy Tab S6 Lite', Size(800, 1280)),
    const _DeviceConfig('Galaxy Tab S9', Size(1024, 1366)),
    const _DeviceConfig('iPad Pro 13 Landscape', Size(1376, 1032)),
    const _DeviceConfig('Tab Landscape', Size(1366, 1024)),
  ];

  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'OnboardingAuth': () => const OnboardingAuthScreen(),
    'OnboardingExpression': () => const OnboardingExpressionScreen(),
    'SignIn': () => const SignInScreen(),
    'BrainFog': () => const BrainFogScreen(),
    'GratitudeBubble': () => const GratitudeBubbleScreen(),
    'Templates': () => const TemplatesScreen(),
    'LogTable': () => const LogTableScreen(
      templateId: 'test-template',
      templateKey: 'mood',
      dayId: '2026-02-18',
    ),
    'JournalsList': () => JournalsListScreen(),
    'NewJournal': () => const NewJournalScreen(),
    'Chat': () => const ChatScreen(dayId: '2026-02-18', chatId: 1),
    'Pomodoro': () => const PomodoroScreen(),
    'Insights': () => const InsightsScreen(),
    'Settings': () => const SettingsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} responsive smoke', (tester) async {
      final layoutErrors = <String>[];

      for (final d in devices) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = d.size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final scale in <double>[1.0, 1.3]) {
          await tester.pumpWidget(
            ProviderScope(
              child: MediaQuery(
                data: _mqFor(d, textScale: scale),
                child: MaterialApp(home: entry.value()),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump(const Duration(milliseconds: 350));

          Object? exception;
          while ((exception = tester.takeException()) != null) {
            final message = exception.toString();
            if (message.contains('RenderFlex overflowed') ||
                message.contains('BOTTOM OVERFLOWED') ||
                message.contains('A RenderFlex overflowed')) {
              layoutErrors.add('${d.name} x$scale: $message');
            }
          }

          if (_keyboardRelevantScreens.contains(entry.key)) {
            final simulatedKeyboard = EdgeInsets.only(
              bottom: (d.size.height * 0.36).clamp(220.0, 360.0),
            );

            await tester.pumpWidget(
              ProviderScope(
                child: MediaQuery(
                  data: _mqFor(
                    d,
                    textScale: scale,
                    viewInsets: simulatedKeyboard,
                  ),
                  child: MaterialApp(home: entry.value()),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));

            while ((exception = tester.takeException()) != null) {
              final message = exception.toString();
              if (message.contains('RenderFlex overflowed') ||
                  message.contains('BOTTOM OVERFLOWED') ||
                  message.contains('A RenderFlex overflowed')) {
                layoutErrors.add('${d.name} x$scale keyboard: $message');
              }
            }
          }
        }
      }

      expect(
        layoutErrors,
        isEmpty,
        reason:
            'Found layout overflow errors in ${entry.key}: '
            '${layoutErrors.join('\n')}',
      );
    });
  }
}
