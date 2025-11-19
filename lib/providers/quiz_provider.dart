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
  QuestionNotifier() : super([]);
  
  bool _isLoading = false;

  Future<void> loadQuestions({String? courseId}) async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'questions',
        filter: filter,
      );
      
      // ✅ FIX: Explicit type casting
      state = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return Question.fromMap(map);
      }).toList();
      
      print('✅ Loaded ${state.length} questions');
    } catch (e) {
      print('Error loading questions: $e');
      state = [];
    } finally {
      _isLoading = false;
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
      
      // ✅ FIX: Explicit type casting
      final doc = <String, dynamic>{
        'courseId': courseId,
        'questionText': questionText,
        'choices': List<String>.from(choices),
        'correctAnswerIndex': correctAnswerIndex,
        'difficulty': difficulty.toString().split('.').last,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      
      final insertedId = await DatabaseService.insertOne(
        collection: 'questions',
        document: doc,
      );
      
      // Add to state immediately
      state = [
        Question(
          id: insertedId,
          courseId: courseId,
          questionText: questionText,
          choices: choices,
          correctAnswerIndex: correctAnswerIndex,
          difficulty: difficulty,
          createdAt: now,
          updatedAt: now,
        ),
        ...state,
      ];
      
      print('✅ Created question: $insertedId');
    } catch (e, stackTrace) {
      print('Error creating question: $e');
      print('StackTrace: $stackTrace');
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
          'choices': List<String>.from(question.choices),
          'correctAnswerIndex': question.correctAnswerIndex,
          'difficulty': question.difficulty.toString().split('.').last,
          'updatedAt': now.toIso8601String(),
        },
      );
      
      state = state.map((q) {
        if (q.id == question.id) {
          return question.copyWith(updatedAt: now);
        }
        return q;
      }).toList();
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
      state = state.where((q) => q.id != questionId).toList();
    } catch (e) {
      print('Error deleting question: $e');
      rethrow;
    }
  }
}

class QuizNotifier extends StateNotifier<List<Quiz>> {
  QuizNotifier() : super([]);
  
  bool _isLoading = false;

  Future<void> loadQuizzes({String? courseId}) async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'quizzes',
        filter: filter,
      );
      
      // ✅ FIX: Explicit type casting
      state = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return Quiz.fromMap(map);
      }).toList();
      
      print('✅ Loaded ${state.length} quizzes');
    } catch (e) {
      print('Error loading quizzes: $e');
      state = [];
    } finally {
      _isLoading = false;
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
      
      // ✅ FIX: Explicit type casting
      final doc = <String, dynamic>{
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
        'questionIds': List<String>.from(questionIds),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      
      final insertedId = await DatabaseService.insertOne(
        collection: 'quizzes',
        document: doc,
      );
      
      // Add to state
      state = [
        Quiz(
          id: insertedId,
          courseId: courseId,
          title: title,
          description: description,
          openTime: openTime,
          closeTime: closeTime,
          maxAttempts: maxAttempts,
          durationMinutes: durationMinutes,
          easyCount: easyCount,
          mediumCount: mediumCount,
          hardCount: hardCount,
          questionIds: questionIds,
          createdAt: now,
          updatedAt: now,
        ),
        ...state,
      ];
      
      print('✅ Created quiz: $insertedId');
    } catch (e, stackTrace) {
      print('Error creating quiz: $e');
      print('StackTrace: $stackTrace');
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
          'questionIds': List<String>.from(quiz.questionIds),
          'updatedAt': now.toIso8601String(),
        },
      );
      
      state = state.map((q) {
        if (q.id == quiz.id) {
          return quiz.copyWith(updatedAt: now);
        }
        return q;
      }).toList();
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
      state = state.where((q) => q.id != quizId).toList();
    } catch (e) {
      print('Error deleting quiz: $e');
      rethrow;
    }
  }
}

class QuizSubmissionNotifier extends StateNotifier<List<QuizSubmission>> {
  QuizSubmissionNotifier() : super([]);

  Future<void> loadSubmissions({String? quizId}) async {
    try {
      final filter = quizId != null ? {'quizId': quizId} : null;
      final data = await DatabaseService.find(
        collection: 'quiz_submissions',
        filter: filter,
      );
      
      // ✅ FIX: Explicit type casting
      state = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return QuizSubmission.fromMap(map);
      }).toList();
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
      
      // ✅ FIX: Explicit type casting
      final doc = <String, dynamic>{
        'quizId': quizId,
        'studentId': studentId,
        'answers': List<int>.from(answers),
        'score': score,
        'maxScore': maxScore,
        'submittedAt': now.toIso8601String(),
        'attemptNumber': attemptNumber,
      };
      
      final insertedId = await DatabaseService.insertOne(
        collection: 'quiz_submissions',
        document: doc,
      );
      
      // Add to state
      state = [
        QuizSubmission(
          id: insertedId,
          quizId: quizId,
          studentId: studentId,
          answers: answers,
          score: score,
          maxScore: maxScore,
          submittedAt: now,
          attemptNumber: attemptNumber,
        ),
        ...state,
      ];
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