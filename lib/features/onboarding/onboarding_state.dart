import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';

class OnboardingAnswers {
  const OnboardingAnswers({
    this.slipFirst = const <String>{},
    this.expressionStyle = const <String>{},
    this.lookingBack = const <String>{},
    this.skippedSignUp = false,
    this.skippedPersonalization = false,
  });

  final Set<String> slipFirst;
  final Set<String> expressionStyle;
  final Set<String> lookingBack;
  final bool skippedSignUp;
  final bool skippedPersonalization;

  OnboardingAnswers copyWith({
    Set<String>? slipFirst,
    Set<String>? expressionStyle,
    Set<String>? lookingBack,
    bool? skippedSignUp,
    bool? skippedPersonalization,
  }) {
    return OnboardingAnswers(
      slipFirst: slipFirst ?? this.slipFirst,
      expressionStyle: expressionStyle ?? this.expressionStyle,
      lookingBack: lookingBack ?? this.lookingBack,
      skippedSignUp: skippedSignUp ?? this.skippedSignUp,
      skippedPersonalization:
          skippedPersonalization ?? this.skippedPersonalization,
    );
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingAnswers>((ref) {
      return OnboardingController();
    });

class OnboardingController extends StateNotifier<OnboardingAnswers> {
  OnboardingController() : super(const OnboardingAnswers());

  static const _installSeenLocallyKey = 'onboarding_seen_locally';
  static const _completedKey = 'onboarding_completed';
  static const _authSkippedKey = 'onboarding_auth_skipped';
  static const _authStageCompletedKey = 'onboarding_auth_stage_completed';
  static const _featuresSeenKey = 'features_seen';
  static const _planCompletedKey = 'plan_completed';
  static const _setupCompletedKey = 'setup_completed';

  static String? _currentUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  static String _scopedKey(String base, String? userId) {
    if (userId == null || userId.isEmpty) return base;
    return '${base}_$userId';
  }

  void setSlipFirst(Set<String> values) {
    state = state.copyWith(slipFirst: Set<String>.from(values));
  }

  void setExpressionStyle(Set<String> values) {
    state = state.copyWith(expressionStyle: Set<String>.from(values));
  }

  void setLookingBack(Set<String> values) {
    state = state.copyWith(lookingBack: Set<String>.from(values));
  }

  void clearSlipFirst() {
    state = state.copyWith(slipFirst: <String>{});
  }

  void clearExpressionStyle() {
    state = state.copyWith(expressionStyle: <String>{});
  }

  void clearLookingBack() {
    state = state.copyWith(lookingBack: <String>{});
  }

  void setSkippedSignUp(bool value) {
    state = state.copyWith(skippedSignUp: value);
  }

  void setSkippedPersonalization(bool value) {
    state = state.copyWith(skippedPersonalization: value);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _currentUserId();
    if (userId != null) {
      return prefs.getBool(_scopedKey(_completedKey, userId)) ?? false;
    }
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _currentUserId();
    await prefs.setBool(_scopedKey(_completedKey, userId), true);
  }

  static Future<bool> hasSeenLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_installSeenLocallyKey) ?? false;
    debugPrint('LOCAL_ONBOARDING_FLAG_LOAD seen=$seen scope=install');
    if (seen) return true;

    final hasExistingLocalAppData = await _hasExistingLocalAppData(prefs);
    debugPrint(
      'LOCAL_ONBOARDING_BACKFILL_CHECK seen=false hasExistingLocalAppData=$hasExistingLocalAppData',
    );
    if (!hasExistingLocalAppData) {
      return false;
    }

    await prefs.setBool(_installSeenLocallyKey, true);
    debugPrint(
      'LOCAL_ONBOARDING_BACKFILL_SAVE seen=true reason=existing_install_data',
    );
    return true;
  }

