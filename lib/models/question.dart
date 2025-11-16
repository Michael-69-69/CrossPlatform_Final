// models/question.dart
import 'package:mongo_dart/mongo_dart.dart';

enum QuestionDifficulty { easy, medium, hard }

class Question {
  final String id;
  final String courseId;
  final String questionText;
  final List<String> choices;
  final int correctAnswerIndex;
  final QuestionDifficulty difficulty;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.courseId,
    required this.questionText,
    required this.choices,
    required this.correctAnswerIndex,
    required this.difficulty,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId ? map['_id'].toHexString() : map['_id'].toString();
    final courseId = map['courseId'] is ObjectId
        ? map['courseId'].toHexString()
        : map['courseId'].toString();

    return Question(
      id: id,
      courseId: courseId,
      questionText: map['questionText'] ?? '',
      choices: (map['choices'] as List? ?? []).cast<String>(),
      correctAnswerIndex: map['correctAnswerIndex'] ?? 0,
      difficulty: QuestionDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == map['difficulty'],
        orElse: () => QuestionDifficulty.medium,
      ),
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
        'questionText': questionText,
        'choices': choices,
        'correctAnswerIndex': correctAnswerIndex,
        'difficulty': difficulty.toString().split('.').last,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Question copyWith({
    String? id,
    String? courseId,
    String? questionText,
    List<String>? choices,
    int? correctAnswerIndex,
    QuestionDifficulty? difficulty,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Question(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      questionText: questionText ?? this.questionText,
      choices: choices ?? this.choices,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

