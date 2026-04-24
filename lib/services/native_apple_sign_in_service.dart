import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NativeAppleSignInResult {
  const NativeAppleSignInResult({
    required this.response,
    required this.email,
    required this.fullName,
  });

  final AuthResponse response;
  final String? email;
  final String? fullName;
}

class NativeAppleSignInService {
  NativeAppleSignInService._();

  static final NativeAppleSignInService instance = NativeAppleSignInService._();

  Future<NativeAppleSignInResult> signIn() async {
    if (!(Platform.isIOS || Platform.isMacOS)) {
      throw const AuthException(
        'Apple sign-in is only available on iOS and macOS in this app.',
      );
    }

    final auth = Supabase.instance.client.auth;
    final rawNonce = auth.generateRawNonce();
    final hashedNonce = await _sha256(rawNonce);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Could not find ID Token from Apple credential.',
        );
      }

      final response = await auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      return NativeAppleSignInResult(
        response: response,
        email: credential.email,
        fullName: _combineName(credential.givenName, credential.familyName),
      );
    } on MissingPluginException {
      throw const AuthException(
        'Apple sign-in is not available in the current app build yet. Fully stop the app and rebuild iOS after refreshing pods.',
      );
    }
  }

  Future<String> _sha256(String value) async {
    final hash = await Sha256().hash(utf8.encode(value));
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String? _combineName(String? givenName, String? familyName) {
    final combined = <String>[
      if (givenName != null && givenName.trim().isNotEmpty) givenName.trim(),
      if (familyName != null && familyName.trim().isNotEmpty) familyName.trim(),
    ].join(' ');
    return combined.isEmpty ? null : combined;
  }
}
