import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/toast_system.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _target = 'All Users';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _messageController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchNotificationsHistory();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification(BuildContext context) async {
    print('DEBUG: Send button pressed');
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      context.showError('Title and message are required');
      return;
    }

    setState(() => _sending = true);

    try {
      final provider = context.read<AdminProvider>();
      final success = await provider.sendRealtimeNotification(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        target: _target,
      );

      print('DEBUG: sendRealtimeNotification returned: $success');

      if (!mounted) return;

      if (success) {
        context.showSuccess('Notification sent successfully to all users!');
        _titleController.clear();
        _messageController.clear();
        // Refresh notifications history
        provider.fetchNotificationsHistory();
      } else {
        context.showError('Failed to send notification');
      }
    } catch (e) {
      print('DEBUG: Exception caught in _sendNotification: $e');
      if (mounted) {
        context.showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Send notification form
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send Notification',
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.borderGlow),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        style: const TextStyle(color: AdminTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        style: const TextStyle(color: AdminTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _target,
                        decoration: const InputDecoration(labelText: 'Target'),
                        dropdownColor: AdminTheme.bgSecondary,
                        items: const [
                          DropdownMenuItem(
                            value: 'All Users',
                            child: Text('All Users'),
                          ),
                          DropdownMenuItem(
                            value: 'Pro Users',
                            child: Text('Pro Users'),
                          ),
                          DropdownMenuItem(
                            value: 'Specific Role',
                            child: Text('Specific Role'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _target = v ?? 'All Users'),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _sending
                            ? null
                            : () => _sendNotification(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.accentNeon,
                          foregroundColor: AdminTheme.bgPrimary,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Send',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Preview
                Text(
                  'Preview',
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.borderGlow),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.isEmpty
                            ? 'Notification Title'
                            : _titleController.text,
                        style: GoogleFonts.orbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.accentNeon,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _messageController.text.isEmpty
                            ? 'Your message will appear here...'
                            : _messageController.text,
                        style: GoogleFonts.rajdhani(
                          color: AdminTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // History
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications History',
                  style: GoogleFonts.orbitron(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.borderGlow),
                  ),
                  child: Consumer<AdminProvider>(
                    builder: (context, provider, _) {
                      final notifications = provider.notificationsHistory;
                      final loading = provider.notificationsHistoryLoading;

                      if (loading) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (notifications.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No notifications sent',
                            style: TextStyle(color: AdminTheme.textSecondary),
                          ),
                        );
                      }

                      return Column(
                        children: notifications
                            .take(20)
                            .map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n['title']?.toString() ?? '',
                                            style: GoogleFonts.orbitron(
                                              fontSize: 14,
                                              color: AdminTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            n['target']?.toString() ?? '',
                                            style: GoogleFonts.rajdhani(
                                              color: AdminTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: (n['readRate'] ?? 0)
                                                .toDouble(),
                                            backgroundColor:
                                                AdminTheme.bgTertiary,
                                            color: AdminTheme.accentGreen,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatDate(n['sentAt']),
                                      style: GoogleFonts.jetBrainsMono(
                                        color: AdminTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return d.toString();
    }
  }
}
