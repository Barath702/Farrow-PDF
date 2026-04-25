import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final bool showPercentage;
  final Color? backgroundColor;
  final Gradient? progressGradient;

  const ProgressBar({
    super.key,
    required this.progress,
    this.height = 4,
    this.showPercentage = false,
    this.backgroundColor,
    this.progressGradient,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (clampedProgress * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: progressGradient ?? AppTheme.progressGradient,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              Expanded(
                flex: ((1 - clampedProgress) * 100).round(),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(clampedProgress * 100).round()}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
            textAlign: TextAlign.right,
          ),
        ],
      ],
    );
  }
}
