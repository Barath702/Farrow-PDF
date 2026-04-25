import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/pdf_document.dart';
import '../models/reading_history.dart';
import '../services/thumbnail_service.dart';
import '../theme/app_theme.dart';

class PdfCard extends StatelessWidget {
  final PdfDocument document;
  final VoidCallback? onTap;
  final bool showProgress;
  final ReadingHistory? history;
  final String? progressText;
  final int? currentPage;

  const PdfCard({
    super.key,
    required this.document,
    this.onTap,
    this.showProgress = true,
    this.history,
    this.progressText,
    this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    final lastPage = currentPage ?? history?.pageNumber ?? document.lastOpenedPage;
    final progress = lastPage / document.totalPages;
    final cleanFileName = document.fileName.replaceAll('.pdf', '').replaceAll('.PDF', '');

    return GestureDetector(
      onTap: onTap ?? () {
        // Navigate to PDF at last opened page (default to page 1 if never opened)
        final targetPage = lastPage > 0 ? lastPage : 1;
        context.push('/viewer/${document.id}?page=$targetPage');
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail with rounded corners
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 0.707, // A4 portrait ratio
                child: Container(
                  color: AppColors.surfaceContainer,
                  child: _buildCoverImage(lastPage),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // File name - single line, truncated
            Text(
              cleanFileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
            ),

            const SizedBox(height: 8),

            // Progress bar
            if (showProgress)
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(1.5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(int pageNumber) {
    // Try to load page-specific thumbnail first
    return FutureBuilder<String?>(
      future: ThumbnailService().retrieveThumbnail(document.id, pageNumber),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final file = File(snapshot.data!);
          return Image.file(
            file,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            opacity: const AlwaysStoppedAnimation(0.95),
          );
        }

        // Fall back to document cover thumbnail
        if (document.coverThumbnailPath != null) {
          final file = File(document.coverThumbnailPath!);
          return FutureBuilder<bool>(
            future: file.exists(),
            builder: (context, coverSnapshot) {
              if (coverSnapshot.data == true) {
                return Image.file(
                  file,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  opacity: const AlwaysStoppedAnimation(0.95),
                );
              }
              return _buildPlaceholder();
            },
          );
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceContainer,
      child: Center(
        child: Icon(
          Icons.picture_as_pdf,
          size: 48,
          color: AppColors.onSecondaryContainer.withOpacity(0.5),
        ),
      ),
    );
  }
}
