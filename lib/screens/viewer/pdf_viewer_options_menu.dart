import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bookmark.dart';
import '../../models/pdf_document.dart';
import '../../providers/bookmark_provider.dart';
import '../../services/file_actions_service.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/app_theme.dart';

class PdfViewerOptionsMenu extends StatelessWidget {
  final PdfDocument document;
  final int currentPage;
  final VoidCallback? onFileDeleted;
  final Function(int pageNumber)? onNavigateToPage;

  const PdfViewerOptionsMenu({
    super.key,
    required this.document,
    required this.currentPage,
    this.onFileDeleted,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Menu title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Options',
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
          ),
          const SizedBox(height: 8),

          // Divider
          Divider(
            color: Colors.white.withOpacity(0.1),
            indent: 24,
            endIndent: 24,
          ),

          // Menu items
          _buildMenuItem(
            context,
            icon: Icons.bookmarks,
            label: 'Bookmarks',
            onTap: () => _handleBookmarks(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.open_in_new,
            label: 'Open With',
            onTap: () => _handleOpenWith(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.share,
            label: 'Share',
            onTap: () => _handleShare(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.copy,
            label: 'Copy To',
            onTap: () => _handleCopyTo(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.drive_file_move,
            label: 'Move To',
            onTap: () => _handleMoveTo(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.delete_outline,
            label: 'Move To Trash',
            iconColor: AppColors.primaryContainer,
            textColor: AppColors.primaryContainer,
            onTap: () => _handleMoveToTrash(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            label: 'File Info',
            onTap: () => _handleFileInfo(context),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.white.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: textColor ?? Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleOpenWith(BuildContext context) {
    Navigator.pop(context);
    final service = FileActionsService();
    service.openWith(context, document.filePath);
  }

  void _handleShare(BuildContext context) {
    Navigator.pop(context);
    final service = FileActionsService();
    service.shareFile(context, document.filePath);
  }

  void _handleCopyTo(BuildContext context) async {
    Navigator.pop(context);
    final service = FileActionsService();
    await service.copyTo(context, document.filePath);
  }

  void _handleMoveTo(BuildContext context) async {
    Navigator.pop(context);
    final service = FileActionsService();
    final success = await service.moveTo(context, document.id, document.filePath);
    if (success && context.mounted) {
      // Refresh the document data
      // This will be handled by the provider
    }
  }

  void _handleMoveToTrash(BuildContext context) async {
    Navigator.pop(context);
    final service = FileActionsService();
    final success = await service.moveToTrash(context, document.id, document.filePath);
    if (success && context.mounted) {
      onFileDeleted?.call();
    }
  }

  void _handleFileInfo(BuildContext context) {
    Navigator.pop(context);
    final service = FileActionsService();
    service.showFileInfo(context, document, currentPage);
  }

  void _handleBookmarks(BuildContext context) {
    Navigator.pop(context);
    showPdfViewerBookmarksSheet(
      context,
      pdfId: document.id,
      pdfDocument: document,
      onBookmarkTap: (pageNumber) {
        // Navigate to the bookmarked page
        onNavigateToPage?.call(pageNumber);
      },
    );
  }
}

/// Show the options menu
void showPdfViewerOptionsMenu(
  BuildContext context, {
  required PdfDocument document,
  required int currentPage,
  VoidCallback? onFileDeleted,
  Function(int pageNumber)? onNavigateToPage,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => PdfViewerOptionsMenu(
      document: document,
      currentPage: currentPage,
      onFileDeleted: onFileDeleted,
      onNavigateToPage: onNavigateToPage,
    ),
  );
}

/// Show the bookmarks bottom sheet for the current PDF
void showPdfViewerBookmarksSheet(
  BuildContext context, {
  required String pdfId,
  required PdfDocument pdfDocument,
  required Function(int pageNumber) onBookmarkTap,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _BookmarksBottomSheet(
      pdfId: pdfId,
      pdfDocument: pdfDocument,
      onBookmarkTap: onBookmarkTap,
    ),
  );
}

class _BookmarksBottomSheet extends StatefulWidget {
  final String pdfId;
  final PdfDocument pdfDocument;
  final Function(int pageNumber) onBookmarkTap;

  const _BookmarksBottomSheet({
    required this.pdfId,
    required this.pdfDocument,
    required this.onBookmarkTap,
  });

  @override
  State<_BookmarksBottomSheet> createState() => _BookmarksBottomSheetState();
}

class _BookmarksBottomSheetState extends State<_BookmarksBottomSheet> {
  List<Bookmark> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarkProvider = context.read<BookmarkProvider>();
    await bookmarkProvider.loadBookmarksForPdf(widget.pdfId);
    if (mounted) {
      setState(() {
        _bookmarks = bookmarkProvider.bookmarks
            .where((b) => b.pdfId == widget.pdfId)
            .toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Bookmarks',
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
          ),
          const SizedBox(height: 8),

          // Divider
          Divider(
            color: Colors.white.withOpacity(0.1),
            indent: 24,
            endIndent: 24,
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          else if (_bookmarks.isEmpty)
            _buildEmptyState()
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: _bookmarks.length,
                itemBuilder: (context, index) {
                  return _buildBookmarkItem(_bookmarks[index]);
                },
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.bookmark_border,
            size: 48,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No bookmarks yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark pages while reading.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkItem(Bookmark bookmark) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        // Navigate to the bookmarked page using the callback
        widget.onBookmarkTap(bookmark.pageNumber);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildThumbnail(bookmark),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page ${bookmark.pageNumber}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (bookmark.pageTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      bookmark.pageTitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Arrow icon
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Bookmark bookmark) {
    return FutureBuilder<String?>(
      future: ThumbnailService().retrieveThumbnail(widget.pdfId, bookmark.pageNumber),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final file = File(snapshot.data!);
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }

        // Fall back to stored bookmark thumbnail
        if (bookmark.thumbnailPath != null) {
          final file = File(bookmark.thumbnailPath!);
          return Image.file(
            file,
            fit: BoxFit.contain,
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
          size: 24,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

}