  static Future<void> setSeenLocally(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_installSeenLocallyKey, value);
    debugPrint('LOCAL_ONBOARDING_FLAG_SAVE seen=$value');
  }

  static Future<bool> _hasExistingLocalAppData(SharedPreferences prefs) async {
    final prefKeys = prefs.getKeys();
    final hasPreferenceEvidence = prefKeys.any(
      (key) =>
          key == _completedKey ||
          key == _authSkippedKey ||
          key == _authStageCompletedKey ||
          key == _featuresSeenKey ||
          key == _planCompletedKey ||
          key == _setupCompletedKey ||
          key == 'mb_settings_v1' ||
          key.startsWith('completion_gate_state_') ||
          key.startsWith('${_completedKey}_') ||
          key.startsWith('${_featuresSeenKey}_') ||
          key.startsWith('${_planCompletedKey}_') ||
          key.startsWith('${_setupCompletedKey}_'),
    );
    if (hasPreferenceEvidence) {
      return true;
    }

    try {
      final db = AppDatabase.shared();
      final result = await db.customSelect('''
        select
          exists(select 1 from settings_records limit 1) as has_settings,
          exists(select 1 from sync_metadata_entries limit 1) as has_sync_metadata,
          exists(select 1 from template_definitions limit 1) as has_templates,
          exists(select 1 from template_log_entries limit 1) as has_template_logs,
          exists(select 1 from journal_entries limit 1) as has_journals,
          exists(select 1 from journal_folders limit 1) as has_journal_folders
        ''').getSingle();
      bool readFlag(String key) =>
          (result.data[key] == true) ||
          result.data[key]?.toString() == '1' ||
          result.data[key]?.toString().toLowerCase() == 'true';

      return readFlag('has_settings') ||
          readFlag('has_sync_metadata') ||
          readFlag('has_templates') ||
          readFlag('has_template_logs') ||
          readFlag('has_journals') ||
          readFlag('has_journal_folders');
    } catch (e) {
      debugPrint(
        '[OnboardingInstallFlag] existing local data check failed error=$e',
      );
      return false;
    }
  }

  static Future<bool> isAuthSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authSkippedKey) ?? false;
  }

  static Future<void> setAuthSkipped(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authSkippedKey, value);
  }

  static Future<bool> isAuthStageCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final explicit = prefs.getBool(_authStageCompletedKey);
    if (explicit != null) return explicit;
    return (prefs.getBool(_authSkippedKey) ?? false) ||
        (prefs.getBool(_completedKey) ?? false);
  }

  static Future<void> setAuthStageCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authStageCompletedKey, value);
  }

  static Future<bool> isFeaturesSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final explicit = prefs.getBool(
      _scopedKey(_featuresSeenKey, _currentUserId()),
    );
    if (explicit != null) return explicit;
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> markFeaturesSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_featuresSeenKey, _currentUserId()), true);
  }

  static Future<bool> isPlanCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _currentUserId();
    if (userId != null) {
      return prefs.getBool(_scopedKey(_planCompletedKey, userId)) ?? false;
    }
    return prefs.getBool(_planCompletedKey) ?? false;
  }

  static Future<void> setPlanCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_planCompletedKey, _currentUserId()), value);
  }

  static Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _currentUserId();
    if (userId != null) {
      return prefs.getBool(_scopedKey(_setupCompletedKey, userId)) ?? false;
    }
    return prefs.getBool(_setupCompletedKey) ?? false;
  }

  static Future<void> setSetupCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _scopedKey(_setupCompletedKey, _currentUserId()),
      value,
    );
  }
}

class CompletionGateState {
  const CompletionGateState({
    required this.onboardingCompleted,
    required this.usernameCompleted,
    required this.subscriptionCompleted,
    this.completedAt,
  });

  final bool onboardingCompleted;
  final bool usernameCompleted;
  final bool subscriptionCompleted;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'onboarding_completed': onboardingCompleted,
    'username_completed': usernameCompleted,
    'subscription_completed': subscriptionCompleted,
    'completed_at': completedAt?.toIso8601String(),
  };

  static CompletionGateState fromJson(Map<String, dynamic> json) {
    final completedAtRaw = json['completed_at']?.toString();
    return CompletionGateState(
      onboardingCompleted: json['onboarding_completed'] == true,
      usernameCompleted: json['username_completed'] == true,
      subscriptionCompleted: json['subscription_completed'] == true,
      completedAt: completedAtRaw == null
          ? null
          : DateTime.tryParse(completedAtRaw),
    );
  }
}

class CompletionGateRepository {
  CompletionGateRepository._();

  static String _cacheKey(String userId) => 'completion_gate_state_$userId';

