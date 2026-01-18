import 'dart:async';
import 'package:flutter/material.dart';

class ChecklistItem {
  final String id;
  final String text;
  final bool done;

  const ChecklistItem({
    required this.id,
    required this.text,
    required this.done,
  });

  ChecklistItem copyWith({String? id, String? text, bool? done}) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};

  static ChecklistItem fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      done: (json['done'] ?? false) == true,
    );
  }
}

class ChecklistBoxWidget extends StatefulWidget {
  const ChecklistBoxWidget({
    super.key,
    required this.box,
    required this.initialItems,
    required this.onSaveItems,
    this.autoMoveCompletedToBottom = true,
  });

  final Map<String, dynamic> box;
  final List<ChecklistItem> initialItems;
  final Future<void> Function(List<ChecklistItem> items) onSaveItems;

  /// Apple Notes-ish: completed items fall to the bottom.
  final bool autoMoveCompletedToBottom;

  @override
  State<ChecklistBoxWidget> createState() => _ChecklistBoxWidgetState();
}

class _ChecklistBoxWidgetState extends State<ChecklistBoxWidget> {
  late List<ChecklistItem> _items;
  final _controllers = <TextEditingController>[];
  final _focusNodes = <FocusNode>[];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initialItems);

    // Keep at least one row
    if (_items.isEmpty) {
      _items = [ChecklistItem(id: _newId(), text: '', done: false)];
    }

    _sortIfNeeded();
    _rebuildControllers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _rebuildControllers() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _controllers.clear();
    _focusNodes.clear();

    for (final item in _items) {
      _controllers.add(TextEditingController(text: item.text));
      _focusNodes.add(FocusNode());
    }
  }

  void _sortIfNeeded() {
    if (!widget.autoMoveCompletedToBottom) return;
    _items.sort((a, b) {
      // incomplete first
      final da = a.done ? 1 : 0;
      final db = b.done ? 1 : 0;
      if (da != db) return da.compareTo(db);
      return 0;
    });
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      await widget.onSaveItems(List.unmodifiable(_items));
    });
  }

  void _toggleDone(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(done: !_items[index].done);
      _sortIfNeeded();
      _rebuildControllers(); // because sorting changes indices
    });
    _schedulePersist();
  }

  void _updateText(int index, String text) {
    _items[index] = _items[index].copyWith(text: text);
    _schedulePersist();
  }

  void _addItem({int? afterIndex, bool focus = true}) async {
    final insertAt = afterIndex == null ? _items.length : afterIndex + 1;
    final newItem = ChecklistItem(id: _newId(), text: '', done: false);

    setState(() {
      _items.insert(insertAt, newItem);
      _sortIfNeeded();
      _rebuildControllers();
    });

    // Persist immediately so it doesn't "snap back"
    await widget.onSaveItems(List.unmodifiable(_items));

    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = insertAt.clamp(0, _focusNodes.length - 1);
        _focusNodes[target].requestFocus();
      });
    }
  }

  Future<void> _removeItemById(String id) async {
    setState(() {
      _items.removeWhere((x) => x.id == id);

      // Always keep one blank row
      if (_items.isEmpty) {
        _items = [ChecklistItem(id: _newId(), text: '', done: false)];
      }

      _sortIfNeeded();
      _rebuildControllers();
    });

    // IMPORTANT: persist immediately so parent reload won't resurrect it
    await widget.onSaveItems(List.unmodifiable(_items));
  }

  void _reorder(int oldIndex, int newIndex) {
    // ReorderableListView gives newIndex with “gap” semantics
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      // If you auto-move completed to bottom, reordering across done/undone
      // would be undone by sorting. So only sort if disabled:
      if (!widget.autoMoveCompletedToBottom) {
        // keep manual order
      } else {
        // If you want “true Apple Notes”, keep the sort.
        _sortIfNeeded();
      }
      _rebuildControllers();
    });

    _schedulePersist();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          onReorder: _reorder,
          buildDefaultDragHandles: false,
          itemBuilder: (_, index) {
            final item = _items[index];

            return Dismissible(
              key: ValueKey('dismiss_${item.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) => _removeItemById(item.id),
              confirmDismiss: (_) async => true,
              child: Padding(
                key: ValueKey('row_${item.id}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleDone(index),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(width: 2),
                        ),
                        alignment: Alignment.center,
                        child: item.done
                            ? const Icon(Icons.check, size: 16)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'List item...',
                        ),
                        textInputAction: TextInputAction.next,
                        style: TextStyle(
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        onChanged: (v) => _updateText(index, v),
                        onSubmitted: (_) => _addItem(afterIndex: index),
                      ),
                    ),

                    // Drag handle
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addItem(),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ),
      ],
    );
  }
}
