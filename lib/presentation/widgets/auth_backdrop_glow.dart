import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class AuthBackdropGlow extends StatefulWidget {
  const AuthBackdropGlow({super.key});

  @override
  State<AuthBackdropGlow> createState() => _AuthBackdropGlowState();
}

class _AuthBackdropGlowState extends State<AuthBackdropGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Stack(
            children: [
              Positioned(
                top: -90 + (t * 30),
                left: -70 + (t * 16),
                child: _GlowBlob(
                  size: 240,
                  color: (isDark ? AppColors.primaryLight : AppColors.primary)
                      .withValues(alpha: isDark ? 0.18 : 0.12),
                ),
              ),
              Positioned(
                right: -80 + (t * 24),
                bottom: -110 + ((1 - t) * 36),
                child: _GlowBlob(
                  size: 270,
                  color: (isDark ? AppColors.secondaryLight : AppColors.secondary)
                      .withValues(alpha: isDark ? 0.16 : 0.10),
                ),
              ),
              Positioned(
                right: 30 + ((1 - t) * 18),
                top: 120 + (t * 24),
                child: _GlowBlob(
                  size: 120,
                  color: AppColors.accent.withValues(alpha: isDark ? 0.14 : 0.08),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.06),
                Colors.transparent,
              ],
              stops: const [0.1, 0.55, 1],
            ),
          ),
        ),
      ),
    );
  }
}
