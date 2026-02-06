import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'Game Generated Successfully!',
      message: 'Your Space Adventure game is ready to play and customize.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      type: NotificationType.success,
      isRead: false,
      icon: Icons.check_circle,
    ),
    NotificationItem(
      id: '2',
      title: 'New Template Available',
      message: 'Check out the new Fantasy RPG template in the marketplace.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.info,
      isRead: false,
      icon: Icons.new_releases,
    ),
    NotificationItem(
      id: '3',
      title: 'Build Completed',
      message: 'Your iOS build has completed successfully. Ready for download!',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      type: NotificationType.success,
      isRead: true,
      icon: Icons.build,
    ),
    NotificationItem(
      id: '4',
      title: 'Subscription Renewed',
      message: 'Your Pro subscription has been renewed for another month.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.info,
      isRead: true,
      icon: Icons.workspace_premium,
    ),
    NotificationItem(
      id: '5',
      title: 'System Maintenance',
      message: 'Scheduled maintenance will occur tonight from 2-4 AM EST.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.warning,
      isRead: true,
      icon: Icons.schedule,
    ),
  ];

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
            child: _notifications.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.notifications_none,
                    title: 'No notifications',
                    subtitle: 'You\'re all caught up!',
                  )
                : ListView.builder(
                    padding: AppSpacing.paddingLarge,
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationItem(_notifications[index]);
                    },
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
    
    return Container(
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
    );
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
              setState(() {
                _notifications.clear();
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

  void _markAsRead(String notificationId) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == notificationId);
      notification.isRead = true;
    });
  }

  void _markAsUnread(String notificationId) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == notificationId);
      notification.isRead = false;
    });
  }

  void _deleteNotification(String notificationId) {
    setState(() {
      _notifications.removeWhere((n) => n.id == notificationId);
    });
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final IconData icon;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.icon,
    this.isRead = false,
  });
}

enum NotificationType {
  success,
  warning,
  error,
  info,
}
