// providers/quiz_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../services/database_service.dart';

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
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'questions',
        filter: filter,
      );
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
      final now = DateTime.now();
      final doc = {
        'courseId': courseId,
        'questionText': questionText,
        'choices': choices,
        'correctAnswerIndex': correctAnswerIndex,
        'difficulty': difficulty.toString().split('.').last,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      
      await DatabaseService.insertOne(
        collection: 'questions',
        document: doc,
      );
      
      await loadQuestions();
    } catch (e) {
      print('Error creating question: $e');
      rethrow;
    }
  }

  Future<void> updateQuestion(Question question) async {
    try {
      final now = DateTime.now();
      
      await DatabaseService.updateOne(
        collection: 'questions',
        id: question.id,
        update: {
          'questionText': question.questionText,
          'choices': question.choices,
          'correctAnswerIndex': question.correctAnswerIndex,
          'difficulty': question.difficulty.toString().split('.').last,
          'updatedAt': now.toIso8601String(),
        },
      );
      
      await loadQuestions();
    } catch (e) {
      print('Error updating question: $e');
      rethrow;
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'questions',
        id: questionId,
      );
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
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'quizzes',
        filter: filter,
      );
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
      final now = DateTime.now();
      final doc = {
        'courseId': courseId,
        'title': title,
        if (description != null) 'description': description,
        'openTime': openTime.toIso8601String(),
        'closeTime': closeTime.toIso8601String(),
        'maxAttempts': maxAttempts,
        'durationMinutes': durationMinutes,
        if (easyCount != null) 'easyCount': easyCount,
        if (mediumCount != null) 'mediumCount': mediumCount,
        if (hardCount != null) 'hardCount': hardCount,
        'questionIds': questionIds,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      
      await DatabaseService.insertOne(
        collection: 'quizzes',
        document: doc,
      );
      
      await loadQuizzes();
    } catch (e) {
      print('Error creating quiz: $e');
      rethrow;
    }
  }

  Future<void> updateQuiz(Quiz quiz) async {
    try {
      final now = DateTime.now();
      
      await DatabaseService.updateOne(
        collection: 'quizzes',
        id: quiz.id,
        update: {
          'title': quiz.title,
          'description': quiz.description,
          'openTime': quiz.openTime.toIso8601String(),
          'closeTime': quiz.closeTime.toIso8601String(),
          'maxAttempts': quiz.maxAttempts,
          'durationMinutes': quiz.durationMinutes,
          'easyCount': quiz.easyCount,
          'mediumCount': quiz.mediumCount,
          'hardCount': quiz.hardCount,
          'questionIds': quiz.questionIds,
          'updatedAt': now.toIso8601String(),
        },
      );
      
      await loadQuizzes();
    } catch (e) {
      print('Error updating quiz: $e');
      rethrow;
    }
  }

  Future<void> deleteQuiz(String quizId) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'quizzes',
        id: quizId,
      );
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
      final filter = quizId != null ? {'quizId': quizId} : null;
      final data = await DatabaseService.find(
        collection: 'quiz_submissions',
        filter: filter,
      );
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
      final now = DateTime.now();
      final doc = {
        'quizId': quizId,
        'studentId': studentId,
        'answers': answers,
        'score': score,
        'maxScore': maxScore,
        'submittedAt': now.toIso8601String(),
        'attemptNumber': attemptNumber,
      };
      
      await DatabaseService.insertOne(
        collection: 'quiz_submissions',
        document: doc,
      );
      
      await loadSubmissions();
    } catch (e) {
      print('Error submitting quiz: $e');
      rethrow;
    }
  }

  Future<int> getAttemptCount(String quizId, String studentId) async {
    try {
      final count = await DatabaseService.count(
        collection: 'quiz_submissions',
        filter: {
          'quizId': quizId,
          'studentId': studentId,
        },
      );
      return count;
    } catch (e) {
      print('Error getting attempt count: $e');
      return 0;
    }
  }
}