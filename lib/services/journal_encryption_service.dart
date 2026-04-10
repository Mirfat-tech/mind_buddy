import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum JournalEncryptionFailureReason {
  missingKey,
  inaccessibleKey,
  unsupportedVersion,
  invalidPayload,
  decryptFailed,
}

class JournalEncryptionException implements Exception {
  const JournalEncryptionException(this.reason, this.message);

  final JournalEncryptionFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

class EncryptedJournalPayload {
  const EncryptedJournalPayload({
    required this.encryptedContent,
    required this.iv,
    required this.encryptionVersion,
    required this.keyVersion,
  });

  final String encryptedContent;
  final String iv;
  final int encryptionVersion;
  final int keyVersion;

  Map<String, dynamic> toColumns() {
    return <String, dynamic>{
      'text': null,
      'encrypted_content': encryptedContent,
      'iv': iv,
      'is_encrypted': true,
      'encryption_version': encryptionVersion,
      'key_version': keyVersion,
    };
  }
}

class JournalEncryptionService {
  JournalEncryptionService._();

  static final JournalEncryptionService instance = JournalEncryptionService._();

  // Phase 1 intentionally keeps the private journal key device-bound. We do
  // not upload or escrow the raw key anywhere server-side yet.
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _keyStoragePrefix = 'journal_key_v1';
  static const int currentEncryptionVersion = 1;
  static const int currentKeyVersion = 1;
  static final AesGcm _cipher = AesGcm.with256bits();

  final Map<String, SecretKey> _secretKeyCache = <String, SecretKey>{};
  final LinkedHashMap<String, String> _decryptedBodyCache =
      LinkedHashMap<String, String>();

  String? _lastScopedUserId;

  Future<EncryptedJournalPayload> encryptBodyForCurrentUser(
    String plaintext,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.missingKey,
        'You must be signed in to encrypt private journals.',
      );
    }

    final secretKey = await _getOrCreateUserKey(user.id);
    final nonce = _generateNonce();
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptedJournalPayload(
      encryptedContent: base64Encode(
        Uint8List.fromList(<int>[...box.cipherText, ...box.mac.bytes]),
      ),
      iv: base64Encode(nonce),
      encryptionVersion: currentEncryptionVersion,
      keyVersion: currentKeyVersion,
    );
  }

  Future<String> decryptBodyForCurrentUser({
    required String encryptedContent,
    required String iv,
    required int? encryptionVersion,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.missingKey,
        'You must be signed in to open private journals.',
      );
    }
    if (encryptionVersion != currentEncryptionVersion) {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.unsupportedVersion,
        'This journal uses an unsupported encryption version.',
      );
    }

    final secretKey = await _readExistingUserKey(user.id);
    if (secretKey == null) {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.missingKey,
        'This device cannot access your private journal key. Private entries are device-bound in phase 1 and may be unreadable after reinstall or device change.',
      );
    }

    try {
      final combined = base64Decode(encryptedContent);
      if (combined.length < 16) {
        throw const JournalEncryptionException(
          JournalEncryptionFailureReason.invalidPayload,
          'Encrypted journal payload is incomplete.',
        );
      }
      final nonce = base64Decode(iv);
      final cipherText = combined.sublist(0, combined.length - 16);
      final mac = Mac(combined.sublist(combined.length - 16));
      final clearBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
      );
      return utf8.decode(clearBytes);
    } on JournalEncryptionException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.decryptFailed,
        'Private journal decryption failed. The key on this device does not match the stored entry.',
      );
    } on FormatException {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.invalidPayload,
        'Encrypted journal metadata is invalid.',
      );
    } catch (_) {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.decryptFailed,
        'Private journal decryption failed.',
      );
    }
  }

  String? getCachedDecryptedBody(String journalId) {
    _touchCache(journalId);
    return _decryptedBodyCache[journalId];
  }

  void cacheDecryptedBody(String journalId, String plaintext) {
    _decryptedBodyCache[journalId] = plaintext;
    _touchCache(journalId);
    while (_decryptedBodyCache.length > 64) {
      _decryptedBodyCache.remove(_decryptedBodyCache.keys.first);
    }
  }

  Future<void> handleAuthScopeChanged() async {
    final nextUserId = Supabase.instance.client.auth.currentUser?.id;
    if (_lastScopedUserId == nextUserId) return;
    _lastScopedUserId = nextUserId;
    _decryptedBodyCache.clear();
    _secretKeyCache.clear();
  }

  Future<void> clearSensitiveCache() async {
    _decryptedBodyCache.clear();
  }

  Future<void> deleteCurrentUserKey() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _secretKeyCache.remove(userId);
    try {
      await _secureStorage.delete(key: _storageKeyForUser(userId));
    } catch (_) {}
  }

  Future<SecretKey> _getOrCreateUserKey(String userId) async {
    final cached = _secretKeyCache[userId];
    if (cached != null) return cached;

    final existing = await _readExistingUserKey(userId);
    if (existing != null) return existing;

    final random = Random.secure();
    final keyBytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final encoded = base64Encode(keyBytes);
    try {
      await _secureStorage.write(
        key: _storageKeyForUser(userId),
        value: encoded,
      );
    } on PlatformException catch (error) {
      throw JournalEncryptionException(
        JournalEncryptionFailureReason.inaccessibleKey,
        'Unable to store the private journal key securely on this device: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw JournalEncryptionException(
        JournalEncryptionFailureReason.inaccessibleKey,
        'Unable to store the private journal key securely on this device: $error',
      );
    }

    final secretKey = SecretKey(keyBytes);
    _secretKeyCache[userId] = secretKey;
    return secretKey;
  }

  Future<SecretKey?> _readExistingUserKey(String userId) async {
    final cached = _secretKeyCache[userId];
    if (cached != null) return cached;

    String? encoded;
    try {
      encoded = await _secureStorage.read(key: _storageKeyForUser(userId));
    } on PlatformException catch (error) {
      throw JournalEncryptionException(
        JournalEncryptionFailureReason.inaccessibleKey,
        'Unable to access the private journal key on this device: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw JournalEncryptionException(
        JournalEncryptionFailureReason.inaccessibleKey,
        'Unable to access the private journal key on this device: $error',
      );
    }

    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final secretKey = SecretKey(base64Decode(encoded));
      _secretKeyCache[userId] = secretKey;
      return secretKey;
    } on FormatException {
      throw const JournalEncryptionException(
        JournalEncryptionFailureReason.invalidPayload,
        'The stored private journal key is corrupted on this device.',
      );
    }
  }

  List<int> _generateNonce() {
    final random = Random.secure();
    return List<int>.generate(12, (_) => random.nextInt(256));
  }

  String _storageKeyForUser(String userId) =>
      '$_keyStoragePrefix::$currentKeyVersion::$userId';

  void _touchCache(String journalId) {
    final cached = _decryptedBodyCache.remove(journalId);
    if (cached != null) {
      _decryptedBodyCache[journalId] = cached;
    }
  }
}
