import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/guides/guide_manager.dart';

import 'package:mind_buddy/features/brain_fog/brain_fog_screen.dart';
import 'package:mind_buddy/features/insights/insights_screen.dart';
import 'package:mind_buddy/features/onboarding/onboarding_expression_screen.dart';

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

const _devices = <_DeviceConfig>[
  _DeviceConfig('se3', Size(375, 667)),
  _DeviceConfig('iphone61', Size(393, 852)),
  _DeviceConfig('ipad_split_1_3', Size(344, 1376)),
];

Future<void> _pump(
  WidgetTester tester,
  _DeviceConfig device,
  Widget child, {
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = device.size;

  await tester.pumpWidget(
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          size: device.size,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          textScaler: const TextScaler.linear(1.0),
          viewInsets: viewInsets,
        ),
        child: MaterialApp(home: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'keepInstructionsVisible': false,
      'pageGuideShown_brainFog': true,
      'pageGuideShown_insights': true,
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
      // Already initialized.
    }
  });

  for (final device in _devices) {
    testWidgets('baseline_onboarding_expression_${device.name}', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, device, const OnboardingExpressionScreen());
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/responsive/onboarding_expression_${device.name}.png',
        ),
      );
    });

    testWidgets('baseline_brainfog_guide_${device.name}', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, device, const BrainFogScreen());
      await tester.pump(const Duration(milliseconds: 250));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/responsive/brainfog_guide_${device.name}.png',
        ),
      );
      GuideManager.dismissActiveGuideForPage('brainFog');
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('baseline_insights_${device.name}', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, device, const InsightsScreen());
      await tester.pump(const Duration(milliseconds: 250));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/responsive/insights_${device.name}.png'),
      );
      GuideManager.dismissActiveGuideForPage('insights');
      await tester.pump(const Duration(milliseconds: 400));
    });
  }
}
