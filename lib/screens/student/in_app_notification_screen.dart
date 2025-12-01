// screens/student/in_app_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/in_app_notification.dart';
import '../../providers/in_app_notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart'; // for localeProvider

class InAppNotificationScreen extends ConsumerStatefulWidget {
  const InAppNotificationScreen({super.key});

  @override
  ConsumerState<InAppNotificationScreen> createState() => _InAppNotificationScreenState();
}

class _InAppNotificationScreenState extends ConsumerState<InAppNotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider);
      if (user != null) {
        ref.read(inAppNotificationProvider.notifier).loadNotifications(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(inAppNotificationProvider);
    final user = ref.watch(authProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    // Group notifications by date
    final groupedNotifications = _groupNotificationsByDate(notifications, isVietnamese);

    return Scaffold(
      appBar: AppBar(
        title: Text(isVietnamese ? 'Thông báo' : 'Notifications'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                if (user != null) {
                  ref.read(inAppNotificationProvider.notifier).markAllAsRead(user.id);
                }
              },
              child: Text(
                isVietnamese ? 'Đọc tất cả' : 'Mark all read',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    isVietnamese ? 'Chưa có thông báo nào' : 'No notifications yet',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                if (user != null) {
                  await ref.read(inAppNotificationProvider.notifier).loadNotifications(user.id);
                }
              },
              child: ListView.builder(
                itemCount: groupedNotifications.length,
                itemBuilder: (context, index) {
                  final group = groupedNotifications[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Colors.grey.shade100,
                        child: Text(
                          group['date'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      // Notifications for this date
                      ...(group['notifications'] as List<InAppNotification>)
                          .map((notification) =>
                              _NotificationTile(notification: notification, isVietnamese: isVietnamese))
                          .toList(),
                    ],
                  );
                },
              ),
            ),
    );
  }

  List<Map<String, dynamic>> _groupNotificationsByDate(
      List<InAppNotification> notifications, bool isVietnamese) {
    final Map<String, List<InAppNotification>> grouped = {};
    final now = DateTime.now();

    for (var notification in notifications) {
      final date = notification.createdAt;
      String label;

      if (_isSameDay(date, now)) {
        label = isVietnamese ? 'Hôm nay' : 'Today';
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        label = isVietnamese ? 'Hôm qua' : 'Yesterday';
      } else if (now.difference(date).inDays < 7) {
        label = isVietnamese ? 'Tuần này' : 'This week';
      } else if (now.difference(date).inDays < 30) {
        label = isVietnamese ? 'Tháng này' : 'This month';
      } else {
        label = DateFormat('MMMM yyyy').format(date);
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(notification);
    }

    return grouped.entries
        .map((entry) => {
              'date': entry.key,
              'notifications': entry.value,
            })
        .toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _NotificationTile extends ConsumerWidget {
  final InAppNotification notification;
  final bool isVietnamese;

  const _NotificationTile({required this.notification, required this.isVietnamese});

  // Get localized title with prefix based on notification type
  String _getLocalizedTitle() {
    final title = notification.title;

    // If title already contains a prefix pattern (old notifications), strip it
    final cleanTitle = title
        .replaceFirst(RegExp(r'^Thông báo mới:\s*'), '')
        .replaceFirst(RegExp(r'^New announcement:\s*'), '');

    switch (notification.type) {
      case InAppNotificationType.announcement:
        return isVietnamese ? 'Thông báo mới: $cleanTitle' : 'New announcement: $cleanTitle';
      case InAppNotificationType.assignment:
        return isVietnamese ? 'Bài tập mới: $cleanTitle' : 'New assignment: $cleanTitle';
      case InAppNotificationType.assignmentGraded:
        return isVietnamese ? 'Đã chấm điểm: $cleanTitle' : 'Graded: $cleanTitle';
      case InAppNotificationType.quiz:
        return isVietnamese ? 'Quiz mới: $cleanTitle' : 'New quiz: $cleanTitle';
      case InAppNotificationType.material:
        return isVietnamese ? 'Tài liệu mới: $cleanTitle' : 'New material: $cleanTitle';
      case InAppNotificationType.message:
        return isVietnamese ? 'Tin nhắn mới: $cleanTitle' : 'New message: $cleanTitle';
      case InAppNotificationType.deadlineReminder:
        return isVietnamese ? 'Nhắc nhở: $cleanTitle' : 'Reminder: $cleanTitle';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor(notification.getColorHex());
    final icon = _getIcon(notification.getIconName());

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(inAppNotificationProvider.notifier).deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVietnamese ? 'Đã xóa thông báo' : 'Notification deleted')),
        );
      },
      child: Container(
        color: notification.isRead ? null : Colors.blue.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            _getLocalizedTitle(),
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(notification.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: () {
            if (!notification.isRead) {
              ref.read(inAppNotificationProvider.notifier).markAsRead(notification.id);
            }
            _handleNotificationTap(context, notification);
          },
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'announcement':
        return Icons.campaign;
      case 'assignment':
        return Icons.assignment;
      case 'grade':
        return Icons.grade;
      case 'quiz':
        return Icons.quiz;
      case 'folder':
        return Icons.folder;
      case 'message':
        return Icons.message;
      case 'alarm':
        return Icons.alarm;
      default:
        return Icons.notifications;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return isVietnamese ? 'Vừa xong' : 'Just now';
    } else if (difference.inHours < 1) {
      return isVietnamese ? '${difference.inMinutes} phút trước' : '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return isVietnamese ? '${difference.inHours} giờ trước' : '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return isVietnamese ? '${difference.inDays} ngày trước' : '${difference.inDays}d ago';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  void _handleNotificationTap(BuildContext context, InAppNotification notification) {
    // TODO: Implement navigation based on notification type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isVietnamese
            ? 'Mở ${notification.type.toString().split('.').last}'
            : 'Opening ${notification.type.toString().split('.').last}'),
      ),
    );
  }
}