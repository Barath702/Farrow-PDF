import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/pdf_document.dart';
import '../providers/search_provider.dart';
import '../services/thumbnail_service.dart';
import '../theme/app_theme.dart';

class PdfListItem extends StatelessWidget {
  final PdfDocument document;
  final String searchQuery;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  const PdfListItem({
    super.key,
    required this.document,
    this.searchQuery = '',
    this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        // Navigate to PDF at last opened page (default to page 1 if never opened)
        final targetPage = document.lastOpenedPage > 0 ? document.lastOpenedPage : 1;
        context.push('/viewer/${document.id}?page=$targetPage');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with proper aspect ratio (A4 ~ 0.707)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                color: AppColors.surfaceContainer,
                child: AspectRatio(
                  aspectRatio: 0.707, // A4 portrait ratio (width/height)
                  child: _buildThumbnail(),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Info section (Google Files style - name and details)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File name - white, 13px equivalent, max 1 line with ellipsis
                  HighlightedText(
                    text: document.fileName,
                    query: searchQuery,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurface,
                          fontSize: 13,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // File size and actual file modification date
                  _buildFileInfo(),
                ],
              ),
            ),

            // More options
            IconButton(
              onPressed: onMoreTap,
              icon: Icon(
                Icons.more_horiz,
                color: AppColors.secondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo() {
    return FutureBuilder<FileStat>(
      future: FileStat.stat(document.filePath),
      builder: (context, snapshot) {
        DateTime fileDate;
        if (snapshot.hasData) {
          fileDate = snapshot.data!.modified;
        } else {
          // Fallback to lastOpenedAt if file stat fails
          fileDate = document.lastOpenedAt ?? DateTime.now();
        }
        return Text(
          '${document.formattedFileSize} · ${_formatDate(fileDate)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSecondaryContainer,
                fontSize: 12,
              ),
        );
      },
    );
  }

  Widget _buildThumbnail() {
    // Try to load page thumbnail first (last opened page)
    final pageNumber = document.lastOpenedPage > 0 ? document.lastOpenedPage : 1;
    return FutureBuilder<String?>(
      future: ThumbnailService().retrieveThumbnail(document.id, pageNumber),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final file = File(snapshot.data!);
          return Image.file(
            file,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
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
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
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
          size: 24,
          color: AppColors.onSecondaryContainer.withOpacity(0.5),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
