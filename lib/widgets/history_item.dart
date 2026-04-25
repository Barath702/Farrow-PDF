import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/reading_history.dart';
import '../models/pdf_document.dart';
import '../theme/app_theme.dart';

class HistoryItem extends StatelessWidget {
  final ReadingHistory history;
  final PdfDocument? document;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkTap;
  final bool isBookmarked;

  const HistoryItem({
    super.key,
    required this.history,
    this.document,
    this.onTap,
    this.onBookmarkTap,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            if (document != null) {
              context.push('/viewer/${document!.id}');
            }
          },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildThumbnail(),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document?.fileName ?? 'Unknown PDF',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurface,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Pg ${history.pageNumber} of ${document?.totalPages ?? '?'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSecondaryContainer,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(history.openedAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.onSecondaryContainer,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bookmark button
            IconButton(
              onPressed: onBookmarkTap,
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked
                    ? AppColors.primaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    // Try to get page thumbnail if available
    if (document?.coverThumbnailPath != null) {
      final file = File(document!.coverThumbnailPath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        opacity: const AlwaysStoppedAnimation(0.8),
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.description,
          size: 20,
          color: AppColors.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return DateFormat('h:mm a').format(date);
    } else if (dateDay == yesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }
}
