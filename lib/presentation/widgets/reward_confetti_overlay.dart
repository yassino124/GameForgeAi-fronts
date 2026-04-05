import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as math;

class RewardConfettiOverlay extends StatelessWidget {
  final bool play;
  final Widget child;

  const RewardConfettiOverlay({
    super.key,
    required this.play,
    required this.child,
  });

  static const String _assetPath = 'assets/animations/confetti.json';

  Future<bool> _assetExists() async {
    try {
      await rootBundle.load(_assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!play) return child;

    return FutureBuilder<bool>(
      future: _assetExists(),
      builder: (context, snap) {
        final ok = snap.data == true;
        return Stack(
          children: [
            child,
            if (ok)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.95,
                    child: Lottie.asset(
                      _assetPath,
                      fit: BoxFit.cover,
                      repeat: false,
                    ),
                  ),
                ),
              ),
            if (!ok)
              Positioned.fill(
                child: IgnorePointer(
                  child: _FallbackConfettiBurst(key: const ValueKey('fallback_confetti')),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FallbackConfettiBurst extends StatelessWidget {
  const _FallbackConfettiBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final p = t.clamp(0.0, 1.0);
        final opacity = (1.0 - (p * 1.1)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: CustomPaint(
            painter: _FallbackConfettiPainter(progress: p),
          ),
        );
      },
    );
  }
}

class _FallbackConfettiPainter extends CustomPainter {
  final double progress;
  const _FallbackConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(1337);
    final center = Offset(size.width * 0.5, size.height * 0.22);

    final colors = <Color>[
      const Color(0xFF7C5CFF),
      const Color(0xFF2EE6A6),
      const Color(0xFFFF4D6D),
      const Color(0xFFFFC857),
      const Color(0xFF4CC9F0),
      const Color(0xFFE9D5FF),
    ];

    final count = 90;
    final maxR = math.min(size.width, size.height) * 0.75;
    final t = progress;

    for (var i = 0; i < count; i++) {
      final a = (i / count) * math.pi * 2 + rnd.nextDouble() * 0.35;
      final speed = 0.55 + rnd.nextDouble() * 0.55;
      final radius = maxR * t * speed;
      final drift = (rnd.nextDouble() - 0.5) * size.width * 0.15 * t;
      final dy = radius * (0.85 + rnd.nextDouble() * 0.45);

      final x = center.dx + math.cos(a) * radius + drift;
      final y = center.dy + math.sin(a) * radius + dy;

      final w = 3 + rnd.nextDouble() * 5;
      final h = 6 + rnd.nextDouble() * 10;
      final rot = (rnd.nextDouble() - 0.5) * math.pi * 1.8 * t;

      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity((1.0 - t * 0.8).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FallbackConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
