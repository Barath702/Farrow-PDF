import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<SettingsProvider>();
    await provider.loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: CustomScrollView(
          slivers: [
            // Content (no app bar - at shell level)
            SliverToBoxAdapter(
              child: Consumer<SettingsProvider>(
                builder: (context, provider, child) {
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

                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Text(
                          'SETTINGS',
                          style: headerStyle,
                        ),

                        const SizedBox(height: 6),

                        // Preferences Section
                        _buildSectionHeader(context, 'Preferences'),
                        const SizedBox(height: 16),
                        _buildPreferencesCard(context, provider),

                        const SizedBox(height: 32),

                        // About Section
                        _buildSectionHeader(context, 'About'),
                        const SizedBox(height: 16),
                        _buildAboutCard(context),

                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: subtitleStyle,
    );
  }

  Widget _buildPreferencesCard(BuildContext context, SettingsProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildToggleItem(
            context,
            icon: Icons.dark_mode,
            title: 'Night Mode',
            subtitle: 'Force dark theme globally',
            value: provider.nightMode,
            onChanged: (value) => provider.setNightMode(value),
          ),
          Divider(
            color: AppColors.surface.withOpacity(0.5),
            height: 1,
            indent: 72,
          ),
          _buildToggleItem(
            context,
            icon: Icons.swipe_up,
            title: 'Smooth Scrolling',
            subtitle: 'Enable kinetic scrolling animation',
            value: provider.smoothScrolling,
            onChanged: (value) => provider.setSmoothScrolling(value),
          ),
          Divider(
            color: AppColors.surface.withOpacity(0.5),
            height: 1,
            indent: 72,
          ),
          _buildToggleItem(
            context,
            icon: Icons.bookmark_added,
            title: 'Remember Last Page',
            subtitle: 'Resume reading where you left off',
            value: provider.rememberLastPage,
            onChanged: (value) => provider.setRememberLastPage(value),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: AppColors.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSecondaryContainer,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryContainer,
            activeTrackColor: AppColors.primaryContainer.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(
              Icons.book,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farrow',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0'.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSecondaryContainer,
                        letterSpacing: 1,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
