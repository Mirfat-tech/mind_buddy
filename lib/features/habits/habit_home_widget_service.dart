import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:mind_buddy/paper/paper_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class HabitHomeWidgetService {
  static const String androidWidgetProviderName = 'HabitTodayWidgetProvider';
  static const String iOSWidgetName = 'HabitTodayWidgetV2';
  static const String iOSAppGroupId = 'group.com.example.mind_buddy';
  static const String _doneKey = 'habits_done_today';
  static const String _totalKey = 'habits_total_today';
  static const String _titleKey = 'habits_widget_title';
  static const String _subtitleKey = 'habits_widget_subtitle';
  static const String _itemsJsonKey = 'habits_widget_items_json';
  static const String _moreCountKey = 'habits_widget_more_count';
  static const String _errorKey = 'habits_widget_error';
  static const String _themePaperKey = 'habits_theme_paper';
  static const String _themeBoxKey = 'habits_theme_box';
  static const String _themeBorderKey = 'habits_theme_border';
  static const String _themeTextKey = 'habits_theme_text';
  static const String _themeMutedKey = 'habits_theme_muted';
  static const String _themeAccentKey = 'habits_theme_accent';
  static const String _pendingTogglesKey = 'habits_widget_pending_toggles_json';
  static const int _maxVisible = 6;

  static Future<void> syncTodaySnapshot() async {
    await HomeWidget.setAppGroupId(iOSAppGroupId);
    final palette = await _loadThemePalette();
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      await _write(
        done: 0,
        total: 0,
        items: const <Map<String, dynamic>>[],
        moreCount: 0,
        errorMessage: null,
        palette: palette,
      );
      await _refreshWidgets();
      return;
    }

    final today = _ymd(DateTime.now().toLocal());
    final activeRows = await supabase
        .from('user_habits')
        .select('id, name')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final activeHabits = <Map<String, String>>[];
    final activeIds = <String>{};
    for (final raw in (activeRows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = (row['id'] ?? '').toString().trim();
      final name = (row['name'] ?? '').toString().trim();
      if (id.isEmpty || name.isEmpty) continue;
      activeHabits.add(<String, String>{'id': id, 'name': name});
      activeIds.add(id);
    }
    List logs;
    try {
      logs = await supabase
          .from('habit_logs')
          .select('habit_id, habit_name, is_completed')
          .eq('user_id', user.id)
          .eq('day', today);
    } catch (_) {
      logs = await supabase
          .from('habit_logs')
          .select('habit_name, is_completed')
          .eq('user_id', user.id)
          .eq('day', today);
    }

    final doneById = <String, bool>{};
    for (final raw in logs) {
      final row = Map<String, dynamic>.from(raw as Map);
      final hid = (row['habit_id'] ?? '').toString().trim();
      final isCompleted = row['is_completed'] == true;
      if (hid.isNotEmpty && activeIds.contains(hid)) {
        doneById[hid] = isCompleted;
      }
    }
    final doneIds = doneById.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    final visibleHabits = activeHabits
        .take(_maxVisible)
        .toList(growable: false);
    final items = visibleHabits
        .map((h) => <String, dynamic>{
              'id': h['id'],
              'name': h['name'],
              'done': doneIds.contains(h['id']),
            })
        .toList(growable: false);

    await _write(
      done: doneIds.length,
      total: activeHabits.length,
      items: items,
      moreCount: activeHabits.length > _maxVisible
          ? activeHabits.length - _maxVisible
          : 0,
      errorMessage: null,
      palette: palette,
    );
    await _refreshWidgets();
  }

  static Future<bool> toggleTodayFromWidget({
    required String habitId,
    String? habitName,
    bool? forceCompleted,
    String? dayOverride,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final trimmedId = habitId.trim();
    final trimmedName = (habitName ?? '').trim();
    if (user == null || trimmedId.isEmpty) return false;

    final day = (dayOverride ?? '').trim().isNotEmpty
        ? dayOverride!.trim()
        : _ymd(DateTime.now().toLocal());

    try {
      final existingRows = await supabase
          .from('habit_logs')
          .select('is_completed')
          .eq('user_id', user.id)
          .eq('habit_id', trimmedId)
          .eq('day', day);

      final existingList = (existingRows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      final wasDone = existingList.any((row) => row['is_completed'] == true);
      final isNowDone = forceCompleted ?? !wasDone;
      // Widget toggle persistence log for debug parity with app reads.
      // ignore: avoid_print
      print(
        '[WidgetPersist] table=habit_logs user_id=${user.id} habit_id=$trimmedId day=$day is_completed=$isNowDone via=toggleTodayFromWidget',
      );

      final payload = <String, dynamic>{
        'user_id': user.id,
        'habit_id': trimmedId,
        'day': day,
        'is_completed': isNowDone,
      };
      if (trimmedName.isNotEmpty) payload['habit_name'] = trimmedName;

      try {
        await supabase
            .from('habit_logs')
            .upsert(payload, onConflict: 'user_id,habit_id,day');
      } catch (_) {
        if (existingList.isNotEmpty) {
          await supabase
              .from('habit_logs')
              .update({'is_completed': isNowDone})
              .eq('user_id', user.id)
              .eq('habit_id', trimmedId)
              .eq('day', day);
        } else {
          await supabase.from('habit_logs').insert(payload);
        }
      }

      await syncTodaySnapshot();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureBackgroundInitialized() async {
    try {
      Supabase.instance.client;
      return;
    } catch (_) {}
    const supabaseUrl = 'https://auth.mybrainbubble.co.uk';
    const fallbackAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudGZ4bmpydGdsaXl6aGVmYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MjIzMDgsImV4cCI6MjA4MDQ5ODMwOH0.TgMtKwjswRTbMESjpep2FWq37_OG20Z8VCb6aR03Bo8';
    await Supabase.initialize(url: supabaseUrl, anonKey: fallbackAnonKey);
  }

  static Future<void> handleInteractivityAction(Uri? uri) async {
    if (uri == null) return;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isToggle =
        (uri.scheme == 'homewidget' && host == 'toggle') ||
        path == '/toggle' ||
        path == 'toggle';
    if (!isToggle) return;
    final habitId = (uri.queryParameters['habit_id'] ?? '').trim();
    if (habitId.isEmpty) return;
    final habitName = (uri.queryParameters['habit_name'] ?? '').trim();
    final alreadyToggled = (uri.queryParameters['already_toggled'] ?? '') == '1';
    final rawCompleted = (uri.queryParameters['is_completed'] ?? '').trim();
    bool? targetCompleted;
    if (rawCompleted == '1' || rawCompleted.toLowerCase() == 'true') {
      targetCompleted = true;
    } else if (rawCompleted == '0' || rawCompleted.toLowerCase() == 'false') {
      targetCompleted = false;
    }

    final today = _ymd(DateTime.now().toLocal());
    final nowDone = alreadyToggled
        ? targetCompleted
        : await _applyOptimisticWidgetToggle(habitId);
    if (nowDone == null) return;
    await _queuePendingToggle(
      habitId: habitId,
      habitName: habitName,
      day: today,
      completed: nowDone,
    );
    final ok = await toggleTodayFromWidget(
      habitId: habitId,
      habitName: habitName,
      forceCompleted: targetCompleted ?? nowDone,
      dayOverride: today,
    );
    if (ok) {
      await _removePendingToggle(habitId: habitId, day: today);
      await HomeWidget.saveWidgetData<String>(_errorKey, null);
      return;
    }
    await HomeWidget.saveWidgetData<String>(
      _errorKey,
      'Could not sync. Tap again.',
    );
    await _refreshWidgets();
  }

  static Future<bool?> _applyOptimisticWidgetToggle(String habitId) async {
    final rawJson = await HomeWidget.getWidgetData<String>(
      _itemsJsonKey,
      defaultValue: '[]',
    );
    final decoded = jsonDecode(rawJson ?? '[]');
    if (decoded is! List) return null;
    bool changed = false;
    bool? nowDone;
    for (final item in decoded) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString().trim();
      if (id != habitId) continue;
      final done = item['done'] == true;
      nowDone = !done;
      item['done'] = nowDone;
      changed = true;
      break;
    }
    if (!changed) return null;
    await HomeWidget.saveWidgetData<String>(_itemsJsonKey, jsonEncode(decoded));
    await _refreshWidgets();
    return nowDone;
  }

  static Future<void> flushPendingWidgetToggles() async {
    await HomeWidget.setAppGroupId(iOSAppGroupId);
    final raw = await HomeWidget.getWidgetData<String>(
      _pendingTogglesKey,
      defaultValue: '[]',
    );
    final decoded = jsonDecode(raw ?? '[]');
    if (decoded is! List || decoded.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final keep = <Map<String, dynamic>>[];
    bool anySuccess = false;
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final row = Map<String, dynamic>.from(entry);
      final habitId = (row['habit_id'] ?? '').toString().trim();
      final habitName = (row['habit_name'] ?? '').toString().trim();
      final day = (row['day'] ?? '').toString().trim();
      final completed = row['is_completed'] == true;
      if (habitId.isEmpty || day.isEmpty) continue;
      final ok = await toggleTodayFromWidget(
        habitId: habitId,
        habitName: habitName.isEmpty ? null : habitName,
        forceCompleted: completed,
        dayOverride: day,
      );
      if (ok) {
        anySuccess = true;
        // ignore: avoid_print
        print(
          '[WidgetPersist] table=habit_logs user_id=${user.id} habit_id=$habitId day=$day is_completed=$completed via=flushPendingWidgetToggles',
        );
      } else {
        keep.add(row);
      }
    }
    await HomeWidget.saveWidgetData<String>(_pendingTogglesKey, jsonEncode(keep));
    if (anySuccess) {
      await syncTodaySnapshot();
    }
  }

  static Future<void> _queuePendingToggle({
    required String habitId,
    required String habitName,
    required String day,
    required bool completed,
  }) async {
    final raw = await HomeWidget.getWidgetData<String>(
      _pendingTogglesKey,
      defaultValue: '[]',
    );
    final decoded = jsonDecode(raw ?? '[]');
    final list = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) list.add(Map<String, dynamic>.from(item));
      }
    }

    final next = <Map<String, dynamic>>[];
    for (final item in list) {
      final hid = (item['habit_id'] ?? '').toString().trim();
      final d = (item['day'] ?? '').toString().trim();
      if (hid == habitId && d == day) continue;
      next.add(item);
    }
    next.add({
      'habit_id': habitId,
      'habit_name': habitName,
      'day': day,
      'is_completed': completed,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await HomeWidget.saveWidgetData<String>(_pendingTogglesKey, jsonEncode(next));
  }

  static Future<void> _removePendingToggle({
    required String habitId,
    required String day,
  }) async {
    final raw = await HomeWidget.getWidgetData<String>(
      _pendingTogglesKey,
      defaultValue: '[]',
    );
    final decoded = jsonDecode(raw ?? '[]');
    if (decoded is! List) return;
    final next = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final hid = (row['habit_id'] ?? '').toString().trim();
      final d = (row['day'] ?? '').toString().trim();
      if (hid == habitId && d == day) continue;
      next.add(row);
    }
    await HomeWidget.saveWidgetData<String>(_pendingTogglesKey, jsonEncode(next));
  }

  static Future<_WidgetThemePalette> _loadThemePalette() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('mb_settings_v1');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          final themeId = (map['themeId'] ?? '').toString().trim();
          final style = styleById(themeId.isEmpty ? null : themeId);
          return _WidgetThemePalette.fromStyle(style);
        }
      }
    } catch (_) {}
    return _WidgetThemePalette.fromStyle(styleById(null));
  }

  static Future<void> _write({
    required int done,
    required int total,
    required List<Map<String, dynamic>> items,
    required int moreCount,
    required String? errorMessage,
    required _WidgetThemePalette palette,
  }) async {
    final safeDone = done < 0 ? 0 : done;
    final safeTotal = total < 0 ? 0 : total;
    final safeMoreCount = moreCount < 0 ? 0 : moreCount;
    await HomeWidget.saveWidgetData<int>(_doneKey, safeDone);
    await HomeWidget.saveWidgetData<int>(_totalKey, safeTotal);
    await HomeWidget.saveWidgetData<String>(_titleKey, 'Habits');
    await HomeWidget.saveWidgetData<String>(_subtitleKey, 'Today habits');
    await HomeWidget.saveWidgetData<String>(_itemsJsonKey, jsonEncode(items));
    await HomeWidget.saveWidgetData<int>(_moreCountKey, safeMoreCount);
    await HomeWidget.saveWidgetData<String>(_errorKey, errorMessage);
    await HomeWidget.saveWidgetData<int>(_themePaperKey, palette.paper);
    await HomeWidget.saveWidgetData<int>(_themeBoxKey, palette.box);
    await HomeWidget.saveWidgetData<int>(_themeBorderKey, palette.border);
    await HomeWidget.saveWidgetData<int>(_themeTextKey, palette.text);
    await HomeWidget.saveWidgetData<int>(_themeMutedKey, palette.muted);
    await HomeWidget.saveWidgetData<int>(_themeAccentKey, palette.accent);
  }

  static Future<void> _refreshWidgets() async {
    await HomeWidget.updateWidget(
      androidName: androidWidgetProviderName,
      iOSName: iOSWidgetName,
    );
  }
}

class _WidgetThemePalette {
  const _WidgetThemePalette({
    required this.paper,
    required this.box,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
  });

  final int paper;
  final int box;
  final int border;
  final int text;
  final int muted;
  final int accent;

  static _WidgetThemePalette fromStyle(PaperStyle style) {
    return _WidgetThemePalette(
      paper: style.paper.toARGB32(),
      box: style.boxFill.toARGB32(),
      border: style.border.toARGB32(),
      text: style.text.toARGB32(),
      muted: style.mutedText.toARGB32(),
      accent: style.accent.toARGB32(),
    );
  }
}
