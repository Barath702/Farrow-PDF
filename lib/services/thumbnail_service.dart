import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:image/image.dart' as img;

/// Thumbnail Service with memory caching and optimized rendering
/// Always renders first page only for consistent performance
class ThumbnailService {
  static const String _thumbnailsDir = 'thumbnails';
  static const double _thumbnailWidth = 200;
  static const double _thumbnailHeight = 300;

  // Memory cache for thumbnail bytes
  final Map<String, Uint8List> _memoryCache = {};

  /// Singleton instance
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  /// Get thumbnail bytes with caching
  /// Always renders page 1 for consistency
  Future<Uint8List?> getThumbnailBytes(
    String filePath,
    String pdfId, {
    int pageNumber = 1,
  }) async {
    final cacheKey = '${pdfId}_$pageNumber';

    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // Check if file exists
    if (!File(filePath).existsSync()) {
      return null;
    }

    try {
      // Try to load from disk cache first
      final cachedBytes = await _loadFromDiskCache(pdfId, pageNumber);
      if (cachedBytes != null) {
        _memoryCache[cacheKey] = cachedBytes;
        return cachedBytes;
      }

      // Generate new thumbnail
      final bytes = await _generateThumbnail(filePath, pdfId, pageNumber);
      if (bytes != null) {
        _memoryCache[cacheKey] = bytes;
        await _saveToDiskCache(pdfId, pageNumber, bytes);
      }
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Generate thumbnail from PDF
  /// Always renders first page with optimized size
  Future<Uint8List?> _generateThumbnail(
    String filePath,
    String pdfId,
    int pageNumber,
  ) async {
    PdfDocument? document;
    try {
      // Open PDF document
      document = await PdfDocument.openFile(filePath);

      // Get first page (index 0)
      if (document.pages.isEmpty) return null;
      final page = document.pages[0];

      // Get page dimensions
      final pageSize = page.size;
      final aspectRatio = pageSize.width / pageSize.height;

      // Calculate render dimensions (max 200x300)
      int renderWidth = _thumbnailWidth.round();
      int renderHeight = (renderWidth / aspectRatio).round();

      // Ensure height doesn't exceed max
      if (renderHeight > _thumbnailHeight) {
        renderHeight = _thumbnailHeight.round();
        renderWidth = (renderHeight * aspectRatio).round();
      }

      // Render page to image
      final image = await page.render(
        width: renderWidth,
        height: renderHeight,
        fullHeight: renderHeight.toDouble(),
      );

      if (image == null || image.pixels == null) return null;

      // Convert BGRA to RGBA and encode as PNG
      final rgbaBytes = _convertBGRAtoRGBA(
        image.pixels!,
        image.width,
        image.height,
      );

      final decodedImage = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: rgbaBytes.buffer,
        numChannels: 4,
      );

      return Uint8List.fromList(img.encodePng(decodedImage));
    } catch (e) {
      return null;
    } finally {
      document?.dispose();
    }
  }

  /// Convert BGRA pixel data to RGBA format
  Uint8List _convertBGRAtoRGBA(Uint8List bgraBytes, int width, int height) {
    final rgbaBytes = Uint8List(bgraBytes.length);
    final pixelCount = width * height;

    for (int i = 0; i < pixelCount; i++) {
      final offset = i * 4;
      rgbaBytes[offset] = bgraBytes[offset + 2];     // R <- B
      rgbaBytes[offset + 1] = bgraBytes[offset + 1]; // G <- G
      rgbaBytes[offset + 2] = bgraBytes[offset];     // B <- R
      rgbaBytes[offset + 3] = bgraBytes[offset + 3]; // A <- A
    }

    return rgbaBytes;
  }

  /// Load thumbnail from disk cache
  Future<Uint8List?> _loadFromDiskCache(String pdfId, int pageNumber) async {
    try {
      final path = await _getThumbnailPath(pdfId, pageNumber);
      if (path == null) return null;

      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }

  /// Save thumbnail to disk cache
  Future<void> _saveToDiskCache(
    String pdfId,
    int pageNumber,
    Uint8List bytes,
  ) async {
    try {
      final path = await _getThumbnailPath(pdfId, pageNumber);
      if (path == null) return;

      final file = File(path);
      await file.writeAsBytes(bytes);
    } catch (e) {
      // Silent fail
    }
  }

  /// Get thumbnail file path
  Future<String?> _getThumbnailPath(String pdfId, int pageNumber) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${dir.path}/$_thumbnailsDir');

      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      return '${thumbnailsDir.path}/${pdfId}_page_$pageNumber.png';
    } catch (e) {
      return null;
    }
  }

  /// Legacy method: Get thumbnail file path (for backward compatibility)
  Future<String?> getThumbnailPath(String pdfId, int pageNumber) async {
    return _getThumbnailPath(pdfId, pageNumber);
  }

  /// Legacy method: Retrieve thumbnail path if exists
  Future<String?> retrieveThumbnail(String pdfId, int pageNumber) async {
    final path = await _getThumbnailPath(pdfId, pageNumber);
    if (path == null) return null;

    final file = File(path);
    if (await file.exists()) {
      return path;
    }
    return null;
  }

  /// Legacy method: Generate and save thumbnail file
  Future<String?> generateThumbnail(
    String filePath,
    String pdfId, {
    int pageNumber = 1,
    double width = 200,
    double? height,
  }) async {
    final bytes = await getThumbnailBytes(filePath, pdfId, pageNumber: pageNumber);
    if (bytes == null) return null;

    final path = await _getThumbnailPath(pdfId, pageNumber);
    return path;
  }

  /// Clear memory cache
  void clearMemoryCache() {
    _memoryCache.clear();
  }

  /// Delete specific thumbnail
  Future<void> deleteThumbnail(String pdfId, int pageNumber) async {
    final cacheKey = '${pdfId}_$pageNumber';
    _memoryCache.remove(cacheKey);

    final path = await _getThumbnailPath(pdfId, pageNumber);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Delete all thumbnails for a PDF
  Future<void> deleteAllThumbnailsForPdf(String pdfId) async {
    // Clear from memory cache
    final keysToRemove = _memoryCache.keys.where((k) => k.startsWith('${pdfId}_')).toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    // Clear from disk
    final dir = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory('${dir.path}/$_thumbnailsDir');

    if (await thumbnailsDir.exists()) {
      final files = await thumbnailsDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.contains('${pdfId}_page_')) {
          await file.delete();
        }
      }
    }
  }

  /// Clear all thumbnails
  Future<void> clearAllThumbnails() async {
    _memoryCache.clear();

    final dir = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory('${dir.path}/$_thumbnailsDir');

    if (await thumbnailsDir.exists()) {
      await thumbnailsDir.delete(recursive: true);
    }
  }
}
