import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/bookmark.dart';
import '../models/pdf_document.dart';
import '../services/thumbnail_service.dart';
import '../theme/app_theme.dart';

class BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final PdfDocument? document;
  final VoidCallback? onTap;
  final VoidCallback? onRemoveTap;

  const BookmarkCard({
    super.key,
    required this.bookmark,
    this.document,
    this.onTap,
    this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            if (document != null) {
              context.push('/viewer/${document!.id}?page=${bookmark.pageNumber}');
            }
          },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with page number and bookmark button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page ${bookmark.pageNumber}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                      ),
                      if (bookmark.pageTitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          bookmark.pageTitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    onPressed: onRemoveTap,
                    icon: const Icon(
                      Icons.bookmark,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Page preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildPreview(),
              ),
            ),

            const SizedBox(height: 16),

            // PDF name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                document?.fileName ?? 'Unknown PDF',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // Try to load page-specific thumbnail first
    return FutureBuilder<String?>(
      future: ThumbnailService().retrieveThumbnail(document?.id ?? '', bookmark.pageNumber),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final file = File(snapshot.data!);
          return Image.file(
            file,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            opacity: const AlwaysStoppedAnimation(0.95),
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }

        // Fall back to stored bookmark thumbnail
        if (bookmark.thumbnailPath != null) {
          final file = File(bookmark.thumbnailPath!);
          return Image.file(
            file,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            opacity: const AlwaysStoppedAnimation(0.9),
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }

        // Try document cover as last resort
        if (document?.coverThumbnailPath != null) {
          final file = File(document!.coverThumbnailPath!);
          return Image.file(
            file,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            opacity: const AlwaysStoppedAnimation(0.5),
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
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
          Icons.description,
          size: 32,
          color: AppColors.onSecondaryContainer.withOpacity(0.5),
        ),
      ),
    );
  }
}
