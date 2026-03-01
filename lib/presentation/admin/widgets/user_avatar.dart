import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.username,
    this.radius = 60,
    this.backgroundColor = AdminTheme.accentPurple,
    this.textColor = AdminTheme.accentPurple,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (username.isNotEmpty ? username[0] : '?').toUpperCase();

    // If avatar URL exists and is not empty, display the image
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor.withOpacity(0.3),
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback to initials if image fails to load
          debugPrint('Failed to load avatar: $exception');
        },
        child: avatarUrl == null || avatarUrl!.isEmpty
            ? Text(
                initials,
                style: GoogleFonts.orbitron(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              )
            : null,
      );
    }

    // Fallback to initials if no avatar URL
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor.withOpacity(0.3),
      child: Text(
        initials,
        style: GoogleFonts.orbitron(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
