import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/pdf_library_provider.dart';
import '../../providers/reading_progress_provider.dart';
import '../../providers/search_provider.dart';
import '../../services/file_scanner_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pdf_card.dart';
import '../../widgets/pdf_list_item.dart';
import '../../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Run init in microtask to avoid blocking UI
    Future.microtask(() async {
      await _initData();
    });
  }

  Future<void> _initData() async {
    final provider = context.read<PdfLibraryProvider>();
    final progressProvider = context.read<ReadingProgressProvider>();

    // Load unified progress data
    await progressProvider.loadProgress();
    await provider.loadDocuments();

    // Scan for PDFs - runs asynchronously without blocking UI
    await _scanAndImportPdfsIfNeeded();
  }

  Future<void> _scanAndImportPdfsIfNeeded() async {
    debugPrint('HOME: Starting storage scan...');
    
    // Use cached scan results if available (no UI blocking)
    if (FileScannerService.hasCachedResults()) {
      debugPrint('HOME: Using cached scan results');
      final cachedFiles = FileScannerService.getCachedResults();
      if (cachedFiles.isNotEmpty && mounted) {
        debugPrint('HOME: Cached files count: ${cachedFiles.length}');
        final provider = context.read<PdfLibraryProvider>();
        await provider.importScannedPdfs(cachedFiles);
      }
      return;
    }
    
    // Request permission before scanning
    if (!await PermissionService.areStoragePermissionsGranted()) {
      debugPrint('HOME: Requesting storage permission...');
      final granted = await PermissionService.requestStoragePermissions();
      if (!granted) {
        debugPrint('HOME: Permission denied, skipping scan');
        return;
      }
      debugPrint('HOME: Permission granted');
    }
    
    // Scan in background without showing UI
    try {
      debugPrint('HOME: Starting directory scan...');
      final scannedFiles = await FileScannerService.scanForPdfFiles();
      debugPrint('HOME: Scan complete, found ${scannedFiles.length} files');
      
      if (scannedFiles.isNotEmpty && mounted) {
        final provider = context.read<PdfLibraryProvider>();
        final importedCount = await provider.importScannedPdfs(scannedFiles);
        debugPrint('HOME: Imported $importedCount PDFs from scan');
        
        if (importedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found and imported $importedCount new PDF files'),
              backgroundColor: AppColors.primaryContainer,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('HOME: Scan error: $e');
    }
  }

  Future<void> _refreshAndScan() async {
    // Force rescan when user explicitly pulls to refresh
    FileScannerService.clearCache();
    
    final provider = context.read<PdfLibraryProvider>();
    await provider.loadDocuments();
    await _scanAndImportPdfsIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAndScan,
          color: AppColors.primaryContainer,
          backgroundColor: AppColors.surfaceContainerLow,
          child: CustomScrollView(
            slivers: [
              // Content (no app bar - moved to shell level)
              SliverToBoxAdapter(
                child: Consumer<PdfLibraryProvider>(
                  builder: (context, pdfProvider, child) {
                    return Consumer<ReadingProgressProvider>(
                      builder: (context, progressProvider, child) {
                        return Consumer<SearchProvider>(
                          builder: (context, searchProvider, child) {
                            if (pdfProvider.isLoading && pdfProvider.allDocuments.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryContainer,
                                  ),
                                ),
                              );
                            }

                            // Filter documents by search query
                            final documents = searchProvider.hasQuery
                                ? searchProvider.filterDocuments(pdfProvider.allDocuments)
                                : pdfProvider.allDocuments;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),

                                // Continue Reading Section - appears first
                                if (progressProvider.getContinueReading().isNotEmpty && !searchProvider.hasQuery) ...[
                                  _buildContinueReadingSection(context, progressProvider),
                                  const SizedBox(height: 16),
                                ],

                                // All Files Section - Recent PDFs appears below Continue Reading
                                _buildAllFilesSection(context, pdfProvider, documents, searchProvider.query),

                                // Bottom padding for nav bar
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
      ),
      floatingActionButton: _buildFab(),
    );
  }


  Widget _buildContinueReadingSection(
    BuildContext context,
    ReadingProgressProvider provider,
  ) {
    final docsWithProgress = provider.getContinueReading();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Continue Reading',
          subtitle: 'Recent PDFs',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 230, // Increased height to accommodate spacing below thumbnail
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: docsWithProgress.length,
            itemBuilder: (context, index) {
              final progress = docsWithProgress[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: PdfCard(
                  document: progress.document,
                  progressText: progress.progressText,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllFilesSection(
    BuildContext context,
    PdfLibraryProvider provider,
    List<dynamic> documents,
    String searchQuery,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: searchQuery.isNotEmpty ? 'Search Results' : 'All Files',
          action: searchQuery.isEmpty ? _buildSortButton(context, provider) : null,
        ),
        const SizedBox(height: 16),
        if (documents.isEmpty)
          _buildEmptyState(context)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: documents.map((doc) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PdfListItem(
                    document: doc,
                    searchQuery: searchQuery,
                    onMoreTap: () => _showDocumentOptions(context, doc.id),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: AppColors.onSecondaryContainer.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No PDFs yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to import a PDF',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSecondaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(BuildContext context, PdfLibraryProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sort type dropdown
        PopupMenuButton<SortOption>(
          onSelected: (value) => provider.setSortOption(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: SortOption.date,
              child: Text('Sort by Date'),
            ),
            const PopupMenuItem(
              value: SortOption.name,
              child: Text('Sort by Name'),
            ),
            const PopupMenuItem(
              value: SortOption.size,
              child: Text('Sort by Size'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getSortLabel(provider.sortOption),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.sort, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Ascending/Descending toggle
        GestureDetector(
          onTap: () => provider.toggleSortDirection(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              provider.isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.date:
        return 'Date';
      case SortOption.name:
        return 'Name';
      case SortOption.size:
        return 'Size';
    }
  }

  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.redGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.fabShadow,
      ),
      child: FloatingActionButton(
        onPressed: () => _importPdf(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _importPdf(BuildContext context) async {
    debugPrint('HOME: + button pressed - starting import');
    final provider = context.read<PdfLibraryProvider>();
    final docs = await provider.importPdf();
    debugPrint('HOME: Imported ${docs.length} documents');
    
    if (docs.isNotEmpty && context.mounted) {
      // Open the first imported document
      context.push('/viewer/${docs.first.id}');
    }
  }

  void _showDocumentOptions(BuildContext context, String docId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/viewer/$docId');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.primaryContainer),
                  title: const Text('Delete', style: TextStyle(color: AppColors.primaryContainer)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context, docId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: const Text('Delete PDF?'),
        content: const Text('This will remove the PDF from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PdfLibraryProvider>().deleteDocument(docId);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.primaryContainer)),
          ),
        ],
      ),
    );
  }
}
