import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_theme_controller.dart';
import 'app.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appRouter = createRouter();

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

  @override
  void initState() {
    super.initState();

    // Load theme
    Future.microtask(() => ref.read(appThemeControllerProvider).load());

    // Password recovery deep link handling
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        widget.router.go('/reset');
      }
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
