import 'package:flutter/material.dart';

/// Admin Dashboard - Dark Cyber Gaming theme
class AdminTheme {
  AdminTheme._();

  // Backgrounds
  static const Color bgPrimary = Color(0xFF080B14);
  static const Color bgSecondary = Color(0xFF0D1426);
  static const Color bgTertiary = Color(0xFF141D35);

  // Accents
  static const Color accentNeon = Color(0xFF00F5FF);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentGreen = Color(0xFF00FF88);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentRed = Color(0xFFFF3366);

  // Text
  static const Color textPrimary = Color(0xFFE8F4FD);
  static const Color textSecondary = Color(0xFF6B8CAE);
  static const Color textMuted = Color(0xFF2A3F5F);

  // Borders & Effects
  static const Color borderGlow = Color(0xFF1A2A4A);
  static const Color glowCyan = Color(0x2000F5FF);
  static const Color glowPurple = Color(0x207C3AED);

  // Sidebar
  static const double sidebarWidth = 240;
  static const double headerHeight = 64;

  // Status colors
  static Color statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('active') || s.contains('success') || s.contains('online') || s.contains('published')) {
      return accentGreen;
    }
    if (s.contains('pending') || s.contains('warning') || s.contains('running') || s.contains('queued')) {
      return s.contains('running') ? accentNeon : accentOrange;
    }
    if (s.contains('failed') || s.contains('error') || s.contains('offline') || s.contains('inactive')) {
      return accentRed;
    }
    if (s.contains('draft') || s.contains('inactive') || s.contains('archived') || s.contains('cancelled')) {
      return textSecondary;
    }
    if (s.contains('in_progress')) {
      return accentPurple;
    }
    return textSecondary;
  }

  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return accentRed;
      case 'devl':
      case 'dev':
        return accentPurple;
      case 'user':
      default:
        return accentNeon;
    }
  }

  static Color planColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'enterprise':
        return const Color(0xFFFFD700); // Gold
      case 'pro':
        return accentNeon;
      case 'free':
      default:
        return textSecondary;
    }
  }
}
