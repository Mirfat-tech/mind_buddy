import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'router.dart';
import 'features/auth/device_session_service.dart';
import 'features/settings/settings_provider.dart';
import 'config/app_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  // ✅ MUST happen before any Supabase.instance usage (router + auth listener)
  await Supabase.initialize(
    url: 'https://jntfxnjrtgliyzhefayh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudGZ4bmpydGdsaXl6aGVmYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MjIzMDgsImV4cCI6MjA4MDQ5ODMwOH0.TgMtKwjswRTbMESjpep2FWq37_OG20Z8VCb6aR03Bo8',
  );
  //eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudGZ4bmpydGdsaXl6aGVmYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MjIzMDgsImV4cCI6MjA4MDQ5ODMwOH0.TgMtKwjswRTbMESjpep2FWq37_OG20Z8VCb6aR03Bo8
  // ✅ create router AFTER Supabase is initialized
  final appRouter = createRouter();
  //await dotenv.load();
  runApp(ProviderScope(child: _Bootstrap(router: appRouter)));
}

/// Bootstraps app-level init that needs Riverpod (theme load) + auth listener.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  StreamSubscription<AuthState>? _authSub;
  bool _envWarned = false;

  @override
  void initState() {
    super.initState();

    // Load settings (includes theme)
    Future.microtask(() => ref.read(settingsControllerProvider).init());

    if (AppEnv.openAiApiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _envWarned) return;
        _envWarned = true;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Missing OpenAI key'),
            content: const Text(
              'OPENAI_API_KEY is not set in .env. If you use the Supabase Edge Function with secrets, this is OK.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }

    // Password recovery deep link handling
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        widget.router.go('/reset');
      }
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        DeviceSessionService.recordSession();
      }
      ref.read(settingsControllerProvider).handleAuthChange();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MindBuddyApp(router: widget.router);
  }
}
