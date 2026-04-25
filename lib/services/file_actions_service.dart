import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pdf_document.dart';
import '../services/pdf_library_service.dart';
import '../services/bookmark_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'file_scanner_service.dart';

class FileActionsService {
  final PdfLibraryService _pdfLibraryService = PdfLibraryService();
  final BookmarkService _bookmarkService = BookmarkService();
  final HistoryService _historyService = HistoryService();

  /// Open PDF with external application
  Future<void> openWith(BuildContext context, String filePath) async {
    try {
      if (Platform.isAndroid) {
        final result = await OpenFilex.open(filePath, type: 'application/pdf');
        if (result.type != ResultType.done) {
          _showSnackBar(context, 'No app available to open PDF');
        }
      } else {
        // Linux fallback using url_launcher
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          _showSnackBar(context, 'Could not open file');
        }
      }
    } catch (e) {
      _showSnackBar(context, 'Error opening file: $e');
    }
  }

  /// Share PDF file
  Future<void> shareFile(BuildContext context, String filePath) async {
    try {
      final file = XFile(filePath);
      await Share.shareXFiles([file], text: 'Sharing PDF file');
    } catch (e) {
      _showSnackBar(context, 'Error sharing file: $e');
    }
  }

  /// Copy PDF to selected directory
  Future<bool> copyTo(BuildContext context, String sourcePath) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Destination Folder',
      );

      if (result == null) return false;

      final sourceFile = File(sourcePath);
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final destinationPath = '$result${Platform.pathSeparator}$fileName';

      // Check if file already exists
      if (File(destinationPath).existsSync()) {
        final shouldOverwrite = await _showConfirmDialog(
          context,
          'File Exists',
          'A file with the same name already exists. Overwrite?',
        );
        if (!shouldOverwrite) return false;
      }

      // Show progress indicator
      _showSnackBar(context, 'Copying file...', duration: const Duration(seconds: 1));

      await sourceFile.copy(destinationPath);

      _showSnackBar(context, 'File copied to: $result');
      return true;
    } catch (e) {
      _showSnackBar(context, 'Error copying file: $e');
      return false;
    }
  }

  /// Move PDF to selected directory
  Future<bool> moveTo(BuildContext context, String pdfId, String sourcePath) async {
    try {
      // Show confirmation dialog first
      final shouldMove = await _showConfirmDialog(
        context,
        'Move File',
        'This will move the file from its current location. The original file will be removed. Continue?',
      );

      if (!shouldMove) return false;

      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Destination Folder',
      );

      if (result == null) return false;

      final sourceFile = File(sourcePath);
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final destinationPath = '$result${Platform.pathSeparator}$fileName';

      // Check if file already exists
      if (File(destinationPath).existsSync()) {
        final shouldOverwrite = await _showConfirmDialog(
          context,
          'File Exists',
          'A file with the same name already exists. Overwrite?',
        );
        if (!shouldOverwrite) return false;
      }

      // Copy file to new location
      await sourceFile.copy(destinationPath);

      // Delete original file
      await sourceFile.delete();

      // Update database with new path
      await _pdfLibraryService.updateFilePath(pdfId, destinationPath);

      _showSnackBar(context, 'File moved to: $result');
      return true;
    } catch (e) {
      _showSnackBar(context, 'Error moving file: $e');
      return false;
    }
  }

  /// Move file to trash/permanently delete
  Future<bool> moveToTrash(BuildContext context, String pdfId, String filePath) async {
    try {
      // Show confirmation dialog
      final shouldDelete = await _showConfirmDialog(
        context,
        'Delete File',
        'This will permanently delete the PDF file. This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: AppColors.primaryContainer,
      );

      if (!shouldDelete) return false;

      // Delete the actual file
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from database
      await _pdfLibraryService.deleteDocument(pdfId);

      // Remove related data
      await _bookmarkService.deleteAllBookmarksForPdf(pdfId);
      await _historyService.deleteHistoryForPdf(pdfId);

      _showSnackBar(context, 'File deleted');
      return true;
    } catch (e) {
      _showSnackBar(context, 'Error deleting file: $e');
      return false;
    }
  }

  /// Show file info in a bottom sheet
  void showFileInfo(BuildContext context, PdfDocument document, int currentPage) {
    final file = File(document.filePath);
    FileStat? stat;
    
    try {
      stat = file.statSync();
    } catch (e) {
      // File stat failed
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FileInfoSheet(
        document: document,
        currentPage: currentPage,
        stat: stat,
      ),
    );
  }

  /// Show confirmation dialog
  Future<bool> _showConfirmDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Confirm',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(color: confirmColor ?? AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show snackbar message
  void _showSnackBar(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceContainer,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}

/// File Info Sheet Widget
class _FileInfoSheet extends StatelessWidget {
  final PdfDocument document;
  final int currentPage;
  final FileStat? stat;

  const _FileInfoSheet({
    required this.document,
    required this.currentPage,
    this.stat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primaryContainer),
              const SizedBox(width: 12),
              Text(
                'File Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info rows
          _buildInfoRow('Full Name', document.fileName),
          _buildInfoRow('File Size', FileScannerService.formatFileSize(document.fileSize)),
          _buildInfoRow('Location', document.filePath),
          if (stat != null)
            _buildInfoRow(
              'Last Modified',
              _formatDateTime(stat!.modified),
            ),
          if (stat != null && stat!.changed != stat!.modified)
            _buildInfoRow(
              'Created',
              _formatDateTime(stat!.changed),
            ),
          _buildInfoRow('Total Pages', '${document.totalPages}'),
          _buildInfoRow('Current Page', '$currentPage'),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.primaryContainer,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
