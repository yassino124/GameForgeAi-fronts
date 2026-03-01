import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/services/notifications_service.dart';
import '../../../core/services/notifications_socket_service.dart';
import '../../../core/services/templates_service.dart';
import '../../widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  bool _loading = false;
  String? _error;

  final Set<String> _approvingNotificationIds = {};
  
  // Socket listener callback
  void Function(Map<String, dynamic>)? _socketListener;

  @override
  void initState() {
    super.initState();
    _initializeRealtimeNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  
  @override
  void dispose() {
    // Remove socket listener when screen is disposed
    if (_socketListener != null) {
      NotificationsSocketService().removeListener(_socketListener!);
    }
    super.dispose();
  }
  
  void _initializeRealtimeNotifications() {
    final token = _getToken();
    if (token == null || token.isEmpty) return;
    
    // Create listener callback
    _socketListener = (notification) {
      print('[NotificationsScreen] 📨 Received real-time notification: ${notification['title']}');
      _handleRealtimeNotification(notification);
    };
    
    // Connect to Socket.io if not already connected
    if (!NotificationsSocketService().isConnected) {
      print('[NotificationsScreen] 🔌 Connecting to Socket.io...');
      NotificationsSocketService().connect(
        baseUrl: 'http://localhost:3000',
        token: token,
      ).then((_) {
        print('[NotificationsScreen] ✅ Socket.io connected');
        // Add listener after connection
        NotificationsSocketService().addListener(_socketListener!);
      }).catchError((error) {
        print('[NotificationsScreen] ❌ Failed to connect: $error');
      });
    } else {
      // Already connected, just add listener
      NotificationsSocketService().addListener(_socketListener!);
    }
  }
  
  void _handleRealtimeNotification(Map<String, dynamic> notification) {
    if (!mounted) return;
    
    // Create notification item from socket data
    final id = notification['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final title = notification['title']?.toString() ?? 'Notification';
    final message = notification['message']?.toString() ?? '';
    final typeStr = notification['type']?.toString() ?? 'info';
    final type = _mapType(typeStr);
    
    DateTime timestamp;
    try {
      final ts = notification['timestamp']?.toString() ?? '';
      timestamp = DateTime.parse(ts).toLocal();
    } catch (_) {
      timestamp = DateTime.now();
    }
    
    final newNotification = NotificationItem(
      id: id,
      title: title,
      message: message,
      timestamp: timestamp,
      type: type,
      isRead: false,
      icon: _mapIcon(type),
      data: notification['data'],
    );
    
    setState(() {
      // Add to the top of the list
      _notifications.insert(0, newNotification);
    });
    
    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _getTypeColor(type),
      ),
    );
  }
  
  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.info:
      default:
        return Colors.blue;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == notificationId);
      notification.isRead = true;
    });

    if (notificationId.startsWith('local_')) {
      try {
        await LocalNotificationsService.markInAppNotificationRead(notificationId, true);
      } catch (_) {}
      return;
    }

    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;
    try {
      await NotificationsService.markNotificationRead(
        token: token,
        notificationId: notificationId,
        isRead: true,
      );
    } catch (_) {}
  }

  bool get _isModerator {
    try {
      final auth = context.read<AuthProvider>();
      return auth.isAdmin || auth.isDevl;
    } catch (_) {
      return false;
    }
  }

  String? _getToken() {
    try {
      return context.read<AuthProvider>().token;
    } catch (_) {
      return null;
    }
  }

  NotificationType _mapType(String raw) {
    final t = raw.trim().toLowerCase();
    switch (t) {
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'error':
        return NotificationType.error;
      case 'info':
      default:
        return NotificationType.info;
    }
  }

  IconData _mapIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.info:
      default:
        return Icons.notifications;
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    final token = _getToken();
    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _error = 'Please sign in to view notifications.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final localRaw = await LocalNotificationsService.listInAppNotifications();

      final res = await NotificationsService.listNotifications(token: token);
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() {
          _error = res['message']?.toString() ?? 'Failed to load notifications';
          _notifications = [];
        });
        return;
      }

      final data = (res['data'] is List) ? (res['data'] as List) : const [];
      final items = <NotificationItem>[];

      for (final n in localRaw) {
        final id = n['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final title = n['title']?.toString() ?? '';
        final message = n['message']?.toString() ?? '';
        final isRead = n['isRead'] == true;
        final createdAt = n['timestamp']?.toString() ?? '';
        DateTime ts;
        try {
          ts = DateTime.parse(createdAt).toLocal();
        } catch (_) {
          ts = DateTime.now();
        }
        final type = _mapType(n['type']?.toString() ?? 'info');
        final payload = (n['data'] is Map) ? Map<String, dynamic>.from(n['data'] as Map) : null;
        items.add(
          NotificationItem(
            id: id,
            title: title,
            message: message,
            timestamp: ts,
            type: type,
            isRead: isRead,
            icon: _mapIcon(type),
            data: payload,
          ),
        );
      }

      for (final n in data) {
        if (n is! Map) continue;
        final id = n['_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final title = n['title']?.toString() ?? '';
        final message = n['message']?.toString() ?? '';
        final isRead = n['isRead'] == true;
        final createdAt = n['createdAt']?.toString() ?? '';
        DateTime ts;
        try {
          ts = DateTime.parse(createdAt).toLocal();
        } catch (_) {
          ts = DateTime.now();
        }
        final type = _mapType(n['type']?.toString() ?? 'info');
        final payload = (n['data'] is Map) ? Map<String, dynamic>.from(n['data'] as Map) : null;
        items.add(
          NotificationItem(
            id: id,
            title: title,
            message: message,
            timestamp: ts,
            type: type,
            isRead: isRead,
            icon: _mapIcon(type),
            data: payload,
          ),
        );
      }

      setState(() {
        _notifications = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _notifications = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        toolbarHeight: kToolbarHeight + AppSpacing.sm,
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            foregroundColor: cs.onSurface,
          ),
        ),
        title: Text(
          'Notifications',
          style: AppTypography.subtitle1,
        ),
        actions: [
          // Mark all as read
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              'Mark all read',
              style: AppTypography.body2.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(),
          
          // Notifications list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: AppSpacing.paddingLarge,
                          child: Text(
                            _error!,
                            style: AppTypography.body2.copyWith(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _notifications.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.notifications_none,
                            title: 'No notifications',
                            subtitle: 'You\'re all caught up!',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: AppSpacing.paddingLarge,
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                return _buildNotificationItem(_notifications[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: Row(
        children: [
          // All tab
          _buildFilterTab('All', _notifications.length, true),
          
          const SizedBox(width: AppSpacing.lg),
          
          // Unread tab
          _buildFilterTab(
            'Unread', 
            _notifications.where((n) => !n.isRead).length, 
            false,
          ),
          
          const Spacer(),
          
          // Clear all button
          TextButton(
            onPressed: _clearAllNotifications,
            child: Text(
              'Clear all',
              style: AppTypography.body2.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, int count, bool isSelected) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        // TODO: Implement filter logic
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppTypography.body2.copyWith(
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            
            if (count > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? cs.onPrimary.withOpacity(0.2)
                      : cs.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: AppTypography.caption.copyWith(
                    color: isSelected ? cs.onPrimary : cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    final cs = Theme.of(context).colorScheme;
    Color iconColor;
    Color backgroundColor;
    
    switch (notification.type) {
      case NotificationType.success:
        iconColor = AppColors.success;
        backgroundColor = AppColors.success.withOpacity(0.1);
        break;
      case NotificationType.warning:
        iconColor = AppColors.warning;
        backgroundColor = AppColors.warning.withOpacity(0.1);
        break;
      case NotificationType.error:
        iconColor = AppColors.error;
        backgroundColor = AppColors.error.withOpacity(0.1);
        break;
      case NotificationType.info:
      default:
        iconColor = AppColors.primary;
        backgroundColor = AppColors.primary.withOpacity(0.1);
        break;
    }
    
    return InkWell(
      borderRadius: BorderRadius.circular(AppBorderRadius.large),
      onTap: () => _onTapNotification(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(
            color: notification.isRead ? cs.outlineVariant.withOpacity(0.6) : cs.primary,
            width: notification.isRead ? 1 : 2,
          ),
        ),
        child: Column(
          children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppSpacing.lg),
              
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.subtitle2.copyWith(
                              fontWeight: notification.isRead 
                                  ? FontWeight.normal 
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        // Unread indicator
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: AppSpacing.sm),
                    
                    Text(
                      notification.message,
                      style: AppTypography.body2.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.sm),
                    
                    Text(
                      _formatTimestamp(notification.timestamp),
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // More options
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: cs.onSurfaceVariant,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'mark_read':
                      _markAsRead(notification.id);
                      break;
                    case 'mark_unread':
                      _markAsUnread(notification.id);
                      break;
                    case 'delete':
                      _deleteNotification(notification.id);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: notification.isRead ? 'mark_unread' : 'mark_read',
                    child: Text(notification.isRead ? 'Mark as unread' : 'Mark as read'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          
          // Action buttons for specific notification types
          if (_isModerator &&
              (notification.data?['kind']?.toString() ?? '') == 'template_review_pending') ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Open Template',
                    onPressed: () {
                      final tid = notification.data?['templateId']?.toString() ?? '';
                      if (tid.trim().isEmpty) return;
                      context.go('/template/$tid');
                    },
                    type: ButtonType.secondary,
                    size: ButtonSize.small,
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: CustomButton(
                    text: _approvingNotificationIds.contains(notification.id) ? 'Approving...' : 'Approve',
                    onPressed: _approvingNotificationIds.contains(notification.id)
                        ? null
                        : () => _approveFromNotification(notification),
                    type: ButtonType.primary,
                    size: ButtonSize.small,
                    icon: const Icon(Icons.verified),
                  ),
                ),
              ],
            ),
          ],
          if (notification.type == NotificationType.success && 
              notification.title.contains('Generated')) ...[
            const SizedBox(height: AppSpacing.md),
            
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'View Game',
                    onPressed: () {
                      context.go('/project-detail');
                    },
                    type: ButtonType.primary,
                    size: ButtonSize.small,
                  ),
                ),
                
                const SizedBox(width: AppSpacing.md),
                
                Expanded(
                  child: CustomButton(
                    text: 'Share',
                    onPressed: () {
                      // TODO: Implement share functionality
                    },
                    type: ButtonType.secondary,
                    size: ButtonSize.small,
                  ),
                ),
              ],
            ),
          ],
          ],
        ),
      ),
    );
  }

  Future<void> _onTapNotification(NotificationItem notification) async {
    final kind = notification.data?['kind']?.toString() ?? '';
    if (kind == 'build_finished') {
      final pid = notification.data?['projectId']?.toString() ?? '';
      if (pid.trim().isNotEmpty) {
        await _markAsRead(notification.id);
        if (!mounted) return;
        context.go('/build-results?projectId=$pid');
      }
      return;
    }

    await _markAsRead(notification.id);
  }

  Future<void> _approveFromNotification(NotificationItem notification) async {
    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    final templateId = notification.data?['templateId']?.toString() ?? '';
    final userId = notification.data?['userId']?.toString() ?? '';

    if (templateId.trim().isEmpty || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Invalid notification payload'), backgroundColor: cs.error),
      );
      return;
    }

    setState(() {
      _approvingNotificationIds.add(notification.id);
    });

    try {
      final res = await TemplatesService.approveTemplateReview(
        token: token,
        templateId: templateId,
        userId: userId,
      );

      if (!mounted) return;
      if (res['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to approve review'),
            backgroundColor: cs.error,
          ),
        );
        return;
      }

      await NotificationsService.markNotificationRead(
        token: token,
        notificationId: notification.id,
        isRead: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Review approved.'), backgroundColor: cs.primary),
      );

      await _load();

      if (mounted) {
        context.go('/template/$templateId');
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _approvingNotificationIds.remove(notification.id);
      });
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _markAllAsRead() {
    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;

    try {
      LocalNotificationsService.markAllInAppRead();
    } catch (_) {}

    NotificationsService.markAllRead(token: token).then((res) {
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          for (var notification in _notifications) {
            notification.isRead = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to mark notifications as read'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }).catchError((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to mark notifications as read'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    });
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              }
              try {
                LocalNotificationsService.clearInAppNotifications();
              } catch (_) {}

              final token = _getToken();
              if (token == null || token.trim().isEmpty) {
                setState(() {
                  _notifications.removeWhere((n) => n.id.startsWith('local_'));
                });
                return;
              }

              NotificationsService.clearAll(token: token).then((res) {
                if (!mounted) return;
                if (res['success'] == true) {
                  setState(() {
                    _notifications.clear();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Failed to clear notifications'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }).catchError((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to clear notifications'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              });
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _markAsUnread(String notificationId) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == notificationId);
      notification.isRead = false;
    });

    if (notificationId.startsWith('local_')) {
      try {
        LocalNotificationsService.markInAppNotificationRead(notificationId, false);
      } catch (_) {}
      return;
    }

    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;
    try {
      NotificationsService.markNotificationRead(
        token: token,
        notificationId: notificationId,
        isRead: false,
      );
    } catch (_) {}
  }

  void _deleteNotification(String notificationId) {
    setState(() {
      _notifications.removeWhere((n) => n.id == notificationId);
    });

    if (notificationId.startsWith('local_')) {
      try {
        LocalNotificationsService.removeInAppNotification(notificationId);
      } catch (_) {}
      return;
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final IconData icon;
  final Map<String, dynamic>? data;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.icon,
    required this.data,
    this.isRead = false,
  });
}

enum NotificationType {
  success,
  warning,
  error,
  info,
}
