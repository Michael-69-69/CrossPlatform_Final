// models/assignment.dart
import 'package:mongo_dart/mongo_dart.dart';

enum AssignmentStatus {
  notStarted,
  inProgress,
  submitted,
  late,
  graded,
}

class AssignmentAttachment {
  final String fileName;
  final String fileUrl;
  final int fileSize; // in bytes
  final String mimeType;

  AssignmentAttachment({
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

  factory AssignmentAttachment.fromMap(Map<String, dynamic> map) {
    return AssignmentAttachment(
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      mimeType: map['mimeType'] ?? '',
    );
  }
}

class AssignmentSubmission {
  final String id;
  final String studentId;
  final String studentName;
  final String groupId;
  final String groupName;
  final List<AssignmentAttachment> files;
  final DateTime submittedAt;
  final int attemptNumber;
  final double? grade;
  final String? feedback;
  final bool isLate;

  AssignmentSubmission({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.groupId,
    required this.groupName,
    this.files = const [],
    required this.submittedAt,
    required this.attemptNumber,
    this.grade,
    this.feedback,
    this.isLate = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'groupId': groupId,
        'groupName': groupName,
        'files': files.map((f) => f.toMap()).toList(),
        'submittedAt': submittedAt.toIso8601String(),
        'attemptNumber': attemptNumber,
        'grade': grade,
        'feedback': feedback,
        'isLate': isLate,
      };

  // ✅ FIXED: Handle ObjectId for all ID fields
  factory AssignmentSubmission.fromMap(Map<String, dynamic> map) {
    final rawFiles = map['files'] as List? ?? [];
    final files = rawFiles
        .map((e) => AssignmentAttachment.fromMap(e as Map<String, dynamic>))
        .toList();

    // ✅ FIX: Handle ObjectId conversion for id
    final id = map['id'] is ObjectId
        ? (map['id'] as ObjectId).toHexString()
        : map['id']?.toString() ?? '';

    // ✅ FIX: Handle ObjectId conversion for studentId
    final studentId = map['studentId'] is ObjectId
        ? (map['studentId'] as ObjectId).toHexString()
        : map['studentId']?.toString() ?? '';

    // ✅ FIX: Handle ObjectId conversion for groupId
    final groupId = map['groupId'] is ObjectId
        ? (map['groupId'] as ObjectId).toHexString()
        : map['groupId']?.toString() ?? '';

    return AssignmentSubmission(
      id: id,
      studentId: studentId,
      studentName: map['studentName']?.toString() ?? '',
      groupId: groupId,
      groupName: map['groupName']?.toString() ?? '',
      files: files,
      submittedAt: DateTime.parse(map['submittedAt'] ?? DateTime.now().toIso8601String()),
      attemptNumber: map['attemptNumber'] ?? 1,
      grade: map['grade']?.toDouble(),
      feedback: map['feedback']?.toString(),
      isLate: map['isLate'] ?? false,
    );
  }
}

class Assignment {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final List<AssignmentAttachment> attachments;
  final DateTime startDate;
  final DateTime deadline;
  final bool allowLateSubmission;
  final DateTime? lateDeadline;
  final int maxAttempts;
  final List<String> allowedFileFormats; // e.g., ['pdf', 'doc', 'docx']
  final int maxFileSize; // in bytes
  final List<String> groupIds; // Empty means all groups
  final String instructorId;
  final String instructorName;
  final List<AssignmentSubmission> submissions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    this.attachments = const [],
    required this.startDate,
    required this.deadline,
    this.allowLateSubmission = false,
    this.lateDeadline,
    this.maxAttempts = 1,
    this.allowedFileFormats = const [],
    this.maxFileSize = 10485760, // 10MB default
    this.groupIds = const [],
    required this.instructorId,
    required this.instructorName,
    this.submissions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'courseId': ObjectId.fromHexString(courseId),
        'title': title,
        'description': description,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'startDate': startDate.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'allowLateSubmission': allowLateSubmission,
        'lateDeadline': lateDeadline?.toIso8601String(),
        'maxAttempts': maxAttempts,
        'allowedFileFormats': allowedFileFormats,
        'maxFileSize': maxFileSize,
        'groupIds': groupIds.map((id) => ObjectId.fromHexString(id)).toList(),
        'instructorId': ObjectId.fromHexString(instructorId),
        'instructorName': instructorName,
        'submissions': submissions.map((s) => s.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Assignment.fromMap(Map<String, dynamic> map) {
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
        .map((e) => AssignmentAttachment.fromMap(e as Map<String, dynamic>))
        .toList();

    final rawSubmissions = map['submissions'] as List? ?? [];
    final submissions = rawSubmissions
        .map((e) => AssignmentSubmission.fromMap(e as Map<String, dynamic>))
        .toList();

    return Assignment(
      id: id,
      courseId: courseId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      attachments: attachments,
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      deadline: DateTime.parse(map['deadline'] ?? DateTime.now().toIso8601String()),
      allowLateSubmission: map['allowLateSubmission'] ?? false,
      lateDeadline: map['lateDeadline'] != null
          ? DateTime.parse(map['lateDeadline'])
          : null,
      maxAttempts: map['maxAttempts'] ?? 1,
      allowedFileFormats: List<String>.from(map['allowedFileFormats'] ?? []),
      maxFileSize: map['maxFileSize'] ?? 10485760,
      groupIds: groupIds,
      instructorId: instructorId,
      instructorName: map['instructorName'] ?? '',
      submissions: submissions,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Helper methods
  AssignmentStatus getStatusForStudent(String studentId, String? groupId) {
    final studentSubmissions = submissions.where((s) => s.studentId == studentId).toList();
    
    if (studentSubmissions.isEmpty) {
      if (DateTime.now().isBefore(startDate)) {
        return AssignmentStatus.notStarted;
      }
      if (DateTime.now().isAfter(deadline) && (!allowLateSubmission || (lateDeadline != null && DateTime.now().isAfter(lateDeadline!)))) {
        return AssignmentStatus.late;
      }
      return AssignmentStatus.inProgress;
    }

    final latestSubmission = studentSubmissions.reduce(
      (a, b) => a.submittedAt.isAfter(b.submittedAt) ? a : b,
    );

    if (latestSubmission.grade != null) {
      return AssignmentStatus.graded;
    }

    if (latestSubmission.isLate) {
      return AssignmentStatus.late;
    }

    return AssignmentStatus.submitted;
  }

  int getAttemptCountForStudent(String studentId) {
    return submissions.where((s) => s.studentId == studentId).length;
  }
}