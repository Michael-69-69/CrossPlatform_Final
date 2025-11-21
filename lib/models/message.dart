// models/message.dart
import 'package:mongo_dart/mongo_dart.dart';

/// Represents a conversation between instructor and student
class Conversation {
  final String id;
  final String instructorId;
  final String instructorName;
  final String studentId;
  final String studentName;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCountInstructor; // Unread messages for instructor
  final int unreadCountStudent; // Unread messages for student
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.instructorId,
    required this.instructorName,
    required this.studentId,
    required this.studentName,
    this.lastMessageContent,
    this.lastMessageAt,
    this.unreadCountInstructor = 0,
    this.unreadCountStudent = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'instructorId': instructorId,
        'instructorName': instructorName,
        'studentId': studentId,
        'studentName': studentName,
        if (lastMessageContent != null) 'lastMessageContent': lastMessageContent,
        if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toIso8601String(),
        'unreadCountInstructor': unreadCountInstructor,
        'unreadCountStudent': unreadCountStudent,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Conversation.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final instructorId = map['instructorId'] is ObjectId
        ? map['instructorId'].toHexString()
        : map['instructorId']?.toString() ?? '';

    final studentId = map['studentId'] is ObjectId
        ? map['studentId'].toHexString()
        : map['studentId']?.toString() ?? '';

    return Conversation(
      id: id,
      instructorId: instructorId,
      instructorName: map['instructorName'] ?? '',
      studentId: studentId,
      studentName: map['studentName'] ?? '',
      lastMessageContent: map['lastMessageContent'],
      lastMessageAt: map['lastMessageAt'] != null
          ? DateTime.parse(map['lastMessageAt'])
          : null,
      unreadCountInstructor: map['unreadCountInstructor'] ?? 0,
      unreadCountStudent: map['unreadCountStudent'] ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }
}

/// Represents a single message in a conversation
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final bool isInstructor; // True if sender is instructor
  final String content;
  final List<MessageAttachment> attachments;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.isInstructor,
    required this.content,
    this.attachments = const [],
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'isInstructor': isInstructor,
        'content': content,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Message.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final conversationId = map['conversationId'] is ObjectId
        ? map['conversationId'].toHexString()
        : map['conversationId']?.toString() ?? '';

    final senderId = map['senderId'] is ObjectId
        ? map['senderId'].toHexString()
        : map['senderId']?.toString() ?? '';

    final rawAttachments = map['attachments'] as List? ?? [];
    final attachments = rawAttachments
        .map((e) => MessageAttachment.fromMap(e as Map<String, dynamic>))
        .toList();

    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: map['senderName'] ?? '',
      isInstructor: map['isInstructor'] ?? false,
      content: map['content'] ?? '',
      attachments: attachments,
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}

/// Message attachment (file or link)
class MessageAttachment {
  final String fileName;
  final String? fileUrl;
  final String? fileData; // Base64 data
  final int? fileSize;
  final String? mimeType;
  final bool isLink;

  MessageAttachment({
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

  factory MessageAttachment.fromMap(Map<String, dynamic> map) {
    return MessageAttachment(
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'],
      fileData: map['fileData'],
      fileSize: map['fileSize'],
      mimeType: map['mimeType'],
      isLink: map['isLink'] ?? false,
    );
  }
}