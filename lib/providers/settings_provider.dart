import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

/// Night mode state manager - manual toggle only
/// Does NOT follow system theme

class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  bool _nightMode = false;
  bool _smoothScrolling = true;
  bool _rememberLastPage = true;
  bool _isLoading = false;
  String? _error;

  /// Global night mode - default false (light mode)
  /// Only enabled when user manually toggles
  bool get nightMode => _nightMode;
  bool get smoothScrolling => _smoothScrolling;
  bool get rememberLastPage => _rememberLastPage;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _nightMode = await _settingsService.getNightMode();
      _smoothScrolling = await _settingsService.getSmoothScrolling();
      _rememberLastPage = await _settingsService.getRememberLastPage();
      _error = null;
    } catch (e) {
      _error = 'Failed to load settings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set global night mode
  /// When false (default), always uses light mode regardless of system
  Future<void> setNightMode(bool value) async {
    try {
      await _settingsService.setNightMode(value);
      _nightMode = value;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save night mode setting: $e';
      notifyListeners();
    }
  }

  Future<void> setSmoothScrolling(bool value) async {
    try {
      await _settingsService.setSmoothScrolling(value);
      _smoothScrolling = value;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save smooth scrolling setting: $e';
      notifyListeners();
    }
  }

  Future<void> setRememberLastPage(bool value) async {
    try {
      await _settingsService.setRememberLastPage(value);
      _rememberLastPage = value;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save remember last page setting: $e';
      notifyListeners();
    }
  }

  Future<void> resetToDefaults() async {
    try {
      await _settingsService.resetToDefaults();
      await loadSettings();
    } catch (e) {
      _error = 'Failed to reset settings: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
