// providers/announcement_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement.dart';
import '../services/database_service.dart';

final announcementProvider = StateNotifierProvider<AnnouncementNotifier, List<Announcement>>((ref) => AnnouncementNotifier());

class AnnouncementNotifier extends StateNotifier<List<Announcement>> {
  AnnouncementNotifier() : super([]);

  Future<void> loadAnnouncements(String courseId) async {
    try {
      final data = await DatabaseService.find(
        collection: 'announcements',
        filter: {'courseId': courseId},
      );
      state = data.map(Announcement.fromMap).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    } catch (e) {
      print('loadAnnouncements error: $e');
      state = [];
    }
  }

  Future<void> createAnnouncement({
    required String courseId,
    required String title,
    required String content,
    required AnnouncementScope scope,
    required List<String> groupIds,
    required String instructorId,
    required String instructorName,
    List<AnnouncementAttachment> attachments = const [],
  }) async {
    try {
      final now = DateTime.now();
      
      final doc = {
        'courseId': courseId,
        'title': title,
        'content': content,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'scope': scope.name,
        'groupIds': groupIds,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'comments': [],
        'viewedBy': [],
        'downloadTracking': {},
        'createdAt': now.toIso8601String(),
        'publishedAt': now.toIso8601String(),
        'isPublished': true,
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'announcements',
        document: doc,
      );

      // Add to state
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
    } catch (e) {
      print('createAnnouncement error: $e');
      rethrow;
    }
  }

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
          'comments': updatedComments.map((c) => c.toMap()).toList(),
        },
      );

      // Update local state
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
    } catch (e) {
      print('addComment error: $e');
      rethrow;
    }
  }

  Future<void> markAsViewed(String announcementId, String userId) async {
    try {
      final announcement = state.firstWhere((a) => a.id == announcementId);
      if (announcement.viewedBy.contains(userId)) {
        return; // Already viewed
      }

      final updatedViewedBy = [...announcement.viewedBy, userId];

      await DatabaseService.updateOne(
        collection: 'announcements',
        id: announcementId,
        update: {
          'viewedBy': updatedViewedBy,
        },
      );

      // Update local state
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

      // Update local state
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
    } catch (e) {
      print('trackDownload error: $e');
      rethrow;
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'announcements',
        id: id,
      );
      state = state.where((a) => a.id != id).toList();
    } catch (e) {
      print('deleteAnnouncement error: $e');
    }
  }
}