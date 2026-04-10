import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JournalFolder {
  const JournalFolder({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorKey,
    required this.iconStyle,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String colorKey;
  final String iconStyle;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory JournalFolder.fromMap(Map<String, dynamic> map) {
    return JournalFolder(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      colorKey: (map['color'] ?? 'pink').toString(),
      iconStyle: (map['icon_style'] ?? 'bubble_folder').toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class JournalFolderPaletteItem {
  const JournalFolderPaletteItem({
    required this.key,
    required this.color,
    required this.tint,
  });

  final String key;
  final Color color;
  final Color tint;
}

class JournalFolderStyle {
  const JournalFolderStyle({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;
}

class JournalFolderSupport {
  JournalFolderSupport._();

  static const List<JournalFolderPaletteItem> palette =
      <JournalFolderPaletteItem>[
        JournalFolderPaletteItem(
          key: 'pink',
          color: Color(0xFFF6B6C8),
          tint: Color(0xFFFCE4EC),
        ),
        JournalFolderPaletteItem(
          key: 'lavender',
          color: Color(0xFFC9B8F9),
          tint: Color(0xFFF1ECFF),
        ),
        JournalFolderPaletteItem(
          key: 'blue',
          color: Color(0xFF9CC9F7),
          tint: Color(0xFFE8F3FF),
        ),
        JournalFolderPaletteItem(
          key: 'mint',
          color: Color(0xFFA8E2C1),
          tint: Color(0xFFEAF9F0),
        ),
        JournalFolderPaletteItem(
          key: 'peach',
          color: Color(0xFFF7C2A6),
          tint: Color(0xFFFFF0E7),
        ),
        JournalFolderPaletteItem(
          key: 'yellow',
          color: Color(0xFFF4D88C),
          tint: Color(0xFFFFF8E3),
        ),
        JournalFolderPaletteItem(
          key: 'grey',
          color: Color(0xFFBFC7D5),
          tint: Color(0xFFF2F4F8),
        ),
      ];

  static const List<JournalFolderStyle> styles = <JournalFolderStyle>[
    JournalFolderStyle(
      key: 'bubble_folder',
      icon: Icons.folder_open_rounded,
      label: 'Bubble',
    ),
    JournalFolderStyle(
      key: 'story_stack',
      icon: Icons.auto_stories_rounded,
      label: 'Story',
    ),
    JournalFolderStyle(
      key: 'bookmark_pocket',
      icon: Icons.bookmarks_rounded,
      label: 'Pocket',
    ),
  ];

  static JournalFolderPaletteItem paletteFor(String key) {
    return palette.firstWhere(
      (item) => item.key == key,
      orElse: () => palette.first,
    );
  }

  static JournalFolderStyle styleFor(String key) {
    return styles.firstWhere(
      (item) => item.key == key,
      orElse: () => styles.first,
    );
  }

  static Future<List<JournalFolder>> fetchFolders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const <JournalFolder>[];
    final response = await Supabase.instance.client
        .from('journal_folders')
        .select()
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);
    return (response as List)
        .map((row) => JournalFolder.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<void> createFolder({
    required String name,
    required String colorKey,
    required String iconStyle,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      developer.log(
        'journal_folder event=create_skip_no_user',
        name: 'journal_folder',
      );
      throw StateError('No authenticated user available for folder creation.');
    }
    final payload = <String, dynamic>{
      'user_id': user.id,
      'name': name.trim(),
      'color': colorKey,
      'icon_style': iconStyle,
    };
    developer.log(
      'journal_folder event=create_payload data={payload: $payload}',
      name: 'journal_folder',
    );
    await _debugSanityCheckJournalFoldersTable();
    try {
      final inserted = await Supabase.instance.client
          .from('journal_folders')
          .insert(payload)
          .select(
            'id, user_id, name, color, icon_style, created_at, updated_at',
          )
          .single();
      developer.log(
        'journal_folder event=create_success data={row: $inserted}',
        name: 'journal_folder',
      );
    } on PostgrestException catch (error, stackTrace) {
      developer.log(
        'journal_folder event=create_postgrest_error data={message: ${error.message}, details: ${error.details}, hint: ${error.hint}, code: ${error.code}}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (error, stackTrace) {
      developer.log(
        'journal_folder event=create_unknown_error data={error: $error}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> updateFolder(
    String folderId, {
    required String name,
    required String colorKey,
    required String iconStyle,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'color': colorKey,
      'icon_style': iconStyle,
    };
    developer.log(
      'journal_folder event=update_payload data={folder_id: $folderId, payload: $payload}',
      name: 'journal_folder',
    );
    try {
      final updated = await Supabase.instance.client
          .from('journal_folders')
          .update(payload)
          .eq('id', folderId)
          .select(
            'id, user_id, name, color, icon_style, created_at, updated_at',
          )
          .single();
      developer.log(
        'journal_folder event=update_success data={row: $updated}',
        name: 'journal_folder',
      );
    } on PostgrestException catch (error, stackTrace) {
      developer.log(
        'journal_folder event=update_postgrest_error data={message: ${error.message}, details: ${error.details}, hint: ${error.hint}, code: ${error.code}}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (error, stackTrace) {
      developer.log(
        'journal_folder event=update_unknown_error data={error: $error}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> deleteFolder(String folderId) async {
    developer.log(
      'journal_folder event=delete_call data={folder_id: $folderId}',
      name: 'journal_folder',
    );
    await Supabase.instance.client.rpc(
      'delete_journal_folder',
      params: {'p_folder_id': folderId},
    );
  }

  static Future<void> assignEntryToFolder(
    String journalId,
    String? folderId,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      developer.log(
        'journal_folder event=assign_skip_no_user data={journal_id: $journalId, folder_id: $folderId}',
        name: 'journal_folder',
      );
      throw StateError('No authenticated user available for entry assignment.');
    }
    final payload = <String, dynamic>{'folder_id': folderId};
    developer.log(
      'journal_folder event=assign_call data={journal_id: $journalId, folder_id: $folderId, user_id: ${user.id}, payload: $payload}',
      name: 'journal_folder',
    );
    await _debugSanityCheckJournalsFolderColumn();
    try {
      final updated = await Supabase.instance.client
          .from('journals')
          .update(payload)
          .eq('id', journalId)
          .eq('user_id', user.id)
          .select('id, user_id, folder_id')
          .single();
      developer.log(
        'journal_folder event=assign_success data={row: $updated}',
        name: 'journal_folder',
      );
    } on PostgrestException catch (error, stackTrace) {
      developer.log(
        'journal_folder event=assign_postgrest_error data={message: ${error.message}, details: ${error.details}, hint: ${error.hint}, code: ${error.code}}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (error, stackTrace) {
      developer.log(
        'journal_folder event=assign_unknown_error data={error: $error}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> _debugSanityCheckJournalFoldersTable() async {
    developer.log(
      'journal_folder event=sanity_check_start',
      name: 'journal_folder',
    );
    try {
      final result = await Supabase.instance.client
          .from('journal_folders')
          .select('id')
          .limit(1);
      developer.log(
        'journal_folder event=sanity_check_success data={result: $result}',
        name: 'journal_folder',
      );
    } on PostgrestException catch (error, stackTrace) {
      developer.log(
        'journal_folder event=sanity_check_postgrest_error data={message: ${error.message}, details: ${error.details}, hint: ${error.hint}, code: ${error.code}}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (error, stackTrace) {
      developer.log(
        'journal_folder event=sanity_check_unknown_error data={error: $error}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> _debugSanityCheckJournalsFolderColumn() async {
    developer.log(
      'journal_folder event=journals_folder_column_check_start',
      name: 'journal_folder',
    );
    try {
      final result = await Supabase.instance.client
          .from('journals')
          .select('id, folder_id')
          .limit(1);
      developer.log(
        'journal_folder event=journals_folder_column_check_success data={result: $result}',
        name: 'journal_folder',
      );
    } on PostgrestException catch (error, stackTrace) {
      developer.log(
        'journal_folder event=journals_folder_column_check_postgrest_error data={message: ${error.message}, details: ${error.details}, hint: ${error.hint}, code: ${error.code}}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (error, stackTrace) {
      developer.log(
        'journal_folder event=journals_folder_column_check_unknown_error data={error: $error}',
        name: 'journal_folder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static String describeError(Object error) {
    if (error is PostgrestException) {
      final details = error.details?.toString() ?? '';
      final hint = error.hint?.toString() ?? '';
      final parts = <String>[
        if (error.code != null && error.code!.isNotEmpty) 'code=${error.code}',
        error.message,
        if (details.isNotEmpty) 'details=$details',
        if (hint.isNotEmpty) 'hint=$hint',
      ];
      return parts.join(' | ');
    }
    return error.toString();
  }

  static String userFacingError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    if (error is PostgrestException) {
      final lower = error.message.toLowerCase();
      if (lower.contains('relation') && lower.contains('journal_folders')) {
        return 'journal_folders table is missing. Apply the journal folder migration.';
      }
      if (lower.contains('column journals.folder_id does not exist') ||
          (lower.contains('folder_id') && error.code == '42703')) {
        return 'journals.folder_id is missing in the live database. Apply the journal folder column migration.';
      }
      if (lower.contains('row-level security') ||
          lower.contains('policy') ||
          error.code == '42501') {
        return 'Folder insert blocked by RLS policy. Check journal_folders INSERT policy.';
      }
      if (lower.contains('column') && lower.contains('icon_style')) {
        return 'journal_folders schema does not match the app payload.';
      }
      return describeError(error);
    }
    if (kDebugMode) return error.toString();
    return 'Could not save folder';
  }
}
