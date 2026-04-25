import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'media_store_service.dart';

class ScannedPdfFile {
  final String filePath;
  final String fileName;
  final int fileSize;
  final DateTime lastModified;

  ScannedPdfFile({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.lastModified,
  });
}

class FileScannerService {
  static final Set<String> _scannedPaths = {};
  static List<ScannedPdfFile>? _cachedResults;
  static DateTime? _lastScanTime;
  static const Duration _minScanInterval = Duration(minutes: 5);

  /// Check if a recent scan result is available
  static bool hasCachedResults() {
    if (_cachedResults == null) return false;
    if (_lastScanTime == null) return false;
    final age = DateTime.now().difference(_lastScanTime!);
    return age < _minScanInterval;
  }

  /// Get cached scan results without scanning
  static List<ScannedPdfFile> getCachedResults() {
    return _cachedResults ?? [];
  }

  /// Clear cached results
  static void clearCache() {
    _cachedResults = null;
    _lastScanTime = null;
  }

  /// Scan device for PDF files - comprehensive approach
  /// Primary: Full recursive scan from /storage/emulated/0/ using await for
  /// Secondary: MediaStore as backup
  static Future<List<ScannedPdfFile>> scanForPdfFiles({bool forceRescan = false}) async {
    // Return cached results if available and not forcing rescan
    if (!forceRescan && hasCachedResults()) {
      return _cachedResults!;
    }

    if (kDebugMode) print('SCAN STARTED');

    final Set<String> scannedPaths = {};
    final List<ScannedPdfFile> pdfFiles = [];

    try {
      // On Android, do full recursive scan from root storage
      if (Platform.isAndroid) {
        final rootDir = Directory('/storage/emulated/0/');
        if (await rootDir.exists()) {
          if (kDebugMode) print('SCAN: Root directory exists, starting recursive scan...');
          await _scanDirectoryAsync(rootDir, pdfFiles, scannedPaths);
        } else {
          if (kDebugMode) print('SCAN ERROR: Root directory does not exist');
        }
      }

      // Fallback: MediaStore for any files we might have missed
      if (pdfFiles.isEmpty && Platform.isAndroid) {
        if (kDebugMode) print('SCAN: No PDFs found via directory scan, trying MediaStore...');
        final mediaStoreFiles = await MediaStoreService.queryPdfFiles();
        for (final file in mediaStoreFiles) {
          if (!scannedPaths.contains(file.filePath)) {
            scannedPaths.add(file.filePath);
            pdfFiles.add(file);
          }
        }
      }

      // Linux: Scan home directory
      if (Platform.isLinux) {
        final directoriesToScan = await _getDirectoriesToScan();
        for (final dir in directoriesToScan) {
          try {
            await _scanDirectory(dir, pdfFiles, scannedPaths);
          } catch (e) {
            continue;
          }
        }
      }

      // Sort by last modified date (newest first)
      pdfFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      // Cache results
      _cachedResults = pdfFiles;
      _lastScanTime = DateTime.now();

      if (kDebugMode) print('SCAN COMPLETE: ${pdfFiles.length} PDFs found');
      return pdfFiles;
    } catch (e) {
      if (kDebugMode) print('SCAN ERROR: $e');
      return pdfFiles;
    }
  }

