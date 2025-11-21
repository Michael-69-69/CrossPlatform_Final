// models/forum.dart
import 'package:mongo_dart/mongo_dart.dart';

class ForumTopic {
  final String id;
  final String courseId;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final bool isInstructor;
  final List<ForumAttachment> attachments;
  final List<String> tags;
  final bool isPinned;
  final bool isClosed;
  final int replyCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastReplyAt;

  ForumTopic({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.isInstructor,
    this.attachments = const [],
    this.tags = const [],
    this.isPinned = false,
    this.isClosed = false,
    this.replyCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.lastReplyAt,
  });

  Map<String, dynamic> toMap() => {
        'courseId': ObjectId.fromHexString(courseId),
        'title': title,
        'content': content,
        'authorId': ObjectId.fromHexString(authorId),
        'authorName': authorName,
        'isInstructor': isInstructor,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'tags': tags,
        'isPinned': isPinned,
        'isClosed': isClosed,
        'replyCount': replyCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (lastReplyAt != null) 'lastReplyAt': lastReplyAt!.toIso8601String(),
      };

  factory ForumTopic.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final courseId = map['courseId'] is ObjectId
        ? map['courseId'].toHexString()
        : map['courseId']?.toString() ?? '';

    final authorId = map['authorId'] is ObjectId
        ? map['authorId'].toHexString()
        : map['authorId']?.toString() ?? '';

    final rawAttachments = map['attachments'] as List? ?? [];
    final attachments = rawAttachments
        .map((e) => ForumAttachment.fromMap(e as Map<String, dynamic>))
        .toList();

    final rawTags = map['tags'] as List? ?? [];
    final tags = rawTags.map((e) => e.toString()).toList();

    return ForumTopic(
      id: id,
      courseId: courseId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: authorId,
      authorName: map['authorName'] ?? '',
      isInstructor: map['isInstructor'] ?? false,
      attachments: attachments,
      tags: tags,
      isPinned: map['isPinned'] ?? false,
      isClosed: map['isClosed'] ?? false,
      replyCount: map['replyCount'] ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      lastReplyAt: map['lastReplyAt'] != null
          ? DateTime.parse(map['lastReplyAt'])
          : null,
    );
  }
}

class ForumReply {
  final String id;
  final String topicId;
  final String content;
  final String authorId;
  final String authorName;
  final bool isInstructor;
  final List<ForumAttachment> attachments;
  final String? parentReplyId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ForumReply({
    required this.id,
    required this.topicId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.isInstructor,
    this.attachments = const [],
    this.parentReplyId,
    required this.createdAt,
    required this.updatedAt,
  });

  // ✅ FIXED: Store topicId as string, not ObjectId
  Map<String, dynamic> toMap() => {
        'topicId': topicId, // ✅ Changed from ObjectId.fromHexString(topicId)
        'content': content,
        'authorId': authorId, // ✅ Changed from ObjectId.fromHexString(authorId)
        'authorName': authorName,
        'isInstructor': isInstructor,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        if (parentReplyId != null) 'parentReplyId': parentReplyId, // ✅ Changed from ObjectId
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ForumReply.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    // ✅ Handle both ObjectId and String for topicId
    final topicId = map['topicId'] is ObjectId
        ? map['topicId'].toHexString()
        : map['topicId']?.toString() ?? '';

    // ✅ Handle both ObjectId and String for authorId
    final authorId = map['authorId'] is ObjectId
        ? map['authorId'].toHexString()
        : map['authorId']?.toString() ?? '';

    // ✅ Handle both ObjectId and String for parentReplyId
    final parentReplyId = map['parentReplyId'] != null
        ? (map['parentReplyId'] is ObjectId
            ? map['parentReplyId'].toHexString()
            : map['parentReplyId'].toString())
        : null;

    final rawAttachments = map['attachments'] as List? ?? [];
    final attachments = rawAttachments
        .map((e) => ForumAttachment.fromMap(e as Map<String, dynamic>))
        .toList();

    return ForumReply(
      id: id,
      topicId: topicId,
      content: map['content'] ?? '',
      authorId: authorId,
      authorName: map['authorName'] ?? '',
      isInstructor: map['isInstructor'] ?? false,
      attachments: attachments,
      parentReplyId: parentReplyId,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }
}

class ForumAttachment {
  final String fileName;
  final String? fileUrl;
  final String? fileData;
  final int? fileSize;
  final String? mimeType;
  final bool isLink;

  ForumAttachment({
    required this.fileName,
    this.fileUrl,
    this.fileData,
    this.fileSize,
    this.mimeType,
    this.isLink = false,
  });

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileData != null) 'fileData': fileData,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        'isLink': isLink,
      };

  factory ForumAttachment.fromMap(Map<String, dynamic> map) {
    return ForumAttachment(
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'],
      fileData: map['fileData'],
      fileSize: map['fileSize'],
      mimeType: map['mimeType'],
      isLink: map['isLink'] ?? false,
    );
  }
}