import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/pdf_document.dart';
import '../models/note.dart';
import '../services/pdf_library_service.dart';
import '../services/bookmark_service.dart';
import '../services/note_service.dart';
import '../services/thumbnail_service.dart';
import 'reading_progress_provider.dart';

class ReaderProvider extends ChangeNotifier {
  final PdfLibraryService _pdfLibraryService = PdfLibraryService();
  final BookmarkService _bookmarkService = BookmarkService();
  final NoteService _noteService = NoteService();
  final ThumbnailService _thumbnailService = ThumbnailService();

  // Unified progress provider - set externally
  ReadingProgressProvider? _progressProvider;

  void setProgressProvider(ReadingProgressProvider provider) {
    _progressProvider = provider;
  }

  PdfDocument? _currentDocument;
  int _currentPage = 1;
  double _zoomLevel = 1.0;
  bool _isBookmarked = false;
  List<Note> _pageNotes = [];
  bool _isLoading = false;
  String? _error;
  bool _uiVisible = true;

  // Per-PDF night mode override
  bool _nightModeOverride = false;

  PdfDocument? get currentDocument => _currentDocument;
  int get currentPage => _currentPage;
  double get zoomLevel => _zoomLevel;
  bool get isBookmarked => _isBookmarked;
  List<Note> get pageNotes => _pageNotes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get uiVisible => _uiVisible;

  /// Get effective night mode for current PDF
  /// Combines global setting with per-PDF override
  bool isNightModeEnabled(bool globalNightMode) {
    // If global is on, always use dark mode
    if (globalNightMode) return true;
    // Otherwise use per-PDF override
    return _nightModeOverride;
  }

  /// Toggle night mode for current PDF only
  void togglePdfNightMode() {
    _nightModeOverride = !_nightModeOverride;
    notifyListeners();
  }

  /// Reset per-PDF night mode when loading new document
  void resetPdfNightMode() {
    _nightModeOverride = false;
    notifyListeners();
  }

