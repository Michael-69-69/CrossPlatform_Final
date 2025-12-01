// screens/student/student_quiz_take.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/quiz.dart';
import '../../models/question.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart'; // for localeProvider

class StudentQuizTake extends ConsumerStatefulWidget {
  final Quiz quiz;

  const StudentQuizTake({super.key, required this.quiz});

  @override
  ConsumerState<StudentQuizTake> createState() => _StudentQuizTakeState();
}

class _StudentQuizTakeState extends ConsumerState<StudentQuizTake> {
  final Map<int, int> _answers = {};
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isSubmitting = false;
  bool _isLoadingQuestions = true; // ✅ NEW

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.quiz.durationMinutes * 60;
    _loadQuestionsAndStartTimer(); // ✅ NEW
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ✅ NEW: Load questions first, then start timer
  Future<void> _loadQuestionsAndStartTimer() async {
    try {
      // Get the courseId from the quiz
      final courseId = widget.quiz.courseId;
      
      // Load questions for this course
      await ref.read(questionProvider.notifier).loadQuestions(courseId: courseId);
      
      print('✅ Loaded questions for quiz: ${widget.quiz.title}');
      
      // Start timer after questions are loaded
      _startTimer();
    } catch (e) {
      print('❌ Error loading questions: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuestions = false);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _autoSubmit();
      }
    });
  }

  // Helper method to check if Vietnamese
  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  Future<void> _autoSubmit() async {
    if (!mounted) return;

    final isVietnamese = _isVietnamese();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isVietnamese ? 'Hết giờ! Tự động nộp bài...' : 'Time\'s up! Auto-submitting...')),
    );

    await _submitQuiz();
  }

  @override
  Widget build(BuildContext context) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    // ✅ Show loading indicator while loading questions
    if (_isLoadingQuestions) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(isVietnamese ? 'Đang tải câu hỏi...' : 'Loading questions...'),
            ],
          ),
        ),
      );
    }

    final allQuestions = ref.watch(questionProvider);
    
    // ✅ IMPROVED: Better error handling for missing questions
    final questions = widget.quiz.questionIds
        .map((id) {
          try {
            return allQuestions.firstWhere((q) => q.id == id);
          } catch (e) {
            print('⚠️ Question not found: $id');
            return null;
          }
        })
        .where((q) => q != null)
        .cast<Question>()
        .toList();

    // ✅ IMPROVED: More detailed error message
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                isVietnamese ? 'Không tìm thấy câu hỏi' : 'Questions not found',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isVietnamese
                    ? 'Quiz có ${widget.quiz.questionIds.length} câu hỏi nhưng không tìm thấy trong hệ thống'
                    : 'Quiz has ${widget.quiz.questionIds.length} questions but they were not found in the system',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(isVietnamese ? 'Quay lại' : 'Go back'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  setState(() => _isLoadingQuestions = true);
                  await _loadQuestionsAndStartTimer();
                },
                icon: const Icon(Icons.refresh),
                label: Text(isVietnamese ? 'Thử lại' : 'Try again'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ IMPROVED: Show warning if some questions are missing
    if (questions.length < widget.quiz.questionIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isVietnamese
                    ? '⚠️ Chỉ tìm thấy ${questions.length}/${widget.quiz.questionIds.length} câu hỏi'
                    : '⚠️ Only found ${questions.length}/${widget.quiz.questionIds.length} questions',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return WillPopScope(
      onWillPop: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isVietnamese ? 'Thoát quiz?' : 'Exit quiz?'),
            content: Text(isVietnamese
                ? 'Bài làm của bạn sẽ không được lưu nếu thoát.'
                : 'Your answers will not be saved if you exit.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(isVietnamese ? 'Thoát' : 'Exit'),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: _answers.length / questions.length,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            
            // Questions List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  final questionNumber = index + 1;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question Text
                          Text(
                            isVietnamese
                                ? 'Câu $questionNumber: ${question.questionText}'
                                : 'Question $questionNumber: ${question.questionText}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Choices
                          ...question.choices.asMap().entries.map((entry) {
                            final choiceIndex = entry.key;
                            final choiceText = entry.value;
                            final isSelected = _answers[index] == choiceIndex;
                            
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _answers[index] = choiceIndex;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Radio<int>(
                                      value: choiceIndex,
                                      groupValue: _answers[index],
                                      onChanged: (value) {
                                        setState(() {
                                          _answers[index] = value!;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(choiceText),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    isVietnamese
                        ? 'Đã trả lời: ${_answers.length}/${questions.length}'
                        : 'Answered: ${_answers.length}/${questions.length}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_answers.length < questions.length) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(isVietnamese ? 'Chưa hoàn thành' : 'Not complete'),
                                    content: Text(
                                      isVietnamese
                                          ? 'Bạn chỉ trả lời ${_answers.length}/${questions.length} câu hỏi. Bạn có chắc muốn nộp bài?'
                                          : 'You only answered ${_answers.length}/${questions.length} questions. Are you sure you want to submit?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _submitQuiz();
                                        },
                                        child: Text(isVietnamese ? 'Nộp bài' : 'Submit'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                _submitQuiz();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isVietnamese ? 'Nộp bài' : 'Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuiz() async {
    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authProvider);
      if (user == null) return;

      final allQuestions = ref.read(questionProvider);
      final questions = widget.quiz.questionIds
          .map((id) {
            try {
              return allQuestions.firstWhere((q) => q.id == id);
            } catch (e) {
              return null;
            }
          })
          .where((q) => q != null)
          .cast<Question>()
          .toList();

      // Calculate score
      int score = 0;
      final answersList = List<int>.filled(questions.length, -1);
      
      for (int i = 0; i < questions.length; i++) {
        final answer = _answers[i] ?? -1;
        answersList[i] = answer;
        
        if (answer == questions[i].correctAnswerIndex) {
          score++;
        }
      }

      // Get attempt count
      final attemptCount = await ref.read(quizSubmissionProvider.notifier).getAttemptCount(
            widget.quiz.id,
            user.id,
          );

      // Submit quiz
      await ref.read(quizSubmissionProvider.notifier).submitQuiz(
            quizId: widget.quiz.id,
            studentId: user.id,
            answers: answersList,
            score: score,
            maxScore: questions.length,
            attemptNumber: attemptCount + 1,
          );

      if (mounted) {
        final isVietnamese = _isVietnamese();
        // Show result dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(isVietnamese ? 'Kết quả' : 'Result'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  score >= questions.length * 0.5 ? Icons.celebration : Icons.sentiment_dissatisfied,
                  size: 64,
                  color: score >= questions.length * 0.5 ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  '$score/${questions.length}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(score / questions.length * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(isVietnamese ? 'Đóng' : 'Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isVietnamese = _isVietnamese();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}