  /// Full recursive scan using await for (non-blocking)
  static Future<void> _scanDirectoryAsync(
    Directory directory,
    List<ScannedPdfFile> pdfFiles,
    Set<String> scannedPaths,
  ) async {
    try {
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        try {
          if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
            // Avoid duplicates
            if (!scannedPaths.contains(entity.path)) {
              scannedPaths.add(entity.path);

              final stat = await entity.stat();
              pdfFiles.add(ScannedPdfFile(
                filePath: entity.path,
                fileName: path.basename(entity.path),
                fileSize: stat.size,
                lastModified: stat.modified,
              ));
            }
          }
        } catch (e) {
          // Skip files we can't access
          continue;
        }
      }
      if (kDebugMode) print('SCAN: Directory scan complete, found ${pdfFiles.length} so far');
    } catch (e) {
      if (kDebugMode) print('SCAN ERROR in directory: $e');
      return;
    }
  }

  /// Get directories to scan based on platform
  static Future<List<Directory>> _getDirectoriesToScan() async {
    final directoriesToScan = <Directory>[];

    if (Platform.isAndroid) {
      // Comprehensive Android directories including WhatsApp
      final primaryPaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
        '/storage/emulated/0/WhatsApp/Media/Documents',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        '/storage/emulated/0/',
      ];

      for (final dirPath in primaryPaths) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          directoriesToScan.add(dir);
        }
      }

      // External storage (SD card or other)
      try {
        final externalDirs = await getExternalStorageDirectories();
        if (externalDirs != null) {
          for (final dir in externalDirs) {
            if (await dir.exists()) {
              directoriesToScan.add(dir);
              // Also add common subdirectories on external storage
              final subDirs = [
                '${dir.path}/Download',
                '${dir.path}/Documents',
              ];
              for (final subDirPath in subDirs) {
                final subDir = Directory(subDirPath);
                if (await subDir.exists()) {
                  directoriesToScan.add(subDir);
                }
              }
            }
          }
        }
      } catch (e) {
        // Ignore if external storage not available
      }
    } else if (Platform.isLinux) {
      // Linux - scan home directory and common document folders
      final homeDir = Directory(Platform.environment['HOME'] ?? '/home');
      if (await homeDir.exists()) {
        directoriesToScan.add(homeDir);
      }

      final commonPaths = [
        '${Platform.environment['HOME']}/Documents',
        '${Platform.environment['HOME']}/Downloads',
        '${Platform.environment['HOME']}/Desktop',
      ];

      for (final dirPath in commonPaths) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          directoriesToScan.add(dir);
        }
      }
    } else {
      // Generic fallback for other platforms
      final appDir = await getApplicationDocumentsDirectory();
      directoriesToScan.add(appDir);

      final downloadDir = await _getDownloadsDirectory();
      if (downloadDir != null && await downloadDir.exists()) {
        directoriesToScan.add(downloadDir);
      }
    }

    return directoriesToScan;
  }

  /// Recursively scan a directory for PDF files
  static Future<void> _scanDirectory(
    Directory directory,
    List<ScannedPdfFile> pdfFiles,
    Set<String> scannedPaths,
  ) async {
    try {
      // Prevent scanning the same directory multiple times
      final resolvedPath = directory.resolveSymbolicLinksSync();
      if (_scannedPaths.contains(resolvedPath)) return;
      _scannedPaths.add(resolvedPath);

      // Limit recursion depth by checking path depth
      final pathDepth = resolvedPath.split(Platform.pathSeparator).length;
      if (pathDepth > 15) return; // Limit depth to prevent excessive scanning

      final entities = await directory.list(recursive: false).toList();

      for (final entity in entities) {
        try {
          if (entity is File) {
            final extension = path.extension(entity.path).toLowerCase();
            if (extension == '.pdf') {
              final stat = await entity.stat();

              // Avoid duplicates
              if (!scannedPaths.contains(entity.path)) {
                scannedPaths.add(entity.path);

                pdfFiles.add(ScannedPdfFile(
                  filePath: entity.path,
                  fileName: path.basename(entity.path),
                  fileSize: stat.size,
                  lastModified: stat.modified,
                ));
              }
            }
          } else if (entity is Directory) {
            // Recursively scan subdirectories
            // Check if directory name suggests it's a system/cache folder
            final dirName = path.basename(entity.path).toLowerCase();
            final skipDirs = [
              'android',
              'cache',
              'tmp',
              'temp',
              '.cache',
              '.tmp',
              'thumbnails',
              '.thumbnails',
              'node_modules',
              '.git',
              '.idea',
              'build',
              '.dart_tool',
              '.flutter',
              'data',
              'obb',
              '.nomedia',
            ];

            if (!skipDirs.any((skip) => dirName.contains(skip))) {
              await _scanDirectory(entity, pdfFiles, scannedPaths);
            }
          }
        } catch (e) {
          // Skip files we can't access
          continue;
        }
      }
    } catch (e) {
      // Directory might not be accessible
      return;
    }
  }

  /// Get downloads directory
  static Future<Directory?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        return Directory('/storage/emulated/0/Download');
      }
      return await getDownloadsDirectory();
    } catch (e) {
      return null;
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format date for display
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else {
      return '${(diff.inDays / 365).floor()} years ago';
    }
  }
}
