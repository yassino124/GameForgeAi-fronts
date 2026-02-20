import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

class StatusChip extends StatefulWidget {
  final String label;
  final String status;
  final VoidCallback? onTap;
  final bool clickable;
  final Color? color;

  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.onTap,
    this.clickable = false,
    this.color,
  });

  @override
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AdminTheme.statusColor(widget.status);
    final isRunning = widget.status.toLowerCase().contains('running');

    return MouseRegion(
      cursor: widget.clickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.clickable ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: isRunning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.5)),
                boxShadow: isRunning
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3 * _pulseAnimation.value),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.label,
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
