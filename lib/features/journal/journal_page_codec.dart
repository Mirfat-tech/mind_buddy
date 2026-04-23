import 'dart:convert';

class JournalEntryPageData {
  const JournalEntryPageData({
    required this.id,
    required this.body,
    this.isBookmarked = false,
  });

  final String id;
  final String body;
  final bool isBookmarked;

  JournalEntryPageData copyWith({
    String? id,
    String? body,
    bool? isBookmarked,
  }) {
    return JournalEntryPageData(
      id: id ?? this.id,
      body: body ?? this.body,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'body': body,
    'is_bookmarked': isBookmarked,
  };

  static JournalEntryPageData? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = (map['id'] ?? '').toString();
    if (id.isEmpty) return null;
    return JournalEntryPageData(
      id: id,
      body: (map['body'] ?? '').toString(),
      isBookmarked: map['is_bookmarked'] == true,
    );
  }
}

class JournalEntryPagesData {
  const JournalEntryPagesData({required this.pages, this.currentPageId});

  final List<JournalEntryPageData> pages;
  final String? currentPageId;
}

class JournalPageCodec {
  JournalPageCodec._();

  static const String _schema = 'journal_pages_v1';

  static JournalEntryPagesData decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map['schema'] == _schema && map['pages'] is List) {
          final pages = (map['pages'] as List)
              .map(JournalEntryPageData.fromJson)
              .whereType<JournalEntryPageData>()
              .toList(growable: false);
          if (pages.isNotEmpty) {
            return JournalEntryPagesData(
              pages: pages,
              currentPageId: map['current_page_id']?.toString(),
            );
          }
        }
      }
    } catch (_) {}

    return JournalEntryPagesData(
      pages: <JournalEntryPageData>[
        JournalEntryPageData(id: 'page-1', body: raw),
      ],
      currentPageId: 'page-1',
    );
  }

  static String encode({
    required List<JournalEntryPageData> pages,
    String? currentPageId,
  }) {
    return jsonEncode(<String, dynamic>{
      'schema': _schema,
      'current_page_id': currentPageId,
      'pages': pages.map((page) => page.toJson()).toList(),
    });
  }
}
