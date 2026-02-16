import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AppNotifier {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static DateTime? _lastShownAt;
  static String? _lastMessage;

  static void showError(String message) {
    _show(message, backgroundColor: AppColors.error);
  }

  static void showSuccess(String message) {
    _show(message, backgroundColor: AppColors.success);
  }

  static void _show(String message, {required Color backgroundColor}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final lastAt = _lastShownAt;
    if (lastAt != null) {
      final ms = now.difference(lastAt).inMilliseconds;
      if (ms >= 0 && ms < 600 && _lastMessage == trimmed) {
        return;
      }
    }

    _lastShownAt = now;
    _lastMessage = trimmed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = messengerKey.currentState;
      if (m == null) return;
      if (!m.mounted) return;

      try {
        m.hideCurrentSnackBar();
      } catch (_) {}

      try {
        m.showSnackBar(
          SnackBar(
            content: Text(trimmed),
            backgroundColor: backgroundColor,
          ),
        );
      } catch (_) {}
    });
  }
}
