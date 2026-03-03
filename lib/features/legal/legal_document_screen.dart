import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = rootBundle.loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBackground = theme.scaffoldBackgroundColor.a == 0
        ? theme.colorScheme.surface
        : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: resolvedBackground,
      appBar: AppBar(
        backgroundColor: resolvedBackground,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not load document: ${snapshot.error}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          }
          final text = snapshot.data ?? '';
          return Container(
            color: resolvedBackground,
            child: Markdown(
              data: text,
              selectable: true,
              padding: const EdgeInsets.all(16),
              styleSheet: MarkdownStyleSheet.fromTheme(theme),
            ),
          );
        },
      ),
    );
  }
}
