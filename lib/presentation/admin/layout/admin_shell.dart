import 'package:flutter/material.dart';
import 'admin_sidebar.dart';
import 'admin_header.dart';
import '../constants/admin_theme.dart';
import '../widgets/toast_system.dart';
import '../widgets/floating_mic_button.dart';
import '../widgets/ai_search_overlay.dart';

class AdminShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? headerActions;

  const AdminShell({
    super.key,
    required this.title,
    required this.child,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.bgPrimary,
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSidebar(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminHeader(title: title, actions: headerActions),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ToastSystem(key: ToastSystem.globalKey),
          FloatingMicButton(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (ctx) => const AiSearchOverlay(),
              );
            },
          ),
        ],
      ),
    );
  }
}
