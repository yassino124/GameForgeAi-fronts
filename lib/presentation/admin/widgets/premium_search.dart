import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

class PremiumSearchBar extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;

  const PremiumSearchBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.controller,
  });

  @override
  State<PremiumSearchBar> createState() => _PremiumSearchBarState();
}

class _PremiumSearchBarState extends State<PremiumSearchBar> {
  late final TextEditingController _controller;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: _isFocused ? 320 : 280,
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused 
              ? AdminTheme.accentNeon.withOpacity(0.5)
              : AdminTheme.borderGlow,
          width: _isFocused ? 2 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AdminTheme.accentNeon.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: GoogleFonts.rajdhani(
          color: AdminTheme.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search...',
          hintStyle: GoogleFonts.rajdhani(
            color: AdminTheme.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: _isFocused ? AdminTheme.accentNeon : AdminTheme.textSecondary,
            size: 20,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AdminTheme.textSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onTap: () => setState(() => _isFocused = true),
        onEditingComplete: () => setState(() => _isFocused = false),
        onSubmitted: (_) => setState(() => _isFocused = false),
      ).animate().fadeIn(duration: 300.ms).slideX(duration: 200.ms),
    );
  }
}

class PremiumButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final double? width;

  const PremiumButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.width,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              if (!widget.isLoading && widget.onPressed != null) {
                _animationController.forward();
                setState(() => _isPressed = true);
              }
            },
            onTapUp: (_) {
              _animationController.reverse();
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            },
            onTapCancel: () {
              _animationController.reverse();
              setState(() => _isPressed = false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.width,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isLoading
                    ? AdminTheme.bgTertiary
                    : (widget.backgroundColor ?? AdminTheme.accentNeon),
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: (widget.backgroundColor ?? AdminTheme.accentNeon)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: widget.isLoading
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.foregroundColor ?? AdminTheme.bgPrimary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: 18,
                            color: widget.foregroundColor ?? AdminTheme.bgPrimary,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.text,
                          style: GoogleFonts.rajdhani(
                            color: widget.foregroundColor ?? AdminTheme.bgPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
