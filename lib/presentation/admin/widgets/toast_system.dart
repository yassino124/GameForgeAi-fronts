import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

enum ToastType { success, error, warning, info }

class ToastSystem extends StatefulWidget {
  const ToastSystem({super.key});

  @override
  State<ToastSystem> createState() => _ToastSystemState();
}

class _ToastSystemState extends State<ToastSystem> {
  static final List<ToastData> _toasts = [];
  static final GlobalKey<_ToastSystemState> _key = GlobalKey();

  static void show(String message, {ToastType type = ToastType.info, Duration? duration}) {
    final toast = ToastData(
      message: message,
      type: type,
      duration: duration ?? const Duration(seconds: 3),
    );
    
    _toasts.add(toast);
    _key.currentState?._addToast(toast);
    
    // Auto remove after duration
    Future.delayed(toast.duration, () {
      _toasts.remove(toast);
      _key.currentState?._removeToast(toast);
    });
  }

  static void success(String message) => show(message, type: ToastType.success);
  static void error(String message) => show(message, type: ToastType.error);
  static void warning(String message) => show(message, type: ToastType.warning);
  static void info(String message) => show(message, type: ToastType.info);

  final List<ToastData> _activeToasts = [];

  void _addToast(ToastData toast) {
    if (mounted) {
      setState(() {
        _activeToasts.add(toast);
      });
    }
  }

  void _removeToast(ToastData toast) {
    if (mounted) {
      setState(() {
        _activeToasts.remove(toast);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      right: 16,
      child: Column(
        children: _activeToasts.map((toast) {
          return _ToastWidget(
            key: ValueKey(toast),
            toast: toast,
            onDismiss: () => _removeToast(toast),
          );
        }).toList(),
      ),
    );
  }
}

class ToastData {
  final String message;
  final ToastType type;
  final Duration duration;

  ToastData({
    required this.message,
    required this.type,
    required this.duration,
  });
}

class _ToastWidget extends StatefulWidget {
  final ToastData toast;
  final VoidCallback onDismiss;

  const _ToastWidget({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  @override
  Widget build(BuildContext context) {
    final color = _getColorForType(widget.toast.type);
    final icon = _getIconForType(widget.toast.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              widget.toast.message,
              style: GoogleFonts.rajdhani(
                color: AdminTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onDismiss,
            child: Icon(
              Icons.close,
              color: AdminTheme.textSecondary,
              size: 16,
            ),
          ),
        ],
      ),
    ).animate()
     .slideX(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut)
     .fadeIn(duration: 300.ms);
  }

  Color _getColorForType(ToastType type) {
    switch (type) {
      case ToastType.success:
        return AdminTheme.accentGreen;
      case ToastType.error:
        return AdminTheme.accentRed;
      case ToastType.warning:
        return AdminTheme.accentOrange;
      case ToastType.info:
        return AdminTheme.accentNeon;
    }
  }

  IconData _getIconForType(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.warning:
        return Icons.warning;
      case ToastType.info:
        return Icons.info;
    }
  }
}

// Extension method for easy access
extension ToastContext on BuildContext {
  void showToast(String message, {ToastType type = ToastType.info}) {
    _ToastSystemState.show(message, type: type);
  }

  void showSuccess(String message) => _ToastSystemState.success(message);
  void showError(String message) => _ToastSystemState.error(message);
  void showWarning(String message) => _ToastSystemState.warning(message);
  void showInfo(String message) => _ToastSystemState.info(message);
}
