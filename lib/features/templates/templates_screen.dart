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
  final TextEditingController _searchController = TextEditingController();
  bool loading = true;
  List<Map<String, dynamic>> templates = [];

  // Updated to match the template_keys we inserted via SQL
  final List<String> _builtInTemplates = [
    'menstrual',
    'cycle',
    'sleep',
    'bills',
    'income',
    'expenses',
    'tasks',
    'wishlist',
    'music',
    'mood',
    'water',
    'movies',
    'tv_log',
    'places',
    'restaurants',
    'books',
    'health',
    'workout',
    'fast',
    'study',
    'skin_care',
    'meditation',
    'social',
    'Goals/Resolutions'
        // 'symptoms',
        'habits',
    'meal_prep',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  bool _isDeletable(Map<String, dynamic> t) {
    final name = (t['name'] ?? '').toString().toLowerCase();
    final key = (t['template_key'] ?? '').toString().toLowerCase();

    // If it matches our built-in list OR if user_id is null (System Template), don't delete
    final isBuiltIn = _builtInTemplates.any(
      (b) => name.contains(b) || key.contains(b),
    );
    if (isBuiltIn || t['user_id'] == null) return false;

    final user = supabase.auth.currentUser;
    return (t['user_id'] ?? '').toString() == user?.id;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // FIX: Fetch where user_id is the current user OR user_id is NULL (System Templates)
      final rows = await supabase
          .from('log_templates_v2')
          .select()
          .or('user_id.eq.${user.id},user_id.is.null')
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          // Filter out 'habits' if you want it hidden from this view
          templates = List<Map<String, dynamic>>.from(
            rows,
          ).where((t) => (t['template_key'] ?? '') != 'habits').toList();
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load error: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
    try {
      await supabase.from('log_entries').delete().eq('template_id', templateId);
      await supabase
          .from('log_template_fields_v2')
          .delete()
          .eq('template_id', templateId);
      await supabase.from('log_templates_v2').delete().eq('id', templateId);
      _load();
    } catch (e) {
      debugPrint('Delete failed: $e');
    }
  }

  String _getEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('menstrual') || t.contains('cycle')) return '🩸';
    if (t.contains('sleep')) return '😴';
    if (t.contains('bill')) return '💸';
    if (t.contains('income')) return '💰';
    if (t.contains('expense')) return '📉';
    if (t.contains('task')) return '✅';
    if (t.contains('wishlist')) return '✨';
    if (t.contains('music')) return '🎵';
    if (t.contains('mood')) return '🎭';
    if (t.contains('water')) return '💧';
    if (t.contains('movie')) return '🍿';
    if (t.contains('tv log')) return '📺';
    if (t.contains('place')) return '📍';
    if (t.contains('restaurant')) return '🍽️';
    if (t.contains('book')) return '📖';
    //if (t.contains('health') || t.contains('symptoms')) return '🏥';
    if (t.contains('workout')) return '💪';
    if (t.contains('fast')) return '⏳';
    if (t.contains('skin care')) return '🧼';
    if (t.contains('meditation')) return '🧘';
    if (t.contains('study')) return '🧠';
    if (t.contains('goals')) return '🎊';
    // if (t.contains('meal prep')) return '🍱';
    return '📋';
  }

  Widget _glowingIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        radius: 20,
        child: IconButton(
          icon: Icon(icon, color: scheme.primary, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? templates
        : templates
              .where(
                (t) =>
                    (t['name'] ?? '').toString().toLowerCase().contains(query),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        leading: _glowingIconButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.pop(context),
          scheme: scheme,
        ),
        title: Text('Templates (${templates.length})'),
        centerTitle: true,
        actions: [
          _glowingIconButton(
            icon: Icons.add,
            onPressed: _openAddMenu,
            scheme: scheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withOpacity(0.08),
                          blurRadius: 15,
                          spreadRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: scheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search templates...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      final title = (t['name'] ?? t['template_key'] ?? '')
                          .toString();
                      final templateId = t['id'].toString();

                      final tileContent = Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ListTile(
                          tileColor: scheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: scheme.outline.withOpacity(0.1),
                            ),
                          ),
                          leading: Text(
                            _getEmoji(title),
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => themed(
                                  LogTableScreen(
                                    templateId: templateId,
                                    templateKey: t['template_key'],
                                    dayId: _today(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );

                      if (!_isDeletable(t)) return tileContent;

                      return Dismissible(
                        key: ValueKey(templateId),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteTemplate(templateId),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.delete, color: scheme.error),
                        ),
                        child: tileContent,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _openAddMenu() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => themed(const CreateLogTemplateScreen()),
      ),
    );
    if (ok == true) _load();
  }
}
