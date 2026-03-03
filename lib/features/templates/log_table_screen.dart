import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
//import 'package:mind_buddy/router.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_floating_hint.dart';
import 'package:mind_buddy/services/subscription_limits.dart';
import 'package:mind_buddy/common/log_table_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_buddy/common/month_navigator.dart';
import 'package:mind_buddy/common/mb_glow_icon_button.dart';
import 'package:mind_buddy/common/input_sanitizer.dart';
import 'package:mind_buddy/guides/guide_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

final logTableMonthProvider = StateProvider.family<DateTime, String>((
  ref,
  key,
) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

class LogTableScreen extends ConsumerStatefulWidget {
  const LogTableScreen({
    super.key,
    required this.templateId,
    required this.templateKey,
    required this.dayId,
    this.readOnly = false,
  });

  final String templateId;
  final String templateKey;
  final String dayId;
  final bool readOnly;

  @override
  ConsumerState<LogTableScreen> createState() => _LogTableScreenState();
}

class _LogTableScreenState extends ConsumerState<LogTableScreen> {
  bool _sortAscending = false;
  String _sortLabel = 'Newest first';
  bool _showTotals = true;
  final SupabaseClient supabase = Supabase.instance.client;
  bool loading = true;
  bool _isPending = false;
  bool _isCoreTemplate = true;
  SubscriptionInfo? _planInfo;
  int _localIdCounter = -1;

  List<Map<String, dynamic>> fields = [];
  List<Map<String, dynamic>> entries = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final GlobalKey _logTableContainerKey = GlobalKey();
  final GlobalKey _dateCellKey = GlobalKey();
  final GlobalKey _logRowItemKey = GlobalKey();

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
      case 'tv_log':
        return 'tv_logs';

      case 'mood':
        return 'mood_logs';
      case 'symptoms':
        return 'symptom_logs';
      default:
        return '${key}_logs';
    }
  }

  bool _enforceUniqueDailyLog(String tableName) {
    return tableName == 'mood_logs' || tableName == 'menstrual_logs';
  }

  String _dayKey(DateTime date) => toYyyyMmDd(date);

  Future<Map<String, dynamic>?> _findExistingDailyLog({
    required String tableName,
    required String userId,
    required String dayKey,
    dynamic excludeId,
  }) async {
    final byDay = await supabase
        .from(tableName)
        .select('id, day')
        .eq('user_id', userId)
        .eq('day', dayKey)
        .limit(1);
    if ((byDay as List).isNotEmpty) {
      final row = Map<String, dynamic>.from(byDay.first);
      if (excludeId == null || row['id'] != excludeId) return row;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    GuideManager.dismissActiveGuideForPage('logTable');
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showGuideIfNeeded({bool force = false}) async {
    final steps = <GuideStep>[
      GuideStep(
        key: _logTableContainerKey,
        title: 'Want the bigger picture?',
        body:
            'Rotate your phone or scroll inside the log box to see the full table.',
        align: GuideAlign.bottom,
      ),
      if (entries.isNotEmpty)
        GuideStep(
          key: _dateCellKey,
          title: 'Need to adjust something?',
          body: 'Tap the date to edit that entry.',
          align: GuideAlign.bottom,
        ),
      if (entries.isNotEmpty)
        GuideStep(
          key: _logRowItemKey,
          title: 'Ready to let it go?',
          body: 'Press and hold a row to delete it.',
          align: GuideAlign.top,
        ),
    ];
    await GuideManager.showGuideIfNeeded(
      context: context,
      pageId: 'logTable',
      force: force,
      steps: steps,
      requireAllTargetsVisible: true,
    );
  }

  void _scheduleGuideAutoStart() {
    if (!mounted || loading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || loading) return;
      Future<void>.delayed(const Duration(milliseconds: 24), () {
        if (!mounted || loading) return;
        _showGuideIfNeeded();
      });
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    final info = await SubscriptionLimits.fetchForCurrentUser();
    _planInfo = info;
    _isPending = info.isPending;
    _isCoreTemplate = await _loadTemplateCoreFlag();

    // 1) Always load fields first
    try {
      final f = await supabase
          .from('log_template_fields_v2')
          .select()
          .eq('template_id', widget.templateId)
          .eq('is_hidden', false)
          .order('sort_order');

      if (mounted) {
        setState(() => fields = List<Map<String, dynamic>>.from(f));
      }
    } catch (err) {
      debugPrint("Field load error: $err");
    }

    // 2) Then try load entries (can fail without breaking the dialog)
    if (_isPending) {
      if (mounted) setState(() => entries = []);
    } else if (_isPreviewMode) {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final preview = await _loadPreviewEntries(user.id);
        if (mounted) {
          setState(() => entries = preview);
        }
      } else if (mounted) {
        setState(() => entries = []);
      }
    } else {
      try {
        final currentTable = _getTableName();
        final e = await supabase
            .from(currentTable)
            .select()
            .eq('user_id', supabase.auth.currentUser!.id)
            .order('day', ascending: _sortAscending);

        if (mounted) {
          setState(() => entries = List<Map<String, dynamic>>.from(e));
          if (currentTable == 'book_logs') {
            for (final row in entries) {
              debugPrint('BOOK_LOG ROW: $row');
            }
          }
        }
      } catch (err) {
        debugPrint("Entries load error: $err");
        // keep entries empty, but fields still exist ✅
      }
    }

    if (mounted) {
      setState(() => loading = false);
      _scheduleGuideAutoStart();
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    final selectedMonth = ref.watch(logTableMonthProvider(widget.templateKey));
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    final monthFiltered = entries.where((entry) {
      final day = _parseEntryDay(entry);
      return !day.isBefore(monthStart) && day.isBefore(monthEnd);
    }).toList();

    final source = _searchQuery.isEmpty
        ? List<Map<String, dynamic>>.from(monthFiltered)
        : monthFiltered.where((entry) {
            // Safely check if day exists
            // final dateStr = entry['day']?.toString() ?? '';
            final dateMatch = _fmtEntryDate(entry).contains(_searchQuery);

            final contentMatch = entry.values.any((val) {
              if (val == null) return false;
              return val.toString().toLowerCase().contains(_searchQuery);
            });
            return dateMatch || contentMatch;
          }).toList();

    source.sort((a, b) {
      final ad = _parseEntryDay(a);
      final bd = _parseEntryDay(b);
      return _sortAscending ? ad.compareTo(bd) : bd.compareTo(ad);
    });
    return source;
  }

  Future<void> _addEntry() async {
    if (widget.readOnly) return;
    final result = await showDialog<_NewEntryResult>(
      context: context,
      builder: (_) => _NewEntryDialog(
        fields: fields,
        title: 'Add ${widget.templateKey}',
        templateKey: widget.templateKey,
      ),
    );
    if (result == null) return;

    if (_isPending) {
      final localEntry = {
        'id': _localIdCounter--,
        'day': result.day.toIso8601String().substring(0, 10),
        ...result.data,
      };
      if (mounted) {
        setState(() {
          entries = [localEntry, ...entries];
        });
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => Navigator.of(context).pushNamed('/subscription'),
        );
      }
      return;
    }

    if (_isPreviewMode) {
      final localEntry = {
        'id': _localIdCounter--,
        'day': result.day.toIso8601String().substring(0, 10),
        '_preview_saved_at': DateTime.now().toIso8601String(),
        ...result.data,
      };
      if (mounted) {
        setState(() {
          entries = [localEntry, ...entries];
        });
      }
      final user = supabase.auth.currentUser;
      if (user != null) {
        await _savePreviewEntries(user.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved in 24-hour preview mode. This template data disappears after 24 hours.',
            ),
          ),
        );
      }
      return;
    }

    try {
      final tableName = _getTableName();
      final userId = supabase.auth.currentUser!.id;
      final dayKey = _dayKey(result.day);
      final payload = <String, dynamic>{
        'user_id': userId,
        'day': dayKey,
        ...result.data,
      };

      if (_enforceUniqueDailyLog(tableName)) {
        final existing = await _findExistingDailyLog(
          tableName: tableName,
          userId: userId,
          dayKey: dayKey,
        );
        if (existing != null) {
          final existingId = existing['id'];
          if (existingId != null) {
            await supabase
                .from(tableName)
                .update({...payload, 'user_id': userId})
                .eq('id', existingId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'You’ve already logged today — updated your existing entry instead.',
                  ),
                ),
              );
            }
            _load();
            return;
          }
        }
      }

      await supabase.from(tableName).insert(payload);
      _load();
    } on PostgrestException catch (e) {
      if (mounted) {
        final isUniqueViolation = e.code == '23505';
        final message = isUniqueViolation
            ? 'You’ve already logged today — edit your existing entry instead.'
            : 'Save error: ${e.message}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    if (widget.readOnly) return;
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

    if (_isPending) {
      final id = entry['id'];
      final updated = {
        ...entry,
        'day': result.day.toIso8601String().substring(0, 10),
        ...result.data,
      };
      if (mounted) {
        setState(() {
          final idx = entries.indexWhere((e) => e['id'] == id);
          if (idx != -1) {
            final copy = List<Map<String, dynamic>>.from(entries);
            copy[idx] = updated;
            entries = copy;
          }
        });
        await SubscriptionLimits.showTrialUpgradeDialog(
          context,
          onUpgrade: () => Navigator.of(context).pushNamed('/subscription'),
        );
      }
      return;
    }

    if (_isPreviewMode) {
      final id = entry['id'];
      final updated = {
        ...entry,
        'day': result.day.toIso8601String().substring(0, 10),
        '_preview_saved_at': DateTime.now().toIso8601String(),
        ...result.data,
      };
      if (mounted) {
        setState(() {
          final idx = entries.indexWhere((e) => e['id'] == id);
          if (idx != -1) {
            final copy = List<Map<String, dynamic>>.from(entries);
            copy[idx] = updated;
            entries = copy;
          }
        });
      }
      final user = supabase.auth.currentUser;
      if (user != null) {
        await _savePreviewEntries(user.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Updated in 24-hour preview mode. This template data disappears after 24 hours.',
            ),
          ),
        );
      }
      return;
    }

    try {
      final tableName = _getTableName();
      final userId = supabase.auth.currentUser!.id;
      final newDayKey = _dayKey(result.day);
      if (_enforceUniqueDailyLog(tableName)) {
        final conflict = await _findExistingDailyLog(
          tableName: tableName,
          userId: userId,
          dayKey: newDayKey,
          excludeId: entry['id'],
        );
        if (conflict != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'A log already exists for that day. Edit the existing entry instead.',
                ),
              ),
            );
          }
          return;
        }
      }

      await supabase
          .from(tableName)
          .update({'day': newDayKey, ...result.data})
          .eq('id', entry['id']);
      _load();
    } on PostgrestException catch (err) {
      if (mounted) {
        final isUniqueViolation = err.code == '23505';
        final message = isUniqueViolation
            ? 'A log already exists for that day. Edit the existing entry instead.'
            : 'Update error: ${err.message}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update error: $err')));
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> entry) async {
    if (widget.readOnly) return;
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
      if (_isPending) {
        if (mounted) {
          setState(() {
            entries = entries.where((e) => e['id'] != entry['id']).toList();
          });
          await SubscriptionLimits.showTrialUpgradeDialog(
            context,
            onUpgrade: () => Navigator.of(context).pushNamed('/subscription'),
          );
        }
        return;
      }
      if (_isPreviewMode) {
        if (mounted) {
          setState(() {
            entries = entries.where((e) => e['id'] != entry['id']).toList();
          });
        }
        final user = supabase.auth.currentUser;
        if (user != null) {
          await _savePreviewEntries(user.id);
        }
      } else {
        await supabase.from(_getTableName()).delete().eq('id', entry['id']);
        _load();
      }
    }
  }

  bool get _isPreviewMode {
    final info = _planInfo;
    if (info == null) return false;
    if (info.isFree) return true;
    if (info.isLight && !_isCoreTemplate) return true;
    return false;
  }

  String _previewStorageKey(String userId) {
    return 'template_preview_entries:$userId:${widget.templateId}';
  }

  Future<bool> _loadTemplateCoreFlag() async {
    try {
      final row = await supabase
          .from('log_templates_v2')
          .select('user_id')
          .eq('id', widget.templateId)
          .maybeSingle();
      return row == null || row['user_id'] == null;
    } catch (_) {
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> _loadPreviewEntries(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_previewStorageKey(userId));
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));
      final decoded = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final filtered = decoded.where((entry) {
        final savedAtRaw = (entry['_preview_saved_at'] ?? '').toString();
        final savedAt = DateTime.tryParse(savedAtRaw);
        if (savedAt == null) return false;
        return savedAt.isAfter(cutoff);
      }).toList();
      if (filtered.length != decoded.length) {
        await prefs.setString(_previewStorageKey(userId), jsonEncode(filtered));
      }
      return filtered;
    } catch (_) {
      await prefs.remove(_previewStorageKey(userId));
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _savePreviewEntries(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    final filtered = entries.where((entry) {
      final savedAtRaw = (entry['_preview_saved_at'] ?? '').toString();
      final savedAt = DateTime.tryParse(savedAtRaw);
      if (savedAt == null) return false;
      return savedAt.isAfter(cutoff);
    }).toList();
    await prefs.setString(_previewStorageKey(userId), jsonEncode(filtered));
  }

  String _fmtEntryDate(Map<String, dynamic> e) {
    final d = DateTime.tryParse(e['day']?.toString() ?? '');
    return d == null ? '' : '${d.day}/${d.month}/${d.year}';
  }

  DateTime _parseEntryDay(Map<String, dynamic> e) {
    final raw = e['day']?.toString();
    if (raw == null || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
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

  String _currencyCode(String raw) {
    final match = RegExp(r'[A-Z]{3}').firstMatch(raw);
    if (match != null) return match.group(0)!;
    return raw.trim();
  }

  String _currencySymbol(String raw) {
    if (raw.contains('£')) return '£';
    if (raw.contains('\$')) return '\$';
    if (raw.contains('€')) return '€';
    final code = _currencyCode(raw);
    switch (code) {
      case 'GBP':
        return '£';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'AED':
        return 'AED';
      case 'SAR':
        return 'SAR';
      case 'JPY':
        return '¥';
      default:
        return code;
    }
  }

  String formatMoney(dynamic amount, String currencyRaw) {
    final numVal = (amount is num)
        ? amount
        : (double.tryParse(amount?.toString() ?? '') ?? 0);
    final symbol = _currencySymbol(currencyRaw);
    final formatted = numVal.toStringAsFixed(2);
    if (symbol.length <= 2 ||
        symbol == '\$' ||
        symbol == '£' ||
        symbol == '€') {
      return '$symbol$formatted';
    }
    return '$symbol $formatted';
  }

  Map<String, double> _sumByCurrency(
    List<Map<String, dynamic>> data,
    DateTime start,
    DateTime end,
  ) {
    final sums = <String, double>{};
    for (final e in data) {
      final day = _parseEntryDay(e);
      if (day.isBefore(start) || !day.isBefore(end)) continue;

      String? currencyRaw;
      dynamic amount;
      if (widget.templateKey == 'expenses') {
        currencyRaw = e['currency']?.toString();
        amount = e['cost'];
      } else if (widget.templateKey == 'income') {
        currencyRaw = e['currency']?.toString();
        amount = e['amount'];
      } else if (widget.templateKey == 'bills') {
        currencyRaw = e['currency']?.toString();
        amount = e['amount'];
      }

      if (currencyRaw == null || currencyRaw.isEmpty) continue;
      final code = _currencyCode(currencyRaw);
      final numVal = (amount is num)
          ? amount.toDouble()
          : (double.tryParse(amount?.toString() ?? '') ?? 0);
      sums[code] = (sums[code] ?? 0) + numVal;
    }
    return sums;
  }

  Widget _buildTotalsCard(List<Map<String, dynamic>> data) {
    final selectedMonth = ref.watch(logTableMonthProvider(widget.templateKey));
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    final yearStart = DateTime(selectedMonth.year, 1, 1);
    final yearEnd = DateTime(selectedMonth.year + 1, 1, 1);

    final monthSums = _sumByCurrency(data, monthStart, monthEnd);
    final yearSums = _sumByCurrency(data, yearStart, yearEnd);

    final cs = Theme.of(context).colorScheme;
    String renderLine(Map<String, double> sums) {
      if (sums.isEmpty) return '—';
      return sums.entries
          .map((e) {
            final symbol = _currencySymbol(e.key);
            final formatted = e.value.toStringAsFixed(2);
            if (symbol.length <= 2 ||
                symbol == '\$' ||
                symbol == '£' ||
                symbol == '€') {
              return '$symbol$formatted';
            }
            return '$symbol $formatted';
          })
          .join(' • ');
    }

    return _GlowPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Totals',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _showTotals = !_showTotals);
                  },
                  child: Text(_showTotals ? 'Hide' : 'Show'),
                ),
              ],
            ),
            if (_showTotals) ...[
              Text(
                'This month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                renderLine(monthSums),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                'This year',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                renderLine(yearSums),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: Text(widget.templateKey.toUpperCase()),
        centerTitle: true,
        leading: MbGlowBackButton(
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.pop(context)
              : context.go('/home'),
        ),
        actions: [
          MbGlowIconButton(
            icon: Icons.help_outline,
            onPressed: () => _showGuideIfNeeded(force: true),
          ),
          MbGlowIconButton(
            icon: Icons.calendar_month,
            onPressed: () async {
              final current = ref.read(
                logTableMonthProvider(widget.templateKey),
              );
              final picked = await showMonthYearPicker(
                context: context,
                initial: current,
              );
              if (picked != null) {
                ref
                    .read(logTableMonthProvider(widget.templateKey).notifier)
                    .state = DateTime(
                  picked.year,
                  picked.month,
                  1,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: loading ? null : _addEntry,
              label: const Text('Add Log'),
              icon: const Icon(Icons.add),
            ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            MbFloatingHintOverlay(
              hintKey: 'hint_template_table_${widget.templateKey}',
              text:
                  'Tap a date to edit. Hold a row to delete. For a clearer view, you might want to turn off portrait lock and rotate your phone.',
              iconText: '🫧',
              align: Alignment.topCenter,
              bottomOffset: 0,
              visual: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_iphone,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Transform.rotate(
                    angle: 1.57,
                    child: Icon(
                      Icons.phone_iphone,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              child: const SizedBox(height: 0),
            ),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      child: MonthNavigator(
                        selectedMonth: ref.watch(
                          logTableMonthProvider(widget.templateKey),
                        ),
                        onPrev: () {
                          final cur = ref.read(
                            logTableMonthProvider(widget.templateKey),
                          );
                          ref
                              .read(
                                logTableMonthProvider(
                                  widget.templateKey,
                                ).notifier,
                              )
                              .state = DateTime(
                            cur.year,
                            cur.month - 1,
                            1,
                          );
                        },
                        onNext: () {
                          final cur = ref.read(
                            logTableMonthProvider(widget.templateKey),
                          );
                          final next = DateTime(cur.year, cur.month + 1, 1);
                          final now = DateTime.now();
                          final max = DateTime(now.year, now.month, 1);
                          if (next.isAfter(max)) return;
                          ref
                                  .read(
                                    logTableMonthProvider(
                                      widget.templateKey,
                                    ).notifier,
                                  )
                                  .state =
                              next;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: LogTableControls(
                        searchController: _searchController,
                        onClearSearch: () => _searchController.clear(),
                        sortLabel: _sortLabel,
                        onChangeSort: (val) {
                          setState(() {
                            _sortLabel = val;
                            _sortAscending = val == 'Oldest first';
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 96,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _GlowPanel(
                              child: _StickyLogTable(
                                entries: _filteredEntries,
                                tableFields: fields,
                                fmtEntryDate: _fmtEntryDate,
                                formatValue: _formatValue,
                                formatMoney: formatMoney,
                                onEdit: _editEntry,
                                onDelete: _confirmDelete,
                                tableContainerKey: _logTableContainerKey,
                                dateCellKey: _dateCellKey,
                                logRowItemKey: _logRowItemKey,
                              ),
                            ),
                            if (widget.templateKey == 'expenses' ||
                                widget.templateKey == 'income' ||
                                widget.templateKey == 'bills')
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _buildTotalsCard(_filteredEntries),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
  _StickyLogTable({
    required this.entries,
    required this.tableFields,
    required this.fmtEntryDate,
    required this.formatValue,
    required this.formatMoney,
    required this.onEdit,
    required this.onDelete,
    this.tableContainerKey,
    this.dateCellKey,
    this.logRowItemKey,
  });

  // ✅ ADD THIS METHOD HERE (after constructor, before _buildColumns)
  String _detectTemplate(Map<String, dynamic> entry) {
    if (entry.containsKey('currency') && entry.containsKey('is_paid')) {
      return 'bills';
    }
    if (entry.containsKey('book_title') || entry.containsKey('author')) {
      return 'books';
    }
    if (entry.containsKey('flow') && entry.containsKey('symptoms')) {
      return 'cycle';
    }
    if (entry.containsKey('cost') && entry.containsKey('category')) {
      return 'expenses';
    }
    if (entry.containsKey('duration_hours') && entry.containsKey('feeling')) {
      return 'fast';
    }
    if (entry.containsKey('goal_title')) return 'goals';
    if (entry.containsKey('source') && !entry.containsKey('currency')) {
      return 'income';
    }
    if (entry.containsKey('duration_minutes') &&
        entry.containsKey('technique')) {
      return 'meditation';
    }
    if (entry.containsKey('feeling') && entry.containsKey('intensity')) {
      return 'mood';
    }
    if (entry.containsKey('movie_title')) return 'movies';
    if (entry.containsKey('place_name') && entry.containsKey('location')) {
      return 'places';
    }
    if (entry.containsKey('restaurant_name') &&
        entry.containsKey('cuisine_type')) {
      return 'restaurants';
    }
    if (entry.containsKey('routine_type') && entry.containsKey('products')) {
      return 'skin_care';
    }
    if (entry.containsKey('hours_slept') && entry.containsKey('quality')) {
      return 'sleep';
    }
    if (entry.containsKey('person_event') &&
        entry.containsKey('activity_type')) {
      return 'social';
    }
    if (entry.containsKey('subject') && entry.containsKey('focus_rating')) {
      return 'study';
    }
    if (entry.containsKey('task_name') && entry.containsKey('is_done')) {
      return 'tasks';
    }
    if (entry.containsKey('title') && entry.containsKey('thoughts')) {
      return 'tv_log';
    }
    if (entry.containsKey('amount') && entry.containsKey('unit')) {
      return 'water';
    }
    if (entry.containsKey('item_name') && !entry.containsKey('source')) {
      return 'wishlist';
    }
    if (entry.containsKey('exercise') && entry.containsKey('sets')) {
      return 'workout';
    }
    return 'other';
  }

  List<DataColumn> _buildColumns() {
    // Detect template by checking unique field combinations
    String templateKey = 'other';

    if (entries.isNotEmpty) {
      final firstEntry = entries.first;

      // Bills: has currency + is_paid
      if (firstEntry.containsKey('currency') &&
          firstEntry.containsKey('is_paid')) {
        templateKey = 'bills';
      }
      // Books: has book_title or author
      else if (firstEntry.containsKey('book_title') ||
          firstEntry.containsKey('author')) {
        templateKey = 'books';
      }
      // Cycle: has flow + symptoms
      else if (firstEntry.containsKey('flow') &&
          firstEntry.containsKey('symptoms')) {
        templateKey = 'cycle';
      }
      // Expenses: has cost (not amount)
      else if (firstEntry.containsKey('cost') &&
          firstEntry.containsKey('category')) {
        templateKey = 'expenses';
      }
      // Fast: has duration_hours + feeling
      else if (firstEntry.containsKey('duration_hours') &&
          firstEntry.containsKey('feeling')) {
        templateKey = 'fast';
      }
      // Goals: has goal_title
      else if (firstEntry.containsKey('goal_title')) {
        templateKey = 'goals';
      }
      // Income: has source + amount (but no currency)
      else if (firstEntry.containsKey('source') &&
          !firstEntry.containsKey('currency')) {
        templateKey = 'income';
      }
      // Meditation: has duration_minutes + technique
      else if (firstEntry.containsKey('duration_minutes') &&
          firstEntry.containsKey('technique')) {
        templateKey = 'meditation';
      }
      // Mood: has feeling + intensity
      else if (firstEntry.containsKey('feeling') &&
          firstEntry.containsKey('intensity')) {
        templateKey = 'mood';
      }
      // Movies: has movie_title
      else if (firstEntry.containsKey('movie_title')) {
        templateKey = 'movies';
      }
      // Places: has place_name + location
      else if (firstEntry.containsKey('place_name') &&
          firstEntry.containsKey('location')) {
        templateKey = 'places';
      }
      // Restaurants: has restaurant_name + cuisine_type
      else if (firstEntry.containsKey('restaurant_name') &&
          firstEntry.containsKey('cuisine_type')) {
        templateKey = 'restaurants';
      }
      // Skin Care: has routine_type + products
      else if (firstEntry.containsKey('routine_type') &&
          firstEntry.containsKey('products')) {
        templateKey = 'skin_care';
      }
      // Sleep: has hours_slept + quality
      else if (firstEntry.containsKey('hours_slept') &&
          firstEntry.containsKey('quality')) {
        templateKey = 'sleep';
      }
      // Social: has person_event + activity_type
      else if (firstEntry.containsKey('person_event') &&
          firstEntry.containsKey('activity_type')) {
        templateKey = 'social';
      }
      // Study: has subject + focus_rating
      else if (firstEntry.containsKey('subject') &&
          firstEntry.containsKey('focus_rating')) {
        templateKey = 'study';
      }
      // Tasks: has task_name + is_done
      else if (firstEntry.containsKey('task_name') &&
          firstEntry.containsKey('is_done')) {
        templateKey = 'tasks';
      }
      // TV Shows: has title + thoughts (not movie_title)
      else if (firstEntry.containsKey('title') &&
          firstEntry.containsKey('thoughts')) {
        templateKey = 'tv_log';
      }
      // Water: has amount + unit
      else if (firstEntry.containsKey('amount') &&
          firstEntry.containsKey('unit')) {
        templateKey = 'water';
      }
      // Wishlist: has item_name + price (but no source)
      else if (firstEntry.containsKey('item_name') &&
          !firstEntry.containsKey('source')) {
        templateKey = 'wishlist';
      }
      // Workout: has exercise + sets + reps
      else if (firstEntry.containsKey('exercise') &&
          firstEntry.containsKey('sets')) {
        templateKey = 'workout';
      }
    }

    // BILLS
    if (templateKey == 'bills') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('BILL NAME')),
        const DataColumn(label: Text('CATEGORY')),
        const DataColumn(label: Text('CURRENCY')),
        const DataColumn(label: Text('AMOUNT')),
        const DataColumn(label: Text('IS PAID?')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // BOOKS
    if (templateKey == 'books') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('BOOK TITLE')),
        const DataColumn(label: Text('AUTHOR')),
        const DataColumn(label: Text('CATEGORY')),
        const DataColumn(label: Text('CURRENT PAGE')),
        const DataColumn(label: Text('RATING')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // CYCLE
    if (templateKey == 'cycle') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('FLOW')),
        const DataColumn(label: Text('SYMPTOMS')),
        const DataColumn(label: Text('CRAMPS')),
        const DataColumn(label: Text('LIBIDO')),
        const DataColumn(label: Text('ENERGY')),
        const DataColumn(label: Text('STRESS')),
        const DataColumn(label: Text('PREGNANCY TEST')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // EXPENSES
    if (templateKey == 'expenses') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('ITEM/SERVICE')),
        const DataColumn(label: Text('CATEGORY')),
        const DataColumn(label: Text('CURRENCY')),
        const DataColumn(label: Text('COST')),
        const DataColumn(label: Text('STATUS')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // FAST
    if (templateKey == 'fast') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('HOURS FASTED')),
        const DataColumn(label: Text('FEELING')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // GOALS
    if (templateKey == 'goals') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('GOAL TITLE')),
        const DataColumn(label: Text('CATEGORY')),
        const DataColumn(label: Text('PRIORITY')),
        const DataColumn(label: Text('COMPLETED?')),
        const DataColumn(label: Text('TARGET DATE')),
        const DataColumn(label: Text('ACTION PLAN')),
      ];
    }

    // INCOME
    if (templateKey == 'income') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('SOURCE')),
        const DataColumn(label: Text('AMOUNT')),
        const DataColumn(label: Text('CATEGORY')),
        const DataColumn(label: Text('STATUS')),
        const DataColumn(label: Text('CURRENCY')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // MEDITATION
    if (templateKey == 'meditation') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('DURATION')),
        const DataColumn(label: Text('TECHNIQUE')),
        const DataColumn(label: Text('FOCUS RATING')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // MOOD
    if (templateKey == 'mood') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('FEELING')),
        const DataColumn(label: Text('INTENSITY')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // MOVIES
    if (templateKey == 'movies') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('MOVIE TITLE')),
        const DataColumn(label: Text('GENRE')),
        const DataColumn(label: Text('RATING')),
        const DataColumn(label: Text('LOCATION')),
        const DataColumn(label: Text('STATUS')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // PLACES
    if (templateKey == 'places') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('PLACE NAME')),
        const DataColumn(label: Text('LOCATION')),
        const DataColumn(label: Text('RATING')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // RESTAURANTS
    if (templateKey == 'restaurants') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('RESTAURANT')),
        const DataColumn(label: Text('CUISINE TYPE')),
        const DataColumn(label: Text('LOCATION')),
        const DataColumn(label: Text('RATING')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // SKIN CARE
    if (templateKey == 'skin_care') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('ROUTINE TYPE')),
        const DataColumn(label: Text('PRODUCTS')),
        const DataColumn(label: Text('SKIN CONDITION')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // SLEEP
    if (templateKey == 'sleep') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('HOURS SLEPT')),
        const DataColumn(label: Text('QUALITY')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // SOCIAL
    if (templateKey == 'social') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('PERSON/EVENT')),
        const DataColumn(label: Text('ACTIVITY TYPE')),
        const DataColumn(label: Text('PEOPLE')),
        const DataColumn(label: Text('SOCIAL ENERGY')),
        const DataColumn(label: Text('LOCATION')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // STUDY
    if (templateKey == 'study') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('SUBJECT')),
        const DataColumn(label: Text('DURATION (HOURS)')),
        const DataColumn(label: Text('STUDY METHODS')),
        const DataColumn(label: Text('FOCUS RATING')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // TASKS
    if (templateKey == 'tasks') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('TASK NAME')),
        const DataColumn(label: Text('PRIORITY')),
        const DataColumn(label: Text('DONE?')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // TV SHOWS
    if (templateKey == 'tv_log') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('SHOW TITLE')),
        const DataColumn(label: Text('GENRE')),
        const DataColumn(label: Text('RATING')),
        const DataColumn(label: Text('STATUS')),
        const DataColumn(label: Text('THOUGHTS')),
      ];
    }

    // WATER
    if (templateKey == 'water') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('AMOUNT')),
        const DataColumn(label: Text('UNIT')),
        const DataColumn(label: Text('GOAL REACHED?')),
      ];
    }

    // WISHLIST
    if (templateKey == 'wishlist') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('ITEM NAME')),
        const DataColumn(label: Text('CURRENCY')),
        const DataColumn(label: Text('ESTIMATED PRICE')),
        const DataColumn(label: Text('PRIORITY')),
        const DataColumn(label: Text('STATUS')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // WORKOUT
    if (templateKey == 'workout') {
      return [
        const DataColumn(label: Text('DATE')),
        const DataColumn(label: Text('EXERCISE')),
        const DataColumn(label: Text('SETS')),
        const DataColumn(label: Text('REPS')),
        const DataColumn(label: Text('WEIGHT (KG)')),
        const DataColumn(label: Text('NOTES')),
      ];
    }

    // Default order for other templates
    return [
      const DataColumn(label: Text('DATE')),
      ...tableFields.map(
        (f) => DataColumn(label: Text(f['label'].toString().toUpperCase())),
      ),
    ];
  }

  List<DataCell> _buildCellsForTemplate(
    String template,
    Map<String, dynamic> entry,
  ) {
    // BILLS (7 columns)
    if (template == 'bills') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['name']?.toString() ?? '-')),
        DataCell(Text(entry['category']?.toString() ?? '-')),
        DataCell(Text(entry['currency']?.toString() ?? '-')),
        DataCell(
          Text(
            formatMoney(entry['amount'], entry['currency']?.toString() ?? ''),
          ),
        ),
        DataCell(Text(formatValue('bool', entry['is_paid']))),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // BOOKS (7 columns)
    if (template == 'books') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(
          Text(
            (entry['book_title'] ?? entry['title'] ?? entry['book'] ?? '')
                    .toString()
                    .trim()
                    .isEmpty
                ? '-'
                : (entry['book_title'] ??
                          entry['title'] ??
                          entry['book'] ??
                          '-')
                      .toString(),
          ),
        ),
        DataCell(Text(entry['author']?.toString() ?? '-')),
        DataCell(Text(entry['category']?.toString() ?? '-')),
        DataCell(Text(entry['current_page']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['rating']))),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // CYCLE (9 columns)
    if (template == 'cycle') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['flow']?.toString() ?? '-')),
        DataCell(Text(entry['symptoms']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['cramps']))),
        DataCell(Text(formatValue('rating', entry['libido']))),
        DataCell(Text(formatValue('rating', entry['energy_level']))),
        DataCell(Text(formatValue('rating', entry['stress_level']))),
        DataCell(Text(entry['pregnancy_test']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // EXPENSES (7 columns)
    if (template == 'expenses') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(
          Text(entry['notes']?.toString() ?? '-'),
        ), // Item/Service is stored in notes
        DataCell(Text(entry['category']?.toString() ?? '-')),
        DataCell(Text(entry['currency']?.toString() ?? '-')),
        DataCell(
          Text(formatMoney(entry['cost'], entry['currency']?.toString() ?? '')),
        ),
        DataCell(Text(entry['status']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // FAST (4 columns)
    if (template == 'fast') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['duration_hours']?.toString() ?? '-')),
        DataCell(Text(entry['feeling']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // GOALS (7 columns)
    if (template == 'goals') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['goal_title']?.toString() ?? '-')),
        DataCell(Text(entry['category']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['priority']))),
        DataCell(Text(formatValue('bool', entry['is_completed']))),
        DataCell(Text(entry['target_date']?.toString() ?? '-')),
        DataCell(Text(entry['action_plan']?.toString() ?? '-')),
      ];
    }

    // INCOME (7 columns)
    if (template == 'income') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['source']?.toString() ?? '-')),
        DataCell(
          Text(
            formatMoney(entry['amount'], entry['currency']?.toString() ?? ''),
          ),
        ),
        DataCell(Text(entry['category']?.toString() ?? '-')),
        DataCell(Text(entry['status']?.toString() ?? '-')),
        DataCell(Text(entry['currency']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // MEDITATION (5 columns)
    if (template == 'meditation') {
      final durMins = entry['duration_minutes'];
      String durStr = '-';
      if (durMins != null) {
        final mins = (durMins is num)
            ? durMins.toDouble()
            : double.tryParse(durMins.toString()) ?? 0.0;
        final d = Duration(seconds: (mins * 60).round());
        durStr =
            '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
      }
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(durStr)),
        DataCell(Text(entry['technique']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['focus_rating']))),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // MOOD (4 columns)
    if (template == 'mood') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['feeling']?.toString() ?? '-')),
        DataCell(Text(entry['intensity']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // MOVIES (7 columns)
    if (template == 'movies') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['movie_title']?.toString() ?? '-')),
        DataCell(Text(entry['genre']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['rating']))),
        DataCell(Text(entry['location']?.toString() ?? '-')),
        DataCell(Text(entry['status']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // PLACES (5 columns)
    if (template == 'places') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['place_name']?.toString() ?? '-')),
        DataCell(Text(entry['location']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['rating']))),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // RESTAURANTS (6 columns)
    if (template == 'restaurants') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['restaurant_name']?.toString() ?? '-')),
        DataCell(Text(entry['cuisine_type']?.toString() ?? '-')),
        DataCell(Text(entry['location']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['rating']))),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // SKIN CARE (5 columns)
    if (template == 'skin_care') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['routine_type']?.toString() ?? '-')),
        DataCell(Text(entry['products']?.toString() ?? '-')),
        DataCell(Text(entry['skin_condition']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // SLEEP (4 columns)
    if (template == 'sleep') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['hours_slept']?.toString() ?? '-')),
        DataCell(Text(entry['quality']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // SOCIAL (7 columns)
    if (template == 'social') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['person_event']?.toString() ?? '-')),
        DataCell(Text(entry['activity_type']?.toString() ?? '-')),
        DataCell(Text(entry['people']?.toString() ?? '-')),
        DataCell(Text(entry['social_energy']?.toString() ?? '-')),
        DataCell(Text(entry['location']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // STUDY (6 columns)
    if (template == 'study') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['subject']?.toString() ?? '-')),
        DataCell(Text(entry['duration_hours']?.toString() ?? '-')),
        DataCell(Text(entry['study_methods']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['focus_rating']))),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // TASKS (5 columns)
    if (template == 'tasks') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['task_name']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['priority']))),
        DataCell(Text(formatValue('bool', entry['is_done']))),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // TV SHOWS (6 columns)
    if (template == 'tv_log') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['title']?.toString() ?? '-')),
        DataCell(Text(entry['genre']?.toString() ?? '-')),
        DataCell(Text(formatValue('rating', entry['rating']))),
        DataCell(Text(entry['status']?.toString() ?? '-')),
        DataCell(Text(entry['thoughts']?.toString() ?? '-')),
      ];
    }

    // WATER (4 columns)
    if (template == 'water') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text('${entry['amount'] ?? ''}')),
        DataCell(Text(entry['unit']?.toString() ?? '-')),
        DataCell(Text(formatValue('bool', entry['goal_reached']))),
      ];
    }

    // WISHLIST (6 columns)
    // WISHLIST (7 columns)
    if (template == 'wishlist') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['item_name']?.toString() ?? '-')),
        DataCell(Text(entry['currency']?.toString() ?? '-')),
        DataCell(
          Text(
            formatMoney(
              entry['price'] ?? entry['estimated_price'],
              entry['currency']?.toString() ?? '',
            ),
          ),
        ),
        DataCell(Text(formatValue('rating', entry['priority']))),
        DataCell(Text(entry['status']?.toString() ?? '-')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // WORKOUT (6 columns)
    if (template == 'workout') {
      return [
        DataCell(
          Text(
            fmtEntryDate(entry),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => onEdit(entry),
        ),
        DataCell(Text(entry['exercise']?.toString() ?? '-')),
        DataCell(Text(entry['sets']?.toString() ?? '-')),
        DataCell(Text(entry['reps']?.toString() ?? '-')),
        DataCell(Text('${entry['weight_kg'] ?? ''} kg')),
        DataCell(Text(entry['notes']?.toString() ?? '-')),
      ];
    }

    // DEFAULT: Use tableFields for any unhandled templates
    return [
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
            key == 'estimated_price' ||
            key == 'weight_kg') {
          final unit = (entry['unit'] ?? entry['currency'] ?? '').toString();
          String shownUnit = unit.isEmpty
              ? (key == 'weight_kg'
                    ? 'kg'
                    : key == 'amount_ml'
                    ? 'ml'
                    : '')
              : unit;

          if (key == 'duration_minutes' && val != null) {
            final mins = (val is num)
                ? val.toDouble()
                : double.tryParse(val.toString()) ?? 0.0;
            final d = Duration(seconds: (mins * 60).round());
            return DataCell(
              Text(
                '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}',
              ),
            );
          }

          return DataCell(Text('${val ?? ''} $shownUnit'));
        }

        return DataCell(Text(formatValue(f['field_type'], val)));
      }),
    ];
  }

  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> tableFields;
  final String Function(Map<String, dynamic>) fmtEntryDate;
  final String Function(String, dynamic) formatValue;
  final String Function(dynamic, String) formatMoney;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final GlobalKey? tableContainerKey;
  final GlobalKey? dateCellKey;
  final GlobalKey? logRowItemKey;
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return const Center(child: Text("No matching logs found."));
    }

    // ✅ Detect template ONCE for all rows
    final template = _detectTemplate(entries.first);

    return Container(
      key: tableContainerKey,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: true,
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  horizontalMargin: 24,
                  columnSpacing: 36,
                  headingRowColor: WidgetStateProperty.all(
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  ),
                  columns: _buildColumns(),
                  rows: entries.asMap().entries.map((rowEntry) {
                    final rowIndex = rowEntry.key;
                    final entry = rowEntry.value;
                    final cells = _buildCellsForTemplate(template, entry);
                    if (rowIndex == 0 &&
                        cells.isNotEmpty &&
                        dateCellKey != null) {
                      final first = cells.first;
                      cells[0] = DataCell(
                        KeyedSubtree(
                          key: logRowItemKey,
                          child: KeyedSubtree(
                            key: dateCellKey,
                            child: first.child,
                          ),
                        ),
                        placeholder: first.placeholder,
                        showEditIcon: first.showEditIcon,
                        onTap: first.onTap,
                        onDoubleTap: first.onDoubleTap,
                        onLongPress: first.onLongPress,
                        onTapCancel: first.onTapCancel,
                        onTapDown: first.onTapDown,
                      );
                    }
                    return DataRow(
                      onLongPress: () => onDelete(entry),
                      cells: cells,
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
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
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
  DateTime day = DateTime.now(); // ✅ default, no LateInitializationError
  final Map<String, TextEditingController> controllers = {};
  final Map<String, dynamic> values = {};
  double _computedHoursSlept = 0.0;
  String _sleepDurationLabel = '—';
  Duration _durationFromMinutes(dynamic v) {
    final mins = (v is num)
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0.0;
    return Duration(seconds: (mins * 60).round());
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDuration(String key) async {
    final initial = values[key] is Duration
        ? values[key] as Duration
        : Duration.zero;

    Duration temp = initial;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final maxHeight = MediaQuery.of(context).size.height * 0.52;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: maxHeight.clamp(240.0, 360.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => values[key] = temp);
                            Navigator.pop(context);
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.ms,
                      initialTimerDuration: initial,
                      onTimerDurationChanged: (d) => temp = d,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    day = widget.initialDay ?? DateTime.now(); // ✅ FIRST

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
      'rating',
    ];

    final numericKeys = [
      'hours_slept',
      'duration_hours',
      'energy_level',
      //   'amount_ml',
      // 'duration_minutes',
      'intensity',
      //'weight_kg',
      //'weight'
      'price',
      'priority',
      'sets',
      'reps',
    ];

    for (var f in widget.fields) {
      final key = f['field_key'];
      final initVal = widget.initialData?[key];

      if (key == 'duration_minutes') {
        values[key] = _durationFromMinutes(initVal);
        continue;
      }

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

    // Ensure Tasks always has a notes field available, even if template fields
    // are missing it in backend config.
    if (widget.templateKey.toLowerCase() == 'tasks' &&
        !controllers.containsKey('notes')) {
      controllers['notes'] = TextEditingController(
        text: widget.initialData?['notes']?.toString() ?? '',
      );
    }

    if (widget.templateKey.toLowerCase() == 'sleep') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSleepDuration();
      });
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
      if (widget.templateKey.toLowerCase() == 'sleep' &&
          (key == 'bedtime' || key == 'wake_up_time')) {
        _updateSleepDuration();
      }
    }
  }

  TimeOfDay? _parseTimeOfDay(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  void _updateSleepDuration() {
    final bedText = controllers['bedtime']?.text;
    final wakeText = controllers['wake_up_time']?.text;
    final bed = _parseTimeOfDay(bedText);
    final wake = _parseTimeOfDay(wakeText);
    if (bed == null || wake == null) {
      setState(() {
        _computedHoursSlept = 0.0;
        _sleepDurationLabel = '—';
        values['hours_slept'] = 0.0;
      });
      return;
    }

    final base = DateTime(day.year, day.month, day.day);
    final bedDt = DateTime(
      base.year,
      base.month,
      base.day,
      bed.hour,
      bed.minute,
    );
    var wakeDt = DateTime(
      base.year,
      base.month,
      base.day,
      wake.hour,
      wake.minute,
    );
    if (wakeDt.isBefore(bedDt)) {
      wakeDt = wakeDt.add(const Duration(days: 1));
    }
    final diff = wakeDt.difference(bedDt);
    final hours = diff.inMinutes / 60.0;
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    setState(() {
      _computedHoursSlept = hours;
      _sleepDurationLabel = '${h}h ${m}m';
      values['hours_slept'] = hours;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // final tKey = widget.templateKey.toLowerCase();

    List<Map<String, dynamic>> sortedFields = List.from(widget.fields);
    sortedFields.sort(
      (a, b) => (a['sort_order'] ?? 99).compareTo(b['sort_order'] ?? 99),
    );

    if (widget.templateKey.toLowerCase() == 'tasks') {
      // Force Notes placement under Completed toggle.
      final filtered = sortedFields.where((f) {
        final key = (f['field_key'] ?? '').toString().toLowerCase();
        return key != 'notes' && key != 'note';
      }).toList();
      final notesField = <String, dynamic>{
        'field_key': 'notes',
        'field_type': 'text',
        'label': 'Notes',
        'sort_order': 999,
      };
      final completedIndex = filtered.indexWhere(
        (f) => (f['field_key'] ?? '').toString().toLowerCase() == 'is_done',
      );
      if (completedIndex >= 0) {
        filtered.insert(completedIndex + 1, notesField);
      } else {
        filtered.add(notesField);
      }
      sortedFields = filtered;
    }

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
        SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: Text(
                    'Cancel',
                    style: textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: textTheme.labelLarge,
                  ),
                  onPressed: () {
                    final data = Map<String, dynamic>.from(values);
                    controllers.forEach((k, c) => data[k] = c.text);

                    if (data['duration_minutes'] is Duration) {
                      final d = data['duration_minutes'] as Duration;
                      data['duration_minutes'] = d.inSeconds / 60.0;
                    }

                    // This prevents the "0.0" reset issue
                    if (controllers.containsKey('weight_kg')) {
                      final weightText = controllers['weight_kg']!.text;
                      data['weight_kg'] = (weightText.isEmpty)
                          ? 0.0
                          : (double.tryParse(weightText) ?? 0.0);
                    }

                    // 5. Template specific cleanup
                    final tKey = widget.templateKey.toLowerCase();
                    if (tKey == 'workout') {
                      if (data.containsKey('exercises')) {
                        data['exercise'] = data['exercises'];
                        data.remove('exercises');
                      }
                      data.remove('amount');
                      data.remove('cost');
                    }

                    if (tKey == 'books') {
                      final title = data['title']?.toString().trim();
                      final bookTitle = data['book_title']?.toString().trim();
                      if ((bookTitle == null || bookTitle.isEmpty) &&
                          (title != null && title.isNotEmpty)) {
                        data['book_title'] = title;
                      }
                    }

                    debugPrint("CHECK THIS IN CONSOLE: ${data['weight_kg']}");

                    if (values.containsKey('currency')) {
                      data['currency'] = values['currency'];
                    }
                    if (values.containsKey('unit')) {
                      data['unit'] = values['unit'];
                    }

                    if (data.containsKey('quality')) {
                      data['quality'] = (data['quality'] as num?)?.toInt() ?? 0;
                    }

                    if (data.containsKey('target_date') &&
                        data['target_date'].toString().isEmpty) {
                      data.remove('target_date');
                    }
                    if (data.containsKey('notes')) {
                      final notes = data['notes']?.toString().trim() ?? '';
                      data['notes'] = notes.isEmpty ? null : notes;
                    }

                    if (data.containsKey('hours_slept')) {
                      if (widget.templateKey.toLowerCase() == 'sleep') {
                        data['hours_slept'] = _computedHoursSlept;
                      } else {
                        data['hours_slept'] =
                            double.tryParse(data['hours_slept'].toString()) ??
                            0.0;
                      }
                    }

                    final intKeys = [
                      'rating',
                      'quality',
                      'focus_rating',
                      'priority',
                      'intensity',
                      'severity',
                      'libido',
                      'energy_level',
                      'sets',
                      'reps',
                      'current_page',
                      'pages',
                      'year',
                    ];
                    final invalidIntegerFields = <String>[];

                    for (final k in intKeys) {
                      if (!data.containsKey(k)) continue;
                      try {
                        data[k] = parseNullableIntLike(data[k], fieldName: k);
                      } on FormatException {
                        invalidIntegerFields.add(k);
                      }
                    }

                    for (final key in data.keys.toList()) {
                      if (!isDateComponentFieldName(key)) continue;
                      try {
                        data[key] = parseNullableIntLike(
                          data[key],
                          fieldName: key,
                        );
                      } on FormatException {
                        invalidIntegerFields.add(key);
                      }
                    }

                    if (invalidIntegerFields.isNotEmpty) {
                      final badFields = invalidIntegerFields.toSet().join(', ');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Invalid input for $badFields. Use whole numbers only.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Cycle/Mood tables are strict about integer-typed auxiliary fields.
                    // Coerce "0.0" -> 0 and block non-integer numeric inputs.
                    if (tKey == 'cycle' || tKey == 'mood') {
                      const skippedTextKeys = {
                        'flow',
                        'symptoms',
                        'feeling',
                        'mood',
                        'notes',
                        'note',
                        'title',
                      };
                      final cycleMoodInvalid = <String>[];
                      final numericLike = RegExp(r'^[-+]?\d+(\.\d+)?$');

                      for (final key in data.keys.toList()) {
                        if (skippedTextKeys.contains(key)) continue;
                        final raw = data[key];
                        if (raw == null || raw is bool) continue;
                        if (raw is List || raw is Map) continue;

                        final text = raw.toString().trim();
                        if (text.isEmpty) {
                          data[key] = null;
                          continue;
                        }

                        final looksNumeric =
                            raw is num || numericLike.hasMatch(text);
                        if (!looksNumeric) continue;

                        try {
                          data[key] = parseNullableIntLike(raw, fieldName: key);
                        } on FormatException {
                          cycleMoodInvalid.add(key);
                        }
                      }

                      if (cycleMoodInvalid.isNotEmpty) {
                        final bad = cycleMoodInvalid.toSet().join(', ');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Invalid integer value for: $bad. Use whole numbers only.',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    for (final k in [
                      'amount',
                      'price',
                      'cost',
                      'estimated_price',
                      // 'weight',
                      'weight_kg',
                      'amount_ml',
                    ]) {
                      if (!data.containsKey(k)) continue;
                      final v = data[k];
                      data[k] = (v == null || v.toString().isEmpty)
                          ? 0.0
                          : (double.tryParse(v.toString()) ?? 0.0);
                    }

                    if (tKey == 'workout') {
                      if (data.containsKey('exercises')) {
                        data['exercise'] = data['exercises'];
                        data.remove('exercises');
                      }
                      data.remove('amount');
                      data.remove('cost');
                      data.remove('price');
                    }

                    if (tKey == 'expenses') {
                      if (data.containsKey('amount') &&
                          !data.containsKey('cost')) {
                        data['cost'] = data['amount'];
                      }
                      data.remove('amount');
                      final v = data['cost'];
                      data['cost'] = (v == null || v.toString().trim().isEmpty)
                          ? 0.0
                          : (double.tryParse(v.toString()) ?? 0.0);
                    }
                    // Clean up target_date
                    if (data.containsKey('target_date') &&
                        (data['target_date'] == null ||
                            data['target_date'].toString().isEmpty)) {
                      data.remove('target_date');
                    }

                    debugPrint(
                      "FINAL duration_minutes -> ${data['duration_minutes']} (${data['duration_minutes'].runtimeType})",
                    );

                    debugPrint("SAVING (${widget.templateKey}): $data");
                    Navigator.pop(
                      context,
                      _NewEntryResult(day: day, data: data),
                    );
                  },
                  child: const Text('Save Entry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(Map<String, dynamic> f, ThemeData theme) {
    final key = f['field_key'];
    debugPrint("FIELD KEY: $key");

    // ✅ TIMER PICKER FOR MEDITATION DURATION
    if (key == 'duration_minutes') {
      final d = (values[key] is Duration)
          ? values[key] as Duration
          : Duration.zero;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: f['label']),
          InkWell(
            onTap: () => _pickDuration(key),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmtDuration(d), style: const TextStyle(fontSize: 16)),
                  const Icon(Icons.timer),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

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
          'location',
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
          key == 'study_methods');
      final bool isMoodLike = key == 'feeling' || key == 'mood';
      if (isMoodLike) {
        isMulti = false;
      }

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
                  initialValue:
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
    if (key == 'hours_slept' && widget.templateKey.toLowerCase() == 'sleep') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: f['label']),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_sleepDurationLabel, style: const TextStyle(fontSize: 16)),
                Text(
                  _computedHoursSlept == 0.0
                      ? '—'
                      : _computedHoursSlept.toStringAsFixed(2),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }
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
          'rating',
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
                  key == 'weight_kg' ||
                  key == 'cost' ||
                  key == 'price' ||
                  key == 'estimated_price' ||
                  key == 'amount_ml' ||
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
          // Read-only for time pickers
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
          minLines: (key == 'notes' || key == 'note') ? 3 : null,
          maxLines: (key == 'notes' || key == 'note')
              ? 5
              : ((key == 'action_plan' ||
                        key == 'feeling' ||
                        key == 'products')
                    ? 4
                    : 1),
          decoration: InputDecoration(
            hintText: hint,
            // Added suffixText for units
            suffixText: key == 'weight_kg'
                ? 'kg'
                : (key == 'amount_ml' ? 'ml' : null),
            suffixStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
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
      } else if (tKey == 'movies' || tKey == 'tv_log') {
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
        'running 🏃',
        'jogging 🏃',
        'walking 🚶',
        'strength 💪',
        'weightlifting 💪',
        'weight 💪',
        'plank 💪',
        'bench 💪',
        'squat 🦵',
        'leg 🦵',
        'yoga 🧘',
        'stretching 🧘',
        'swimming 🏊',
        'cycling 🚴',
        'pilates 🤸',
        'gymnastics 🤸',
        'hiit ⚡',
        'boxing 🥊',
        'martial 🥋',
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
    } else if (key == 'location' &&
        (tKey == 'movies' || tKey == 'tv_log' || tKey == 'social')) {
      options = [
        '🏠 Home',
        '🎬 Cinema',
        '🛋️ Friend/Relative',
        '✈️ Airplane',
        '🚌 Commute',
      ];
    } else if (key == 'genre' && (tKey == 'movies' || tKey == 'tv_log')) {
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
      options = ['Spotting', 'Light', 'Medium', 'Heavy', 'Other'];
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
