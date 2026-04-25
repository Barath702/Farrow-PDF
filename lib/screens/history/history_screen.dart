import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/reading_progress_provider.dart';
import '../../providers/search_provider.dart';
import '../../services/thumbnail_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/history_item.dart';
import '../../widgets/pdf_card.dart';
import '../../widgets/section_header.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final historyProvider = context.read<HistoryProvider>();
    final bookmarkProvider = context.read<BookmarkProvider>();
    final progressProvider = context.read<ReadingProgressProvider>();

    // Load unified progress data
    await progressProvider.loadProgress();
    await historyProvider.loadHistory();
    await bookmarkProvider.loadAllBookmarks();
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
              child: Consumer<HistoryProvider>(
                builder: (context, historyProvider, child) {
                  return Consumer<ReadingProgressProvider>(
                    builder: (context, progressProvider, child) {
                      return Consumer<SearchProvider>(
                        builder: (context, searchProvider, child) {
                          if (historyProvider.isLoading || progressProvider.isLoading) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryContainer,
                                ),
                              ),
                            );
                          }

                          // Get unified progress data
                          var todayDocs = progressProvider.getTodayDocuments();
                          var yesterdayDocs = progressProvider.getYesterdayDocuments();
                          var last7DaysDocs = progressProvider.getLast7DaysDocuments();

                          // Filter by search query if active
                          if (searchProvider.hasQuery) {
                            todayDocs = _filterProgressList(todayDocs, searchProvider);
                            yesterdayDocs = _filterProgressList(yesterdayDocs, searchProvider);
                            last7DaysDocs = _filterProgressList(last7DaysDocs, searchProvider);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HISTORY',
                                      style: headerStyle,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      searchProvider.hasQuery ? 'SEARCH RESULTS' : 'YOUR RECENT READING ACTIVITY',
                                      style: subtitleStyle,
                                    ),
                                  ],
                                ),
                              ),

                              // Timeline Sections using unified progress data
                              if (todayDocs.isNotEmpty) ...[
                                _buildTimelineSection(
                                  context,
                                  'Today',
                                  todayDocs,
                                  searchProvider.query,
                                ),
                              ],

                              if (yesterdayDocs.isNotEmpty) ...[
                                _buildTimelineSection(
                                  context,
                                  'Yesterday',
                                  yesterdayDocs,
                                  searchProvider.query,
                                ),
                              ],

                              if (last7DaysDocs.isNotEmpty) ...[
                                _buildTimelineSection(
                                  context,
                                  'Last 7 Days',
                                  last7DaysDocs,
                                  searchProvider.query,
                                ),
                              ],

                              if (todayDocs.isEmpty &&
                                  yesterdayDocs.isEmpty &&
                                  last7DaysDocs.isEmpty) ...[
                                _buildEmptyState(context),
                              ],

                              const SizedBox(height: 100),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PdfProgressData> _filterProgressList(
    List<PdfProgressData> progressList,
    SearchProvider searchProvider,
  ) {
    return progressList.where((progress) {
      return searchProvider.fuzzyMatch(progress.document.fileName, searchProvider.query);
    }).toList();
  }

  Widget _buildTimelineSection(
    BuildContext context,
    String title,
    List<PdfProgressData> progressList,
    String searchQuery,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSecondaryContainer,
                  letterSpacing: 2,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: progressList.map((progress) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildHistoryProgressItem(context, progress, searchQuery),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHistoryProgressItem(
    BuildContext context,
    PdfProgressData progress,
    String searchQuery,
  ) {
    return GestureDetector(
      onTap: () {
        context.push('/viewer/${progress.document.id}?page=${progress.currentPage}');
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // THUMBNAIL (left side)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildThumbnail(progress.document, progress.currentPage),
            ),

            const SizedBox(width: 12),

            // MIDDLE: PDF Name + time (flexible)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HighlightedText(
                    text: progress.fileName,
                    query: searchQuery,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(progress.lastOpened),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSecondaryContainer,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // RIGHT SIDE: Progress badge (fixed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                progress.progressText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
              ),
            ),

            const Padding(padding: EdgeInsets.only(right: 4)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildThumbnail(dynamic document, int pageNumber) {
    return FutureBuilder<Uint8List?>(
      future: ThumbnailService().getThumbnailBytes(document.filePath, document.id, pageNumber: pageNumber),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderThumbnail();
            },
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 48,
            height: 48,
            color: AppColors.surfaceContainer,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              ),
            ),
          );
        }

        return _buildPlaceholderThumbnail();
      },
    );
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.surfaceContainer,
      child: const Icon(
        Icons.picture_as_pdf,
        size: 24,
        color: Colors.white54,
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
              Icons.history,
              size: 64,
              color: AppColors.onSecondaryContainer.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start reading some PDFs to see your history',
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
}
