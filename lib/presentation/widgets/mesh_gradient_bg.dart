import 'dart:math';
import 'package:flutter/material.dart';

class MeshGradientBg extends StatefulWidget {
  final List<Color> colors;

  const MeshGradientBg({
    super.key,
    required this.colors,
  });

  @override
  State<MeshGradientBg> createState() => _MeshGradientBgState();
}

class _MeshGradientBgState extends State<MeshGradientBg> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;
        final colors = widget.colors;
        final stops = colors.length == 3 ? const [0.0, 0.5, 1.0] : null;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(cos(t) * 0.5, sin(t) * 0.5),
              end: Alignment(cos(t + pi) * 0.5, sin(t + pi) * 0.5),
              colors: colors,
              stops: stops,
            ),
          ),
        );
      },
    );
  }
}
