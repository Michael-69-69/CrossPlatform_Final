// providers/announcement_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/announcement.dart';
import '../services/mongodb_service.dart';

final announcementProvider = StateNotifierProvider<AnnouncementNotifier, List<Announcement>>((ref) => AnnouncementNotifier());

class AnnouncementNotifier extends StateNotifier<List<Announcement>> {
  AnnouncementNotifier() : super([]);

  Future<void> loadAnnouncements(String courseId) async {
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('announcements');
      final oid = ObjectId.fromHexString(courseId);
      final data = await col.find(where.eq('courseId', oid)).toList();
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
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('announcements');
      final now = DateTime.now();
      
      final announcement = Announcement(
        id: '',
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
      );

      final result = await col.insertOne(announcement.toMap());
      final insertedId = result.id as ObjectId;

      state = [
        Announcement(
          id: insertedId.toHexString(),
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
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('announcements');
      final oid = ObjectId.fromHexString(announcementId);
      
      final comment = AnnouncementComment(
        id: ObjectId().toHexString(),
        userId: userId,
        userName: userName,
        content: content,
        createdAt: DateTime.now(),
      );

      await col.updateOne(
        where.id(oid),
        modify.push('comments', comment.toMap()),
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
            comments: [...a.comments, comment],
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
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('announcements');
      final oid = ObjectId.fromHexString(announcementId);
      final userOid = ObjectId.fromHexString(userId);

      final announcement = state.firstWhere((a) => a.id == announcementId);
      if (announcement.viewedBy.contains(userId)) {
        return; // Already viewed
      }

      await col.updateOne(
        where.id(oid),
        modify.push('viewedBy', userOid),
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
            viewedBy: [...a.viewedBy, userId],
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
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('announcements');
      final oid = ObjectId.fromHexString(announcementId);

      final announcement = state.firstWhere((a) => a.id == announcementId);
      final updatedTracking = Map<String, DateTime>.from(announcement.downloadTracking);
      updatedTracking['$userId:$fileName'] = DateTime.now();

      await col.updateOne(
        where.id(oid),
        modify.set('downloadTracking', updatedTracking.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        )),
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
    } catch (e) {
      print('trackDownload error: $e');
      rethrow;
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    final oid = _oid(id);
    if (oid == null) return;
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('announcements');
      await col.deleteOne(where.id(oid));
      state = state.where((a) => a.id != id).toList();
    } catch (e) {
      print('deleteAnnouncement error: $e');
    }
  }

  ObjectId? _oid(String id) => id.length == 24 ? ObjectId.fromHexString(id) : null;
}

