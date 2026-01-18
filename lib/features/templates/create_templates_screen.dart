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

    final baseKey = _slugify(keyCtrl.text.trim().isEmpty ? name : keyCtrl.text);

    final templateKey = await _uniqueTemplateKey(baseKey, user.id);

    // Basic validation: must have at least 1 field
    final cleanedFields = fields
        .where((f) => f.label.trim().isNotEmpty)
        .map((f) => f.cleaned())
        .toList();

    if (cleanedFields.isEmpty) return;

    setState(() => saving = true);

    try {
      // 1) insert template
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

      // 2) insert fields
      final rows = <Map<String, dynamic>>[];
      for (int i = 0; i < cleanedFields.length; i++) {
        final f = cleanedFields[i];
        rows.add({
          'user_id': user.id,
          'template_id': templateId,
          'field_key': f.key,
          'label': f.label,
          'field_type': f.type,
          'sort_order': i,
          'options': f.optionsJson,
          'is_hidden': false,
        });
      }

      await supabase.from(tFields).insert(rows);

      if (!mounted) return;
      Navigator.pop(context, true); // tells caller to refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _addField() {
    setState(() {
      fields.add(_FieldDraft(label: '', key: '', type: 'text'));
    });
  }

  void _removeField(int index) {
    setState(() {
      fields.removeAt(index);
      if (fields.isEmpty) {
        fields.add(_FieldDraft(label: 'Item', key: '', type: 'text'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: false, // ✅ let PaperCanvas show through

      appBar: AppBar(
        title: const Text('Create logs template'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving ? const Text('Saving...') : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            textDirection: TextDirection.ltr,
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Template name',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              if (keyCtrl.text.trim().isEmpty) {
                keyCtrl.text = _slugify(v);
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          //TextField(
          //controller: keyCtrl,
          //decoration: const InputDecoration(
          //labelText: 'Template key (auto)',
          //helperText: 'Used internally, e.g. gym_log',
          //border: OutlineInputBorder(),
          //),
          //),
          const SizedBox(height: 18),
          const Text('Fields', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (int i = 0; i < fields.length; i++) ...[
            _FieldEditor(
              field: fields[i],
              onChanged: (f) => setState(() => fields[i] = f),
              onDelete: () => _removeField(i),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: saving ? null : _addField,
              icon: const Icon(Icons.add),
              label: const Text('Add field'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

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

  _FieldDraft copyWith(
      {String? label, String? key, String? type, List<String>? options}) {
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
      final vals =
          options.map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
      optionsJson = {'values': vals};
    }

    return _CleanedField(
        label: label2, key: key2, type: type2, optionsJson: optionsJson);
  }

  static String _autoKey(String s) {
    final lower = s.trim().toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s_-]'), '');
    final underscored = cleaned.replaceAll(RegExp(r'[\s-]+'), '_');
    return underscored.replaceAll(RegExp(r'_+'), '_');
  }
}

class _CleanedField {
  final String label;
  final String key;
  final String type;
  final Map<String, dynamic>? optionsJson;
  _CleanedField(
      {required this.label,
      required this.key,
      required this.type,
      required this.optionsJson});
}

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
    final types = const <({String value, String label})>[
      (value: 'text', label: 'Text'),
      (value: 'number', label: 'Number'),
      (value: 'rating', label: 'Rating (1–5)'),
      (value: 'bool', label: 'Yes / No'),
      (value: 'select', label: 'Pick one option'),
      (value: 'multi_select', label: 'Pick multiple options'),
    ];

    //final optionsCtrl = TextEditingController(text: field.options.join(', '));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                  initialValue: field.label,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'Label'),
                  onChanged: (v) => onChanged(field.copyWith(label: v)),
                )),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value:
                  types.any((t) => t.value == field.type) ? field.type : 'text',
              items: types
                  .map((t) =>
                      DropdownMenuItem(value: t.value, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => onChanged(field.copyWith(type: v ?? 'text')),
              decoration: const InputDecoration(labelText: 'Answer type'),
            ),
            if (field.type == 'select' || field.type == 'multi_select') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: field.options.join(', '),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'Choices (comma separated)',
                  helperText: 'Example: treadmill, stairmaster, bike',
                ),
                onChanged: (v) {
                  final parts = v
                      .split(',')
                      .map((x) => x.trim())
                      .where((x) => x.isNotEmpty)
                      .toList();
                  onChanged(field.copyWith(options: parts));
                },
              )
            ],
          ],
        ),
      ),
    );
  }
}
