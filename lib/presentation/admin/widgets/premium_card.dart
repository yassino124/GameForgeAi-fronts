import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/admin_theme.dart';

class PremiumCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool enableHover;
  final double elevation;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.enableHover = true,
    this.elevation = 2.0,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.enableHover ? setState(() => _isHovered = true) : null,
      onExit: (_) => widget.enableHover ? setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AdminTheme.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered 
                  ? AdminTheme.accentNeon.withOpacity(0.3)
                  : AdminTheme.borderGlow,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? AdminTheme.accentNeon.withOpacity(0.1)
                    : Colors.black.withOpacity(0.2),
                blurRadius: _isHovered ? 12 : 8,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
              if (_isHovered)
                BoxShadow(
                  color: AdminTheme.accentNeon.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Container(
            padding: widget.padding ?? const EdgeInsets.all(16),
            child: widget.child,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(duration: 300.ms),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? change;
  final bool isPositive;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.change,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AdminTheme.accentNeon).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AdminTheme.accentNeon,
                  size: 20,
                ),
              ),
              const Spacer(),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPositive ? AdminTheme.accentGreen : AdminTheme.accentRed).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: isPositive ? AdminTheme.accentGreen : AdminTheme.accentRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        change!,
                        style: TextStyle(
                          color: isPositive ? AdminTheme.accentGreen : AdminTheme.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(duration: 300.ms);
  }
}