  static CompletionGateState _fromProfile(Map<String, dynamic>? profileRow) {
    final username = (profileRow?['username'] ?? '').toString().trim();
    final tier = (profileRow?['subscription_tier'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final usernameCompleted =
        profileRow?['username_completed'] == true || username.isNotEmpty;
    final hasChosenPlan = tier.isNotEmpty && tier != 'pending';
    final subscriptionCompleted =
        profileRow?['subscription_completed'] == true ||
        hasChosenPlan ||
        usernameCompleted;
    final onboardingCompleted =
        profileRow?['onboarding_completed'] == true ||
        subscriptionCompleted ||
        usernameCompleted;
    final completedAtRaw = profileRow?['completed_at']?.toString();
    return CompletionGateState(
      onboardingCompleted: onboardingCompleted,
      usernameCompleted: usernameCompleted,
      subscriptionCompleted: subscriptionCompleted,
      completedAt: completedAtRaw == null
          ? null
          : DateTime.tryParse(completedAtRaw),
    );
  }

  static CompletionGateState _mergeCompletionState({
    CompletionGateState? remote,
    CompletionGateState? cached,
  }) {
    if (remote != null) {
      return CompletionGateState(
        onboardingCompleted: remote.onboardingCompleted,
        usernameCompleted: remote.usernameCompleted,
        subscriptionCompleted: remote.subscriptionCompleted,
        completedAt: remote.completedAt ?? cached?.completedAt,
      );
    }
    if (cached != null) {
      return cached;
    }
    return const CompletionGateState(
      onboardingCompleted: false,
      usernameCompleted: false,
      subscriptionCompleted: false,
    );
  }

  static Future<void> _backfillLegacyProfileFlagsIfNeeded(
    String userId,
    Map<String, dynamic>? profileRow,
  ) async {
    if (profileRow == null) return;
    final updates = <String, dynamic>{};
    final username = (profileRow['username'] ?? '').toString().trim();
    if (profileRow['username_completed'] != true && username.isNotEmpty) {
      updates['username_completed'] = true;
    }
    final tier = (profileRow['subscription_tier'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final usernameCompleted =
        profileRow['username_completed'] == true || username.isNotEmpty;
    final hasChosenPlan = tier.isNotEmpty && tier != 'pending';
    if (profileRow['subscription_completed'] != true &&
        (hasChosenPlan || usernameCompleted)) {
      updates['subscription_completed'] = true;
    }
    if (profileRow['onboarding_completed'] != true &&
        (profileRow['subscription_completed'] == true ||
            hasChosenPlan ||
            usernameCompleted)) {
      updates['onboarding_completed'] = true;
    }
    if (updates.isNotEmpty && profileRow['completed_at'] == null) {
      updates['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (updates.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        '[CompletionGate] legacy flag backfill userId=$userId updates=$updates',
      );
    }
    unawaited(_upsertFlagsForCurrentUser(updates));
  }

  static Future<void> _backfillMergedFlagsIfNeeded(
    CompletionGateState merged,
    CompletionGateState? remote,
  ) async {
    if (remote == null) return;
    final updates = <String, dynamic>{};
    if (merged.onboardingCompleted && !remote.onboardingCompleted) {
      updates['onboarding_completed'] = true;
    }
    if (merged.usernameCompleted && !remote.usernameCompleted) {
      updates['username_completed'] = true;
    }
    if (merged.subscriptionCompleted && !remote.subscriptionCompleted) {
      updates['subscription_completed'] = true;
    }
    if (updates.isEmpty) return;
    if (kDebugMode) {
      debugPrint('[CompletionGate] merged flag backfill updates=$updates');
    }
    unawaited(_upsertFlagsForCurrentUser(updates));
  }

  static Future<CompletionGateState?> loadCached(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return CompletionGateState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheState(
    String userId,
    CompletionGateState state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(userId), jsonEncode(state.toJson()));
  }

  static Future<CompletionGateState> fetchForCurrentUser({
    bool preferCache = true,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const CompletionGateState(
        onboardingCompleted: false,
        usernameCompleted: false,
        subscriptionCompleted: false,
      );
    }

    if (preferCache) {
      final cached = await loadCached(user.id);
      if (cached != null) {
        if (kDebugMode) {
          debugPrint(
            '[CompletionGate] source=cached userId=${user.id} onboarding_completed=${cached.onboardingCompleted} username_completed=${cached.usernameCompleted} subscription_completed=${cached.subscriptionCompleted}',
          );
        }
        return cached;
      }
    }

    try {
      final bundle = await StartupUserDataService.instance.fetchCombinedForUser(
        user.id,
      );
      final cached = await loadCached(user.id);
      if (bundle.failedTables.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[CompletionGate] partial sync failure userId=${user.id} failedTables=${bundle.failedTables.join(',')} details=${bundle.failedDetails}',
          );
        }
        final remote = bundle.profileRow == null
            ? null
            : _fromProfile(bundle.profileRow);
        await _backfillLegacyProfileFlagsIfNeeded(user.id, bundle.profileRow);
        final merged = _mergeCompletionState(remote: remote, cached: cached);
        await _backfillMergedFlagsIfNeeded(merged, remote);
        if (kDebugMode) {
          debugPrint(
            '[CompletionGate] source=partial userId=${user.id} profile_loaded=${bundle.profileRow != null} onboarding_completed=${merged.onboardingCompleted} username_completed=${merged.usernameCompleted} subscription_completed=${merged.subscriptionCompleted}',
          );
        }
        await cacheState(user.id, merged);
        return merged;
      }
      final profile = bundle.profileRow;
      await _backfillLegacyProfileFlagsIfNeeded(user.id, profile);
      final merged = _mergeCompletionState(
        remote: _fromProfile(profile),
        cached: cached,
      );
      await _backfillMergedFlagsIfNeeded(merged, _fromProfile(profile));
      if (kDebugMode) {
        debugPrint(
          '[CompletionGate] source=remote userId=${user.id} profile_loaded=${profile != null} onboarding_completed=${merged.onboardingCompleted} username_completed=${merged.usernameCompleted} subscription_completed=${merged.subscriptionCompleted}',
        );
      }
      await cacheState(user.id, merged);
      return merged;
    } catch (_) {
      final cached = await loadCached(user.id);
      if (cached != null) {
        if (kDebugMode) {
          debugPrint(
            '[CompletionGate] source=cached_fallback userId=${user.id} onboarding_completed=${cached.onboardingCompleted} username_completed=${cached.usernameCompleted} subscription_completed=${cached.subscriptionCompleted}',
          );
        }
        return cached;
      }
      const fallback = CompletionGateState(
        onboardingCompleted: false,
        usernameCompleted: false,
        subscriptionCompleted: false,
      );
      if (kDebugMode) {
        debugPrint(
          '[CompletionGate] source=empty_fallback userId=${user.id} onboarding_completed=${fallback.onboardingCompleted} username_completed=${fallback.usernameCompleted} subscription_completed=${fallback.subscriptionCompleted}',
        );
      }
      await cacheState(user.id, fallback);
      return fallback;
    }
  }

  static Future<void> _upsertFlagsForCurrentUser(
    Map<String, dynamic> fields,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await _ensureCurrentProfileRow(user.id, user.email);
      final updated = await Supabase.instance.client
          .from('profiles')
          .update(fields)
          .eq('id', user.id)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        throw const PostgrestException(
          message: 'No profile row updated for completion flags.',
        );
      }
      StartupUserDataService.instance.invalidateUser(user.id);
      final refreshed = await fetchForCurrentUser(preferCache: false);
      await cacheState(user.id, refreshed);
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
      final missingColumns = e.code == 'PGRST204' || msg.contains('column');
      debugPrint(
        '[CompletionGate] update failed userId=${user.id} code=${e.code} message=${e.message} details=${e.details} hint=${e.hint} fields=$fields',
      );
      if (!missingColumns) rethrow;
      final fallback = await fetchForCurrentUser(preferCache: true);
      await cacheState(user.id, fallback);
    }
  }

