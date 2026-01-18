import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appThemeControllerProvider = ChangeNotifierProvider<AppThemeController>((
  ref,
) {
  final supabase = Supabase.instance.client;
  return AppThemeController(supabase);
});

class AppThemeController extends ChangeNotifier {
  AppThemeController(this._supabase);

  final SupabaseClient _supabase;

  String? _themeId;
  bool _loading = true;

  String? get themeId => _themeId;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _themeId = null;
      _loading = false;
      notifyListeners();
      return;
    }

    final row = await _supabase
        .from('user_prefs')
        .select('app_theme_id')
        .eq('user_id', user.id)
        .maybeSingle();

    _themeId = row?['app_theme_id'] as String?;
    _loading = false;
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    _themeId = id;
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('user_prefs').upsert({
      'user_id': user.id,
      'app_theme_id': id,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
