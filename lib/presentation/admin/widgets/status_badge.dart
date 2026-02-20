import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

class StatusBadge extends StatefulWidget {
  final String status;
  final double? size;
  final bool showPulse;

  const StatusBadge({
    super.key,
    required this.status,
    this.size,
    this.showPulse = false,
  });

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge> {
  @override
  Widget build(BuildContext context) {
    final color = AdminTheme.statusColor(widget.status);
    final shouldPulse = widget.showPulse && 
        (widget.status.toLowerCase().contains('running') || 
         widget.status.toLowerCase().contains('pending'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.size ?? 8,
            height: widget.size ?? 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ).animate(
            onComplete: (controller) => controller.repeat(),
          ).shimmer(
            duration: shouldPulse ? 1500.ms : null,
            color: Colors.white.withOpacity(0.5),
          ).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.2, 1.2),
            duration: shouldPulse ? 800.ms : null,
            curve: Curves.easeInOut,
          ).then()
           .scale(
            begin: const Offset(1.2, 1.2),
            end: const Offset(1, 1),
            duration: shouldPulse ? 800.ms : null,
            curve: Curves.easeInOut,
          ),
          const SizedBox(width: 6),
          Text(
            widget.status,
            style: GoogleFonts.rajdhani(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class AnimatedProgressIndicator extends StatefulWidget {
  final double value;
  final Color? color;
  final String? label;
  final double? width;
  final double height;

  const AnimatedProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.label,
    this.width,
    this.height = 8,
  });

  @override
  State<AnimatedProgressIndicator> createState() => _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.forward(from: _animation.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: AdminTheme.bgTertiary,
                borderRadius: BorderRadius.circular(widget.height / 2),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: _animation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color ?? AdminTheme.accentNeon,
                            AdminTheme.accentPurple,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.color ?? AdminTheme.accentNeon).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(_animation.value * 100).toInt()}%',
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class CircularProgressIndicator extends StatefulWidget {
  final double value;
  final Color? color;
  final double size;
  final double strokeWidth;

  const CircularProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.size = 60,
    this.strokeWidth = 6,
  });

  @override
  State<CircularProgressIndicator> createState() => _CircularProgressIndicatorState();
}

class _CircularProgressIndicatorState extends State<CircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(CircularProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.forward(from: _animation.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: widget.strokeWidth,
                  color: AdminTheme.borderGlow,
                ),
              ),
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: _animation.value,
                  strokeWidth: widget.strokeWidth,
                  color: widget.color ?? AdminTheme.accentNeon,
                ),
              ),
              Center(
                child: Text(
                  '${(_animation.value * 100).toInt()}%',
                  style: TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: widget.size * 0.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms);
      },
    );
  }
}