  static Future<void> _ensureCurrentProfileRow(
    String userId,
    String? email,
  ) async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('ensure_my_profile');
      return;
    } catch (_) {
      // Older environments may not have the RPC yet.
    }

    final existing = await client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (existing != null) return;

    await client.from('profiles').upsert({
      'id': userId,
      'email': email,
      'subscription_tier': 'free',
      'subscription_status': 'inactive',
    }, onConflict: 'id');
  }

  static Future<void> _cacheLocalCompletionState({
    bool? onboardingCompleted,
    bool? usernameCompleted,
    bool? subscriptionCompleted,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final cached = await loadCached(user.id);
    final next = CompletionGateState(
      onboardingCompleted:
          onboardingCompleted ?? cached?.onboardingCompleted ?? false,
      usernameCompleted:
          usernameCompleted ?? cached?.usernameCompleted ?? false,
      subscriptionCompleted:
          subscriptionCompleted ?? cached?.subscriptionCompleted ?? false,
      completedAt: DateTime.now().toUtc(),
    );
    await cacheState(user.id, next);
  }

  static Future<void> markOnboardingCompleted() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (kDebugMode) {
      debugPrint('[CompletionGate] write onboarding_completed=true');
    }
    await _cacheLocalCompletionState(onboardingCompleted: true);
    await _upsertFlagsForCurrentUser({
      'onboarding_completed': true,
      'completed_at': nowIso,
    }).timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  static Future<void> markUsernameCompleted() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (kDebugMode) {
      debugPrint('[CompletionGate] write username_completed=true');
    }
    await _cacheLocalCompletionState(usernameCompleted: true);
    await _upsertFlagsForCurrentUser({
      'username_completed': true,
      'completed_at': nowIso,
    }).timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  static Future<void> markSubscriptionCompleted() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (kDebugMode) {
      debugPrint('[CompletionGate] write subscription_completed=true');
    }
    await _cacheLocalCompletionState(subscriptionCompleted: true);
    await _upsertFlagsForCurrentUser({
      'subscription_completed': true,
      'completed_at': nowIso,
    }).timeout(const Duration(seconds: 5), onTimeout: () {});
  }
}
