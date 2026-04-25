import 'package:flutter/foundation.dart';
import '../models/pdf_document.dart';
import '../models/reading_history.dart';
import '../services/pdf_library_service.dart';
import '../services/history_service.dart';

/// Unified progress data for a PDF
class PdfProgressData {
  final PdfDocument document;
  int currentPage;
  int totalPages;
  DateTime lastOpened;

  PdfProgressData({
    required this.document,
    required this.currentPage,
    required this.totalPages,
    required this.lastOpened,
  });

  String get filePath => document.filePath;
  String get fileName => document.fileName;
  String get id => document.id;

  double get progressPercentage =>
      totalPages > 0 ? currentPage / totalPages : 0.0;

  String get progressText => 'Pg ${currentPage > 0 ? currentPage : 1} of ${totalPages > 0 ? totalPages : 1}';
}

/// Unified Reading Progress Provider
/// Single source of truth for all reading progress data across all tabs
class ReadingProgressProvider extends ChangeNotifier {
  final PdfLibraryService _pdfLibraryService = PdfLibraryService();
  final HistoryService _historyService = HistoryService();

  // Unified progress map - key is document ID
  Map<String, PdfProgressData> _progressMap = {};
  bool _isLoading = false;
  String? _error;

  Map<String, PdfProgressData> get progressMap => _progressMap;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all progress data from services
  /// Only includes PDFs that have actual history (opened at least once)
  Future<void> loadProgress() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get history for last opened info
      final history = await _historyService.getAllHistory();
      final historyByPdfId = <String, ReadingHistory>{};
      for (final h in history) {
        if (!historyByPdfId.containsKey(h.pdfId) ||
            h.openedAt.isAfter(historyByPdfId[h.pdfId]!.openedAt)) {
          historyByPdfId[h.pdfId] = h;
        }
      }

      // Build unified progress map - only for PDFs with history
      _progressMap = {};
      for (final h in historyByPdfId.values) {
        final doc = await _pdfLibraryService.getDocument(h.pdfId);
        if (doc != null) {
          _progressMap[doc.id] = PdfProgressData(
            document: doc,
            currentPage: h.pageNumber > 0 ? h.pageNumber : 1,
            totalPages: doc.totalPages > 0 ? doc.totalPages : 1,
            lastOpened: h.openedAt,
          );
        }
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to load progress: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update progress when page changes (called from PDF viewer)
  Future<void> updateProgress(String pdfId, int currentPage) async {
    final existing = _progressMap[pdfId];
    if (existing == null) return;

    // Ensure currentPage is at least 1
    final safePage = currentPage > 0 ? currentPage : 1;

    // Update local state immediately for real-time UI
    final safeTotal = existing.totalPages > 0 ? existing.totalPages : 1;
    _progressMap[pdfId] = PdfProgressData(
      document: existing.document,
      currentPage: safePage,
      totalPages: safeTotal,
      lastOpened: DateTime.now(),
    );
    notifyListeners();

    // Persist to services
    try {
      await _pdfLibraryService.updateReadingProgress(
        pdfId,
        safePage,
        safeTotal,
      );
      await _historyService.logPdfOpened(
        pdfId: pdfId,
        pageNumber: safePage,
        totalPages: safeTotal,
      );
    } catch (e) {
      _error = 'Failed to save progress: $e';
      notifyListeners();
    }
  }

  /// Called when document is opened - updates lastOpened timestamp
  Future<void> markOpened(String pdfId, int currentPage) async {
    final existing = _progressMap[pdfId];
    if (existing == null) return;

    // Ensure currentPage is at least 1
    final safePage = currentPage > 0 ? currentPage : 1;
    final safeTotal = existing.totalPages > 0 ? existing.totalPages : 1;

    _progressMap[pdfId] = PdfProgressData(
      document: existing.document,
      currentPage: safePage,
      totalPages: safeTotal,
      lastOpened: DateTime.now(),
    );
    notifyListeners();

    try {
      await _historyService.logPdfOpened(
        pdfId: pdfId,
        pageNumber: safePage,
        totalPages: safeTotal,
      );
    } catch (e) {
      _error = 'Failed to log: $e';
      notifyListeners();
    }
  }

  /// Called when exiting PDF viewer - final save
  Future<void> saveOnExit(String pdfId, int currentPage) async {
    final existing = _progressMap[pdfId];
    if (existing == null) return;

    // Ensure currentPage is at least 1
    final safePage = currentPage > 0 ? currentPage : 1;
    final safeTotal = existing.totalPages > 0 ? existing.totalPages : 1;

    _progressMap[pdfId] = PdfProgressData(
      document: existing.document,
      currentPage: safePage,
      totalPages: safeTotal,
      lastOpened: DateTime.now(),
    );
    notifyListeners();

    try {
      await _pdfLibraryService.updateReadingProgress(
        pdfId,
        safePage,
        safeTotal,
      );
      await _historyService.logPdfOpened(
        pdfId: pdfId,
        pageNumber: safePage,
        totalPages: safeTotal,
      );
    } catch (e) {
      _error = 'Failed to save on exit: $e';
    }
  }

  /// Get progress for a specific PDF
  PdfProgressData? getProgress(String pdfId) => _progressMap[pdfId];

  /// Get last page for a PDF (for resuming reading)
  int getLastPage(String pdfId) {
    return _progressMap[pdfId]?.currentPage ?? 1;
  }

  /// Get documents for "Continue Reading" section
  /// Shows PDFs that have history entries (opened at least once)
  /// Sorted by lastOpened descending (most recent first)
  List<PdfProgressData> getContinueReading() {
    final withProgress = _progressMap.values.toList();
    withProgress.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return withProgress;
  }

  /// Get documents opened today
  List<PdfProgressData> getTodayDocuments() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _progressMap.values
        .where((p) {
          final openedDate = DateTime(
            p.lastOpened.year,
            p.lastOpened.month,
            p.lastOpened.day,
          );
          return openedDate.isAtSameMomentAs(today);
        })
        .toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
  }

  /// Get documents opened yesterday
  List<PdfProgressData> getYesterdayDocuments() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return _progressMap.values
        .where((p) {
          final openedDate = DateTime(
            p.lastOpened.year,
            p.lastOpened.month,
            p.lastOpened.day,
          );
          return openedDate.isAtSameMomentAs(yesterday);
        })
        .toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
  }

  /// Get documents from last 7 days (excluding today and yesterday)
  List<PdfProgressData> getLast7DaysDocuments() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last7DaysStart = today.subtract(const Duration(days: 7));

    return _progressMap.values
        .where((p) {
          final openedDate = DateTime(
            p.lastOpened.year,
            p.lastOpened.month,
            p.lastOpened.day,
          );
          return openedDate.isAfter(last7DaysStart) &&
              openedDate.isBefore(today) &&
              !openedDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)));
        })
        .toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
  }

  /// Get all documents sorted by last opened (for History tab)
  List<PdfProgressData> getAllByLastOpened() {
    final all = List<PdfProgressData>.from(_progressMap.values);
    all.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return all;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
