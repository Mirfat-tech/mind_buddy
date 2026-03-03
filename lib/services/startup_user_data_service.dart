import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StartupUserDataBundle {
  const StartupUserDataBundle({
    this.settingsRow,
    this.profileRow,
    this.userProfileRow,
    this.failedTables = const <String>{},
  });

  final Map<String, dynamic>? settingsRow;
  final Map<String, dynamic>? profileRow;
  final Map<String, dynamic>? userProfileRow;
  final Set<String> failedTables;
}

class StartupUserDataService {
  StartupUserDataService._();

  static final StartupUserDataService instance = StartupUserDataService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, Future<StartupUserDataBundle>> _inFlight = {};
  final Map<String, _CachedBundle> _cache = {};
  int _requestCount = 0;

  void invalidateUser(String userId) {
    _cache.remove(userId);
    _inFlight.remove(userId);
  }

  void invalidateCurrentUser() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    invalidateUser(userId);
  }

  Future<StartupUserDataBundle> fetchCombinedForCurrentUser() async {
    final user = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;
    debugPrint(
      '[StartupUserData] prefetch currentUser=${user?.id ?? 'none'} session=${session != null}',
    );
    if (user == null || session == null) {
      return const StartupUserDataBundle();
    }
    return fetchCombinedForUser(user.id);
  }

  Future<StartupUserDataBundle> fetchCombinedForUser(String userId) {
    final cached = _cache[userId];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(seconds: 15)) {
      return Future<StartupUserDataBundle>.value(cached.bundle);
    }

    final existing = _inFlight[userId];
    if (existing != null) return existing;

    final future = _fetchCombinedForUserInternal(userId);
    _inFlight[userId] = future;
    future
        .then((bundle) {
          _cache[userId] = _CachedBundle(
            bundle: bundle,
            createdAt: DateTime.now(),
          );
        })
        .whenComplete(() => _inFlight.remove(userId));
    return future;
  }

  Future<StartupUserDataBundle> _fetchCombinedForUserInternal(
    String userId,
  ) async {
    final session = _supabase.auth.currentSession;
    debugPrint(
      '[StartupUserData] combined start user=$userId session=${session != null}',
    );

    await _ensureProfileBootstrap(userId);

    final settingsRead = await _safeRead(
      label: 'user_settings',
      userId: userId,
      call: () => _supabase
          .from('user_settings')
          .select('settings, updated_at')
          .eq('user_id', userId)
          .maybeSingle(),
    );

    final profileRead = await _safeRead(
      label: 'profiles',
      userId: userId,
      call: () => _supabase
          .from('profiles')
          .select('subscription_tier, username, is_active')
          .eq('id', userId)
          .maybeSingle(),
    );

    final userProfileRead = await _safeRead(
      label: 'user_profile',
      userId: userId,
      call: () => _supabase
          .from('user_profile')
          .select('user_id, display_name')
          .eq('user_id', userId)
          .maybeSingle(),
    );

    final failed = <String>{};
    if (settingsRead.failed) failed.add('user_settings');
    if (profileRead.failed) failed.add('profiles');
    if (userProfileRead.failed) failed.add('user_profile');

    return StartupUserDataBundle(
      settingsRow: settingsRead.data,
      profileRow: profileRead.data,
      userProfileRow: userProfileRead.data,
      failedTables: failed,
    );
  }

  Future<void> _ensureProfileBootstrap(String userId) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.id != userId) return;
    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (existing != null) {
        debugPrint('[StartupUserData] profile already exists for user=$userId');
        return;
      }

      // Prefer RPC bootstrap (SECURITY DEFINER) when available.
      try {
        await _supabase.rpc('ensure_my_profile');
      } catch (e) {
        // Backward compatibility for projects that have not deployed the RPC.
        debugPrint(
          '[StartupUserData] ensure_my_profile rpc unavailable/failed user=$userId error=$e',
        );
      }

      try {
        await _supabase.from('profiles').insert({
          'id': userId,
          'email': user.email,
          'subscription_tier': 'pending',
          'subscription_status': 'inactive',
        });
      } on PostgrestException catch (_) {
        // Fallback to idempotent upsert for environments where insert paths vary.
        await _supabase.from('profiles').upsert({
          'id': userId,
          'email': user.email,
          'subscription_tier': 'pending',
          'subscription_status': 'inactive',
        }, onConflict: 'id');
      }
      debugPrint('[StartupUserData] ensured profiles row for user=$userId');
    } catch (e) {
      // Never block startup reads on bootstrap upsert failures.
      debugPrint(
        '[StartupUserData] ensure profiles row failed user=$userId error=$e',
      );
    }
  }

  Future<_ReadResult> _safeRead({
    required String label,
    required String userId,
    required Future<Map<String, dynamic>?> Function() call,
  }) async {
    const delays = <Duration>[
      Duration(milliseconds: 300),
      Duration(milliseconds: 800),
    ];
    Object? lastError;

    for (var attempt = 0; attempt < delays.length + 1; attempt++) {
      _requestCount++;
      final session = _supabase.auth.currentSession;
      debugPrint(
        '[StartupUserData] request=$_requestCount label=$label user=$userId session=${session != null} attempt=${attempt + 1}',
      );
      try {
        final result = await call().timeout(const Duration(seconds: 12));
        return _ReadResult(data: result, failed: false);
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on PostgrestException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }

      if (attempt < delays.length) {
        await Future<void>.delayed(delays[attempt]);
      }
    }

    debugPrint(
      '[StartupUserData] failed label=$label user=$userId error=$lastError',
    );
    return const _ReadResult(data: null, failed: true);
  }
}

class _ReadResult {
  const _ReadResult({required this.data, required this.failed});

  final Map<String, dynamic>? data;
  final bool failed;
}

class _CachedBundle {
  const _CachedBundle({required this.bundle, required this.createdAt});

  final StartupUserDataBundle bundle;
  final DateTime createdAt;
}
