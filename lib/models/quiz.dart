// models/quiz.dart
import 'package:mongo_dart/mongo_dart.dart';
import 'question.dart';

class Quiz {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final DateTime openTime;
  final DateTime closeTime;
  final int maxAttempts;
  final int durationMinutes;
  final int? easyCount;
  final int? mediumCount;
  final int? hardCount;
  final List<String> questionIds; // Selected question IDs
  final DateTime createdAt;
  final DateTime updatedAt;

  Quiz({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.openTime,
    required this.closeTime,
    required this.maxAttempts,
    required this.durationMinutes,
    this.easyCount,
    this.mediumCount,
    this.hardCount,
    this.questionIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Quiz.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId ? map['_id'].toHexString() : map['_id'].toString();
    final courseId = map['courseId'] is ObjectId
        ? map['courseId'].toHexString()
        : map['courseId'].toString();

    final rawQuestionIds = map['questionIds'] as List? ?? [];
    final questionIds = rawQuestionIds
        .map((e) => e is ObjectId ? e.toHexString() : e.toString())
        .toList();

    return Quiz(
      id: id,
      courseId: courseId,
      title: map['title'] ?? '',
      description: map['description'],
      openTime: map['openTime'] != null
          ? DateTime.parse(map['openTime'])
          : DateTime.now(),
      closeTime: map['closeTime'] != null
          ? DateTime.parse(map['closeTime'])
          : DateTime.now(),
      maxAttempts: map['maxAttempts'] ?? 1,
      durationMinutes: map['durationMinutes'] ?? 60,
      easyCount: map['easyCount'],
      mediumCount: map['mediumCount'],
      hardCount: map['hardCount'],
      questionIds: questionIds,
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
        'openTime': openTime.toIso8601String(),
        'closeTime': closeTime.toIso8601String(),
        'maxAttempts': maxAttempts,
        'durationMinutes': durationMinutes,
        if (easyCount != null) 'easyCount': easyCount,
        if (mediumCount != null) 'mediumCount': mediumCount,
        if (hardCount != null) 'hardCount': hardCount,
        'questionIds': questionIds.map(ObjectId.fromHexString).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Quiz copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    DateTime? openTime,
    DateTime? closeTime,
    int? maxAttempts,
    int? durationMinutes,
    int? easyCount,
    int? mediumCount,
    int? hardCount,
    List<String>? questionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Quiz(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      easyCount: easyCount ?? this.easyCount,
      mediumCount: mediumCount ?? this.mediumCount,
      hardCount: hardCount ?? this.hardCount,
      questionIds: questionIds ?? this.questionIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class QuizSubmission {
  final String id;
  final String quizId;
  final String studentId;
  final List<int> answers; // Index of selected answer for each question
  final int score;
  final int maxScore;
  final DateTime submittedAt;
  final int attemptNumber;

  QuizSubmission({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.answers,
    required this.score,
    required this.maxScore,
    required this.submittedAt,
    required this.attemptNumber,
  });

  factory QuizSubmission.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId ? map['_id'].toHexString() : map['_id'].toString();
    final quizId = map['quizId'] is ObjectId
        ? map['quizId'].toHexString()
        : map['quizId'].toString();
    final studentId = map['studentId'] is ObjectId
        ? map['studentId'].toHexString()
        : map['studentId'].toString();

    return QuizSubmission(
      id: id,
      quizId: quizId,
      studentId: studentId,
      answers: (map['answers'] as List? ?? []).cast<int>(),
      score: map['score'] ?? 0,
      maxScore: map['maxScore'] ?? 0,
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'])
          : DateTime.now(),
      attemptNumber: map['attemptNumber'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        '_id': ObjectId.fromHexString(id),
        'quizId': ObjectId.fromHexString(quizId),
        'studentId': ObjectId.fromHexString(studentId),
        'answers': answers,
        'score': score,
        'maxScore': maxScore,
        'submittedAt': submittedAt.toIso8601String(),
        'attemptNumber': attemptNumber,
      };
}

