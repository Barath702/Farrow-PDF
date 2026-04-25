import 'package:flutter/foundation.dart';
import '../models/bookmark.dart';
import '../models/pdf_document.dart';
import '../services/bookmark_service.dart';
import '../services/pdf_library_service.dart';

class BookmarkProvider extends ChangeNotifier {
  final BookmarkService _bookmarkService = BookmarkService();
  final PdfLibraryService _pdfLibraryService = PdfLibraryService();

  List<Bookmark> _bookmarks = [];
  List<Bookmark> _pdfBookmarks = [];
  Map<String, PdfDocument> _pdfDocuments = {};
  bool _isLoading = false;
  String? _error;

  List<Bookmark> get bookmarks => _bookmarks;
  List<Bookmark> get pdfBookmarks => _pdfBookmarks;
  Map<String, PdfDocument> get pdfDocuments => _pdfDocuments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllBookmarks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bookmarks = await _bookmarkService.getAllBookmarks();

      // Load PDF documents for bookmarks
      _pdfDocuments = {};
      for (final bookmark in _bookmarks) {
        if (!_pdfDocuments.containsKey(bookmark.pdfId)) {
          final doc = await _pdfLibraryService.getDocument(bookmark.pdfId);
          if (doc != null) {
            _pdfDocuments[bookmark.pdfId] = doc;
          }
        }
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to load bookmarks: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBookmarksForPdf(String pdfId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pdfBookmarks = await _bookmarkService.getBookmarksForPdf(pdfId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load bookmarks: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> isPageBookmarked(String pdfId, int pageNumber) async {
    return await _bookmarkService.isPageBookmarked(pdfId, pageNumber);
  }

  Future<void> toggleBookmark({
    required String pdfId,
    required int pageNumber,
    String? pageTitle,
    String? thumbnailPath,
  }) async {
    try {
      await _bookmarkService.toggleBookmark(
        pdfId: pdfId,
        pageNumber: pageNumber,
        pageTitle: pageTitle,
        thumbnailPath: thumbnailPath,
      );
      await loadAllBookmarks();
      await loadBookmarksForPdf(pdfId);
    } catch (e) {
      _error = 'Failed to toggle bookmark: $e';
      notifyListeners();
    }
  }

  Future<void> addBookmark({
    required String pdfId,
    required int pageNumber,
    String? pageTitle,
    String? thumbnailPath,
  }) async {
    try {
      await _bookmarkService.addBookmark(
        pdfId: pdfId,
        pageNumber: pageNumber,
        pageTitle: pageTitle,
        thumbnailPath: thumbnailPath,
      );
      await loadAllBookmarks();
      await loadBookmarksForPdf(pdfId);
    } catch (e) {
      _error = 'Failed to add bookmark: $e';
      notifyListeners();
    }
  }

  Future<void> removeBookmark(String id) async {
    try {
      await _bookmarkService.removeBookmark(id);
      await loadAllBookmarks();
    } catch (e) {
      _error = 'Failed to remove bookmark: $e';
      notifyListeners();
    }
  }

  Future<void> removeBookmarkByPage(String pdfId, int pageNumber) async {
    try {
      await _bookmarkService.removeBookmarkByPage(pdfId, pageNumber);
      await loadAllBookmarks();
      await loadBookmarksForPdf(pdfId);
    } catch (e) {
      _error = 'Failed to remove bookmark: $e';
      notifyListeners();
    }
  }

  Future<void> updateBookmarkThumbnail(
      String bookmarkId, String thumbnailPath) async {
    try {
      await _bookmarkService.updateBookmarkThumbnail(bookmarkId, thumbnailPath);
      await loadAllBookmarks();
    } catch (e) {
      _error = 'Failed to update thumbnail: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
