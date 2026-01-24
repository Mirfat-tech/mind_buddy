import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';

class BrainFogScreen extends StatefulWidget {
  const BrainFogScreen({super.key});

  @override
  State<BrainFogScreen> createState() => _BrainFogScreenState();
}

class _Thought {
  _Thought({required this.id, this.text = '', required this.offset});
  final String id;
  String text;
  Offset offset;
}

class _BrainFogScreenState extends State<BrainFogScreen>
    with TickerProviderStateMixin {
  final List<_Thought> _thoughts = [];
  bool _isDeleteMode = false;
  bool _isLoading = true;
  late AnimationController _shakeController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _fetchThoughts();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _shakeController.stop();
    super.dispose();
  }

  // --- SUPABASE LOGIC ---
  Future<bool?> _showExitConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard thought?'),
        content: const Text(
          "You have a thought typed out. If you leave now, it won't be kept.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Don't leave
            child: const Text('STAY'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Leave
            child: Text(
              'DISCARD',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchThoughts() async {
    try {
      final data = await supabase.from('brain_fog').select();
      setState(() {
        _thoughts.clear();
        for (var item in data) {
          _thoughts.add(
            _Thought(
              id: item['id'].toString(),
              text: item['text'] ?? '',
              // .toDouble() prevents the 'int is not a subtype of double' crash
              offset: Offset(
                (item['x_pos'] ?? 100).toDouble(),
                (item['y_pos'] ?? 100).toDouble(),
              ),
            ),
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fetch error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _upsertThought(_Thought thought) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final bool isTempId = RegExp(r'^\d+$').hasMatch(thought.id);
      final Map<String, dynamic> data = {
        'user_id': user.id,
        'text': thought.text,
        'x_pos': thought.offset.dx,
        'y_pos': thought.offset.dy,
      };

      if (!isTempId) data['id'] = thought.id;

      await supabase.from('brain_fog').upsert(data);

      // We fetch again to get the real UUIDs and update the UI
      await _fetchThoughts();
    } catch (e) {
      debugPrint('Upsert error: $e');
      setState(() => _isLoading = false); // Safety net
    }
  }

  // ... inside _BrainFogScreenState ...

  Future<void> _deleteThought(_Thought thought) async {
    final deletedThought = thought;
    final originalIndex = _thoughts.indexOf(thought);

    setState(() {
      _thoughts.remove(thought);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: const Text('Thought cleared...'),
            backgroundColor: Colors.teal.shade900,
            // CHANGED: 15 seconds as requested
            duration: const Duration(seconds: 15),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _thoughts.insert(originalIndex, deletedThought);
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            final bool isRealId = !RegExp(r'^\d+$').hasMatch(deletedThought.id);
            if (isRealId) {
              await supabase.from('brain_fog').delete().match({
                'id': deletedThought.id,
              });
            }
          }
        });
  }

  // ... inside your build method AppBar ...

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear all thoughts?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final user = supabase.auth.currentUser;
              if (user != null) {
                await supabase.from('brain_fog').delete().match({
                  'user_id': user.id,
                });
                setState(() => _thoughts.clear());
              }
              Navigator.pop(context);
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- UI LOGIC ---

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      _isDeleteMode
          ? _shakeController.repeat(reverse: true)
          : _shakeController.stop();
    });
  }

  void _addThought() {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2 - 55, size.height / 2 - 100);
    final newThought = _Thought(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      offset: center,
    );
    setState(() => _thoughts.add(newThought));
    _showEditSheet(newThought);
  }

  void _showEditSheet(_Thought thought) {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: thought.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
                maxLines: 3,
              ),
              FilledButton(
                onPressed: () {
                  setState(() => thought.text = controller.text);
                  _upsertThought(thought);
                  Navigator.pop(context);
                },
                child: const Text("Keep Thought"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getBubbleSize(String text) {
    return (110.0 + (text.length / 10) * 15).clamp(110.0, 220.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Brain Fog'),
        // Add this leading block:
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            // This will force the app to go to your home route
            // Ensure '/home' matches the path in your main.dart GoRouter setup
            context.go('/home');
          },
        ),
        actions: [
          if (_thoughts.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmClearAll,
            ),
            IconButton(
              icon: Icon(
                _isDeleteMode ? Icons.check_circle : Icons.delete_outline,
              ),
              color: _isDeleteMode ? Colors.green : cs.onSurface,
              onPressed: _toggleDeleteMode,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addThought,
        backgroundColor: cs.primary,
        child: Icon(Icons.add, color: cs.onPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Center(
                  child: Text(
                    "Let it out 💨 \nWhat's overwhelming you today?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.3)),
                  ),
                ),
                ..._thoughts.map((t) {
                  double bSize = _getBubbleSize(t.text);
                  return Positioned(
                    left: t.offset.dx,
                    top: t.offset.dy,
                    child: Draggable<_Thought>(
                      onDragEnd: (details) {
                        setState(() {
                          t.offset = Offset(
                            details.offset.dx.clamp(0, size.width - bSize),
                            details.offset.dy.clamp(0, size.height - 250),
                          );
                        });
                        _upsertThought(t);
                      },
                      feedback: _buildBubble(t, isDragging: true),
                      childWhenDragging: const SizedBox.shrink(),
                      child: _buildBubble(t),
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }

  Widget _buildBubble(_Thought t, {bool isDragging = false}) {
    final cs = Theme.of(context).colorScheme;
    double bSize = _getBubbleSize(t.text);

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) => Transform.rotate(
        angle: (_isDeleteMode && !isDragging)
            ? (0.05 * _shakeController.value) - 0.025
            : 0,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => _isDeleteMode ? _deleteThought(t) : _showEditSheet(t),
        child: Container(
          width: bSize,
          height: bSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surface.withOpacity(0.6),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.4),
                blurRadius: 15,
                blurStyle: BlurStyle.outer,
              ),
            ],
            border: Border.all(
              color: _isDeleteMode ? Colors.red : cs.primary.withOpacity(0.2),
            ),
          ),
          child: Stack(
            // Added Stack back to bubbles to hold the delete button
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      t.text.isEmpty ? "Tap..." : t.text,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
              // --- THIS PART WAS MISSING ---
              if (_isDeleteMode)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.remove, size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
