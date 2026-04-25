import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home/home_screen.dart';
import 'history/history_screen.dart';
import 'bookmarks/bookmarks_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    BookmarksScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        context.read<SearchProvider>().clearQuery();
      }
    });
  }

  void _onSearchChanged(String value) {
    context.read<SearchProvider>().setQuery(value);
  }

  void _onIndexChanged(int index) {
    if (index != _currentIndex) {
      // Update index immediately for responsive UI
      setState(() {
        _currentIndex = index;
      });

      // Fast animation with minimal duration
      final distance = (_currentIndex - index).abs();
      final duration = Duration(
        milliseconds: 100 + (distance * 20), // 100ms base + 20ms per tab
      );

      // Fast acceleration curve for snappy feel
      _pageController.animateToPage(
        index,
        duration: duration,
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      // Persistent app bar at the top level
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: _showSearch ? _buildSearchAppBar() : _buildNormalAppBar(),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Prevent user swipe, programmatic only
        children: _screens,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onIndexChanged: _onIndexChanged,
      ),
    );
  }

  Widget _buildNormalAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surface.withOpacity(0.8),
      leadingWidth: 120,
      leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FARROW Logo Icon
                    Image.asset(
                      'assets/icon/arrow.png',
                      height: 28,
                    ),
                    const SizedBox(width: 10),
                    // Brand Text
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FARROW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'PDF READER',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              title: const SizedBox.shrink(),
              actions: [
                IconButton(
                  onPressed: _toggleSearch,
                  icon: const Icon(Icons.search),
                ),
              ],
            );
  }

  Widget _buildSearchAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surface.withOpacity(0.8),
      leading: IconButton(
        onPressed: _toggleSearch,
        icon: const Icon(Icons.arrow_back),
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search PDFs...',
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
            icon: const Icon(Icons.clear),
          ),
      ],
    );
  }
}
