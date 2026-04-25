import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/pdf_library_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'pdf_viewer_options_menu.dart';

/// High-speed kinetic scroll physics with amplified velocity
class FastScrollPhysics extends BouncingScrollPhysics {
  const FastScrollPhysics({super.parent, this.velocityMultiplier = 2.5});

  final double velocityMultiplier;

  @override
  FastScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FastScrollPhysics(
      parent: buildParent(ancestor),
      velocityMultiplier: velocityMultiplier,
    );
  }

  @override
  double get minFlingVelocity => 50; // Lower threshold for easier fling

  @override
  double get maxFlingVelocity => 12000; // Allow very fast swipes

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Amplify velocity for faster scrolling
    var boostedVelocity = velocity * velocityMultiplier;

    // Clamp to prevent overshoot bugs
    if (boostedVelocity > 12000) {
      boostedVelocity = 12000;
    } else if (boostedVelocity < -12000) {
      boostedVelocity = -12000;
    }

    return super.createBallisticSimulation(position, boostedVelocity);
  }
}

class PdfViewerScreen extends StatefulWidget {
  final String pdfId;
  final int? startPage;

  const PdfViewerScreen({
    super.key,
    required this.pdfId,
    this.startPage,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with SingleTickerProviderStateMixin {
  late PdfViewerController _pdfController;
  late TransformationController _transformationController;
  double _zoomLevel = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;
  static const double _zoomStep = 0.25;
  bool _isSystemUIVisible = false; // Start hidden for cinematic experience
  Timer? _uiHideTimer;
  late AnimationController _uiAnimationController;

  // Page navigation
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isScrolling = false; // Track if user is scrolling

  // Page jump tracking
  bool _initialPageJumped = false;
  int? _pendingTargetPage;

  // Password handling for encrypted PDFs
  String? _pdfPassword;

  // Page dimensions
  double _pageHeight = 0;
  double _viewportHeight = 0;

  // PDF capture
  final GlobalKey _pdfRepaintKey = GlobalKey();

  // Custom scrollbar state
  bool _isScrollbarVisible = false;
  Timer? _scrollbarHideTimer;
  bool _isDraggingScrollbar = false;
  double _dragStartThumbTop = 0;
  double _trackHeight = 0;
  DateTime? _lastDragUpdate;
  int _lastScrolledPage = 0;
  double _lastDragY = 0;
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool _isVerticalDrag = false;
  final ValueNotifier<double> _arrowPosition = ValueNotifier<double>(0);
  final GlobalKey _scrollbarKey = GlobalKey();
  static const double _scrollbarWidth = 32;
  static const double _scrollbarThumbHeight = 48;
  static const _thumbUpdateThrottle = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _transformationController = TransformationController();
    _zoomLevel = 1.0;
    _uiAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _uiAnimationController.value = 0.0; // Start with UI hidden
    _hideSystemUI(); // Ensure system UI is also hidden

    // Listen to controller changes to update page count
    _pdfController.addListener(_onControllerChanged);

    _loadDocument();

    // Safety fallback to ensure currentPage is never 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentPage <= 0) {
        setState(() {
          _currentPage = 1;
        });
      }
    });
  }

  Future<void> _loadDocument() async {
    final settingsProvider = context.read<SettingsProvider>();
    final readerProvider = context.read<ReaderProvider>();

    // If we have an explicit startPage (from bookmark), don't load saved page
    // to avoid race condition and UI flicker
    final bool useSavedPage = widget.startPage == null && settingsProvider.rememberLastPage;

    await readerProvider.loadDocument(
      widget.pdfId,
      rememberLastPage: useSavedPage,
    );

    // Set initial total pages and current page immediately from document
    if (readerProvider.currentDocument != null) {
      _totalPages = readerProvider.currentDocument!.totalPages > 0
          ? readerProvider.currentDocument!.totalPages
          : 1;
      _currentPage = readerProvider.currentPage > 0
          ? readerProvider.currentPage
          : 1;
      setState(() {});

      // Sync with controller to ensure it starts at the correct page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pdfController.layout != null) {
          _pdfController.goToPage(pageNumber: _currentPage);
        }
      });
    }

    // Log history entry for this PDF
    await context.read<HistoryProvider>().logPdfOpened(
      widget.pdfId,
      readerProvider.currentPage,
      _totalPages,
    );

    // Determine which page to navigate to
    int targetPage;
    if (widget.startPage != null) {
      // Use the explicitly provided startPage (from bookmark navigation)
      targetPage = widget.startPage!;
    } else if (useSavedPage && readerProvider.currentPage > 1) {
      // Use the saved last read page
      targetPage = readerProvider.currentPage;
    } else {
      return; // Stay at page 1 (default)
    }

    // Store the target page for jumping after PDF is fully rendered
    _pendingTargetPage = targetPage;

    // Schedule the page jump after the PDF is fully loaded and rendered
    if (mounted) {
      _schedulePageJump();
    }
  }

  /// Schedule page jump with delay to ensure PDF is fully rendered
  void _schedulePageJump() {
    if (_initialPageJumped || _pendingTargetPage == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialPageJumped) return;

      // Add a small delay to ensure PDF is fully rendered
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _initialPageJumped) return;

        final targetPage = _pendingTargetPage;
        if (targetPage != null) {
          try {
            _pdfController.goToPage(
              pageNumber: targetPage,
            );
          } catch (e) {
            // Silently handle navigation errors
          }

          // Also update the provider to match
          context.read<ReaderProvider>().goToPage(targetPage);

          _initialPageJumped = true;
          _pendingTargetPage = null;
        }
      });
    });
  }

  @override
  void dispose() {
    // Save progress before disposing
    final readerProvider = context.read<ReaderProvider>();
    readerProvider.saveProgressOnExit();

    _pdfController.removeListener(_onControllerChanged);
    _uiHideTimer?.cancel();
    _uiAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _showSystemUI() {
    if (!_isSystemUIVisible) {
      setState(() {
        _isSystemUIVisible = true;
      });
      _uiAnimationController.forward();
      context.read<ReaderProvider>().setUiVisible(true);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _resetHideTimer();
  }

  void _hideSystemUI() {
    if (_isSystemUIVisible) {
      setState(() {
        _isSystemUIVisible = false;
      });
      _uiAnimationController.reverse();
      context.read<ReaderProvider>().setUiVisible(false);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    }
  }

  void _resetHideTimer() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isSystemUIVisible) {
        _hideSystemUI();
      }
    });
  }

  void _cancelHideTimer() {
    _uiHideTimer?.cancel();
  }

  void _toggleUI() {
    if (_isSystemUIVisible) {
      _hideSystemUI();
    } else {
      _showSystemUI();
    }
  }

  /// Handle tap on PDF content area - toggles UI visibility
  void _onContentTap() {
    _toggleUI();
  }

  /// Go to previous page
  void _goToPreviousPage() {
    final provider = context.read<ReaderProvider>();
    if (provider.currentPage > 1) {
      provider.goToPage(provider.currentPage - 1);
    }
  }

  /// Go to next page
  void _goToNextPage() {
    final provider = context.read<ReaderProvider>();
    final totalPages = provider.currentDocument?.totalPages ?? 1;
    if (provider.currentPage < totalPages) {
      provider.goToPage(provider.currentPage + 1);
    }
  }

  void _onControllerChanged() {
    // Update total pages from controller layout when available
    if (_pdfController.layout != null && _pdfController.layout!.pageLayouts.isNotEmpty) {
      final actualPages = _pdfController.layout!.pageLayouts.length;
      if (actualPages > 0 && _totalPages != actualPages) {
        setState(() {
          _totalPages = actualPages;
        });
        // Update in database
        final readerProvider = context.read<ReaderProvider>();
        if (readerProvider.currentDocument != null) {
          context.read<PdfLibraryProvider>().updateTotalPages(
            readerProvider.currentDocument!.id,
            actualPages,
          );
        }
      }
    }

    // Sync current page from controller when available
    // This ensures the page is correct on first open before any scrolling
    // Don't sync if user is actively scrolling to prevent conflicts
    if (!_isScrolling && _pdfController.pageNumber != null && _currentPage != _pdfController.pageNumber) {
      setState(() {
        _currentPage = _pdfController.pageNumber!;
      });
    }
  }

  void _onPageChanged(int? page) {
    if (page != null) {
      // Mark as scrolling to prevent controller sync from overwriting
      _isScrolling = true;
      // Reset scrolling flag after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _isScrolling = false;
        }
      });

      // Show scrollbar when page changes
      _showScrollbar();

      // Update current page in UI state immediately
      if (_currentPage != page) {
        setState(() {
          _currentPage = page;
        });
      }

      // Update page using half-threshold logic for provider sync
      _updatePageAtHalfThreshold(page);

      // If we haven't jumped to the initial page yet and user is on page 1,
      // the initial jump might have been missed - try again
      if (!_initialPageJumped &&
          _pendingTargetPage != null &&
          _pendingTargetPage != page &&
          _pendingTargetPage != 1 &&
          page == 1 &&
          _pendingTargetPage != 1) {
        _schedulePageJump();
      }
    }
  }

  /// Current displayed page based on half-threshold logic
  int _displayedPage = 1;

  /// Calculate page based on scroll offset with 0.5 threshold
  /// Page changes when top edge crosses the midpoint of viewport
  void _updatePageAtHalfThreshold(int? reportedPage) {
    if (reportedPage == null) return;

    final provider = context.read<ReaderProvider>();
    final totalPages = provider.currentDocument?.totalPages ?? 1;

    // Ensure the page is within bounds
    var targetPage = reportedPage.clamp(1, totalPages);

    // Update displayed page if it differs from current
    if (_displayedPage != targetPage) {
      _displayedPage = targetPage;

      // Sync with provider for state consistency
      // Use microtask to avoid setState during build
      Future.microtask(() {
        if (mounted && provider.currentPage != targetPage) {
          provider.goToPage(targetPage);
        }
      });
    }
  }

  /// Calculate which page should be displayed based on half-threshold rule
  /// Uses page height and viewport to determine when page top crosses midpoint
  void _calculatePageAtHalfThreshold(double scrollOffsetY) {
    final provider = context.read<ReaderProvider>();
    final document = provider.currentDocument;
    if (document == null) return;

    final totalPages = document.totalPages;

    // Estimate page height based on viewport and margins
    // Each page has: margin (16) + page + margin (16) + spacing between pages
    final pdfParams = _pdfController.params;
    final margin = pdfParams?.margin ?? 16;
    final pageSpacing = 16.0; // Estimated spacing between pages

    // Page height including margins and spacing
    final fullPageHeight = _pageHeight + (margin * 2) + pageSpacing;

    if (fullPageHeight <= 0) return;

    // Viewport midpoint relative to scroll position
    final midpoint = scrollOffsetY + (_viewportHeight / 2);

    // Find which page's top edge is closest to and above the midpoint
    int targetPage = 1;
    for (int page = 1; page <= totalPages; page++) {
      // Page top position = (page - 1) * fullPageHeight + margin
      final pageTop = (page - 1) * fullPageHeight + margin;

      // If this page's top edge is at or above the midpoint, it's the current page
      if (pageTop <= midpoint) {
        targetPage = page;
      } else {
        // Page top is below midpoint, previous page is current
        break;
      }
    }

    // Update if changed
    if (_displayedPage != targetPage) {
      _displayedPage = targetPage;
      if (provider.currentPage != targetPage) {
        provider.goToPage(targetPage);
      }
    }
  }

  // Custom scrollbar methods
  void _showScrollbar() {
    if (!_isScrollbarVisible) {
      setState(() {
        _isScrollbarVisible = true;
      });
    }
    _resetScrollbarHideTimer();
  }

  void _hideScrollbar() {
    if (_isScrollbarVisible && !_isDraggingScrollbar) {
      setState(() {
        _isScrollbarVisible = false;
      });
    }
  }

  void _resetScrollbarHideTimer() {
    _scrollbarHideTimer?.cancel();
    _scrollbarHideTimer = Timer(const Duration(seconds: 2), () {
      _hideScrollbar();
    });
  }

  void _cancelScrollbarHideTimer() {
    _scrollbarHideTimer?.cancel();
  }

  void _onScrollbarDragStart(DragStartDetails details, double thumbTop, double trackHeight) {
    _trackHeight = trackHeight;
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _isVerticalDrag = false;
    _dragStartThumbTop = thumbTop;
    setState(() {
      _isDraggingScrollbar = true;
    });
    _cancelScrollbarHideTimer();
    _showScrollbar();
  }

  void _onScrollbarDragUpdate(DragUpdateDetails details, ReaderProvider provider) {
    if (_trackHeight <= 0 || _totalPages <= 1) return;

    final dx = (details.globalPosition.dx - _dragStartX).abs();
    final dy = (details.globalPosition.dy - _dragStartY).abs();

    // Detect gesture direction on first movement
    if (!_isVerticalDrag && dx > dy) {
      return;
    }
    _isVerticalDrag = true;

    // Ignore micro-movements (< 2px)
    if (dy.abs() < 2.0) return;

    // Convert global touch to local scrollbar coordinates
    final scrollbarRenderBox = _scrollbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollbarRenderBox == null) return;

    final local = scrollbarRenderBox.globalToLocal(details.globalPosition);
    final boundedHeight = scrollbarRenderBox.size.height;

    // Map finger position to arrow position (centered under finger)
    final arrowHeight = _scrollbarThumbHeight;
    final maxThumbTop = boundedHeight - arrowHeight;
    double newY = (local.dy - arrowHeight / 2).clamp(0.0, maxThumbTop);

    // Update arrow position immediately (every frame)
    _arrowPosition.value = newY;

    // Normalize to [0,1] for page mapping using bounded height
    final t = (newY / maxThumbTop).clamp(0.0, 1.0);

    // Map to page index (monotonic: down = higher page)
    final targetPage = (t * (_totalPages - 1)).round() + 1;
    final clampedPage = targetPage.clamp(1, _totalPages);

    // Throttle page navigation to ~60fps
    final now = DateTime.now();
    if (_lastDragUpdate != null && now.difference(_lastDragUpdate!) < _thumbUpdateThrottle) {
      return;
    }
    _lastDragUpdate = now;

    // Only navigate if page changed
    if (clampedPage != _lastScrolledPage) {
      _lastScrolledPage = clampedPage;
      _pdfController.goToPage(pageNumber: clampedPage);
      provider.jumpToPage(clampedPage);
    }
  }

  void _onScrollbarDragEnd(ReaderProvider provider) {
    setState(() {
      _isDraggingScrollbar = false;
    });
    _isVerticalDrag = false;
    _lastScrolledPage = 0;
    _resetScrollbarHideTimer();
  }

  double _calculateThumbTop(int currentPage, int totalPages, double boundedHeight) {
    if (boundedHeight <= 0 || totalPages <= 1) return 0;
    final maxThumbTop = boundedHeight - _scrollbarThumbHeight;
    final ratio = (currentPage - 1) / (totalPages - 1);
    return ratio * maxThumbTop;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _showScrollbar();
    } else if (notification is ScrollUpdateNotification) {
      _showScrollbar();
    } else if (notification is ScrollEndNotification) {
      _resetScrollbarHideTimer();
    }
    return false;
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + _zoomStep).clamp(_minZoom, _maxZoom);
    });
    _applyZoom();
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - _zoomStep).clamp(_minZoom, _maxZoom);
    });
    _applyZoom();
  }

  void _applyZoom() {
    final matrix = Matrix4.identity()..scale(_zoomLevel);
    _transformationController.value = matrix;
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    // Sync zoom level from gesture with our state
    final scale = _transformationController.value.getMaxScaleOnAxis();
    setState(() {
      _zoomLevel = scale.clamp(_minZoom, _maxZoom);
    });
  }

  /// Show password dialog for encrypted PDFs
  Future<String?> _showPasswordDialog() async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: const Text('Password Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This PDF is password-protected. Enter the password to open it.'),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Enter password...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: const Text('Add Note'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter your note...',
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                context.read<ReaderProvider>().addNote(textController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Consumer<ReaderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryContainer,
              ),
            );
          }

          if (provider.error != null || provider.currentDocument == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.primaryContainer,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error ?? 'Failed to load PDF',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // PDF Viewer - fills entire screen edge-to-edge
              // Wrapped with RepaintBoundary for capture functionality
              // Also wrapped with ColorFiltered for Night Mode
              // Uses combined global + per-PDF night mode logic
              Consumer2<SettingsProvider, ReaderProvider>(
                builder: (context, settingsProvider, readerProvider, child) {
                  final isNightMode = readerProvider.isNightModeEnabled(settingsProvider.nightMode);
                  return RepaintBoundary(
                    key: _pdfRepaintKey,
                    child: SizedBox.expand(
                      child: ColorFiltered(
                        colorFilter: isNightMode
                            ? const ColorFilter.matrix([
                                -1.2, 0, 0, 0, 255,
                                0, -1.2, 0, 0, 255,
                                0, 0, -1.2, 0, 255,
                                0, 0, 0, 1, 0,
                              ])
                            : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              ),
                        child: IgnorePointer(
                          ignoring: _isDraggingScrollbar,
                          child: GestureDetector(
                            onLongPress: () {}, // Consume long press to prevent text selection
                            child: PdfViewer.file(
                              provider.currentDocument!.filePath,
                              controller: _pdfController,
                              passwordProvider: _pdfPassword != null
                                  ? createSimplePasswordProvider(_pdfPassword)
                                  : null,
                              firstAttemptByEmptyPassword: true,
                              initialPageNumber: provider.currentPage > 0 ? provider.currentPage : 1,
                              params: PdfViewerParams(
                                margin: 16,
                                pageDropShadow: BoxShadow(
                                  color: AppColors.onSurface.withOpacity(0.04),
                                  blurRadius: 64,
                                  offset: const Offset(0, 32),
                                ),
                                backgroundColor: AppColors.surfaceContainerLowest,
                                // High-speed kinetic scrolling with velocity amplification
                                scrollPhysics: const FastScrollPhysics(
                                  velocityMultiplier: 2.5,
                                ),
                                // Allow free panning without page snapping
                                panEnabled: true,
                                // Enable scaling for zoom
                                scaleEnabled: true,
                                onPageChanged: _onPageChanged,
                                onViewSizeChanged: (size, pageSize, controller) {
                                  if (pageSize != null) {
                                    _pageHeight = pageSize.height;
                                  }
                                  if (size != null) {
                                    _viewportHeight = size.height;
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Tap detector for toggling top/bottom bars
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onContentTap,
                ),
              ),

              // Top Bar - slides down when visible, up when hidden
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _uiAnimationController,
                  builder: (context, child) {
                    return AnimatedSlide(
                      offset: Offset(0, _isSystemUIVisible ? 0 : -1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: AnimatedOpacity(
                        opacity: _isSystemUIVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: _buildTopBar(context, provider),
                      ),
                    );
                  },
                ),
              ),

              // Custom Scrollbar - positioned on right edge
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                bottom: 100,
                right: 0,
                child: _buildCustomScrollbar(context, provider),
              ),

              // Bottom Navigation Bar - centered, compact, floating with animation
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _uiAnimationController,
                  builder: (context, child) {
                    return AnimatedSlide(
                      offset: Offset(0, _isSystemUIVisible ? 0 : 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: AnimatedOpacity(
                        opacity: _isSystemUIVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: _buildBottomNavBar(provider),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomScrollbar(BuildContext context, ReaderProvider provider) {
    // HIDE if less than 20 pages
    if (_totalPages < 20) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = kToolbarHeight + MediaQuery.of(context).padding.top;
    final bottomPadding = 80.0;
    final boundedHeight = screenHeight - topPadding - bottomPadding;
    _trackHeight = boundedHeight;

    final thumbTop = _calculateThumbTop(_currentPage, _totalPages, boundedHeight);
    if (!_isDraggingScrollbar) {
      _arrowPosition.value = thumbTop;
    }

    // Narrow touch zone container (bounded area)
    return Container(
      key: _scrollbarKey,
      width: _scrollbarWidth,
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Arrow with gesture detection ONLY on the arrow itself
          ValueListenableBuilder<double>(
            valueListenable: _arrowPosition,
            builder: (context, position, child) {
              return Positioned(
                top: _isDraggingScrollbar ? position : thumbTop,
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (details) {
                    _onScrollbarDragStart(details, thumbTop, boundedHeight);
                  },
                  onVerticalDragUpdate: (details) {
                    _onScrollbarDragUpdate(details, provider);
                  },
                  onVerticalDragEnd: (details) {
                    _onScrollbarDragEnd(provider);
                  },
                  child: AnimatedOpacity(
                    opacity: _isScrollbarVisible || _isDraggingScrollbar ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: Image.asset(
                      'assets/icon/arrow.png',
                      width: 32,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          // Page number overlay (shown while dragging)
          if (_isDraggingScrollbar)
            Positioned(
              top: _arrowPosition.value + (_scrollbarThumbHeight / 2) - 12,
              right: _scrollbarWidth + 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// New bottom navigation bar - centered pill, no zoom controls
  Widget _buildBottomNavBar(ReaderProvider provider) {
    final safePage = _currentPage <= 0 ? 1 : _currentPage;
    final safeTotal = _totalPages <= 0 ? 1 : _totalPages;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.85),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: _currentPage > 1
                    ? () {
                        provider.previousPage();
                        _pdfController.goToPage(pageNumber: provider.currentPage);
                      }
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                '${safePage.clamp(1, safeTotal)} / $safeTotal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: _currentPage < _totalPages
                    ? () {
                        provider.nextPage();
                        _pdfController.goToPage(pageNumber: provider.currentPage);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// New top bar - pill-shaped floating header
  Widget _buildTopBar(BuildContext context, ReaderProvider provider) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF131313).withOpacity(0.9),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Back button
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),

            const SizedBox(width: 8),

            // Filename (truncated)
            Expanded(
              child: Text(
                provider.currentDocument?.fileName ?? 'PDF Viewer',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 8),

            // Night mode button
            Consumer2<SettingsProvider, ReaderProvider>(
              builder: (context, settingsProvider, readerProvider, child) {
                final isNightMode = readerProvider.isNightModeEnabled(settingsProvider.nightMode);
                return IconButton(
                  onPressed: () {
                    readerProvider.togglePdfNightMode();
                  },
                  icon: Icon(
                    isNightMode ? Icons.dark_mode : Icons.light_mode,
                    color: isNightMode
                        ? AppColors.primaryContainer
                        : Colors.white.withOpacity(0.9),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                );
              },
            ),

            // Bookmark button
            IconButton(
              onPressed: () async {
                await provider.toggleBookmark();
              },
              icon: Icon(
                provider.isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: provider.isBookmarked
                    ? AppColors.primaryContainer
                    : Colors.white.withOpacity(0.9),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),

            // More options button
            IconButton(
              onPressed: () {
                if (provider.currentDocument != null) {
                  showPdfViewerOptionsMenu(
                    context,
                    document: provider.currentDocument!,
                    currentPage: provider.currentPage,
                    onFileDeleted: () {
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                    onNavigateToPage: (pageNumber) {
                      _pdfController.goToPage(pageNumber: pageNumber);
                      provider.goToPage(pageNumber);
                    },
                  );
                }
              },
              icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.9)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
      ),
    );
  }
}
