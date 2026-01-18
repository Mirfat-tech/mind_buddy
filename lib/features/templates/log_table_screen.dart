// lib/features/templates/log_table_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';

class LogTableScreen extends StatefulWidget {
  const LogTableScreen({
    super.key,
    required this.templateId, // UUID string
    required this.templateKey, // e.g. "sleep"
    required this.dayId, // "YYYY-MM-DD"
  });

  final String templateId;
  final String templateKey;
  final String dayId;

  @override
  State<LogTableScreen> createState() => _LogTableScreenState();
}

class _LogTableScreenState extends State<LogTableScreen> {
  /// Hide columns from the TABLE (but keep available in Add/Edit dialog)
  final Map<String, Set<String>> hiddenTableColumnsByTemplateKey = {
    'sleep': {'hours_slept', 'sleep_quality'},
    'cycle': {'period_flow'},
  };

  final SupabaseClient supabase = Supabase.instance.client;

  bool loading = true;

  Map<String, dynamic>? template; // {id, template_key, name, ...}
  List<Map<String, dynamic>> fields = [];
  List<Map<String, dynamic>> entries = [];

  // ====== Table names ======
  static const String tTemplates = 'log_templates_v2';
  static const String tFields = 'log_template_fields_v2';
  static const String tEntries = 'log_entries';

  // ====== Column keys ======
  static const String cTemplateId = 'template_id';

  static const String cFieldKey = 'field_key';
  static const String cFieldLabel = 'label';
  static const String cFieldType = 'field_type';

  static const String cEntryId = 'id';
  static const String cEntryDay = 'day'; // "YYYY-MM-DD"
  static const String cEntryData = 'data';
  static const String cEntryCreatedAt = 'created_at';

  Map<String, dynamic> _asMap(dynamic v) => Map<String, dynamic>.from(v as Map);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      // Template (by UUID id)
      final tpl = await supabase
          .from(tTemplates)
          .select()
          .eq('id', widget.templateId)
          .maybeSingle();

      // Fields (by UUID template_id)
      final f = await supabase
          .from(tFields)
          .select()
          .eq(cTemplateId, widget.templateId)
          .eq('is_hidden', false)
          .order('sort_order');

      // Entries (by UUID template_id + day)
      final e = await supabase
          .from(tEntries)
          .select()
          .eq(cTemplateId, widget.templateId)
          .order(cEntryCreatedAt, ascending: false);

      template = (tpl is Map) ? _asMap(tpl) : null;
      fields = (f as List).map<Map<String, dynamic>>((x) => _asMap(x)).toList();

      // Optional: remove sleep_quality from dialog too
      if (widget.templateKey == 'sleep') {
        fields = fields.where((field) {
          final key = (field[cFieldKey] ?? '').toString();
          return key != 'sleep_quality';
        }).toList();
      }

      entries =
          (e as List).map<Map<String, dynamic>>((x) => _asMap(x)).toList();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load error: $err')));
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _addEntry() async {
    final result = await showDialog<_NewEntryResult>(
      context: context,
      builder: (_) => _NewEntryDialog(fields: fields, title: 'Add log entry'),
    );

    if (result == null) return;

    try {
      final dayString = result.day.toIso8601String().substring(0, 10);

      final insert = <String, dynamic>{
        cTemplateId: widget.templateId, // UUID
        cEntryDay: dayString,
        cEntryData: result.data,
      };

      await supabase.from(tEntries).insert(insert);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $err')));
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final initialDataRaw = entry[cEntryData];
    final initialData = (initialDataRaw is Map)
        ? Map<String, dynamic>.from(initialDataRaw)
        : <String, dynamic>{};

    DateTime initialDay = DateTime.now();
    final dayVal = entry[cEntryDay];
    if (dayVal is String) {
      final parsed = DateTime.tryParse(dayVal);
      if (parsed != null) initialDay = parsed;
    } else {
      final created = entry[cEntryCreatedAt];
      if (created is String) {
        final parsed = DateTime.tryParse(created);
        if (parsed != null) initialDay = parsed;
      }
    }

    final result = await showDialog<_NewEntryResult>(
      context: context,
      builder: (_) => _NewEntryDialog(
        fields: fields,
        title: 'Edit log entry',
        initialDay: initialDay,
        initialData: initialData,
      ),
    );

    if (result == null) return;

    try {
      final dayString = result.day.toIso8601String().substring(0, 10);

      final update = <String, dynamic>{
        cEntryDay: dayString,
        cEntryData: result.data,
      };

      await supabase
          .from(tEntries)
          .update(update)
          .eq(cEntryId, entry[cEntryId]);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update error: $err')));
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await supabase.from(tEntries).delete().eq(cEntryId, entry[cEntryId]);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete error: $err')),
      );
    }
  }

