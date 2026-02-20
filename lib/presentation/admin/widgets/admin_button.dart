import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

class AdminButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final Color? color;

  const AdminButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.outlined = false,
    this.color,
  });

  @override
  State<AdminButton> createState() => _AdminButtonState();
}

class _AdminButtonState extends State<AdminButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AdminTheme.accentNeon;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: widget.outlined
            ? OutlinedButton.icon(
                onPressed: widget.onPressed,
                icon: widget.icon != null ? Icon(widget.icon, size: 18, color: color) : const SizedBox.shrink(),
                label: Text(widget.label, style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: _hovered ? color : AdminTheme.borderGlow),
                ),
              )
            : ElevatedButton.icon(
                onPressed: widget.onPressed,
                icon: widget.icon != null ? Icon(widget.icon, size: 18) : const SizedBox.shrink(),
                label: Text(widget.label, style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AdminTheme.bgPrimary,
                ),
              ),
      ),
    );
  }
}
