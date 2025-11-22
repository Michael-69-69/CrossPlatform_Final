// models/in_app_notification.dart

enum InAppNotificationType {
  announcement,
  assignment,
  assignmentGraded,
  quiz,
  material,
  message,
  deadlineReminder,
}

class InAppNotification {
  final String id;
  final String userId; // Student who receives this
  final String title;
  final String body;
  final InAppNotificationType type;
  final bool isRead;
  final DateTime createdAt;
  
  // Optional metadata for navigation
  final String? relatedId; // ID of assignment/quiz/announcement
  final String? courseId;
  final String? courseName;

  InAppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.relatedId,
    this.courseId,
    this.courseName,
  });

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: InAppNotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => InAppNotificationType.announcement,
      ),
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : json['createdAt'] as DateTime,
      relatedId: json['relatedId'] as String?,
      courseId: json['courseId'] as String?,
      courseName: json['courseName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'relatedId': relatedId,
      'courseId': courseId,
      'courseName': courseName,
    };
  }

  InAppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    InAppNotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    String? relatedId,
    String? courseId,
    String? courseName,
  }) {
    return InAppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      relatedId: relatedId ?? this.relatedId,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
    );
  }

  // Helper to get icon based on type
  String getIconName() {
    switch (type) {
      case InAppNotificationType.announcement:
        return 'announcement';
      case InAppNotificationType.assignment:
        return 'assignment';
      case InAppNotificationType.assignmentGraded:
        return 'grade';
      case InAppNotificationType.quiz:
        return 'quiz';
      case InAppNotificationType.material:
        return 'folder';
      case InAppNotificationType.message:
        return 'message';
      case InAppNotificationType.deadlineReminder:
        return 'alarm';
    }
  }

  // Helper to get color based on type
  String getColorHex() {
    switch (type) {
      case InAppNotificationType.announcement:
        return '#2196F3'; // Blue
      case InAppNotificationType.assignment:
        return '#FF9800'; // Orange
      case InAppNotificationType.assignmentGraded:
        return '#4CAF50'; // Green
      case InAppNotificationType.quiz:
        return '#9C27B0'; // Purple
      case InAppNotificationType.material:
        return '#607D8B'; // Blue Grey
      case InAppNotificationType.message:
        return '#00BCD4'; // Cyan
      case InAppNotificationType.deadlineReminder:
        return '#F44336'; // Red
    }
  }
}