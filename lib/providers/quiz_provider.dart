// providers/quiz_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../services/mongodb_service.dart';

final questionProvider = StateNotifierProvider<QuestionNotifier, List<Question>>((ref) {
  return QuestionNotifier();
});

final quizProvider = StateNotifierProvider<QuizNotifier, List<Quiz>>((ref) {
  return QuizNotifier();
});

final quizSubmissionProvider = StateNotifierProvider<QuizSubmissionNotifier, List<QuizSubmission>>((ref) {
  return QuizSubmissionNotifier();
});

class QuestionNotifier extends StateNotifier<List<Question>> {
  QuestionNotifier() : super([]) {
    loadQuestions();
  }

  Future<void> loadQuestions({String? courseId}) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('questions');
      var query = where;
      if (courseId != null) {
        query = where.eq('courseId', ObjectId.fromHexString(courseId));
      }
      final data = await collection.find(query).toList();
      state = data.map((e) => Question.fromMap(e)).toList();
    } catch (e) {
      print('Error loading questions: $e');
    }
  }

  Future<void> createQuestion({
    required String courseId,
    required String questionText,
    required List<String> choices,
    required int correctAnswerIndex,
    required QuestionDifficulty difficulty,
  }) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('questions');
      final now = DateTime.now();
      final doc = {
        'courseId': ObjectId.fromHexString(courseId),
        'questionText': questionText,
        'choices': choices,
        'correctAnswerIndex': correctAnswerIndex,
        'difficulty': difficulty.toString().split('.').last,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await collection.insertOne(doc);
      await loadQuestions();
    } catch (e) {
      print('Error creating question: $e');
      rethrow;
    }
  }

  Future<void> updateQuestion(Question question) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('questions');
      final now = DateTime.now();
      await collection.updateOne(
        where.id(ObjectId.fromHexString(question.id)),
        ModifierBuilder()
          ..set('questionText', question.questionText)
          ..set('choices', question.choices)
          ..set('correctAnswerIndex', question.correctAnswerIndex)
          ..set('difficulty', question.difficulty.toString().split('.').last)
          ..set('updatedAt', now.toIso8601String()),
      );
      await loadQuestions();
    } catch (e) {
      print('Error updating question: $e');
      rethrow;
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('questions');
      await collection.deleteOne(where.id(ObjectId.fromHexString(questionId)));
      await loadQuestions();
    } catch (e) {
      print('Error deleting question: $e');
      rethrow;
    }
  }
}

class QuizNotifier extends StateNotifier<List<Quiz>> {
  QuizNotifier() : super([]) {
    loadQuizzes();
  }

  Future<void> loadQuizzes({String? courseId}) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('quizzes');
      var query = where;
      if (courseId != null) {
        query = where.eq('courseId', ObjectId.fromHexString(courseId));
      }
      final data = await collection.find(query).toList();
      state = data.map((e) => Quiz.fromMap(e)).toList();
    } catch (e) {
      print('Error loading quizzes: $e');
    }
  }

  Future<void> createQuiz({
    required String courseId,
    required String title,
    String? description,
    required DateTime openTime,
    required DateTime closeTime,
    required int maxAttempts,
    required int durationMinutes,
    int? easyCount,
    int? mediumCount,
    int? hardCount,
    required List<String> questionIds,
  }) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('quizzes');
      final now = DateTime.now();
      final doc = {
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
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await collection.insertOne(doc);
      await loadQuizzes();
    } catch (e) {
      print('Error creating quiz: $e');
      rethrow;
    }
  }

  Future<void> updateQuiz(Quiz quiz) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('quizzes');
      final now = DateTime.now();
      await collection.updateOne(
        where.id(ObjectId.fromHexString(quiz.id)),
        ModifierBuilder()
          ..set('title', quiz.title)
          ..set('description', quiz.description)
          ..set('openTime', quiz.openTime.toIso8601String())
          ..set('closeTime', quiz.closeTime.toIso8601String())
          ..set('maxAttempts', quiz.maxAttempts)
          ..set('durationMinutes', quiz.durationMinutes)
          ..set('easyCount', quiz.easyCount)
          ..set('mediumCount', quiz.mediumCount)
          ..set('hardCount', quiz.hardCount)
          ..set('questionIds', quiz.questionIds.map(ObjectId.fromHexString).toList())
          ..set('updatedAt', now.toIso8601String()),
      );
      await loadQuizzes();
    } catch (e) {
      print('Error updating quiz: $e');
      rethrow;
    }
  }

  Future<void> deleteQuiz(String quizId) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('quizzes');
      await collection.deleteOne(where.id(ObjectId.fromHexString(quizId)));
      await loadQuizzes();
    } catch (e) {
      print('Error deleting quiz: $e');
      rethrow;
    }
  }
}

class QuizSubmissionNotifier extends StateNotifier<List<QuizSubmission>> {
  QuizSubmissionNotifier() : super([]) {
    loadSubmissions();
  }

  Future<void> loadSubmissions({String? quizId}) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('quiz_submissions');
      var query = where;
      if (quizId != null) {
        query = where.eq('quizId', ObjectId.fromHexString(quizId));
      }
      final data = await collection.find(query).toList();
      state = data.map((e) => QuizSubmission.fromMap(e)).toList();
    } catch (e) {
      print('Error loading quiz submissions: $e');
    }
  }

  Future<void> submitQuiz({
    required String quizId,
    required String studentId,
    required List<int> answers,
    required int score,
    required int maxScore,
    required int attemptNumber,
  }) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('quiz_submissions');
      final now = DateTime.now();
      final doc = {
        'quizId': ObjectId.fromHexString(quizId),
        'studentId': ObjectId.fromHexString(studentId),
        'answers': answers,
        'score': score,
        'maxScore': maxScore,
        'submittedAt': now.toIso8601String(),
        'attemptNumber': attemptNumber,
      };
      await collection.insertOne(doc);
      await loadSubmissions();
    } catch (e) {
      print('Error submitting quiz: $e');
      rethrow;
    }
  }

  Future<int> getAttemptCount(String quizId, String studentId) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('quiz_submissions');
      final count = await collection.count(where
          .eq('quizId', ObjectId.fromHexString(quizId))
          .eq('studentId', ObjectId.fromHexString(studentId)));
      return count;
    } catch (e) {
      print('Error getting attempt count: $e');
      return 0;
    }
  }
}

