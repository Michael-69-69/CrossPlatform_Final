// models/material.dart
import 'package:mongo_dart/mongo_dart.dart';

class Material {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final List<MaterialAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Material({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Material.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId ? map['_id'].toHexString() : map['_id'].toString();
    final courseId = map['courseId'] is ObjectId
        ? map['courseId'].toHexString()
        : map['courseId'].toString();

    final rawAttachments = map['attachments'] as List? ?? [];
    final attachments = rawAttachments
        .map((e) => MaterialAttachment.fromMap(e as Map<String, dynamic>))
        .toList();

    return Material(
      id: id,
      courseId: courseId,
      title: map['title'] ?? '',
      description: map['description'],
      attachments: attachments,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        '_id': ObjectId.fromHexString(id),
        'courseId': ObjectId.fromHexString(courseId),
        'title': title,
        if (description != null) 'description': description,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Material copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    List<MaterialAttachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Material(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MaterialAttachment {
  final String fileName;
  final String? fileUrl;        // For external URLs
  final String? fileData;       // ✅ NEW: For Base64 encoded files
  final int? fileSize;
  final String? mimeType;
  final bool isLink;

  MaterialAttachment({
    required this.fileName,
    this.fileUrl,
    this.fileData,               // ✅ NEW
    this.fileSize,
    this.mimeType,
    this.isLink = false,
  });

  factory MaterialAttachment.fromMap(Map<String, dynamic> map) {
    return MaterialAttachment(
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'],
      fileData: map['fileData'],  // ✅ NEW
      fileSize: map['fileSize'],
      mimeType: map['mimeType'],
      isLink: map['isLink'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileData != null) 'fileData': fileData,  // ✅ NEW
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        'isLink': isLink,
      };
}

class MaterialView {
  final String id;
  final String materialId;
  final String studentId;
  final DateTime viewedAt;
  final bool downloaded;

  MaterialView({
    required this.id,
    required this.materialId,
    required this.studentId,
    required this.viewedAt,
    this.downloaded = false,
  });

  factory MaterialView.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId ? map['_id'].toHexString() : map['_id'].toString();
    final materialId = map['materialId'] is ObjectId
        ? map['materialId'].toHexString()
        : map['materialId'].toString();
    final studentId = map['studentId'] is ObjectId
        ? map['studentId'].toHexString()
        : map['studentId'].toString();

    return MaterialView(
      id: id,
      materialId: materialId,
      studentId: studentId,
      viewedAt: map['viewedAt'] != null
          ? DateTime.parse(map['viewedAt'])
          : DateTime.now(),
      downloaded: map['downloaded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        '_id': ObjectId.fromHexString(id),
        'materialId': ObjectId.fromHexString(materialId),
        'studentId': ObjectId.fromHexString(studentId),
        'viewedAt': viewedAt.toIso8601String(),
        'downloaded': downloaded,
      };
}