import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      margin: margin ?? AppSpacing.marginVerticalSmall,
      padding: padding ?? AppSpacing.paddingAll,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? const Color(0xFF0D0E14).withOpacity(0.8) : cs.surface),
        borderRadius: borderRadius ?? BorderRadius.circular(28),
        border: border ?? (isDark ? Border.all(color: Colors.white.withOpacity(0.08)) : null),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(28),
        child: child,
      ),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = ApiService.normalizeImageUrl(thumbnailUrl);
    return AnimatedCard(
      duration: const Duration(milliseconds: 600),
      slideY: 20,
      child: LayoutBuilder(
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
          padding: EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(32),
          backgroundColor: Colors.transparent,
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8),
            width: 1.2,
          ),
          child: SizedBox(
            height: constraints.maxHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.02),
                            ]
                          : [
                              cs.surface,
                              cs.surface.withOpacity(0.9),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: coverH,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                child: coverUrl.isNotEmpty
                                    ? Image.network(
                                        coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          debugPrint('ProjectCard image failed: $coverUrl ($error)');
                                          return _fallbackCover(context, cs);
                                        },
                                      )
                                    : _fallbackCover(context, cs),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.6)]
                                        : [Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.2)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(top: 12, left: 12, child: _buildStatusChip()),
                            if (onMoreOptions != null)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  onPressed: onMoreOptions,
                                  icon: Icon(Icons.more_horiz_rounded, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.toUpperCase(),
                                style: AppTypography.labelLarge.copyWith(
                                  color: isDark ? Colors.white : cs.onSurface,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (description != null && description!.isNotEmpty)
                                Text(
                                  description!,
                                  style: AppTypography.body3.copyWith(
                                    color: isDark ? Colors.white.withOpacity(0.5) : cs.onSurfaceVariant,
                                    fontSize: 10,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(lastModified),
                                    style: AppTypography.caption.copyWith(
                                      color: isDark ? Colors.white.withOpacity(0.25) : cs.onSurfaceVariant.withOpacity(0.5),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (isDark ? AppColors.primary : cs.primary).withOpacity(0.12),
                                      border: Border.all(
                                        color: (isDark ? AppColors.primary : cs.primary).withOpacity(0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark ? AppColors.primary : cs.primary,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _fallbackCover(BuildContext context, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDark ? AppColors.primary : cs.primary).withOpacity(0.2),
            (isDark ? AppColors.accent : cs.secondary).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_mosaic_rounded,
          color: isDark ? Colors.white24 : cs.onSurface.withOpacity(0.2),
          size: 32,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: chipColor,
              boxShadow: [
                BoxShadow(
                  color: chipColor.withOpacity(0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            chipText,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
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
