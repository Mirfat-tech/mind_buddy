import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';

class CreateLogTemplateScreen extends StatefulWidget {
  const CreateLogTemplateScreen({super.key});

  @override
  State<CreateLogTemplateScreen> createState() =>
      _CreateLogTemplateScreenState();
}

class _CreateLogTemplateScreenState extends State<CreateLogTemplateScreen> {
  final supabase = Supabase.instance.client;
  final nameCtrl = TextEditingController();
  final keyCtrl = TextEditingController();

  bool saving = false;

  final fields = <_FieldDraft>[
    _FieldDraft(label: 'Item', key: '', type: 'text'),
  ];

  static const tTemplates = 'log_templates_v2';
  static const tFields = 'log_template_fields_v2';

  @override
  void dispose() {
    nameCtrl.dispose();
    keyCtrl.dispose();
    super.dispose();
  }

  // --- UI HELPERS ---

  String _getEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('menstrual')) return '🩸';
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
    if (t.contains('places')) return '📍';
    if (t.contains('restaurants')) return '🍽️';
    if (t.contains('books')) return '📖';
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
            color: scheme.primary.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          icon: Icon(icon, color: scheme.primary, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _inputWrapper(ColorScheme scheme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: scheme.primary.withOpacity(0.08), blurRadius: 15),
        ],
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  // --- LOGIC ---

  String _slugify(String s) {
    final lower = s.trim().toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s_-]'), '');
    final underscored = cleaned.replaceAll(RegExp(r'[\s-]+'), '_');
    return underscored.replaceAll(RegExp(r'_+'), '_');
  }

  Future<String> _uniqueTemplateKey(String baseKey, String userId) async {
    var key = baseKey;
    var i = 2;
    while (true) {
      final existing = await supabase
          .from(tTemplates)
          .select('id')
          .eq('user_id', userId)
          .eq('template_key', key)
          .maybeSingle();
      if (existing == null) return key;
      key = '${baseKey}_$i';
      i++;
    }
  }

  Future<void> _save() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final cleanedFields = fields
        .where((f) => f.label.trim().isNotEmpty)
        .map((f) => f.cleaned())
        .toList();

    if (cleanedFields.isEmpty) return;

    setState(() => saving = true);

    try {
      final baseKey = _slugify(keyCtrl.text.isEmpty ? name : keyCtrl.text);
      final templateKey = await _uniqueTemplateKey(baseKey, user.id);

      final tpl = await supabase
          .from(tTemplates)
          .insert({
            'user_id': user.id,
            'template_key': templateKey,
            'name': name,
          })
          .select()
          .single();

      final templateId = (tpl['id'] ?? '').toString();
      final rows = cleanedFields.asMap().entries.map((entry) {
        final i = entry.key;
        final f = entry.value;
        return {
          'user_id': user.id,
          'template_id': templateId,
          'field_key': f.key,
          'label': f.label,
          'field_type': f.type,
          'sort_order': i,
          'options': f.optionsJson,
          'is_hidden': false,
        };
      }).toList();

      await supabase.from(tFields).insert(rows);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        leading: _glowingIconButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.pop(context),
          scheme: scheme,
        ),
        title: const Text('New Template'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: saving ? null : _save,
              child: Text(
                saving ? 'SAVING...' : 'SAVE',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          24,
          24,
          24,
          40,
        ), // Bottom padding added
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary.withOpacity(0.1)),
              ),
              alignment: Alignment.center,
              child: Text(
                _getEmoji(nameCtrl.text),
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _inputWrapper(
            scheme,
            child: TextField(
              controller: nameCtrl,
              onChanged: (v) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Template Name',
                border: InputBorder.none, // Removes default pink border
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'FIELDS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < fields.length; i++) ...[
            _FieldEditor(
              field: fields[i],
              onChanged: (f) => setState(() => fields[i] = f),
              onDelete: () => setState(() {
                fields.removeAt(i);
                if (fields.isEmpty)
                  fields.add(_FieldDraft(label: 'Item', key: '', type: 'text'));
              }),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => fields.add(_FieldDraft(label: '', key: '', type: 'text')),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Field'),
            ),
          ),
        ],
      ),
    );
  }
}

// --- DATA CLASSES ---

class _FieldDraft {
  final String label;
  final String key;
  final String type;
  final List<String> options;

  _FieldDraft({
    required this.label,
    required this.key,
    required this.type,
    this.options = const [],
  });

  _FieldDraft copyWith({
    String? label,
    String? key,
    String? type,
    List<String>? options,
  }) {
    return _FieldDraft(
      label: label ?? this.label,
      key: key ?? this.key,
      type: type ?? this.type,
      options: options ?? this.options,
    );
  }

  _CleanedField cleaned() {
    final label2 = label.trim();
    final key2 = (key.trim().isEmpty) ? _autoKey(label2) : _autoKey(key);
    final type2 = type.trim().isEmpty ? 'text' : type.trim();

    Map<String, dynamic>? optionsJson;
    if (type2 == 'select' || type2 == 'multi_select') {
      optionsJson = {
        'values': options
            .map((x) => x.trim())
            .where((x) => x.isNotEmpty)
            .toList(),
      };
    }

    return _CleanedField(
      label: label2,
      key: key2,
      type: type2,
      optionsJson: optionsJson,
    );
  }

  static String _autoKey(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}

class _CleanedField {
  final String label, key, type;
  final Map<String, dynamic>? optionsJson;
  _CleanedField({
    required this.label,
    required this.key,
    required this.type,
    required this.optionsJson,
  });
}

// --- FIELD COMPONENT ---

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.field,
    required this.onChanged,
    required this.onDelete,
  });
  final _FieldDraft field;
  final ValueChanged<_FieldDraft> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final types = const <({String value, String label})>[
      (value: 'text', label: 'Text'),
      (value: 'number', label: 'Number'),
      (value: 'rating', label: 'Rating (1–5)'),
      (value: 'bool', label: 'Yes / No'),
      (value: 'select', label: 'Pick one option'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: scheme.primary.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: field.label,
                  // border: InputBorder.none stops the overlapping label issue
                  decoration: const InputDecoration(
                    hintText: 'Field Label',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => onChanged(field.copyWith(label: v)),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.primary.withOpacity(0.5),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: scheme.outline.withOpacity(0.1), height: 1),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: field.type,
              items: types
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.value,
                      child: Text(
                        t.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => onChanged(field.copyWith(type: v ?? 'text')),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (field.type == 'select') ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: field.options.join(', '),
              decoration: InputDecoration(
                hintText: 'Choices (comma separated)',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.4),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) => onChanged(
                field.copyWith(
                  options: v.split(',').map((e) => e.trim()).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
