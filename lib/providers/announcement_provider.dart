// providers/announcement_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/announcement.dart';
import '../models/user.dart';
import '../models/in_app_notification.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';
import 'notification_provider.dart';
import 'in_app_notification_provider.dart';

final announcementProvider = StateNotifierProvider<AnnouncementNotifier, List<Announcement>>((ref) => AnnouncementNotifier(ref));

class AnnouncementNotifier extends StateNotifier<List<Announcement>> {
  final Ref ref;
  
  AnnouncementNotifier(this.ref) : super([]);
  
  bool _isLoading = false;

  Future<void> loadAnnouncements(String courseId) async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      
      // ✅ 1. Try to load from cache first
      final cacheKey = 'announcements_$courseId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Announcement.fromMap(map);
        }).toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        print('📦 Loaded ${state.length} announcements from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshAnnouncementsInBackground(courseId, cacheKey);
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for announcements');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database if online or no cache
      final data = await DatabaseService.find(
        collection: 'announcements',
        filter: {'courseId': courseId},
      );
      
      // ✅ FIX: Convert data with proper ObjectId handling
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Announcement.fromMap(map);
      }).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      
      // ✅ 4. Save to cache (convert ObjectIds to strings for cache)
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('✅ Loaded ${state.length} announcements from database');
    } catch (e, stackTrace) {
      print('loadAnnouncements error: $e');
      print('StackTrace: $stackTrace');
      
      // ✅ 5. On error, try to fallback to cache
      final cacheKey = 'announcements_$courseId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Announcement.fromMap(map);
        }).toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        print('📦 Loaded ${state.length} announcements from cache (fallback)');
      } else {
        state = [];
      }
    } finally {
      _isLoading = false;
    }
  }

  // ✅ Helper: Convert all ObjectId values to strings recursively
  Map<String, dynamic> _convertObjectIds(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIds(item);
          } else if (item is Map) {
            return _convertObjectIds(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIds(value);
      } else if (value is Map) {
        result[key] = _convertObjectIds(Map<String, dynamic>.from(value));
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  // ✅ Background refresh (silent update without blocking UI)
  Future<void> _refreshAnnouncementsInBackground(String courseId, String cacheKey) async {
    try {
      final data = await DatabaseService.find(
        collection: 'announcements',
        filter: {'courseId': courseId},
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Announcement.fromMap(map);
      }).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      
      // Update cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('🔄 Background refresh: announcements updated');
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  Future<void> createAnnouncement({
    required String courseId,
    required String courseName,
    required String title,
    required String content,
    required AnnouncementScope scope,
    required List<String> groupIds,
    required String instructorId,
    required String instructorName,
    required List<AppUser> students,
    List<AnnouncementAttachment> attachments = const [],
  }) async {
    try {
      final now = DateTime.now();
      
      final doc = <String, dynamic>{
        'courseId': courseId,
        'title': title,
        'content': content,
        'attachments': attachments.map((a) {
          final map = a.toMap();
          return <String, dynamic>{
            'fileName': map['fileName'],
            'fileUrl': map['fileUrl'],
            if (map['fileData'] != null) 'fileData': map['fileData'],
            if (map['fileSize'] != null) 'fileSize': map['fileSize'],
            if (map['mimeType'] != null) 'mimeType': map['mimeType'],
            'isLink': map['isLink'] ?? false,
          };
        }).toList(),
        'scope': scope.name,
        'groupIds': groupIds,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'comments': <Map<String, dynamic>>[],
        'viewedBy': <String>[],
        'downloadTracking': <String, String>{},
        'createdAt': now.toIso8601String(),
        'publishedAt': now.toIso8601String(),
        'isPublished': true,
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'announcements',
        document: doc,
      );

      state = [
        Announcement(
          id: insertedId,
          courseId: courseId,
          title: title,
          content: content,
          attachments: attachments,
          scope: scope,
          groupIds: groupIds,
          instructorId: instructorId,
          instructorName: instructorName,
          createdAt: now,
          publishedAt: now,
          isPublished: true,
        ),
        ...state,
      ];
      
      // ✅ Clear cache after creating
      await CacheService.clearCache('announcements_$courseId');
      
      print('✅ Created announcement: $insertedId');
      
      // ✅ SEND EMAIL NOTIFICATIONS
      final studentsToNotify = students.where((s) => s.email.isNotEmpty).toList();
      
      if (studentsToNotify.isNotEmpty) {
        Future.microtask(() {
          ref.read(notificationProvider.notifier).notifyAnnouncement(
            recipients: studentsToNotify,
            courseName: courseName,
            announcementTitle: title,
            announcementContent: content,
          );
        });
      }

      // ✅ CREATE IN-APP NOTIFICATIONS
      final studentUserIds = students.map((s) => s.id).toList();
      if (studentUserIds.isNotEmpty) {
        final notificationBody = content.length > 100 
            ? '${content.substring(0, 100)}...' 
            : content;

        await ref.read(inAppNotificationProvider.notifier).createBatchNotifications(
          userIds: studentUserIds,
          title: 'Thông báo mới: $title',
          body: notificationBody,
          type: InAppNotificationType.announcement,
          relatedId: insertedId,
          courseId: courseId,
          courseName: courseName,
        );
        print('✅ Created ${studentUserIds.length} in-app notifications for announcement');
      }
    } catch (e, stackTrace) {
      print('createAnnouncement error: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // ✅ FIXED: Keep original 4 parameters (announcementId, userId, userName, content)
  Future<void> addComment(String announcementId, String userId, String userName, String content) async {
    try {
      final announcement = state.firstWhere((a) => a.id == announcementId);
      
      final comment = AnnouncementComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: userName,
        content: content,
        createdAt: DateTime.now(),
      );

      final updatedComments = [...announcement.comments, comment];

      await DatabaseService.updateOne(
        collection: 'announcements',
        id: announcementId,
        update: {
          'comments': updatedComments.map((c) {
            final map = c.toMap();
            return <String, dynamic>{
              'id': map['id'],
              'userId': map['userId'],
              'userName': map['userName'],
              'content': map['content'],
              'createdAt': map['createdAt'],
            };
          }).toList(),
        },
      );

      state = state.map((a) {
        if (a.id == announcementId) {
          return Announcement(
            id: a.id,
            courseId: a.courseId,
            title: a.title,
            content: a.content,
            attachments: a.attachments,
            scope: a.scope,
            groupIds: a.groupIds,
            instructorId: a.instructorId,
            instructorName: a.instructorName,
            comments: updatedComments,
            viewedBy: a.viewedBy,
            downloadTracking: a.downloadTracking,
            createdAt: a.createdAt,
            publishedAt: a.publishedAt,
            isPublished: a.isPublished,
          );
        }
        return a;
      }).toList();
      
      // ✅ Clear cache after updating
      await CacheService.clearCache('announcements_${announcement.courseId}');
    } catch (e) {
      print('addComment error: $e');
      rethrow;
    }
  }

  Future<void> markAsViewed(String announcementId, String userId) async {
    try {
      final announcement = state.firstWhere((a) => a.id == announcementId);
      if (announcement.viewedBy.contains(userId)) return;

      final updatedViewedBy = [...announcement.viewedBy, userId];

      await DatabaseService.updateOne(
        collection: 'announcements',
        id: announcementId,
        update: {'viewedBy': updatedViewedBy},
      );

      state = state.map((a) {
        if (a.id == announcementId) {
          return Announcement(
            id: a.id,
            courseId: a.courseId,
            title: a.title,
            content: a.content,
            attachments: a.attachments,
            scope: a.scope,
            groupIds: a.groupIds,
            instructorId: a.instructorId,
            instructorName: a.instructorName,
            comments: a.comments,
            viewedBy: updatedViewedBy,
            downloadTracking: a.downloadTracking,
            createdAt: a.createdAt,
            publishedAt: a.publishedAt,
            isPublished: a.isPublished,
          );
        }
        return a;
      }).toList();
      
      // ✅ Clear cache after updating
      await CacheService.clearCache('announcements_${announcement.courseId}');
    } catch (e) {
      print('markAsViewed error: $e');
      rethrow;
    }
  }

  Future<void> trackDownload(String announcementId, String userId, String fileName) async {
    try {
      final announcement = state.firstWhere((a) => a.id == announcementId);
      final updatedTracking = Map<String, DateTime>.from(announcement.downloadTracking);
      updatedTracking['$userId:$fileName'] = DateTime.now();

      await DatabaseService.updateOne(
        collection: 'announcements',
        id: announcementId,
        update: {
          'downloadTracking': updatedTracking.map(
            (key, value) => MapEntry(key, value.toIso8601String()),
          ),
        },
      );

      state = state.map((a) {
        if (a.id == announcementId) {
          return Announcement(
            id: a.id,
            courseId: a.courseId,
            title: a.title,
            content: a.content,
            attachments: a.attachments,
            scope: a.scope,
            groupIds: a.groupIds,
            instructorId: a.instructorId,
            instructorName: a.instructorName,
            comments: a.comments,
            viewedBy: a.viewedBy,
            downloadTracking: updatedTracking,
            createdAt: a.createdAt,
            publishedAt: a.publishedAt,
            isPublished: a.isPublished,
          );
        }
        return a;
      }).toList();
      
      // ✅ Clear cache after updating
      await CacheService.clearCache('announcements_${announcement.courseId}');
    } catch (e) {
      print('trackDownload error: $e');
      rethrow;
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      final announcement = state.firstWhere((a) => a.id == id);
      final courseId = announcement.courseId;
      
      await DatabaseService.deleteOne(collection: 'announcements', id: id);
      state = state.where((a) => a.id != id).toList();
      
      // ✅ Clear cache after deleting
      await CacheService.clearCache('announcements_$courseId');
    } catch (e) {
      print('deleteAnnouncement error: $e');
    }
  }
  
  // ✅ Force refresh from database
  Future<void> forceRefresh(String courseId) async {
    await CacheService.clearCache('announcements_$courseId');
    _isLoading = false;
    await loadAnnouncements(courseId);
  }
}