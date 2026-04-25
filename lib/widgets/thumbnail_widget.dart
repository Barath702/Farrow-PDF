import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThumbnailWidget extends StatelessWidget {
  final String? thumbnailPath;
  final double width;
  final double height;
  final double opacity;
  final BorderRadius? borderRadius;

  const ThumbnailWidget({
    super.key,
    this.thumbnailPath,
    this.width = 48,
    this.height = 64,
    this.opacity = 0.8,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnailPath != null) {
      final file = File(thumbnailPath!);
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return ClipRRect(
              borderRadius: borderRadius ?? BorderRadius.circular(6),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Image.file(
                  file,
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  opacity: AlwaysStoppedAnimation(opacity),
                  errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                ),
              ),
            );
          }
          return _buildPlaceholder(context);
        },
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(
          Icons.description,
          size: width * 0.4,
          color: AppColors.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }
}