  Widget _buildThemedTable(
      BuildContext context, List<Map<String, dynamic>> tableFields) {
    final scheme = Theme.of(context).colorScheme;

    return Theme(
      // forces DataTable to respect your current colorScheme
      data: Theme.of(context).copyWith(
        dividerColor: scheme.outline.withOpacity(0.35),
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(scheme.surface),
        dataRowColor:
            MaterialStateProperty.all(scheme.surface.withOpacity(0.6)),
        columns: [
          const DataColumn(label: Text('Date')),
          ...tableFields.map(
            (f) => DataColumn(label: Text((f[cFieldLabel] ?? '').toString())),
          ),
        ],
        rows: entries.map<DataRow>((e) {
          final dataRaw = e[cEntryData];
          final data = (dataRaw is Map)
              ? Map<String, dynamic>.from(dataRaw)
              : <String, dynamic>{};

          final dateText = _fmtEntryDate(e);

          Widget cellLongPressWrapper(Widget child) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _confirmDelete(e),
              child: child,
            );
          }

          return DataRow(
            onSelectChanged: (_) => _editEntry(e),
            cells: [
              DataCell(cellLongPressWrapper(Text(dateText))),
              ...tableFields.map((f) {
                final key = (f[cFieldKey] ?? '').toString();
                final type = (f[cFieldType] ?? '').toString();
                final v = data[key];
                return DataCell(
                  cellLongPressWrapper(Text(_formatValue(type, v))),
                );
              }).toList(),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hidden =
        hiddenTableColumnsByTemplateKey[widget.templateKey] ?? <String>{};

    final tableFields = fields.where((f) {
      final key = (f[cFieldKey] ?? '').toString();
      return key.isNotEmpty && !hidden.contains(key);
    }).toList();

    final title = (template?['name'] ?? widget.templateKey).toString();

    return MbScaffold(
      applyBackground: false, // ✅ IMPORTANT: let PaperCanvas show through
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        onPressed: loading ? null : _addEntry,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const Center(child: Text('No entries yet. Tap + to add one.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  scrollDirection: Axis.horizontal,
                  child: _buildThemedTable(context, tableFields),
                ),
    );
  }

  String _fmtEntryDate(Map<String, dynamic> e) {
    DateTime? d;
    final dayVal = e[cEntryDay];
    if (dayVal is String) d = DateTime.tryParse(dayVal);

    d ??= (() {
      final created = e[cEntryCreatedAt];
      if (created is String) return DateTime.tryParse(created);
      return null;
    })();

    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String _formatValue(String fieldType, dynamic v) {
    if (v == null) return '';
    if (fieldType == 'rating') return '⭐ ${v.toString()}';
    if (fieldType == 'bool') return (v == true) ? '✓' : '';
    if (fieldType == 'multi_select') {
      if (v is List) return v.map((x) => x.toString()).join(', ');
      return v.toString();
    }
    if (fieldType == 'select') return v.toString();
    return v.toString();
  }
}

class _NewEntryResult {
  final DateTime day;
  final Map<String, dynamic> data;
  const _NewEntryResult({required this.day, required this.data});
}

class _NewEntryDialog extends StatefulWidget {
  const _NewEntryDialog({
    required this.fields,
    this.initialDay,
    this.initialData,
    this.title,
  });

  final List<Map<String, dynamic>> fields;
  final DateTime? initialDay;
  final Map<String, dynamic>? initialData;
  final String? title;

  @override
  State<_NewEntryDialog> createState() => _NewEntryDialogState();
}

class _NewEntryDialogState extends State<_NewEntryDialog> {
  DateTime day = DateTime.now();

  final Map<String, TextEditingController> controllers = {};
  final Map<String, int> rating = {};
  final Map<String, bool> bools = {};
  final Map<String, String> selects = {};
  final Map<String, Set<String>> multiSelects = {};

  static const String cFieldKey = 'field_key';
  static const String cFieldLabel = 'label';
  static const String cFieldType = 'field_type';
  static const String cFieldOptions = 'options';

  @override
  void initState() {
    super.initState();

    day = widget.initialDay ?? DateTime.now();
    final initial = widget.initialData ?? <String, dynamic>{};

    for (final f in widget.fields) {
      final key = (f[cFieldKey] ?? '').toString();
      final type = (f[cFieldType] ?? '').toString();

      if (type == 'rating') {
        final v = initial[key];
        rating[key] = (v is num) ? v.toInt() : 0;
      } else if (type == 'bool') {
        bools[key] = initial[key] == true;
      } else if (type == 'select') {
        selects[key] = (initial[key] ?? '').toString();
      } else if (type == 'multi_select') {
        final v = initial[key];
        multiSelects[key] =
            (v is List) ? v.map((x) => x.toString()).toSet() : <String>{};
      } else {
        controllers[key] = TextEditingController(
          text: initial[key]?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? 'Add log entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_fmtDate(day)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => day = picked);
                },
              ),
            ),
            const SizedBox(height: 12),
            ...widget.fields.map((f) {
              final key = (f[cFieldKey] ?? '').toString();
              final label = (f[cFieldLabel] ?? '').toString();
              final type = (f[cFieldType] ?? '').toString();

              if (type == 'rating') {
                final current = rating[key] ?? 0;
                return _RatingPicker(
                  label: label,
                  value: current,
                  onChanged: (v) => setState(() => rating[key] = v),
                );
              }

              if (type == 'bool') {
                final current = bools[key] ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(label)),
                      Switch(
                        value: current,
                        onChanged: (v) => setState(() => bools[key] = v),
                      ),
                    ],
                  ),
                );
              }

              if (type == 'select') {
                final opts = _optionsValues(f);
                final current = (selects[key] ?? '').trim();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: current.isEmpty ? null : current,
                    items: opts
                        .map(
                          (v) => DropdownMenuItem<String>(
                            value: v,
                            child: Text(v),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selects[key] = v ?? ''),
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }

              if (type == 'multi_select') {
                final opts = _optionsValues(f);
                final selected = multiSelects[key] ?? <String>{};

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: opts.map((v) {
                          final isOn = selected.contains(v);
                          return FilterChip(
                            label: Text(v),
                            selected: isOn,
                            onSelected: (on) {
                              setState(() {
                                final set = multiSelects[key] ?? <String>{};
                                if (on) {
                                  set.add(v);
                                } else {
                                  set.remove(v);
                                }
                                multiSelects[key] = set;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[key],
                  keyboardType: type == 'number'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final data = <String, dynamic>{};

            for (final f in widget.fields) {
              final key = (f[cFieldKey] ?? '').toString();
              final type = (f[cFieldType] ?? '').toString();

              if (type == 'rating' ||
                  type == 'bool' ||
                  type == 'select' ||
                  type == 'multi_select') continue;

              final text = controllers[key]?.text.trim() ?? '';
              if (text.isEmpty) continue;

              if (type == 'number') {
                final numVal = num.tryParse(text);
                data[key] = numVal ?? text;
              } else {
                data[key] = text;
              }
            }

            for (final f in widget.fields.where(
              (x) => (x[cFieldType] ?? '') == 'rating',
            )) {
              final key = (f[cFieldKey] ?? '').toString();
              final v = rating[key] ?? 0;
              if (v > 0) data[key] = v;
            }

            for (final f in widget.fields.where(
              (x) => (x[cFieldType] ?? '') == 'bool',
            )) {
              final key = (f[cFieldKey] ?? '').toString();
              data[key] = bools[key] ?? false;
            }

            for (final f in widget.fields.where(
              (x) => (x[cFieldType] ?? '') == 'select',
            )) {
              final key = (f[cFieldKey] ?? '').toString();
              final v = (selects[key] ?? '').trim();
              if (v.isNotEmpty) data[key] = v;
            }

            for (final f in widget.fields.where(
              (x) => (x[cFieldType] ?? '') == 'multi_select',
            )) {
              final key = (f[cFieldKey] ?? '').toString();
              final set = multiSelects[key] ?? <String>{};
              if (set.isNotEmpty) data[key] = set.toList();
            }

            Navigator.pop(context, _NewEntryResult(day: day, data: data));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  List<String> _optionsValues(Map<String, dynamic> f) {
    final raw = f[cFieldOptions];
    if (raw is Map) {
      final values = raw['values'];
      if (values is List) return values.map((x) => x.toString()).toList();
    }
    return <String>[];
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }
}

class _RatingPicker extends StatelessWidget {
  const _RatingPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<int>(
            value: value,
            items: List.generate(6, (i) => i)
                .map(
                  (i) => DropdownMenuItem<int>(
                    value: i,
                    child: Text(i == 0 ? '-' : '$i'),
                  ),
                )
                .toList(),
            onChanged: (v) => onChanged(v ?? 0),
          ),
        ],
      ),
    );
  }
}
