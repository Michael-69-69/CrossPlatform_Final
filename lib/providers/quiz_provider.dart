// providers/quiz_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';

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

  // ✅ Helper: Convert ObjectIds to strings recursively
  Map<String, dynamic> _convertObjectIds(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIds(item);
          } else if (item is Map) {
            return _convertObjectIds(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIds(value);
      } else if (value is Map) {
        result[key] = _convertObjectIds(Map<String, dynamic>.from(value));
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  Future<void> loadQuestions({String? courseId}) async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      
      // ✅ 1. Try to load from cache first
      final cacheKey = courseId != null ? 'questions_$courseId' : 'questions_all';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Question.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} questions from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshQuestionsInBackground(courseId, cacheKey);
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for questions');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'questions',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Question.fromMap(map);
      }).toList();
      
      // ✅ 4. Save to cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60,
      );
      
      print('✅ Loaded ${state.length} questions');
    } catch (e, stack) {
      print('❌ Error loading questions: $e');
      print('Stack: $stack');
      
      // ✅ 5. Fallback to cache on error
      final cacheKey = courseId != null ? 'questions_$courseId' : 'questions_all';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Question.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} questions from cache (fallback)');
      } else {
        state = [];
      }
    } finally {
      _isLoading = false;
    }
  }

  // ✅ Background refresh
  Future<void> _refreshQuestionsInBackground(String? courseId, String cacheKey) async {
    try {
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'questions',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Question.fromMap(map);
      }).toList();
      
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60,
      );
      
      print('🔄 Background refresh: questions updated');
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  Future<void> createQuestion({
    required String courseId,
    required String questionText,
    required List<String> choices,
    required int correctAnswerIndex,
    required QuestionDifficulty difficulty,
  }) async {
    // ✅ Check if online before creating
    if (NetworkService().isOffline) {
      throw Exception('Không thể tạo câu hỏi khi offline');
    }
    
    try {
      final now = DateTime.now();
      
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
      
      // ✅ Clear cache after creating
      await CacheService.clearCache('questions_$courseId');
      await CacheService.clearCache('questions_all');
      
      print('✅ Created question: $insertedId');
    } catch (e, stackTrace) {
      print('❌ Error creating question: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateQuestion(Question question) async {
    // ✅ Check if online before updating
    if (NetworkService().isOffline) {
      throw Exception('Không thể cập nhật câu hỏi khi offline');
    }
    
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
      
      // ✅ Clear cache after updating
      await CacheService.clearCache('questions_${question.courseId}');
      await CacheService.clearCache('questions_all');
      
      print('✅ Updated question: ${question.id}');
    } catch (e) {
      print('❌ Error updating question: $e');
      rethrow;
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    // ✅ Check if online before deleting
    if (NetworkService().isOffline) {
      throw Exception('Không thể xóa câu hỏi khi offline');
    }
    
    try {
      // Get courseId before deleting
      final question = state.firstWhere((q) => q.id == questionId);
      final courseId = question.courseId;
      
      await DatabaseService.deleteOne(
        collection: 'questions',
        id: questionId,
      );
      
      state = state.where((q) => q.id != questionId).toList();
      
      // ✅ Clear cache after deleting
      await CacheService.clearCache('questions_$courseId');
      await CacheService.clearCache('questions_all');
      
      print('✅ Deleted question: $questionId');
    } catch (e) {
      print('❌ Error deleting question: $e');
      rethrow;
    }
  }
  
  // ✅ Force refresh from database
  Future<void> forceRefresh({String? courseId}) async {
    final cacheKey = courseId != null ? 'questions_$courseId' : 'questions_all';
    await CacheService.clearCache(cacheKey);
    _isLoading = false;
    await loadQuestions(courseId: courseId);
  }
}

class QuizNotifier extends StateNotifier<List<Quiz>> {
  QuizNotifier() : super([]);
  
  bool _isLoading = false;

  // ✅ Helper: Convert ObjectIds to strings recursively
  Map<String, dynamic> _convertObjectIds(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIds(item);
          } else if (item is Map) {
            return _convertObjectIds(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIds(value);
      } else if (value is Map) {
        result[key] = _convertObjectIds(Map<String, dynamic>.from(value));
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  Future<void> loadQuizzes({String? courseId}) async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      
      // ✅ 1. Try to load from cache first
      final cacheKey = courseId != null ? 'quizzes_$courseId' : 'quizzes_all';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Quiz.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} quizzes from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshQuizzesInBackground(courseId, cacheKey);
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for quizzes');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'quizzes',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Quiz.fromMap(map);
      }).toList();
      
      // ✅ 4. Save to cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('✅ Loaded ${state.length} quizzes');
    } catch (e, stack) {
      print('❌ Error loading quizzes: $e');
      print('Stack: $stack');
      
      // ✅ 5. Fallback to cache on error
      final cacheKey = courseId != null ? 'quizzes_$courseId' : 'quizzes_all';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Quiz.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} quizzes from cache (fallback)');
      } else {
        state = [];
      }
    } finally {
      _isLoading = false;
    }
  }

  // ✅ Background refresh
  Future<void> _refreshQuizzesInBackground(String? courseId, String cacheKey) async {
    try {
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'quizzes',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Quiz.fromMap(map);
      }).toList();
      
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('🔄 Background refresh: quizzes updated');
    } catch (e) {
      print('Background refresh failed: $e');
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
    // ✅ Check if online before creating
    if (NetworkService().isOffline) {
      throw Exception('Không thể tạo quiz khi offline');
    }
    
    try {
      final now = DateTime.now();
      
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
      
      // ✅ Clear cache after creating
      await CacheService.clearCache('quizzes_$courseId');
      await CacheService.clearCache('quizzes_all');
      
      print('✅ Created quiz: $insertedId');
    } catch (e, stackTrace) {
      print('❌ Error creating quiz: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateQuiz(Quiz quiz) async {
    // ✅ Check if online before updating
    if (NetworkService().isOffline) {
      throw Exception('Không thể cập nhật quiz khi offline');
    }
    
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
      
      // ✅ Clear cache after updating
      await CacheService.clearCache('quizzes_${quiz.courseId}');
      await CacheService.clearCache('quizzes_all');
      
      print('✅ Updated quiz: ${quiz.id}');
    } catch (e) {
      print('❌ Error updating quiz: $e');
      rethrow;
    }
  }

  Future<void> deleteQuiz(String quizId) async {
    // ✅ Check if online before deleting
    if (NetworkService().isOffline) {
      throw Exception('Không thể xóa quiz khi offline');
    }
    
    try {
      // Get courseId before deleting
      final quiz = state.firstWhere((q) => q.id == quizId);
      final courseId = quiz.courseId;
      
      await DatabaseService.deleteOne(
        collection: 'quizzes',
        id: quizId,
      );
      
      state = state.where((q) => q.id != quizId).toList();
      
      // ✅ Clear cache after deleting
      await CacheService.clearCache('quizzes_$courseId');
      await CacheService.clearCache('quizzes_all');
      
      print('✅ Deleted quiz: $quizId');
    } catch (e) {
      print('❌ Error deleting quiz: $e');
      rethrow;
    }
  }
  
  // ✅ Force refresh from database
  Future<void> forceRefresh({String? courseId}) async {
    final cacheKey = courseId != null ? 'quizzes_$courseId' : 'quizzes_all';
    await CacheService.clearCache(cacheKey);
    _isLoading = false;
    await loadQuizzes(courseId: courseId);
  }
}

