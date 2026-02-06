import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final card = Container(
      margin: margin ?? AppSpacing.marginVerticalSmall,
      padding: padding ?? AppSpacing.paddingAll,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surface,
        borderRadius: borderRadius ?? AppBorderRadius.allLarge,
        border: border,
        boxShadow: elevation != null 
            ? [BoxShadow(
                color: Colors.black.withOpacity(0.16),
                offset: const Offset(0, 4),
                blurRadius: elevation!,
              )]
            : AppShadows.boxShadowMedium,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? AppBorderRadius.allLarge,
        child: card,
      );
    }

    return card;
  }
}

class ProjectCard extends StatelessWidget {
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String status;
  final DateTime lastModified;
  final double? progress;
  final VoidCallback onTap;
  final VoidCallback? onMoreOptions;

  const ProjectCard({
    super.key,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.status,
    required this.lastModified,
    this.progress,
    required this.onTap,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      padding: AppSpacing.paddingAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: AppBorderRadius.allMedium,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: AppBorderRadius.allMedium,
                        child: Image.network(
                          thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.games, color: AppColors.primary),
                        ),
                      )
                    : const Icon(Icons.games, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.lg),
              
              // Project Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.subtitle2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description!,
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _buildStatusChip(),
                        const Spacer(),
                        Text(
                          _formatDate(lastModified),
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // More Options
              if (onMoreOptions != null)
                IconButton(
                  onPressed: onMoreOptions,
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                ),
            ],
          ),
          
          // Progress Bar
          if (progress != null && progress! < 1.0) ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${(progress! * 100).toInt()}% Complete',
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    String chipText;

    switch (status.toLowerCase()) {
      case 'completed':
        chipColor = AppColors.success;
        chipText = 'Completed';
        break;
      case 'in_progress':
        chipColor = AppColors.warning;
        chipText = 'In Progress';
        break;
      case 'failed':
        chipColor = AppColors.error;
        chipText = 'Failed';
        break;
      default:
        chipColor = AppColors.textSecondary;
        chipText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: AppBorderRadius.allSmall,
      ),
      child: Text(
        chipText,
        style: AppTypography.caption.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 24,
              ),
              const Spacer(),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              color: iconColor ?? AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
