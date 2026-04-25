import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_document.dart' as model;
import '../services/pdf_library_service.dart';
import '../services/thumbnail_service.dart';
import '../services/file_scanner_service.dart';

enum SortOption { date, name, size }

/// Lightweight metadata cache for fast PDF loading
class PdfMeta {
  final int totalPages;
  final Uint8List? thumbnailBytes;

  PdfMeta({
    required this.totalPages,
    this.thumbnailBytes,
  });
}

class PdfLibraryProvider extends ChangeNotifier {
  final PdfLibraryService _pdfLibraryService = PdfLibraryService();
  final ThumbnailService _thumbnailService = ThumbnailService();

  List<model.PdfDocument> _allDocuments = [];
  List<model.PdfDocument> _recentDocuments = [];
  List<model.PdfDocument> _inProgressDocuments = [];
  bool _isLoading = false;
  String? _error;
  SortOption _sortOption = SortOption.date;
  bool _isAscending = false; // Default: descending (newest first)

  // PDF document cache for fast reopening
  final Map<String, PdfDocument> _pdfCache = {};
  static const int _maxCacheSize = 10;

  // Lightweight metadata cache (totalPages + thumbnail)
  final Map<String, PdfMeta> _metaCache = {};
  static const int _maxMetaCacheSize = 50;

  List<model.PdfDocument> get allDocuments => _getSortedDocuments(_allDocuments);
  List<model.PdfDocument> get recentDocuments => _recentDocuments;
  List<model.PdfDocument> get inProgressDocuments => _inProgressDocuments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  SortOption get sortOption => _sortOption;
  bool get isAscending => _isAscending;

  List<model.PdfDocument> _getSortedDocuments(List<model.PdfDocument> documents) {
    final sorted = List<model.PdfDocument>.from(documents);
    switch (_sortOption) {
      case SortOption.date:
        sorted.sort((a, b) {
          final dateA = a.lastOpenedAt ?? DateTime(1970);
          final dateB = b.lastOpenedAt ?? DateTime(1970);
          return _isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });
        break;
      case SortOption.name:
        sorted.sort((a, b) {
          return _isAscending
              ? a.fileName.compareTo(b.fileName)
              : b.fileName.compareTo(a.fileName);
        });
        break;
      case SortOption.size:
        sorted.sort((a, b) {
          return _isAscending
              ? a.fileSize.compareTo(b.fileSize)
              : b.fileSize.compareTo(a.fileSize);
        });
        break;
    }
    return sorted;
  }