class QuizSubmissionNotifier extends StateNotifier<List<QuizSubmission>> {
  QuizSubmissionNotifier() : super([]);

  // ✅ Helper: Convert ObjectIds to strings recursively
  Map<String, dynamic> _convertObjectIds(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIds(item);
          } else if (item is Map) {
            return _convertObjectIds(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIds(value);
      } else if (value is Map) {
        result[key] = _convertObjectIds(Map<String, dynamic>.from(value));
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  Future<void> loadSubmissions({String? quizId, String? studentId}) async {
    try {
      print('📥 Loading quiz submissions (quizId: $quizId, studentId: $studentId)');
      
      // ✅ 1. Try to load from cache first
      final cacheKey = quizId != null 
          ? 'quiz_submissions_$quizId' 
          : studentId != null
              ? 'quiz_submissions_student_$studentId'
              : 'quiz_submissions_all';
      
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return QuizSubmission.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} quiz submissions from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshSubmissionsInBackground(quizId, studentId, cacheKey);
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for quiz submissions');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database
      Map<String, dynamic>? filter;
      if (quizId != null && studentId != null) {
        filter = {'quizId': quizId, 'studentId': studentId};
      } else if (quizId != null) {
        filter = {'quizId': quizId};
      } else if (studentId != null) {
        filter = {'studentId': studentId};
      }
      
      final data = await DatabaseService.find(
        collection: 'quiz_submissions',
        filter: filter,
        sort: {'submittedAt': -1}, // Most recent first
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return QuizSubmission.fromMap(map);
      }).toList();
      
      // ✅ 4. Save to cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('✅ Loaded ${state.length} quiz submissions');
    } catch (e, stack) {
      print('❌ Error loading quiz submissions: $e');
      print('Stack: $stack');
      
      // ✅ 5. Fallback to cache on error
      final cacheKey = quizId != null 
          ? 'quiz_submissions_$quizId' 
          : studentId != null
              ? 'quiz_submissions_student_$studentId'
              : 'quiz_submissions_all';
      
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return QuizSubmission.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} quiz submissions from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh
  Future<void> _refreshSubmissionsInBackground(String? quizId, String? studentId, String cacheKey) async {
    try {
      Map<String, dynamic>? filter;
      if (quizId != null && studentId != null) {
        filter = {'quizId': quizId, 'studentId': studentId};
      } else if (quizId != null) {
        filter = {'quizId': quizId};
      } else if (studentId != null) {
        filter = {'studentId': studentId};
      }
      
      final data = await DatabaseService.find(
        collection: 'quiz_submissions',
        filter: filter,
        sort: {'submittedAt': -1},
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return QuizSubmission.fromMap(map);
      }).toList();
      
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('🔄 Background refresh: quiz submissions updated');
    } catch (e) {
      print('Background refresh failed: $e');
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
    // ✅ Check if online before submitting
    if (NetworkService().isOffline) {
      throw Exception('Không thể nộp quiz khi offline');
    }
    
    try {
      final now = DateTime.now();
      
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
      
      // ✅ Clear cache after submitting
      await CacheService.clearCache('quiz_submissions_$quizId');
      await CacheService.clearCache('quiz_submissions_student_$studentId');
      await CacheService.clearCache('quiz_submissions_all');
      
      print('✅ Submitted quiz: $insertedId');
    } catch (e, stack) {
      print('❌ Error submitting quiz: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  Future<int> getAttemptCount(String quizId, String studentId) async {
    try {
      // ✅ Check if online before querying
      if (NetworkService().isOffline) {
        // Try to count from local state
        final attempts = state.where((s) => 
          s.quizId == quizId && s.studentId == studentId
        ).length;
        print('⚠️ Offline - counted $attempts attempts from cache');
        return attempts;
      }
      
      final count = await DatabaseService.count(
        collection: 'quiz_submissions',
        filter: {
          'quizId': quizId,
          'studentId': studentId,
        },
      );
      return count;
    } catch (e) {
      print('❌ Error getting attempt count: $e');
      // Fallback to local state count
      final attempts = state.where((s) => 
        s.quizId == quizId && s.studentId == studentId
      ).length;
      return attempts;
    }
  }
  
  // ✅ Get student's submissions for dashboard
  List<QuizSubmission> getStudentSubmissions(String studentId) {
    return state.where((s) => s.studentId == studentId).toList();
  }
  
  // ✅ Get quiz submissions for instructor
  List<QuizSubmission> getQuizSubmissions(String quizId) {
    return state.where((s) => s.quizId == quizId).toList();
  }
  
  // ✅ Get student's best score for a quiz
  QuizSubmission? getBestSubmission(String quizId, String studentId) {
    final submissions = state.where((s) => 
      s.quizId == quizId && s.studentId == studentId
    ).toList();
    
    if (submissions.isEmpty) return null;
    
    submissions.sort((a, b) => b.score.compareTo(a.score));
    return submissions.first;
  }
  
  // ✅ Force refresh from database
  Future<void> forceRefresh({String? quizId, String? studentId}) async {
    final cacheKey = quizId != null 
        ? 'quiz_submissions_$quizId' 
        : studentId != null
            ? 'quiz_submissions_student_$studentId'
            : 'quiz_submissions_all';
    await CacheService.clearCache(cacheKey);
    await loadSubmissions(quizId: quizId, studentId: studentId);
  }
}