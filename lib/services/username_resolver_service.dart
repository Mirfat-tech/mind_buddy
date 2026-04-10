import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsernameResolutionResult {
  const UsernameResolutionResult({
    required this.usernamesById,
    required this.missingIds,
    required this.hadError,
  });

  final Map<String, String> usernamesById;
  final Set<String> missingIds;
  final bool hadError;
}

class UsernameResolverService {
  UsernameResolverService._();

  static final UsernameResolverService instance = UsernameResolverService._();

  void _logPgError(String scope, Object error) {
    if (error is! PostgrestException) {
      debugPrint('[UsernameResolver:$scope] error=$error');
      return;
    }
    debugPrint(
      '[UsernameResolver:$scope] code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
    );
  }

  Future<dynamic> _callGetUsernamesRpc(List<String> ids) {
    return Supabase.instance.client.rpc(
      'get_usernames_by_ids',
      params: {'p_user_ids': ids},
    );
  }

  Future<UsernameResolutionResult> resolveUsernamesByIdsDetailed(
    Iterable<String> userIds,
  ) async {
    final ids = userIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return const UsernameResolutionResult(
        usernamesById: <String, String>{},
        missingIds: <String>{},
        hadError: false,
      );
    }

    try {
      final result = await _callGetUsernamesRpc(ids);
      final rows = result is List ? result : const <dynamic>[];
      final map = <String, String>{};
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id']?.toString() ?? '';
        final username = (row['username'] ?? '').toString();
        if (id.isEmpty || username.isEmpty) continue;
        map[id] = username;
      }
      final missing = ids.where((id) => !map.containsKey(id)).toSet();
      return UsernameResolutionResult(
        usernamesById: map,
        missingIds: missing,
        hadError: false,
      );
    } catch (e) {
      _logPgError('resolveUsernamesByIdsDetailed', e);
      return UsernameResolutionResult(
        usernamesById: const <String, String>{},
        missingIds: ids.toSet(),
        hadError: true,
      );
    }
  }

  Future<Map<String, String>> resolveUsernamesByIds(
    Iterable<String> userIds,
  ) async {
    final detailed = await resolveUsernamesByIdsDetailed(userIds);
    return detailed.usernamesById;
  }

  Future<List<Map<String, dynamic>>> searchUsernames(
    String prefix, {
    int maxResults = 8,
  }) async {
    final normalized = prefix.trim().toLowerCase().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    if (normalized.isEmpty) return const <Map<String, dynamic>>[];

    try {
      final result = await Supabase.instance.client.rpc(
        'search_usernames',
        params: {'prefix': normalized, 'max_results': maxResults},
      );
      final rows = result is List ? result : const <dynamic>[];
      return rows
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .where((row) => (row['id']?.toString() ?? '').isNotEmpty)
          .toList();
    } catch (e) {
      _logPgError('searchUsernames', e);
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> findUserByUsername(String inputUsername) async {
    final normalized = inputUsername.trim().toLowerCase().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    if (normalized.isEmpty) return null;

    try {
      final result = await Supabase.instance.client.rpc(
        'find_user_by_username',
        params: {'input_username': normalized},
      );
      final rows = result is List ? result : const <dynamic>[];
      if (rows.isEmpty) return null;
      final row = Map<String, dynamic>.from(rows.first as Map);
      final id = row['id']?.toString() ?? '';
      final username = (row['username'] ?? '').toString();
      if (id.isEmpty || username.isEmpty) return null;
      return <String, dynamic>{'id': id, 'username': username};
    } catch (e) {
      _logPgError('findUserByUsername', e);
      return null;
    }
  }

  Future<void> debugProbe({String? knownUsername}) async {
    if (!kDebugMode) return;
    final client = Supabase.instance.client;
    try {
      await client.rpc(
        'get_usernames_by_ids',
        params: {'p_user_ids': <String>[]},
      );
      debugPrint('[UsernameResolverProbe] get_usernames_by_ids(empty) ok');
    } catch (e) {
      _logPgError('probe:get_usernames_by_ids', e);
    }

    try {
      final search = await searchUsernames('m', maxResults: 8);
      debugPrint(
        '[UsernameResolverProbe] search_usernames("m") rows=${search.length} sample=${search.take(3).toList()}',
      );
      if (knownUsername != null && knownUsername.trim().isNotEmpty) {
        final exact = await findUserByUsername(knownUsername);
        debugPrint(
          '[UsernameResolverProbe] find_user_by_username("$knownUsername") row=$exact',
        );
      }
    } catch (e) {
      _logPgError('probe:search/find', e);
    }
  }

  Future<Map<String, String>> runRpcHealthCheck({
    String searchPrefix = 'a',
  }) async {
    final client = Supabase.instance.client;
    final result = <String, String>{};

    try {
      final rows = await client.rpc(
        'search_usernames',
        params: {'prefix': searchPrefix, 'max_results': 1},
      );
      final count = rows is List ? rows.length : 0;
      result['search_usernames'] = 'ok rows=$count';
      debugPrint('[UsernameResolverHealth] search_usernames ok rows=$count');
    } catch (e) {
      _logPgError('health:search_usernames', e);
      result['search_usernames'] = 'error';
    }

    try {
      await client.rpc(
        'get_usernames_by_ids',
        params: {'p_user_ids': <String>[]},
      );
      result['get_usernames_by_ids'] = 'ok';
      debugPrint('[UsernameResolverHealth] get_usernames_by_ids ok');
    } catch (e) {
      _logPgError('health:get_usernames_by_ids', e);
      result['get_usernames_by_ids'] = 'error';
    }

    return result;
  }
}
