import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/subscription_limits.dart';

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
  String _examplePreset = 'None';

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

  void _applyExamplePreset(String preset) {
    setState(() {
      _examplePreset = preset;
      final presetFields = _exampleFields(preset);
      if (presetFields.isNotEmpty) {
        fields
          ..clear()
          ..addAll(presetFields);
      }
      if (nameCtrl.text.trim().isEmpty) {
        nameCtrl.text = preset;
      }
    });
  }

  List<_FieldDraft> _exampleFields(String preset) {
    switch (preset) {
      case 'Mood log':
        return [
          _FieldDraft(label: 'Feeling', key: 'feeling', type: 'text'),
          _FieldDraft(label: 'Intensity', key: 'intensity', type: 'rating'),
          _FieldDraft(label: 'Notes', key: 'notes', type: 'text'),
        ];
      case 'Budget':
        return [
          _FieldDraft(label: 'Category', key: 'category', type: 'text'),
          _FieldDraft(label: 'Amount', key: 'amount', type: 'number'),
          _FieldDraft(label: 'Notes', key: 'notes', type: 'text'),
        ];
      case 'Workout':
        return [
          _FieldDraft(label: 'Exercise', key: 'exercise', type: 'text'),
          _FieldDraft(label: 'Sets', key: 'sets', type: 'number'),
          _FieldDraft(label: 'Reps', key: 'reps', type: 'number'),
          _FieldDraft(label: 'Notes', key: 'notes', type: 'text'),
        ];
      default:
        return [];
    }
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
    final info = await SubscriptionLimits.fetchForCurrentUser();
    if (info.isPending) {
      if (mounted) {
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => Navigator.of(context).pushNamed('/subscription'),
        );
      }
      return;
    }
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
      applyBackground: true,
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _GlowPanel(
            child: Column(
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
                const SizedBox(height: 10),
                Text(
                  'Create your own table in 3 steps:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                _StepsRow(scheme: scheme),
                const SizedBox(height: 24),
                _inputWrapper(
                  scheme,
                  child: DropdownButtonFormField<String>(
                    value: _examplePreset,
                    decoration: const InputDecoration(
                      hintText: 'Field examples',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'None', child: Text('Examples')),
                      DropdownMenuItem(
                        value: 'Mood log',
                        child: Text('Mood log'),
                      ),
                      DropdownMenuItem(
                        value: 'Budget',
                        child: Text('Budget'),
                      ),
                      DropdownMenuItem(
                        value: 'Workout',
                        child: Text('Workout'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null || v == 'None') return;
                      _applyExamplePreset(v);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _inputWrapper(
                  scheme,
                  child: TextField(
                    controller: nameCtrl,
                    onChanged: (v) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Template Name',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GlowPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FIELDS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add columns your table should track (e.g. "Cost", "Mood", "Duration").',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < fields.length; i++) ...[
                  _FieldEditor(
                    field: fields[i],
                    onChanged: (f) => setState(() => fields[i] = f),
                    onDelete: () => setState(() {
                      fields.removeAt(i);
                      if (fields.isEmpty)
                        fields.add(
                          _FieldDraft(label: 'Item', key: '', type: 'text'),
                        );
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => fields.add(
                        _FieldDraft(label: '', key: '', type: 'text'),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Field'),
                  ),
                ),
                const SizedBox(height: 16),
                _PreviewTable(fields: fields),
              ],
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

class _GlowPanel extends StatelessWidget {
  const _GlowPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StepsRow extends StatelessWidget {
  const _StepsRow({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepChip(
          number: '1',
          label: 'Name it',
          scheme: scheme,
        ),
        const SizedBox(width: 8),
        _StepChip(
          number: '2',
          label: 'Add fields',
          scheme: scheme,
        ),
        const SizedBox(width: 8),
        _StepChip(
          number: '3',
          label: 'Save',
          scheme: scheme,
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.scheme,
  });

  final String number;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.fields});

  final List<_FieldDraft> fields;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewFields = fields.where((f) => f.label.trim().isNotEmpty).toList();
    if (previewFields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withOpacity(0.25)),
        ),
        child: Text(
          'Preview will appear here once you add fields.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: previewFields
                .take(4)
                .map(
                  (f) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          Text(
            previewFields.length > 4
                ? '+${previewFields.length - 4} more columns'
                : 'Example row will appear when you start logging.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
