import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/bookmark.dart';
import '../../models/pdf_document.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/search_provider.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/app_theme.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<BookmarkProvider>();
    await provider.loadAllBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Content (no app bar - at shell level)
            SliverToBoxAdapter(
              child: Consumer<BookmarkProvider>(
                builder: (context, provider, child) {
                  final searchProvider = context.watch<SearchProvider>();

                  if (provider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    );
                  }

                  return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'BOOKMARKS',
                                        style: headerStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        searchProvider.hasQuery ? 'SEARCH RESULTS' : 'CURATED COLLECTION',
                                        style: subtitleStyle,
                                      ),
                                    ],
                                  ),
                                ),
                                if (provider.bookmarks.isNotEmpty && !searchProvider.hasQuery)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${provider.bookmarks.length}',
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryContainer,
                                            ),
                                      ),
                                      Text(
                                        'Saved Pages'.toUpperCase(),
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      // Grouped Bookmarks List
                      if (provider.bookmarks.isEmpty)
                        _buildEmptyState(context)
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildGroupedBookmarks(context, provider, searchProvider),
                        ),

                      const SizedBox(height: 100),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedBookmarks(
    BuildContext context,
    BookmarkProvider provider,
    SearchProvider searchProvider,
  ) {
    // Group bookmarks by PDF
    final Map<String, List<Bookmark>> groupedBookmarks = {};
    final Map<String, PdfDocument?> pdfDocuments = {};

    for (final bookmark in provider.bookmarks) {
      if (!groupedBookmarks.containsKey(bookmark.pdfId)) {
        groupedBookmarks[bookmark.pdfId] = [];
        pdfDocuments[bookmark.pdfId] = provider.pdfDocuments[bookmark.pdfId];
      }
      groupedBookmarks[bookmark.pdfId]!.add(bookmark);
    }

    // Filter by search query if active
    if (searchProvider.hasQuery) {
      groupedBookmarks.removeWhere((pdfId, bookmarks) {
        final doc = pdfDocuments[pdfId];
        final fileName = doc?.fileName ?? 'Unknown PDF';
        return !searchProvider.fuzzyMatch(fileName, searchProvider.query);
      });
    }

    // Sort bookmarks within each group by page number
    for (final entries in groupedBookmarks.values) {
      entries.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    }

    return Column(
      children: groupedBookmarks.entries.map((entry) {
        final pdfId = entry.key;
        final bookmarks = entry.value;
        final doc = pdfDocuments[pdfId];
        final cleanFileName = (doc?.fileName ?? 'Unknown PDF')
            .replaceAll('.pdf', '')
            .replaceAll('.PDF', '');

        return _buildPdfBookmarkCard(
          context,
          pdfId: pdfId,
          fileName: cleanFileName,
          bookmarks: bookmarks,
          doc: doc,
          searchQuery: searchProvider.query,
        );
      }).toList(),
    );
  }

  Widget _buildPdfBookmarkCard(
    BuildContext context, {
    required String pdfId,
    required String fileName,
    required List<Bookmark> bookmarks,
    required PdfDocument? doc,
    required String searchQuery,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PDF NAME (TOP)
          HighlightedText(
            text: fileName,
            query: searchQuery,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          // THUMBNAIL (CENTERED)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnail(doc, bookmarks.first.pageNumber),
            ),
          ),

          const SizedBox(height: 16),

          const Divider(color: Colors.white12),

          const SizedBox(height: 8),

          // BOOKMARK LIST
          Column(
            children: bookmarks.map((bookmark) {
              return _buildBookmarkRow(context, bookmark, doc);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(PdfDocument? doc, int pageNumber) {
    if (doc == null) {
      return _buildPlaceholderThumbnail();
    }

    return FutureBuilder<Uint8List?>(
      future: ThumbnailService().getThumbnailBytes(doc.filePath, doc.id, pageNumber: pageNumber),
      builder: (context, snapshot) {
        // Check if we have valid thumbnail bytes
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: 120,
            height: 160,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderThumbnail();
            },
          );
        }

        // Show loading indicator while waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingThumbnail();
        }

        // Show placeholder for errors or no data
        return _buildPlaceholderThumbnail();
      },
    );
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      width: 120,
      height: 160,
      color: AppColors.surfaceContainer,
      child: const Center(
        child: Icon(
          Icons.picture_as_pdf,
          size: 40,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildLoadingThumbnail() {
    return Container(
      width: 120,
      height: 160,
      color: AppColors.surfaceContainer,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white38,
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkRow(BuildContext context, Bookmark bookmark, PdfDocument? doc) {
    return InkWell(
      onTap: () {
        // Navigate to PDF at bookmarked page
        context.push('/viewer/${bookmark.pdfId}?page=${bookmark.pageNumber}');
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${bookmark.pageNumber}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Delete icon - wrapped to prevent tap propagation
                GestureDetector(
                  onTap: () {
                    _confirmDelete(context, bookmark.id);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Bookmark icon - static indicator
                const Icon(
                  Icons.bookmark,
                  color: AppColors.primaryContainer,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppColors.onSecondaryContainer.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No bookmarks yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmark pages while reading to save them here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSecondaryContainer,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String bookmarkId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: const Text('Remove Bookmark?'),
        content: const Text('This bookmark will be removed from your collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<BookmarkProvider>().removeBookmark(bookmarkId);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.primaryContainer)),
          ),
        ],
      ),
    );
  }
}
