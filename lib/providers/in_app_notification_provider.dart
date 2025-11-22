// providers/in_app_notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/in_app_notification.dart';
import '../services/database_service.dart';

class InAppNotificationNotifier extends StateNotifier<List<InAppNotification>> {
  InAppNotificationNotifier() : super([]);

  // Load notifications for a user
  Future<void> loadNotifications(String userId) async {
    try {
      final results = await DatabaseService.find(
        collection: 'in_app_notifications',
        filter: {'userId': userId},
        sort: {'createdAt': -1},
      );

      state = results
          .map((doc) {
            // ✅ FIX: Handle ObjectId conversion properly
            final userIdValue = doc['userId'];
            final relatedIdValue = doc['relatedId'];
            final courseIdValue = doc['courseId'];
            
            return InAppNotification.fromJson({
              'id': doc['_id'] is ObjectId 
                  ? (doc['_id'] as ObjectId).toHexString() 
                  : doc['_id'].toString(),
              'userId': userIdValue is ObjectId 
                  ? userIdValue.toHexString() 
                  : userIdValue.toString(),
              'title': doc['title'],
              'body': doc['body'],
              'type': doc['type'],
              'isRead': doc['isRead'] ?? false,
              'createdAt': doc['createdAt'],
              'relatedId': relatedIdValue is ObjectId 
                  ? relatedIdValue.toHexString() 
                  : relatedIdValue?.toString(),
              'courseId': courseIdValue is ObjectId 
                  ? courseIdValue.toHexString() 
                  : courseIdValue?.toString(),
              'courseName': doc['courseName'],
            });
          })
          .toList();

      print('✅ Loaded ${state.length} in-app notifications for user $userId');
    } catch (e, stackTrace) {
      print('❌ Error loading in-app notifications: $e');
      print('Stack trace: $stackTrace');
      state = [];
    }
  }

  // Create a new notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required InAppNotificationType type,
    String? relatedId,
    String? courseId,
    String? courseName,
  }) async {
    try {
      final notification = {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type.toString().split('.').last,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        'relatedId': relatedId,
        'courseId': courseId,
        'courseName': courseName,
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'in_app_notifications',
        document: notification,
      );

      final newNotification = InAppNotification(
        id: insertedId,
        userId: userId,
        title: title,
        body: body,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
        relatedId: relatedId,
        courseId: courseId,
        courseName: courseName,
      );

      state = [newNotification, ...state];
      print('✅ Created in-app notification for user $userId: $title');
    } catch (e) {
      print('❌ Error creating in-app notification: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await DatabaseService.updateOne(
        collection: 'in_app_notifications',
        id: notificationId,
        update: {'isRead': true},
      );

      state = state.map((notification) {
        if (notification.id == notificationId) {
          return notification.copyWith(isRead: true);
        }
        return notification;
      }).toList();

      print('✅ Marked in-app notification as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all as read
  Future<void> markAllAsRead(String userId) async {
    try {
      // Update all unread notifications for this user
      final unreadNotifications = state.where((n) => !n.isRead && n.userId == userId);
      
      for (var notification in unreadNotifications) {
        await DatabaseService.updateOne(
          collection: 'in_app_notifications',
          id: notification.id,
          update: {'isRead': true},
        );
      }

      state = state.map((notification) {
        if (notification.userId == userId) {
          return notification.copyWith(isRead: true);
        }
        return notification;
      }).toList();

      print('✅ Marked all in-app notifications as read for user $userId');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'in_app_notifications',
        id: notificationId,
      );

      state = state.where((n) => n.id != notificationId).toList();
      print('✅ Deleted in-app notification: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  // Get unread count
  int getUnreadCount() {
    return state.where((n) => !n.isRead).length;
  }

  // Batch create notifications for multiple users
  Future<void> createBatchNotifications({
    required List<String> userIds,
    required String title,
    required String body,
    required InAppNotificationType type,
    String? relatedId,
    String? courseId,
    String? courseName,
  }) async {
    try {
      final notifications = userIds.map((userId) => {
            'userId': userId,
            'title': title,
            'body': body,
            'type': type.toString().split('.').last,
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
            'relatedId': relatedId,
            'courseId': courseId,
            'courseName': courseName,
          }).toList();

      await DatabaseService.insertMany(
        collection: 'in_app_notifications',
        documents: notifications,
      );
      
      print('✅ Created ${notifications.length} batch in-app notifications');
    } catch (e) {
      print('❌ Error creating batch notifications: $e');
    }
  }
}

final inAppNotificationProvider =
    StateNotifierProvider<InAppNotificationNotifier, List<InAppNotification>>(
  (ref) => InAppNotificationNotifier(),
);