  Future<void> loadDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allDocuments = await _pdfLibraryService.getAllDocuments();
      _recentDocuments = await _pdfLibraryService.getRecentlyOpened(limit: 10);
      _inProgressDocuments =
          await _pdfLibraryService.getInProgressDocuments();
      _error = null;
    } catch (e) {
      _error = 'Failed to load documents: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import PDF files discovered by file scanner
  Future<int> importScannedPdfs(List<ScannedPdfFile> scannedFiles) async {
    int importedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;
    
    if (kDebugMode) print('IMPORT: Starting import of ${scannedFiles.length} scanned files');
    
    for (final scannedFile in scannedFiles) {
      try {
        // Check if already imported
        if (await _pdfLibraryService.documentExists(scannedFile.filePath)) {
          skippedCount++;
          continue;
        }

        // Try to get PDF page count; fallback to 0 if openFile fails
        int totalPages = 0;
        try {
          final document = await PdfDocument.openFile(scannedFile.filePath);
          totalPages = document.pages.length;
          await document.dispose();
        } catch (e) {
          if (kDebugMode) print('IMPORT: Could not open PDF for page count: ${scannedFile.fileName} - $e');
          // Still import with 0 pages - better than skipping entirely
        }

        final pdfDocument = await _pdfLibraryService.addDocument(
          filePath: scannedFile.filePath,
          fileName: scannedFile.fileName,
          fileSize: scannedFile.fileSize,
          totalPages: totalPages,
        );

        // Generate cover thumbnail in background
        _generateThumbnail(pdfDocument);

        importedCount++;
        if (kDebugMode) print('IMPORT: Imported ${scannedFile.fileName}');
      } catch (e) {
        failedCount++;
        if (kDebugMode) print('IMPORT ERROR: Failed to import ${scannedFile.fileName} - $e');
        continue;
      }
    }

    if (kDebugMode) print('IMPORT: Done. Imported=$importedCount, Skipped=$skippedCount, Failed=$failedCount');
    
    // ALWAYS reload documents - even failed imports may have partial data
    await loadDocuments();
    
    return importedCount;
  }

  Future<void> setSortOption(SortOption option) async {
    _sortOption = option;
    notifyListeners();
  }

  /// Toggle ascending/descending sort direction
  void toggleSortDirection() {
    _isAscending = !_isAscending;
    notifyListeners();
  }

  /// Set explicit sort direction
  void setSortDirection(bool ascending) {
    _isAscending = ascending;
    notifyListeners();
  }

  /// Import PDF(s) via file picker with debug logging
  Future<List<model.PdfDocument>> importPdf() async {
    final List<model.PdfDocument> importedDocs = [];
    
    try {
      if (kDebugMode) print('PICKER: Starting file picker...');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,  // Get bytes for files without paths
      );

      if (result == null || result.files.isEmpty) {
        if (kDebugMode) print('PICKER: No files selected');
        return importedDocs;
      }

      if (kDebugMode) print('PICKER: Selected ${result.files.length} files');

      for (final file in result.files) {
        if (kDebugMode) {
          print('PICKED FILE PATH: ${file.path}');
          print('PICKED FILE NAME: ${file.name}');
          print('PICKED FILE BYTES: ${file.bytes?.length ?? 0} bytes');
        }

        String? filePath = file.path;
        Uint8List? fileBytes = file.bytes;
        String fileName = file.name;
        int fileSize = 0;

        // Handle case where path is null but bytes are available
        if (filePath == null && fileBytes != null) {
          // Save to temp directory
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/${file.name}';
          await File(tempPath).writeAsBytes(fileBytes);
          filePath = tempPath;
          fileSize = fileBytes.length;
          if (kDebugMode) print('PICKER: Saved to temp path: $tempPath');
        } else if (filePath != null) {
          try {
            fileSize = await File(filePath).length();
          } catch (e) {
            fileSize = fileBytes?.length ?? 0;
          }
        } else {
          if (kDebugMode) print('PICKER: Skipping file - no path or bytes');
          continue;
        }

        // Check if already imported
        if (await _pdfLibraryService.documentExists(filePath)) {
          if (kDebugMode) print('PICKER: File already imported: $fileName');
          continue;
        }

        // Try to get PDF page count; fallback to 0 if openFile fails
        int totalPages = 0;
        try {
          final document = await PdfDocument.openFile(filePath);
          totalPages = document.pages.length;
          await document.dispose();
        } catch (e) {
          if (kDebugMode) print('PICKER: Could not open PDF for page count: $fileName - $e');
          // Still import with 0 pages
        }

        final pdfDocument = await _pdfLibraryService.addDocument(
          filePath: filePath,
          fileName: fileName,
          fileSize: fileSize,
          totalPages: totalPages,
        );

        // Generate cover thumbnail in background
        _generateThumbnail(pdfDocument);
        
        importedDocs.add(pdfDocument);
        if (kDebugMode) print('PICKER: Successfully imported: $fileName');
      }

      // ALWAYS reload documents
      await loadDocuments();
      if (kDebugMode) print('PICKER: Total imported: ${importedDocs.length} files');
      if (kDebugMode) print('PICKER: Total documents in library: ${allDocuments.length}');
      return importedDocs;
    } catch (e) {
      if (kDebugMode) print('PICKER ERROR: $e');
      _error = 'Failed to import PDF: $e';
      notifyListeners();
      return importedDocs;
    }
  }

  Future<void> _generateThumbnail(model.PdfDocument document) async {
    try {
      final thumbnailPath = await _thumbnailService.generateThumbnail(
        document.filePath,
        document.id,
        pageNumber: 1,
      );
      if (thumbnailPath != null) {
        await _pdfLibraryService.updateCoverThumbnail(
            document.id, thumbnailPath);
        await loadDocuments();
      }
    } catch (e) {
      // Thumbnail generation failed, but document is still imported
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _thumbnailService.deleteAllThumbnailsForPdf(id);
      await _pdfLibraryService.deleteDocument(id);
      await loadDocuments();
    } catch (e) {
      _error = 'Failed to delete document: $e';
      notifyListeners();
    }
  }

  Future<void> updateLastOpened(String id, int page) async {
    try {
      final doc = await _pdfLibraryService.getDocument(id);
      if (doc != null) {
        await _pdfLibraryService.updateReadingProgress(id, page, doc.totalPages);
        await loadDocuments();
      }
    } catch (e) {
      _error = 'Failed to update progress: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update total page count for a document (called after PDF is opened in viewer)
  Future<void> updateTotalPages(String id, int totalPages) async {
    try {
      final doc = await _pdfLibraryService.getDocument(id);
      if (doc != null && doc.totalPages != totalPages) {
        final updated = doc.copyWith(totalPages: totalPages);
        await _pdfLibraryService.updateDocument(updated);
        // Regenerate thumbnail if page count was previously 0
        if (doc.totalPages == 0 && totalPages > 0) {
          _generateThumbnail(updated);
        }
        await loadDocuments();
      }
    } catch (e) {
      // Silent fail - page count update is not critical
    }
  }

  /// Get documents that have reading progress (for "Continue Reading" section)
  List<model.PdfDocument> getDocumentsWithProgress() {
    return _allDocuments.where((doc) =>
      doc.lastOpenedPage > 1 ||
      (doc.lastOpenedAt != null && doc.lastOpenedAt!.isAfter(DateTime(1970)))
    ).toList();
  }

  /// Get cached PDF document or null if not cached
  PdfDocument? getCachedDocument(String filePath) {
    return _pdfCache[filePath];
  }

  /// Cache a PDF document with size limit
  void cacheDocument(String filePath, PdfDocument document) {
    // Remove oldest if cache is full
    if (_pdfCache.length >= _maxCacheSize) {
      final oldestKey = _pdfCache.keys.first;
      _pdfCache[oldestKey]?.dispose();
      _pdfCache.remove(oldestKey);
    }
    _pdfCache[filePath] = document;
  }

  /// Clear PDF cache
  Future<void> clearCache() async {
    for (final doc in _pdfCache.values) {
      await doc.dispose();
    }
    _pdfCache.clear();
  }

  /// Preload PDF metadata (page count and thumbnails) in background
  Future<void> preloadPdfMetadata() async {
    Future.microtask(() async {
      try {
        final docs = _allDocuments.where((doc) => doc.totalPages == 0).toList();
        if (docs.isEmpty) return;

        // Priority loading: first 10 immediate, rest background
        final priorityDocs = docs.take(10).toList();
        final backgroundDocs = docs.skip(10).toList();

        // Load priority docs with concurrency limit of 3
        await _loadWithConcurrencyLimit(priorityDocs, 3);

        // Load remaining docs in background with lower concurrency
        _loadWithConcurrencyLimit(backgroundDocs, 2);
      } catch (e) {
        // Silent fail - preload is not critical
      }
    });
  }

  /// Load PDFs with concurrency limit
  Future<void> _loadWithConcurrencyLimit(List<model.PdfDocument> docs, int concurrency) async {
    if (docs.isEmpty) return;

    for (int i = 0; i < docs.length; i += concurrency) {
      final batch = docs.skip(i).take(concurrency).toList();
      await Future.wait(
        batch.map((doc) => _preloadSinglePdf(doc)),
        eagerError: false,
      );
      // Add small delay between batches to prevent UI freeze
      if (i + concurrency < docs.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// Preload single PDF with lightweight open and fast thumbnail
  Future<void> _preloadSinglePdf(model.PdfDocument doc) async {
    // Check cache first
    if (_metaCache.containsKey(doc.filePath)) {
      final meta = _metaCache[doc.filePath]!;
      if (meta.totalPages > 0 && doc.totalPages != meta.totalPages) {
        await updateTotalPages(doc.id, meta.totalPages);
      }
      return;
    }

    try {
      // Lightweight open - don't preload pages
      final pdfDoc = await PdfDocument.openFile(doc.filePath);
      final actualPages = pdfDoc.pages.length;

      // Generate ultra fast thumbnail at ultra low resolution (80x100)
      Uint8List? thumbnailBytes;
      if (actualPages > 0) {
        try {
          final page = pdfDoc.pages[0];
          final image = await page.render(
            width: 80,
            height: 100,
          );
          if (image != null) {
            thumbnailBytes = image.pixels;
            image.dispose();
          }
        } catch (e) {
          // Thumbnail generation failed, continue without it
        }
      }

      await pdfDoc.dispose();

      // Cache metadata
      _metaCache[doc.filePath] = PdfMeta(
        totalPages: actualPages,
        thumbnailBytes: thumbnailBytes,
      );

      // Limit cache size
      if (_metaCache.length > _maxMetaCacheSize) {
        _metaCache.remove(_metaCache.keys.first);
      }

      // Update database if page count changed
      if (actualPages > 0 && doc.totalPages != actualPages) {
        await updateTotalPages(doc.id, actualPages);
      }
    } catch (e) {
      // Ignore corrupted PDFs
    }
  }
}
