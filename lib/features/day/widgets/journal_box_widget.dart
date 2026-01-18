import 'package:flutter/material.dart';

class JournalBoxWidget extends StatefulWidget {
  const JournalBoxWidget({
    super.key,
    required this.box,
    required this.onSave,
    this.initialText = '',
  });

  final Map<String, dynamic> box;
  final String initialText;
  final Future<void> Function(String text) onSave;

  @override
  State<JournalBoxWidget> createState() => _JournalBoxWidgetState();
}

class _JournalBoxWidgetState extends State<JournalBoxWidget> {
  late final TextEditingController ctrl;

  @override
  void initState() {
    super.initState();
    final content = (widget.box['content'] as Map?) ?? {};
    ctrl = TextEditingController(text: (content['text'] ?? '').toString());
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: null,
      decoration: const InputDecoration(
        hintText: 'Write anything…',
        border: InputBorder.none,
      ),
      onChanged: (v) => widget.onSave(v),
    );
  }
}
