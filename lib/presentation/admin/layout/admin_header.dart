import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const AdminHeader({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(AdminTheme.headerHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AdminTheme.headerHeight,
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: AdminTheme.borderGlow, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.orbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}
