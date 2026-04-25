import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgressService {
  static const String _prefix = 'reading_progress_';

  Future<void> saveLastPage(String pdfId, int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$pdfId', pageNumber);
  }

  Future<int> getLastPage(String pdfId, {int defaultPage = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$pdfId') ?? defaultPage;
  }

  Future<void> saveZoomLevel(String pdfId, double zoomLevel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_prefix}zoom_$pdfId', zoomLevel);
  }

  Future<double> getZoomLevel(String pdfId, {double defaultZoom = 1.0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('${_prefix}zoom_$pdfId') ?? defaultZoom;
  }

  Future<void> clearProgress(String pdfId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$pdfId');
    await prefs.remove('${_prefix}zoom_$pdfId');
  }

  Future<Map<String, int>> getAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix) && !key.contains('zoom_'));
    final Map<String, int> progress = {};
    for (final key in keys) {
      final pdfId = key.substring(_prefix.length);
      final page = prefs.getInt(key);
      if (page != null) {
        progress[pdfId] = page;
      }
    }
    return progress;
  }
}
