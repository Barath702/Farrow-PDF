import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../providers/reader_provider.dart';
import '../../theme/app_theme.dart';

class PdfViewerMenuSheet extends StatelessWidget {
  final String pdfId;
  final VoidCallback? onAddNote;

  const PdfViewerMenuSheet({
    super.key,
    required this.pdfId,
    this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppTheme.bottomNavShadow,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Menu Items
              _buildMenuItem(
                context,
                icon: Icons.bookmark,
                title: 'Bookmark Page',
                subtitle: 'Save this page for quick access',
                onTap: () async {
                  final provider = context.read<ReaderProvider>();
                  await provider.toggleBookmark();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.isBookmarked
                              ? 'Page bookmarked'
                              : 'Bookmark removed',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  }
                },
              ),
                            _buildMenuItem(
                context,
                icon: Icons.photo_camera,
                title: 'Capture Page',
                subtitle: 'Save or share this page',
                onTap: () => _captureAndShare(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.onSurface,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndShare(BuildContext context) async {
    final provider = context.read<ReaderProvider>();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryContainer,
        ),
      ),
    );

    try {
      final bytes = await provider.captureCurrentPage();

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close menu sheet
      }

      if (bytes != null && context.mounted) {
        // Save to temporary file for preview
        final tempDir = await getTemporaryDirectory();
        final fileName = 'PDF_Page_${provider.currentPage}_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = await File('${tempDir.path}/$fileName').create();
        await file.writeAsBytes(bytes);

        // Show preview dialog with Save and Share options
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            title: Text('Page ${provider.currentPage}'),
            content: SizedBox(
              width: double.maxFinite,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await Gal.putImage(file.path);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Saved to gallery',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.black87,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save: $e'),
                          backgroundColor: AppColors.errorContainer,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save_alt),
                label: const Text('Save to Gallery'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    subject: 'PDF Page ${provider.currentPage}',
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture page: $e'),
            backgroundColor: AppColors.errorContainer,
          ),
        );
      }
    }
  }
}
