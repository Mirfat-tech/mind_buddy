// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mind_buddy/app.dart';
import 'package:mind_buddy/router.dart';

void main() {
  // Ensure the test binding is ready (plugins, MethodChannels, etc.)
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 👈 Mock shared_preferences so Supabase can store session locally in tests
    SharedPreferences.setMockInitialValues({});

    // 👈 Initialize Supabase with dummy values (no real network calls made)
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy-anon-key',
    );
  });

  testWidgets('app builds', (WidgetTester tester) async {
    final router = createRouter();
    await tester.pumpWidget(ProviderScope(child: MindBuddyApp(router: router)));
    await tester.pump(); // settle first frame

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
