import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class CustomBackButton extends StatelessWidget {
  final Color? color;
  final VoidCallback? onPressed;
  final bool showLabel;

  const CustomBackButton({
    super.key,
    this.color,
    this.onPressed,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: effectiveColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          onTap: onPressed ?? () {
            if (context.canPop()) {
              context.pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: effectiveColor,
                  size: 20,
                ),
                if (showLabel) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Back',
                    style: AppTypography.caption.copyWith(
                      color: effectiveColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBarBackButton extends StatelessWidget {
  final Color? color;
  final VoidCallback? onPressed;

  const AppBarBackButton({
    super.key,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;

    return IconButton(
      onPressed: onPressed ?? () {
        if (context.canPop()) {
          context.pop();
        }
      },
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: effectiveColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: effectiveColor,
          size: 18,
        ),
      ),
    );
  }
}

class FloatingBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const FloatingBackButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Positioned(
      top: MediaQuery.of(context).padding.top + AppSpacing.lg,
      left: AppSpacing.lg,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AppBarBackButton(
          onPressed: onPressed,
        ),
      ),
    );
  }
}
