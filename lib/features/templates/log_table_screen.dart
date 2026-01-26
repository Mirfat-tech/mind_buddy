import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
//import 'package:mind_buddy/router.dart';

class LogTableScreen extends StatefulWidget {
  const LogTableScreen({
    super.key,
    required this.templateId,
    required this.templateKey,
    required this.dayId,
  });

  final String templateId;
  final String templateKey;
  final String dayId;

  @override
  State<LogTableScreen> createState() => _LogTableScreenState();
}

class _LogTableScreenState extends State<LogTableScreen> {
  bool _sortAscending = false;
  final SupabaseClient supabase = Supabase.instance.client;
  bool loading = true;

  List<Map<String, dynamic>> fields = [];
  List<Map<String, dynamic>> entries = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String _getTableName() {
    final key = widget.templateKey.toLowerCase();
    switch (key) {
      case 'goals':
        return 'goal_logs';
      case 'water':
        return 'water_logs';
      case 'sleep':
        return 'sleep_logs';
      case 'cycle':
        return 'menstrual_logs';
      case 'books':
        return 'book_logs';
      case 'income':
        return 'income_logs';
      case 'wishlist':
        return 'wishlist';
      case 'restaurants':
        return 'restaurant_logs';
      case 'movies':
        return 'movie_logs';
      case 'bills':
        return 'bill_logs';
      case 'expenses':
        return 'expense_logs';
      case 'places':
        return 'place_logs';
      case 'tasks':
        return 'task_logs';
      case 'fast':
        return 'fast_logs';
      case 'meditation':
        return 'meditation_logs';
      case 'skin_care':
        return 'skin_care_logs';
      case 'social':
        return 'social_logs';
      case 'study':
        return 'study_logs';
      case 'workout':
        return 'workout_logs';
      case 'mood':
        return 'mood_logs';
      case 'symptoms':
        return 'symptom_logs';
      default:
        return '${key}_logs';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      if (mounted)
        setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final currentTable = _getTableName();
      final f = await supabase
          .from('log_template_fields_v2')
          .select()
          .eq('template_id', widget.templateId)
          .eq('is_hidden', false)
          .order('sort_order');

      final e = await supabase
          .from(currentTable)
          .select()
          .order('day', ascending: _sortAscending);

      if (mounted) {
        setState(() {
          fields = List<Map<String, dynamic>>.from(f);
          entries = List<Map<String, dynamic>>.from(e);
          loading = false;
        });
      }
    } catch (err) {
      debugPrint("Load error: $err");
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    if (_searchQuery.isEmpty) return entries;
    return entries.where((entry) {
      // Safely check if day exists
      // final dateStr = entry['day']?.toString() ?? '';
      final dateMatch = _fmtEntryDate(entry).contains(_searchQuery);

      final contentMatch = entry.values.any((val) {
        if (val == null) return false;
        return val.toString().toLowerCase().contains(_searchQuery);
      });
      return dateMatch || contentMatch;
    }).toList();
  }

  Future<void> _addEntry() async {
    final result = await showDialog<_NewEntryResult>(
      context: context,
      builder: (_) => _NewEntryDialog(
        fields: fields,
        title: 'Add ${widget.templateKey}',
        templateKey: widget.templateKey,
      ),
    );
    if (result == null) return;

    try {
      await supabase.from(_getTableName()).insert({
        'user_id': supabase.auth.currentUser!.id,
        'day': result.day.toIso8601String().substring(0, 10),
        ...result.data,
      });
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final result = await showDialog<_NewEntryResult>(
      context: context,
      builder: (_) => _NewEntryDialog(
        fields: fields,
        title: 'Edit entry',
        initialDay:
            DateTime.tryParse(entry['day']?.toString() ?? '') ?? DateTime.now(),

        initialData: Map<String, dynamic>.from(entry),
        templateKey: widget.templateKey,
      ),
    );
    if (result == null) return;

    try {
      await supabase
          .from(_getTableName())
          .update({
            'day': result.day.toIso8601String().substring(0, 10),
            ...result.data,
          })
          .eq('id', entry['id']);
      _load();
    } catch (err) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update error: $err')));
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await supabase.from(_getTableName()).delete().eq('id', entry['id']);
      _load();
    }
  }

  String _fmtEntryDate(Map<String, dynamic> e) {
    final d = DateTime.tryParse(e['day']?.toString() ?? '');
    return d == null ? '' : '${d.day}/${d.month}/${d.year}';
  }

  String _formatValue(String fieldType, dynamic v) {
    if (v == null || v.toString().isEmpty) return '-';

    if (fieldType == 'rating') {
      // Convert "5.0" or 5 to an int, then repeat the star icon
      int stars = double.tryParse(v.toString())?.toInt() ?? 0;
      return '⭐' * stars;
    }

    if (fieldType == 'bool' || v is bool) return (v == true) ? '✓' : '✗';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: false,
      appBar: AppBar(
        title: Text(widget.templateKey.toUpperCase()),
        centerTitle: true,
        leading: Center(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              radius: 20,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).canPop()
                    ? Navigator.pop(context)
                    : Navigator.pushReplacementNamed(context, '/home'),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : _addEntry,
        label: const Text('Add Log'),
        icon: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search logs...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.3),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _StickyLogTable(
                      entries: _filteredEntries,
                      tableFields: fields,
                      fmtEntryDate: _fmtEntryDate,
                      formatValue: _formatValue,
                      onEdit: _editEntry,
                      onDelete: _confirmDelete,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NewEntryResult {
  final DateTime day;
  final Map<String, dynamic> data;
  const _NewEntryResult({required this.day, required this.data});
}

class _StickyLogTable extends StatelessWidget {
  const _StickyLogTable({
    required this.entries,
    required this.tableFields,
    required this.fmtEntryDate,
    required this.formatValue,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> tableFields;
  final String Function(Map<String, dynamic>) fmtEntryDate;
  final String Function(String, dynamic) formatValue;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty)
      return const Center(child: Text("No matching logs found."));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: DataTable(
          horizontalMargin: 24,
          columnSpacing: 36,
          headingRowColor: MaterialStateProperty.all(
            theme.colorScheme.surfaceVariant.withOpacity(0.4),
          ),
          columns: [
            const DataColumn(label: Text('DATE')),
            ...tableFields.map(
              (f) =>
                  DataColumn(label: Text(f['label'].toString().toUpperCase())),
            ),
          ],
          rows: entries.map((entry) {
            return DataRow(
              onLongPress: () => onDelete(entry),
              cells: [
                DataCell(
                  Text(
                    fmtEntryDate(entry),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => onEdit(entry),
                ),
                ...tableFields.map((f) {
                  final key = f['field_key'];
                  final val = entry.containsKey(key) ? entry[key] : null;
                  if (key == 'amount' ||
                      key == 'amount_ml' ||
                      key == 'cost' ||
                      key == 'estimated_price') {
                    final unit = (entry['unit'] ?? entry['currency'] ?? '')
                        .toString();
                    final shownUnit = unit.isEmpty
                        ? (key == 'amount_ml' ? 'ml' : '')
                        : unit;
                    return DataCell(Text('${val ?? ''} $shownUnit'));
                  }

                  return DataCell(Text(formatValue(f['field_type'], val)));
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NewEntryDialog extends StatefulWidget {
  const _NewEntryDialog({
    required this.fields,
    this.initialDay,
    this.initialData,
    this.title,
    required this.templateKey,
  });
  final List<Map<String, dynamic>> fields;
  final DateTime? initialDay;
  final Map<String, dynamic>? initialData;
  final String? title;
  final String templateKey;

  @override
  State<_NewEntryDialog> createState() => _NewEntryDialogState();
}

class _NewEntryDialogState extends State<_NewEntryDialog> {
  late DateTime day;
  final Map<String, TextEditingController> controllers = {};
  final Map<String, dynamic> values = {};

  @override
  void initState() {
    super.initState();

    day = widget.initialDay ?? DateTime.now();

    // Define which types are NOT text-based
    final specialTypes = ['rating', 'bool', 'dropdown', 'time', 'scale'];
    final specialKeys = [
      'products',
      'skin_condition',
      'people',
      'study_methods',
      'hours_slept',
      'paid',
      'is_done',
      'duration_hours',
      'energy_level',
      'severity',
      'intensity',
    ];

    final numericKeys = [
      'hours_slept',
      'duration_hours',
      'energy_level',
      //   'amount_ml',
      'duration_minutes',
      'intensity',
      'weight_kg',
      'price',
      'priority',
      'sets',
      'reps',
    ];

    for (var f in widget.fields) {
      final key = f['field_key'];
      final initVal = widget.initialData?[key];
      // ✅ Always treat money inputs as text (so decimals like 12.50 work)
      if (key == 'amount' ||
          key == 'cost' ||
          key == 'price' ||
          key == 'estimated_price') {
        controllers[key] = TextEditingController(
          text: initVal?.toString() ?? '',
        );
        continue;
      }

      // 1. Handle Numeric Sliders & Ratings
      if (numericKeys.contains(key) ||
          f['field_type'] == 'rating' ||
          key == 'severity') {
        if (initVal == null || initVal.toString().isEmpty) {
          values[key] = (key == 'intensity') ? 5.0 : 0.0;
        } else {
          values[key] = double.tryParse(initVal.toString()) ?? 0.0;
        }
      }
      // 2. Handle Booleans
      else if (f['field_type'] == 'bool') {
        values[key] = initVal ?? false;
      }
      // 3. Handle Dropdowns & Multi-select (Strings in 'values' map)
      else if (f['field_type'] == 'time') {
        controllers[key] = TextEditingController(
          text: initVal?.toString() ?? '',
        );
      } else if ([
            'dropdown',
            'multi_select',
            'date',
          ].contains(f['field_type']) ||
          [
            'products',
            'skin_condition',
            'people',
            'study_methods',
            'feeling',
            'mood',
          ].contains(key)) {
        values[key] = initVal?.toString() ?? "";
      }
      // 4. Handle Text Fields (The part that was breaking)
      else {
        controllers[key] = TextEditingController(
          text: initVal?.toString() ?? '',
        );
      }
    }
  }

  Future<void> _selectTime(String key) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        // Formats it as "HH:mm" (e.g., 22:30)
        final localizations = MaterialLocalizations.of(context);
        controllers[key]?.text = localizations.formatTimeOfDay(
          picked,
          alwaysUse24HourFormat: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final tKey = widget.templateKey.toLowerCase();

    List<Map<String, dynamic>> sortedFields = List.from(widget.fields);
    sortedFields.sort(
      (a, b) => (a['sort_order'] ?? 99).compareTo(b['sort_order'] ?? 99),
    );

    return AlertDialog(
      title: Text(widget.title ?? 'New Entry'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel(label: "Date"),
              _buildDateButton(theme),
              const SizedBox(height: 16),
              ...sortedFields.map((f) => _buildField(f, theme)),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          // Inside your Save Entry FilledButton
          onPressed: () {
            // 1. Start with a copy of the special values (sliders, dates, etc.)
            final data = Map<String, dynamic>.from(values);

            // 2. Overwrite/Add text values from controllers
            controllers.forEach((k, c) => data[k] = c.text);

            // 1. DYNAMIC CURRENCY FIX:
            // If the user picked a currency from your dropdown, make sure it's in the data
            // We check for 'currency' and 'unit' as these are the common dropdown keys
            if (values.containsKey('currency'))
              data['currency'] = values['currency'];
            if (values.containsKey('unit')) data['unit'] = values['unit'];

            // CRITICAL FIXES:
            // 1. Force Quality/Rating to Integer
            if (data.containsKey('quality')) {
              data['quality'] = (data['quality'] as num?)?.toInt() ?? 0;
            }

            // 2. Format Date for Supabase (YYYY-MM-DD)
            // Ensure we aren't sending 'target_date' if it's empty
            if (data.containsKey('target_date') &&
                data['target_date'].toString().isEmpty) {
              data.remove('target_date');
            }

            // 3. Ensure numeric fields are actually numbers
            if (data.containsKey('hours_slept')) {
              data['hours_slept'] =
                  double.tryParse(data['hours_slept'].toString()) ?? 0.0;
            }

            // 3. CRITICAL: Force integers for DB compatibility (Fixes the 11.0 error)
            final intKeys = [
              'rating',
              'quality',
              'focus_rating',
              'priority',
              'intensity',
              'severity',
              'libido',
              'energy_level',
            ];

            // Force integer columns safely
            for (final k in intKeys) {
              final v = data[k];
              if (v == null) continue;

              final parsed = (v is num) ? v : num.tryParse(v.toString());
              if (parsed != null) data[k] = parsed.toInt();
            }

            // Decimal safety for numeric columns like amount/price
            // Decimal safety for numeric money fields
            for (final k in ['amount', 'price', 'cost', 'estimated_price']) {
              if (!data.containsKey(k)) continue;
              final v = data[k];
              data[k] = (v == null || v.toString().isEmpty)
                  ? 0.0
                  : (double.tryParse(v.toString()) ?? 0.0);
            }

            // ✅ Water fix: parse amount_ml too
            if (data.containsKey('amount_ml')) {
              final v = data['amount_ml'];
              data['amount_ml'] = (v == null || v.toString().isEmpty)
                  ? 0.0
                  : (double.tryParse(v.toString()) ?? 0.0);
            }
            // ---- EXPENSES: map amount -> cost (because expense_logs uses 'cost' not 'amount')

            // 4. Ensure date fields aren't empty strings (Fixes the date error)
            if (data['target_date'] == null ||
                data['target_date'].toString().isEmpty) {
              // Optional: remove it or set a default if the column allows nulls
              data.remove('target_date');
            }
            // ✅ Only enforce 'amount' for tables that actually have an 'amount' column
            final tKey = widget.templateKey.toLowerCase();

            // ✅ EXPENSES: ensure we only send 'cost' (never 'amount')
            if (tKey == 'expenses') {
              // If UI field is 'amount', convert it -> cost
              if (data.containsKey('amount') && !data.containsKey('cost')) {
                data['cost'] = data['amount'];
              }
              data.remove('amount');

              // Parse cost to double
              final v = data['cost'];
              data['cost'] = (v == null || v.toString().trim().isEmpty)
                  ? 0.0
                  : (double.tryParse(v.toString()) ?? 0.0);
            } else {
              // Expenses table uses 'cost'
              if (data.containsKey('cost')) {
                final v = data['cost'];
                data['cost'] = (v == null || v.toString().isEmpty)
                    ? 0.0
                    : (double.tryParse(v.toString()) ?? 0.0);
              }
            }
            debugPrint("SAVING (${widget.templateKey}): $data");

            Navigator.pop(context, _NewEntryResult(day: day, data: data));
          },
          child: const Text('Save Entry'),
        ),
      ],
    );
  }

  Widget _buildField(Map<String, dynamic> f, ThemeData theme) {
    final key = f['field_key'];

    if (f['field_type'] == 'date') {
      return ListTile(
        title: Text("${f['label']}: ${values[key] ?? 'Select Date'}"),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setState(
              () => values[key] = picked.toIso8601String().split('T')[0],
            );
          }
        },
      );
    }
    // 1. CONSOLIDATED DROPDOWN & MULTI-SELECT
    if (f['field_type'] == 'dropdown' ||
        f['field_type'] == 'multi_select' ||
        [
          'exercise',
          'exercises',
          'flow',
          'category',
          'cuisine_type',
          'routine_type',
          'symptoms',
          'feeling',
          'status',
          'genre',
          'subject',
          'study_methods',
          'people',
          'currency',
        ].contains(key)) {
      List<String> options = _getDropdownOptions(key);
      bool isMulti =
          (key == 'exercise' ||
          key == 'exercises' ||
          key == 'exercises' ||
          key == 'symptoms' ||
          key == 'products' ||
          key == 'skin_condition' ||
          key == 'people' ||
          key == 'study_methods' ||
          key == 'feeling' || // Added
          key == 'mood');

      // SAFETY CHECK: If for some reason a controller got in here, convert to string
      final dynamic currentVal = values[key] is TextEditingController
          ? ""
          : values[key];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: f['label']),
          isMulti
              ? Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: options.map((option) {
                    bool selected = currentVal.toString().contains(option);
                    return FilterChip(
                      label: Text(option),
                      selected: selected,
                      onSelected: (bool value) {
                        setState(() {
                          List<String> current = currentVal
                              .toString()
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          if (value) {
                            if (!current.contains(option)) current.add(option);
                          } else {
                            current.remove(option);
                          }
                          values[key] = current.join(', ');
                        });
                      },
                    );
                  }).toList(),
                )
              : DropdownButtonFormField<String>(
                  // 1. Check if options contains the value, otherwise force null
                  value:
                      (options.contains(currentVal.toString()) &&
                          currentVal.toString().isNotEmpty)
                      ? currentVal.toString()
                      : null,
                  // 2. .toSet().toList() removes any duplicate strings in your list that cause crashes
                  items: options
                      .toSet()
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (v) => setState(() => values[key] = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  isExpanded: true,
                ),
          const SizedBox(height: 16),
        ],
      );
    }
    // Handle Sliders (Hours Slept, Fasting Duration, Energy)
    // --- 3. Numeric Sliders & Ratings ---
    if ([
          'hours_slept',
          'duration_hours',
          'energy_level',
          'priority',
          'intensity',
        ].contains(key) ||
        f['field_type'] == 'rating') {
      if (f['field_type'] == 'rating' ||
          ['severity', 'quality', 'focus_rating'].contains(key)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(label: f['label']),
            _RatingPicker(
              value: values[key] ?? 0,
              onChanged: (v) => setState(() => values[key] = v),
            ),
            const SizedBox(height: 16),
          ],
        );
      }

      double maxVal = (key == 'duration_hours')
          ? 72.0
          : (key == 'hours_slept' ? 24.0 : 10.0);
      double current = (values[key] ?? 0.0).toDouble().clamp(0.0, maxVal);
      return Column(
        children: [
          _FieldLabel(label: "${f['label']}: ${current.toInt()}"),
          Slider(
            value: current,
            min: 0,
            max: maxVal,
            divisions: maxVal.toInt(),
            onChanged: (v) => setState(() => values[key] = v),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // --- 4. Booleans ---
    if (f['field_type'] == 'bool' ||
        ['paid', 'is_done', 'goal_reached'].contains(key)) {
      return SwitchListTile(
        title: Text(
          f['label'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        value: values[key] == true,
        onChanged: (v) => setState(() => values[key] = v),
      );
    }

    if (key == 'intensity') {
      // FIX: Ensure current value isn't 0.0 (which causes the crash)
      double current = (values[key] ?? 5.0).toDouble();
      if (current < 1.0) current = 1.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: "${f['label']}: ${current.toInt()}"),
          Slider(
            value: current,
            min: 1, // Slider starts at 1
            max: 10,
            divisions: 9,
            onChanged: (v) => setState(() => values[key] = v),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    if (f['field_type'] == 'slider' || key == 'sets' || key == 'reps') {
      double maxVal = (key == 'reps') ? 30.0 : 12.0;
      // Ensure we have a double for the slider
      double currentSliderVal = 0.0;
      if (values[key] is num) {
        currentSliderVal = (values[key] as num).toDouble();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: "${f['label']}: ${currentSliderVal.toInt()}"),
          Slider(
            value: currentSliderVal.clamp(0.0, maxVal),
            min: 0,
            max: maxVal,
            divisions: maxVal.toInt(), // Makes it snap to whole numbers
            label: currentSliderVal.toInt().toString(),
            onChanged: (val) {
              setState(() {
                values[key] = val;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // Handle Ratings
    if (f['field_type'] == 'rating' ||
        [
          'severity',
          'focus_rating',
          'quality',
          'libido', // Added for Menstrual
          'energy_level', // Added for Menstrual
          'stress_level', // Added for Menstrual
        ].contains(key)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: f['label']),
          _RatingPicker(
            value: values[key] ?? 0,
            onChanged: (v) => setState(() => values[key] = v),
          ),
          const SizedBox(height: 16),
        ],
      );
    }
    final hint = (key == 'bedtime' || key == 'wake_up_time')
        ? "Tap to select time"
        : null; // This removes the "Enter your thoughts" text from everything else

    // Default Text Fields
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: f['label']),
        TextField(
          controller: controllers[key],

          keyboardType:
              (key == 'amount' ||
                  key == 'cost' ||
                  key == 'price' ||
                  key == 'estimated_price' ||
                  key == 'weight_kg' ||
                  key == 'current_page' ||
                  key == 'sets' ||
                  key == 'reps')
              ? const TextInputType.numberWithOptions(decimal: true)
              : (key == 'notes' || key == 'note' || key == 'action_plan')
              ? TextInputType.multiline
              : TextInputType.text,
          textInputAction:
              (key == 'notes' || key == 'note' || key == 'action_plan')
              ? TextInputAction.newline
              : TextInputAction.done,

          // If it's a "time" field, we make it read-only so they have to use our picker
          readOnly:
              f['field_type'] == 'time' ||
              key == 'bedtime' ||
              key == 'wake_up_time',
          onTap:
              (f['field_type'] == 'time' ||
                  key == 'bedtime' ||
                  key == 'wake_up_time')
              ? () => _selectTime(key)
              : null,
          maxLines:
              (key == 'notes' ||
                  key == 'note' ||
                  key == 'action_plan' ||
                  key == 'feeling' ||
                  key == 'products')
              ? 4
              : 1,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon:
                (f['field_type'] == 'time' ||
                    key == 'bedtime' ||
                    key == 'wake_up_time')
                ? const Icon(Icons.access_time)
                : null,
            prefixIcon: key == 'current_page'
                ? const Icon(Icons.bookmark_outline)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  List<String> _getDropdownOptions(String key) {
    final tKey = widget.templateKey.toLowerCase();
    List<String> options = [];

    // --- 1. CATEGORY LOGIC
    if (key == 'category') {
      if (tKey == 'bills') {
        options = [
          '🏠 Rent/Mortgage',
          '⚡ Utilities (Elec/Water)',
          '📱 Phone/Internet',
          '🚗 Insurance',
          '📺 Subscription',
          '💳 Credit Card',
          '🎓 Loan/Education',
          '🛠️ Maintenance',
        ];
      } else if (tKey == 'goals') {
        options = [
          '🎉 Annual Resolution',
          '🏆 Life Goal',
          '💪 Fitness',
          '📚 Learning',
          '🧠 Mental Well-being',
        ];
      } else if (tKey == 'income') {
        options = [
          '💰 Salary',
          '💻 Freelance',
          '📈 Investment',
          '🎁 Gift',
          '🔄 Refund',
          '🏦 Interest',
          '🧸 Selling Items',
        ];
      } else if (tKey == 'books') {
        options = [
          'Fiction',
          'Non-Fiction',
          'Mystery',
          'Thriller',
          'Sci-Fi',
          'Fantasy',
          'Romance',
          'Historical',
          'Horror',
          'Graphic Novel',
          'Young Adult',
          'Self-Help',
          'Business',
          'Textbook',
          'Research Paper',
          'Poetry',
          'Drama/Plays',
        ];
      }
    }
    // --- 2. STATUS LOGIC ---
    else if (key == 'status') {
      if (tKey == 'expenses') {
        options = ['✅ Paid', '⏳ Pending', '🟡 Cleared', '❌ Cancelled'];
      } else if (tKey == 'movies' || tKey == 'tv') {
        options = ['⏳ Watchlist', '🍿 Watching', '✅ Finished', '❌ Abandoned'];
      } else if (tKey == 'wishlist') {
        options = ['🛍️ To Buy', '📦 Ordered', '⏳ Waiting', '✅ Received'];
      } else if (tKey == 'income') {
        options = ['✅ Received', '⏳ Expected', '📅 Scheduled'];
      }
    }
    // --- 3. EXERCISE LOGIC (Fixes Multi-select) ---
    else if (key == 'exercise' || key == 'exercises') {
      options = [
        'Bench Press',
        'Squat',
        'Deadlift',
        'Pushups',
        'Pullups',
        'Plank',
        'Running',
      ];
    } else if (key == 'skin_condition') {
      options = [
        '✨ Clear',
        '🕳️ Pitted',
        '🌵 Dry',
        '🛢️ Oily',
        '🔴 Redness',
        '🌋 Active Acne',
        '🩹 Scars',
        '🧖 Pores',
        'Other',
      ];
    }
    // --- 4. OTHER LOGIC (Skin, People, Symptoms, etc.) ---
    else if (key == 'feeling') {
      options = [
        '😊 Happy',
        '🤩 Excited',
        '😎 Confident',
        '🧘 Calm',
        '😐 Neutral',
        '😔 Sad',
        '😤 Angry',
        '🤯 Stressed',
        '🤔 Anxious',
        '😴 Tired',
        '🤒 Sick',
      ];
    } else if (key == 'symptoms') {
      options = [
        'Cramps',
        'Headache',
        'Bloating',
        'Acne',
        'Mood Swings',
        'Fatigue',
      ];
    }
    if (key == 'category' && tKey == 'expenses') {
      options = [
        '🛒 Groceries',
        '🍱 Dining & Takeout',
        '🚗 Transport/Fuel',
        '🛍️ Shopping/Retail',
        '🏥 Health & Medical',
        '🎬 Entertainment',
        '🏠 Household/Home',
        '🛡️ Personal Care',
        '✈️ Travel',
      ];
    } else if (key == 'activity_type') {
      options = [
        '☕ Coffee/Cafe',
        '🍽️ Dinner/Lunch',
        '🍻 Drinks/Nightlife',
        '🍿 Movie/Show',
        '🚶 Walk/Hike',
        '🎮 Gaming',
        '🛍️ Shopping',
        '🏠 Chilling at Home',
        'Other',
      ];
    } else if (key == 'people') {
      options = [
        'Family',
        'Partner',
        'Best Friends',
        'Work Colleagues',
        'New Acquaintance',
        'Large Group',
        'Solo (Public)',
        'Other',
      ];
    } else if (key == 'products') {
      options = [
        '🧼 Cleanser',
        '🧪 Serum',
        '🧴 Moisturizer',
        '☀️ SPF',
        '💧 Toner',
        '✨ Retinol',
        '🧪 Vitamin C',
        '💊 Exfoliant',
        '👁️ Eye Cream',
        '🎭 Face Mask',
        '🩹 Pimple Patch',
      ];
    } else if (key == 'unit') {
      options = ['ml', 'oz', 'Glasses', 'Litres'];
    } else if (key == 'routine_type') {
      options = [
        '☀️ Morning (AM)',
        '🌙 Evening (PM)',
        '🧖 Mid-day Refresh',
        '🛁 Weekly Treatment',
      ];
    } else if (key == 'cuisine_type') {
      options = [
        '🍕 Italian',
        '🌮 Mexican',
        '🍣 Japanese',
        '🍜 Chinese',
        '🥘 Indian',
        '🍔 American',
        '🥗 Mediterranean',
        '🥖 French',
        '☕ Cafe/Bakery',
        '🥙 Middle Eastern',
        '🍷 Steakhouse',
      ];
    } else if (key == 'location' && tKey == 'movies') {
      options = [
        '🏠 Home',
        '🎬 Cinema',
        '🛋️ Friend/Relative',
        '✈️ Airplane',
        '🚌 Commute',
      ];
    } else if (key == 'genre' && tKey == 'movies') {
      options = [
        'Action',
        'Comedy',
        'Drama',
        'Horror',
        'Sci-Fi',
        'Documentary',
        'Anime',
        'Romance',
        'Other',
      ];
    } else if (key == 'technique') {
      options = [
        '🌬️ Breathwork',
        '🧘 Mindfulness',
        '👁️ Visualization',
        '🌌 Scan (Body/Energy)',
        '🚶 Walking Meditation',
      ];
    } else if (key == 'subject') {
      options = [
        '📚 Math',
        '🧬 Science',
        '✍️ English',
        '⚖️ Law',
        '💻 Programming',
        '🎨 Art/Design',
        '🌍 Languages',
        '📈 Business',
        '🌍 Religion',
      ];
    } else if (key == 'study_methods') {
      options = [
        '⏲️ Pomodoro',
        '🃏 Flashcards',
        '📝 Note Taking',
        '🧠 Active Recall',
        '🎧 Deep Work',
        '👥 Group Study',
      ];
    } else if (key == 'symptoms') {
      options = [
        'Cramps',
        'Headache',
        'Bloating',
        'Acne',
        'Mood Swings',
        'Fatigue',
        'Cravings',
        'Back Pain',
      ];
    } else if (key == 'expenses') {
      options = ['Groceries', 'Dining', 'Shopping', 'Health', 'Travel'];
    } // --- MOOD & FEELING SHARED LOGIC ---
    if (key == 'feeling' || key == 'mood' || tKey == 'mood') {
      options = [
        '😊 Happy',
        '🤩 Excited',
        '😎 Confident',
        '🧘 Calm',
        '😐 Neutral',
        '😔 Sad',
        '😤 Angry',
        '🤯 Stressed',
        '🤔 Anxious',
        '😴 Tired',
        '🤒 Sick',
      ];
    }
    // --- NEW CURRENCY LOGIC ---
    if (key == 'currency') {
      options = [
        'USD (\$)',
        'EUR (€)',
        'GBP (£)',
        'JPY (¥)',
        'AUD (\$)',
        'CAD (\$)',
        'INR (₹)',
      ];
    }
    if (key == 'flow') {
      options = ['Spotting', 'Light', 'Medium', 'Heavy', 'Very Heavy', 'Other'];
    }
    if (key == 'pregnancy_test') {
      options = ['Not Done', 'Positive', 'Negative', 'Inconclusive', 'Other'];
    }

    // Always ensure 'Other' is at the end and the list is unique
    if (options.isEmpty) {
      options = ['Other'];
    } else if (!options.contains('Other')) {
      options.add('Other');
    }

    return options.toSet().toList().where((s) => s.trim().isNotEmpty).toList();
  }
  /////-------------------------

  Widget _buildDateButton(ThemeData theme) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: day,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (d != null) setState(() => day = d);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text("${day.day}/${day.month}/${day.year}"),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}

class _RatingPicker extends StatelessWidget {
  const _RatingPicker({required this.value, required this.onChanged});
  final dynamic value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final int cur = (value is num) ? value.toInt() : 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (i) => IconButton(
          icon: Icon(
            i < cur ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
          onPressed: () => onChanged(i + 1),
        ),
      ),
    );
  }
}