  Future<void> loadDocument(String pdfId, {bool rememberLastPage = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentDocument = await _pdfLibraryService.getDocument(pdfId);
      if (_currentDocument == null) {
        _error = 'Document not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Reset per-PDF night mode for new document
      resetPdfNightMode();

      // Load last page from unified progress provider
      if (rememberLastPage && _progressProvider != null) {
        _currentPage = _progressProvider!.getLastPage(pdfId);
      } else if (rememberLastPage) {
        _currentPage = _currentDocument!.lastOpenedPage;
      } else {
        _currentPage = 1;
      }

      // Ensure page is within bounds
      if (_currentPage < 1) _currentPage = 1;
      if (_currentDocument!.totalPages > 0 && _currentPage > _currentDocument!.totalPages) {
        _currentPage = _currentDocument!.totalPages;
      }

      _zoomLevel = 1.0; // Default zoom

      await _checkBookmarkStatus();
      await _loadPageNotes();

      // Mark as opened in unified progress
      _progressProvider?.markOpened(pdfId, _currentPage);

      _error = null;
    } catch (e) {
      _error = 'Failed to load document: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> goToPage(int page) async {
    if (_currentDocument == null) return;

    if (page < 1) page = 1;
    if (_currentDocument!.totalPages > 0 && page > _currentDocument!.totalPages) {
      page = _currentDocument!.totalPages;
    }

    _currentPage = page;
    await _checkBookmarkStatus();
    await _loadPageNotes();
    await _saveProgress();
    notifyListeners();
  }

  // Lightweight page jump for real-time scrollbar scrubbing
  void jumpToPage(int page) {
    if (_currentDocument == null) return;

    if (page < 1) page = 1;
    if (_currentDocument!.totalPages > 0 && page > _currentDocument!.totalPages) {
      page = _currentDocument!.totalPages;
    }

    if (_currentPage != page) {
      _currentPage = page;
      // Skip heavy operations for real-time updates
      // Only notify listeners to update UI
      notifyListeners();
    }
  }

  Future<void> nextPage() async {
    if (_currentDocument == null) return;
    if (_currentPage < _currentDocument!.totalPages) {
      await goToPage(_currentPage + 1);
    }
  }

  Future<void> previousPage() async {
    if (_currentPage > 1) {
      await goToPage(_currentPage - 1);
    }
  }

  Future<void> setZoom(double zoom) async {
    _zoomLevel = zoom.clamp(0.5, 3.0);
    notifyListeners();
  }

  Future<void> zoomIn() async {
    await setZoom(_zoomLevel + 0.25);
  }

  Future<void> zoomOut() async {
    await setZoom(_zoomLevel - 0.25);
  }

  void toggleUiVisibility() {
    _uiVisible = !_uiVisible;
    notifyListeners();
  }

  void setUiVisible(bool visible) {
    _uiVisible = visible;
    notifyListeners();
  }

  Future<void> toggleBookmark({String? pageTitle}) async {
    if (_currentDocument == null) return;

    try {
      await _bookmarkService.toggleBookmark(
        pdfId: _currentDocument!.id,
        pageNumber: _currentPage,
        pageTitle: pageTitle,
      );
      await _checkBookmarkStatus();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to toggle bookmark: $e';
      notifyListeners();
    }
  }

  Future<void> _checkBookmarkStatus() async {
    if (_currentDocument == null) return;
    _isBookmarked = await _bookmarkService.isPageBookmarked(
      _currentDocument!.id,
      _currentPage,
    );
  }

  Future<void> _loadPageNotes() async {
    if (_currentDocument == null) return;
    _pageNotes = await _noteService.getNotesForPage(
      _currentDocument!.id,
      _currentPage,
    );
  }

  Future<void> addNote(String text) async {
    if (_currentDocument == null) return;

    try {
      await _noteService.addNote(
        pdfId: _currentDocument!.id,
        pageNumber: _currentPage,
        noteText: text,
      );
      await _loadPageNotes();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add note: $e';
      notifyListeners();
    }
  }

  Future<void> updateNote(String noteId, String text) async {
    try {
      await _noteService.updateNote(noteId, text);
      await _loadPageNotes();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update note: $e';
      notifyListeners();
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _noteService.deleteNote(noteId);
      await _loadPageNotes();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete note: $e';
      notifyListeners();
    }
  }

  Future<void> _saveProgress() async {
    if (_currentDocument == null) return;

    // Use unified progress provider for real-time updates
    await _progressProvider?.updateProgress(_currentDocument!.id, _currentPage);
  }

  /// Call this when exiting the PDF viewer to save final progress
  Future<void> saveProgressOnExit() async {
    if (_currentDocument == null) return;
    await _progressProvider?.saveOnExit(_currentDocument!.id, _currentPage);
  }

  Future<Uint8List?> captureCurrentPage() async {
    if (_currentDocument == null) return null;
    // Use RepaintBoundary capture if available, otherwise fall back to thumbnail service
    if (_captureCallback != null) {
      return await _captureCallback!();
    }
    return await _thumbnailService.getThumbnailBytes(
      _currentDocument!.filePath,
      _currentDocument!.id,
      pageNumber: _currentPage,
    );
  }

  // Callback for RepaintBoundary capture from widget
  Future<Uint8List?> Function()? _captureCallback;

  void setCaptureCallback(Future<Uint8List?> Function()? callback) {
    _captureCallback = callback;
  }

  Future<String?> generatePageThumbnail() async {
    if (_currentDocument == null) return null;
    return await _thumbnailService.generateThumbnail(
      _currentDocument!.filePath,
      _currentDocument!.id,
      pageNumber: _currentPage,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    // Save progress before clearing if we have a document
    if (_currentDocument != null) {
      saveProgressOnExit();
    }
    _currentDocument = null;
    _currentPage = 1;
    _zoomLevel = 1.0;
    _isBookmarked = false;
    _pageNotes = [];
    _uiVisible = true;
    _error = null;
    notifyListeners();
  }
}
