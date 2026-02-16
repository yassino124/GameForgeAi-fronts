import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideY;

  const AnimatedCard({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.slideY = 14,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (!mounted) return;
        _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        return Transform.translate(
          offset: Offset(0, (1 - t) * widget.slideY),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: widget.child,
    );
  }
}

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 180;
        final defaultCoverH = compact ? 96.0 : 118.0;

        final hasBoundedHeight = constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final maxH = hasBoundedHeight ? constraints.maxHeight : double.infinity;
        // In tight grid tiles, the available height can be smaller than our default cover.
        // Ensure the cover never exceeds the card height, otherwise the Column overflows.
        final coverH = hasBoundedHeight
            ? math.min(defaultCoverH, math.max(44.0, maxH * 0.52))
            : defaultCoverH;

        return CustomCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                SizedBox(
                  height: coverH,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppBorderRadius.large),
                          ),
                          child: (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
                              ? Image.network(
                                  thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.games, color: Colors.white70, size: 34),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.games, color: Colors.white70, size: 34),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: _buildStatusChip(),
                      ),
                      if (onMoreOptions != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            onPressed: onMoreOptions,
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      compact ? 4 : AppSpacing.md,
                      AppSpacing.md,
                      compact ? 4 : AppSpacing.sm,
                    ),
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        // iOS grid tiles can end up around ~90px height; keep a safety margin
                        // so we don't overflow by a few pixels.
                        final tight = compact && inner.maxHeight < 112;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.subtitle2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!tight && description != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                description!,
                                style: AppTypography.caption,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (!tight) const Spacer(),
                            if (!tight)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _formatDate(lastModified),
                                  style: AppTypography.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            if (!tight && progress != null && progress! < 1.0) ...[
                              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${(progress! * 100).toInt()}% Complete',
                                style: AppTypography.caption,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
