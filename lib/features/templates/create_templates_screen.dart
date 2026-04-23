import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/features/templates/data/repository/custom_templates_repository.dart';
import 'package:mind_buddy/features/templates/data/repository/template_logs_repository.dart';

class CreateLogTemplateScreen extends ConsumerStatefulWidget {
  const CreateLogTemplateScreen({super.key, this.templateId});

  final String? templateId;

  @override
  ConsumerState<CreateLogTemplateScreen> createState() =>
      _CreateLogTemplateScreenState();
}

class _CreateLogTemplateScreenState
    extends ConsumerState<CreateLogTemplateScreen> {
  final supabase = Supabase.instance.client;
  final nameCtrl = TextEditingController();
  final keyCtrl = TextEditingController();

  bool saving = false;
  bool _loadingTemplate = false;

  final fields = <_FieldDraft>[
    _FieldDraft(label: 'Item', key: '', type: 'text'),
  ];
  List<_FieldDraft> _originalFields = const <_FieldDraft>[];

  bool get _isEditing => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingTemplate();
    }
  }

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

  Future<void> _loadExistingTemplate() async {
    final user = supabase.auth.currentUser;
    final templateId = widget.templateId;
    if (user == null || templateId == null) return;

    setState(() => _loadingTemplate = true);
    try {
      final repo = ref.read(customTemplatesRepositoryProvider);
      final tpl = await repo.loadTemplateById(
        templateId: templateId,
        userId: user.id,
      );
      if (tpl == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This template could not be loaded for editing.'),
          ),
        );
        Navigator.pop(context);
        return;
      }
      final loadedFields = tpl.fields.map(_FieldDraft.fromDatabase).toList();

      if (!mounted) return;
      setState(() {
        nameCtrl.text = tpl.name;
        keyCtrl.text = tpl.templateKey;
        fields
          ..clear()
          ..addAll(
            loadedFields.isEmpty
                ? <_FieldDraft>[
                    _FieldDraft(label: 'Item', key: '', type: 'text'),
                  ]
                : loadedFields,
          );
        _originalFields = List<_FieldDraft>.from(loadedFields);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load template: $e')));
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _loadingTemplate = false);
      }
    }
  }

  Future<bool> _existingLogsNeedWarning() async {
    if (!_isEditing || widget.templateId == null) return false;
    final beforeById = <String, _FieldDraft>{
      for (final field in _originalFields)
        if (field.id != null) field.id!: field,
    };
    var changedDefinition = false;

    for (final field in fields) {
      final id = field.id;
      if (id == null) continue;
      final original = beforeById[id];
      if (original == null) continue;
      if (original.type != field.type ||
          original.label.trim() != field.label.trim()) {
        changedDefinition = true;
        break;
      }
    }

    final removedExistingIds = beforeById.keys.where(
      (id) => !fields.any((field) => field.id == id),
    );
    if (!changedDefinition && removedExistingIds.isEmpty) {
      return false;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return false;
    final templateKey = keyCtrl.text.trim().toLowerCase();
    final repo = ref.read(templateLogsRepositoryProvider);
    final localEntries = await repo.loadEntries(
      templateId: widget.templateId!,
      templateKey: templateKey,
      userId: user.id,
    );
    return localEntries.isNotEmpty;
  }

  Future<bool> _confirmDefinitionChangeIfNeeded() async {
    final needsWarning = await _existingLogsNeedWarning();
    if (!needsWarning || !mounted) return true;
    final keepGoing = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update template structure?'),
        content: const Text(
          'Existing logs will stay saved. Renamed fields will keep their old data linked, and removed fields will be hidden so older logs are not corrupted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    return keepGoing == true;
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

    if (_isEditing) {
      final continueSave = await _confirmDefinitionChangeIfNeeded();
      if (!continueSave) return;
    }

    setState(() => saving = true);

    try {
      final repo = ref.read(customTemplatesRepositoryProvider);
      if (_isEditing) {
        await repo.saveTemplate(
          templateId: widget.templateId!,
          userId: user.id,
          name: name,
          templateKey: keyCtrl.text.trim(),
          fields: cleanedFields
              .map(
                (field) => CustomTemplateDraftField(
                  id: field.id,
                  label: field.label,
                  fieldKey: field.key,
                  fieldType: field.type,
                  options: field.optionsJson?.toString(),
                ),
              )
              .toList(growable: false),
        );
      } else {
        final baseKey = _slugify(keyCtrl.text.isEmpty ? name : keyCtrl.text);
        final templateKey = await repo.uniqueTemplateKey(
          userId: user.id,
          baseKey: baseKey,
        );
        await repo.saveTemplate(
          userId: user.id,
          name: name,
          templateKey: templateKey,
          fields: cleanedFields
              .map(
                (field) => CustomTemplateDraftField(
                  id: field.id,
                  label: field.label,
                  fieldKey: field.key,
                  fieldType: field.type,
                  options: field.optionsJson?.toString(),
                ),
              )
              .toList(growable: false),
        );
      }

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
        leading: MbGlowBackButton(onPressed: () => Navigator.pop(context)),
        title: Text(_isEditing ? 'Edit Template' : 'New Template'),
        actions: [
          MbGlowIconButton(
            icon: Icons.check,
            tooltip: saving
                ? 'Saving...'
                : (_isEditing ? 'Save changes' : 'Save'),
            onPressed: saving ? null : _save,
          ),
        ],
      ),
      body: MbFloatingHintOverlay(
        hintKey: 'hint_templates_create',
        text: _isEditing
            ? 'Adjust the template, then save your changes.'
            : 'Add fields, then tap Save to build your table.',
        iconText: '✨',
        child: _loadingTemplate
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
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
                              border: Border.all(
                                color: scheme.primary.withOpacity(0.1),
                              ),
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
                          _isEditing
                              ? 'Shape your custom template gently:'
                              : 'Create your own table in 3 steps:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        _StepsRow(scheme: scheme),
                        const SizedBox(height: 24),
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
                        if (_isEditing) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Renaming a field keeps its existing logs linked. Removing one hides it from the template so older data stays safe.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
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
                            onMoveUp: i == 0
                                ? null
                                : () => setState(() {
                                    final current = fields[i];
                                    fields[i] = fields[i - 1];
                                    fields[i - 1] = current;
                                  }),
                            onMoveDown: i == fields.length - 1
                                ? null
                                : () => setState(() {
                                    final current = fields[i];
                                    fields[i] = fields[i + 1];
                                    fields[i + 1] = current;
                                  }),
                            onDelete: () => setState(() {
                              fields.removeAt(i);
                              if (fields.isEmpty) {
                                fields.add(
                                  _FieldDraft(
                                    label: 'Item',
                                    key: '',
                                    type: 'text',
                                  ),
                                );
                              }
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
      ),
    );
  }
}

// --- DATA CLASSES ---

class _FieldDraft {
  final String? id;
  final String label;
  final String key;
  final String type;
  final List<String> options;

  _FieldDraft({
    this.id,
    required this.label,
    required this.key,
    required this.type,
    this.options = const [],
  });

  factory _FieldDraft.fromDatabase(Map<String, dynamic> row) {
    final rawOptions = row['options'];
    final values = rawOptions is Map && rawOptions['values'] is List
        ? List<String>.from(
            (rawOptions['values'] as List).map((value) => '$value'),
          )
        : const <String>[];
    return _FieldDraft(
      id: row['id']?.toString(),
      label: (row['label'] ?? '').toString(),
      key: (row['field_key'] ?? '').toString(),
      type: (row['field_type'] ?? 'text').toString(),
      options: values,
    );
  }

  _FieldDraft copyWith({
    String? id,
    String? label,
    String? key,
    String? type,
    List<String>? options,
  }) {
    return _FieldDraft(
      id: id ?? this.id,
      label: label ?? this.label,
      key: key ?? this.key,
      type: type ?? this.type,
      options: options ?? this.options,
    );
  }

  _CleanedField cleaned() {
    final label2 = label.trim();
    final key2 = key.trim().isEmpty ? _autoKey(label2) : _autoKey(key);
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
      id: id,
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
  final String? id;
  final String label, key, type;
  final Map<String, dynamic>? optionsJson;
  _CleanedField({
    required this.id,
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
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });
  final _FieldDraft field;
  final ValueChanged<_FieldDraft> onChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const types = <({String value, String label})>[
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
                onPressed: onMoveUp,
                icon: Icon(
                  Icons.keyboard_arrow_up,
                  size: 18,
                  color: scheme.primary.withOpacity(
                    onMoveUp == null ? 0.2 : 0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: onMoveDown,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: scheme.primary.withOpacity(
                    onMoveDown == null ? 0.2 : 0.5,
                  ),
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
              initialValue: field.type,
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
        _StepChip(number: '1', label: 'Name it', scheme: scheme),
        const SizedBox(width: 8),
        _StepChip(number: '2', label: 'Add fields', scheme: scheme),
        const SizedBox(width: 8),
        _StepChip(number: '3', label: 'Save', scheme: scheme),
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
          Text(label, style: Theme.of(context).textTheme.labelMedium),
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
    final previewFields = fields
        .where((f) => f.label.trim().isNotEmpty)
        .toList();
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
          Text('Preview', style: Theme.of(context).textTheme.labelLarge),
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
