import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _userChose = false; // абонент явно выбрал тему

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode');
    if (mode != null) {
      _userChose = true;
      _themeMode = _fromString(mode);
    }
    notifyListeners();
  }

  /// Применить серверный дефолт темы (MOBILE_DARK_THEME_DEFAULT),
  /// только если абонент сам ещё не выбирал тему.
  void applyServerDefault(bool darkDefault) {
    if (_userChose) return;
    final wanted = darkDefault ? ThemeMode.dark : ThemeMode.system;
    if (_themeMode != wanted) {
      _themeMode = wanted;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _userChose = true;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _toString(mode));
  }

  static ThemeMode _fromString(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light: return 'light';
      case ThemeMode.dark: return 'dark';
      default: return 'system';
    }
  }
}
