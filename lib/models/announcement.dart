// models/announcement.dart
import 'package:mongo_dart/mongo_dart.dart';

enum AnnouncementScope {
  oneGroup,
  multipleGroups,
  allGroups,
}

class AnnouncementAttachment {
  final String fileName;
  final String fileUrl;
  final int fileSize; // in bytes
  final String mimeType;

  AnnouncementAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
  });

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'fileUrl': fileUrl,
        'fileSize': fileSize,
        'mimeType': mimeType,
      };

  factory AnnouncementAttachment.fromMap(Map<String, dynamic> map) {
    return AnnouncementAttachment(
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      mimeType: map['mimeType'] ?? '',
    );
  }
}

class AnnouncementComment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  AnnouncementComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AnnouncementComment.fromMap(Map<String, dynamic> map) {
    return AnnouncementComment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class Announcement {
  final String id;
  final String courseId;
  final String title;
  final String content; // Rich text content
  final List<AnnouncementAttachment> attachments;
  final AnnouncementScope scope;
  final List<String> groupIds; // Empty if scope is allGroups
  final String instructorId;
  final String instructorName;
  final List<AnnouncementComment> comments;
  final List<String> viewedBy; // User IDs who viewed
  final Map<String, DateTime> downloadTracking; // userId -> download timestamp
  final DateTime createdAt;
  final DateTime publishedAt;
  final bool isPublished;

  Announcement({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    this.attachments = const [],
    required this.scope,
    this.groupIds = const [],
    required this.instructorId,
    required this.instructorName,
    this.comments = const [],
    this.viewedBy = const [],
    this.downloadTracking = const {},
    required this.createdAt,
    required this.publishedAt,
    this.isPublished = false,
  });

  Map<String, dynamic> toMap() => {
        'courseId': ObjectId.fromHexString(courseId),
        'title': title,
        'content': content,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'scope': scope.name,
        'groupIds': groupIds.map((id) => ObjectId.fromHexString(id)).toList(),
        'instructorId': ObjectId.fromHexString(instructorId),
        'instructorName': instructorName,
        'comments': comments.map((c) => c.toMap()).toList(),
        'viewedBy': viewedBy.map((id) => ObjectId.fromHexString(id)).toList(),
        'downloadTracking': downloadTracking.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
        'createdAt': createdAt.toIso8601String(),
        'publishedAt': publishedAt.toIso8601String(),
        'isPublished': isPublished,
      };

  factory Announcement.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final courseId = map['courseId'] is ObjectId
        ? map['courseId'].toHexString()
        : map['courseId']?.toString() ?? '';

    final instructorId = map['instructorId'] is ObjectId
        ? map['instructorId'].toHexString()
        : map['instructorId']?.toString() ?? '';

    final rawGroupIds = map['groupIds'] as List? ?? [];
    final groupIds = rawGroupIds
        .map((e) => e is ObjectId ? e.toHexString() : e.toString())
        .toList();

    final rawAttachments = map['attachments'] as List? ?? [];
    final attachments = rawAttachments
        .map((e) => AnnouncementAttachment.fromMap(e as Map<String, dynamic>))
        .toList();

    final rawComments = map['comments'] as List? ?? [];
    final comments = rawComments
        .map((e) => AnnouncementComment.fromMap(e as Map<String, dynamic>))
        .toList();

    final rawViewedBy = map['viewedBy'] as List? ?? [];
    final viewedBy = rawViewedBy
        .map((e) => e is ObjectId ? e.toHexString() : e.toString())
        .toList();

    final rawDownloadTracking = map['downloadTracking'] as Map? ?? {};
    final downloadTracking = rawDownloadTracking.map(
      (key, value) => MapEntry(
        key.toString(),
        DateTime.parse(value.toString()),
      ),
    );

    return Announcement(
      id: id,
      courseId: courseId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      attachments: attachments,
      scope: AnnouncementScope.values.firstWhere(
        (e) => e.name == map['scope'],
        orElse: () => AnnouncementScope.allGroups,
      ),
      groupIds: groupIds,
      instructorId: instructorId,
      instructorName: map['instructorName'] ?? '',
      comments: comments,
      viewedBy: viewedBy,
      downloadTracking: downloadTracking,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      publishedAt: DateTime.parse(map['publishedAt'] ?? DateTime.now().toIso8601String()),
      isPublished: map['isPublished'] ?? false,
    );
  }
}

