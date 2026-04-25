import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.bottomNavShadow,
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(context, Icons.grid_view, 'Home', 0),
                _buildNavItem(context, Icons.history, 'History', 1),
                _buildNavItem(context, Icons.star, 'Bookmarks', 2),
                _buildNavItem(context, Icons.settings, 'Settings', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index) {
    final isSelected = currentIndex == index;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          onIndexChanged(index);
        }
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Icon(
            icon,
            color: isSelected
                ? AppColors.primaryContainer
                : AppColors.onSecondaryContainer.withOpacity(0.6),
            size: 24,
          ),
        ),
      ),
    );
  }
}
