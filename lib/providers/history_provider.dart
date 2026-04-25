import 'package:flutter/foundation.dart';
import '../models/reading_history.dart';
import '../models/pdf_document.dart';
import '../services/history_service.dart';
import '../services/pdf_library_service.dart';

class HistoryProvider extends ChangeNotifier {
  final HistoryService _historyService = HistoryService();
  final PdfLibraryService _pdfLibraryService = PdfLibraryService();

  List<ReadingHistory> _todayHistory = [];
  List<ReadingHistory> _yesterdayHistory = [];
  List<ReadingHistory> _last7DaysHistory = [];
  Map<String, PdfDocument> _pdfDocuments = {};
  bool _isLoading = false;
  String? _error;

  List<ReadingHistory> get todayHistory => _todayHistory;
  List<ReadingHistory> get yesterdayHistory => _yesterdayHistory;
  List<ReadingHistory> get last7DaysHistory => _last7DaysHistory;
  Map<String, PdfDocument> get pdfDocuments => _pdfDocuments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get all history - already deduplicated at DB level (one entry per PDF)
      final allHistory = await _historyService.getAllHistory();

      // Sort by openedAt descending (most recent first)
      allHistory.sort((a, b) => b.openedAt.compareTo(a.openedAt));

      // Group into time sections based on openedAt date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final last7DaysStart = today.subtract(const Duration(days: 7));

      _todayHistory = [];
      _yesterdayHistory = [];
      _last7DaysHistory = [];

      for (final history in allHistory) {
        final historyDate = DateTime(
          history.openedAt.year,
          history.openedAt.month,
          history.openedAt.day,
        );

        if (historyDate.isAtSameMomentAs(today)) {
          _todayHistory.add(history);
        } else if (historyDate.isAtSameMomentAs(yesterday)) {
          _yesterdayHistory.add(history);
        } else if (historyDate.isAfter(last7DaysStart) && historyDate.isBefore(today)) {
          _last7DaysHistory.add(history);
        }
      }

      // Load unique PDF documents
      _pdfDocuments = {};
      for (final history in allHistory) {
        if (!_pdfDocuments.containsKey(history.pdfId)) {
          final doc = await _pdfLibraryService.getDocument(history.pdfId);
          if (doc != null) {
            _pdfDocuments[history.pdfId] = doc;
          }
        }
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to load history: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logPdfOpened(String pdfId, int pageNumber, int totalPages) async {
    try {
      await _historyService.logPdfOpened(
        pdfId: pdfId,
        pageNumber: pageNumber,
        totalPages: totalPages,
      );
      await loadHistory();
    } catch (e) {
      _error = 'Failed to log history: $e';
      notifyListeners();
    }
  }

  Future<void> deleteHistoryEntry(String id) async {
    try {
      await _historyService.deleteHistoryEntry(id);
      await loadHistory();
    } catch (e) {
      _error = 'Failed to delete history entry: $e';
      notifyListeners();
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _historyService.clearAllHistory();
      await loadHistory();
    } catch (e) {
      _error = 'Failed to clear history: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
