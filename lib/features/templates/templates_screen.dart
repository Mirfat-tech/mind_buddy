import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'log_table_screen.dart';
import 'create_templates_screen.dart';
import 'package:mind_buddy/router.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> templates = [];

  // ===== Supabase tables =====
  static const tTemplates = 'log_templates_v2';
  static const tFields = 'log_template_fields_v2';
  static const tEntries = 'log_entries';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Only fetch this user's templates (these are "user templates")
      final rows = await supabase
          .from(tTemplates)
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      templates = (rows as List)
          .map<Map<String, dynamic>>((x) => Map<String, dynamic>.from(x))
          .where((t) => (t['template_key'] ?? '').toString() != 'habits')
          .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  /// Confirm popup before deleting
  Future<bool> _confirmDeleteTemplate({
    required String title,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete template?'),
        content:
            Text('“$title” will be deleted permanently (including its logs).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return ok == true;
  }

  /// Deletes a template + its children (fields + entries)
  /// Returns true if successful (so the swipe only completes if delete succeeded).
  Future<bool> _deleteTemplate(String templateId) async {
    try {
      // NOTE: delete children first to avoid FK constraint errors
      await supabase.from(tEntries).delete().eq('template_id', templateId);
      await supabase.from(tFields).delete().eq('template_id', templateId);

      // Finally delete the template row itself
      await supabase.from(tTemplates).delete().eq('id', templateId);

      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
      return false;
    }
  }

  /// This decides whether a template is allowed to be deleted.
  /// Right now: only templates owned by the current user are deletable.
  bool _isDeletable(Map<String, dynamic> t) {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final ownerId = (t['user_id'] ?? '').toString();
    return ownerId == user.id;

    // If you later add a column like is_system, you can do:
    // final isSystem = t['is_system'] == true;
    // return ownerId == user.id && !isSystem;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddMenu, // ✅ this calls the bottom sheet
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : templates.isEmpty
              ? const Center(
                  child: Text('No templates yet. Tap + to create one.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = templates[i];

                    final name = (t['name'] ?? '').toString();
                    final templateKey = (t['template_key'] ?? '').toString();
                    final templateId = (t['id'] ?? '').toString();

                    final title = name.isEmpty ? templateKey : name;

                    // Your existing tile UI
                    final tile = ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: Theme.of(context).colorScheme.surface,
                      leading: const Icon(Icons.table_chart_outlined),
                      title: Text(title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final dayId = _today();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => themed(
                              LogTableScreen(
                                templateId: templateId,
                                templateKey: templateKey,
                                dayId: dayId,
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    // If it isn't deletable, just return the tile (no swipe)
                    if (!_isDeletable(t)) return tile;

                    // Swipe-to-delete wrapper
                    return Dismissible(
                      key: ValueKey('tpl_$templateId'),
                      direction: DismissDirection.endToStart,

                      // Red delete background
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),

                      /// ✅ We delete BEFORE dismissing. If delete fails, it snaps back.
                      confirmDismiss: (_) async {
                        final confirm =
                            await _confirmDeleteTemplate(title: title);
                        if (!confirm) return false;

                        // Do the backend delete
                        final success = await _deleteTemplate(templateId);

                        if (!success) return false;

                        // Also remove locally so it disappears immediately
                        if (mounted) {
                          setState(() {
                            templates.removeAt(i);
                          });
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Deleted “$title”')),
                        );

                        return true;
                      },

                      child: tile,
                    );
                  },
                ),
    );
  }

  Future<void> _openAddMenu() async {
    final scheme = Theme.of(context).colorScheme;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Create logs template'),
                subtitle: const Text('Make a custom table (movies, gym, etc)'),
                onTap: () => Navigator.pop(ctx, 'create_log_template'),
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined),
                title: const Text('Add checklist'),
                subtitle:
                    const Text('A checklist template (Apple Notes style)'),
                onTap: () => Navigator.pop(ctx, 'create_checklist'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    if (result == 'create_log_template') {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => themed(const CreateLogTemplateScreen())),
      );
      if (ok == true) await _load();
    }

    if (result == 'create_checklist') {
      // ✅ This depends on what your checklist flow is:
      // If you already have a ChecklistTemplateCreateScreen, push it here.
      // If you store checklists differently, you might insert a "checklist template" row in DB, then reload.
      //
      // Example route push (replace with your real screen/route):
      // final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => themed(const CreateChecklistTemplateScreen())));
      // if (ok == true) await _load();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Checklist create not wired yet. Tell me your checklist screen name/route and I’ll hook it in.')),
      );
    }
  }
}
