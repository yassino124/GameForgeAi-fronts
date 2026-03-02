import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/voice_assistant_provider.dart';
import 'admin_sidebar.dart';
import 'admin_header.dart';
import '../constants/admin_theme.dart';
import '../widgets/toast_system.dart';
import '../widgets/admin_voice_assistant.dart';

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
    return ChangeNotifierProvider(
      create: (_) => VoiceAssistantProvider(),
      child: Scaffold(
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
            const AdminVoiceAssistant(),
          ],
        ),
      ),
    );
  }
}
