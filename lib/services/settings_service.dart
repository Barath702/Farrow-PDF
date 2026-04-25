import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _nightModeKey = 'night_mode';
  static const String _smoothScrollingKey = 'smooth_scrolling';
  static const String _rememberLastPageKey = 'remember_last_page';

  // Default values
  static const bool _defaultNightMode = false;
  static const bool _defaultSmoothScrolling = true;
  static const bool _defaultRememberLastPage = true;

  Future<bool> getNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_nightModeKey) ?? _defaultNightMode;
  }

  Future<void> setNightMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nightModeKey, value);
  }

  Future<bool> getSmoothScrolling() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_smoothScrollingKey) ?? _defaultSmoothScrolling;
  }

  Future<void> setSmoothScrolling(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smoothScrollingKey, value);
  }

  Future<bool> getRememberLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberLastPageKey) ?? _defaultRememberLastPage;
  }

  Future<void> setRememberLastPage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberLastPageKey, value);
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nightModeKey, _defaultNightMode);
    await prefs.setBool(_smoothScrollingKey, _defaultSmoothScrolling);
    await prefs.setBool(_rememberLastPageKey, _defaultRememberLastPage);
  }

  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'nightMode': await getNightMode(),
      'smoothScrolling': await getSmoothScrolling(),
      'rememberLastPage': await getRememberLastPage(),
    };
  }
}
