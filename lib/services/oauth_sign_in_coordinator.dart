import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum OAuthLaunchStatus { started, inProgress, throttled, failed }

class OAuthLaunchResult {
  const OAuthLaunchResult(this.status, {this.message});

  final OAuthLaunchStatus status;
  final String? message;

  bool get started => status == OAuthLaunchStatus.started;
}

class OAuthSignInCoordinator {
  OAuthSignInCoordinator._();

  static final OAuthSignInCoordinator instance = OAuthSignInCoordinator._();
  static const _tapDebounce = Duration(milliseconds: 800);
  static const _redirectTo = 'brainbubble://auth/callback';

  final ValueNotifier<bool> _isSigningIn = ValueNotifier<bool>(false);
  DateTime? _lastAttemptAt;
  OAuthProvider? _activeProvider;

  ValueListenable<bool> get isSigningInListenable => _isSigningIn;
  bool get isSigningIn => _isSigningIn.value;
  OAuthProvider? get activeProvider => _activeProvider;

  Future<OAuthLaunchResult> start(OAuthProvider provider) async {
    final now = DateTime.now();
    final last = _lastAttemptAt;
    if (_isSigningIn.value) {
      return const OAuthLaunchResult(
        OAuthLaunchStatus.inProgress,
        message: 'Sign in is already in progress. Finish it in the browser.',
      );
    }
    if (last != null && now.difference(last) < _tapDebounce) {
      return const OAuthLaunchResult(
        OAuthLaunchStatus.throttled,
        message: 'Please wait a moment and try again.',
      );
    }

    _lastAttemptAt = now;
    _activeProvider = provider;
    _isSigningIn.value = true;

    try {
      debugPrint(
        'OAuthCoordinator start provider=$provider redirect=$_redirectTo',
      );
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: _redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return const OAuthLaunchResult(OAuthLaunchStatus.started);
    } on AuthException catch (e) {
      markFailed(reason: 'start_auth_exception');
      return OAuthLaunchResult(OAuthLaunchStatus.failed, message: e.message);
    } catch (e) {
      markFailed(reason: 'start_unexpected_exception');
      return OAuthLaunchResult(
        OAuthLaunchStatus.failed,
        message: 'OAuth failed: $e',
      );
    }
  }

  void markCompleted({String? reason}) {
    if (_isSigningIn.value) {
      debugPrint('OAuthCoordinator completed reason=${reason ?? 'unknown'}');
    }
    _activeProvider = null;
    _isSigningIn.value = false;
  }

  void markFailed({String? reason}) {
    if (_isSigningIn.value) {
      debugPrint('OAuthCoordinator failed reason=${reason ?? 'unknown'}');
    }
    _activeProvider = null;
    _isSigningIn.value = false;
  }
}
