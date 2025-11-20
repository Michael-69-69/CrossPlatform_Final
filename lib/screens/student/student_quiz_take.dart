// screens/student/tabs/student_quiz_take.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/quiz.dart';
import '../../../models/question.dart';
import '../../../providers/quiz_provider.dart';
import '../../../providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.quiz.durationMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  Future<void> _autoSubmit() async {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hết giờ! Tự động nộp bài...')),
    );
    
    await _submitQuiz();
  }

  @override
  Widget build(BuildContext context) {
    final allQuestions = ref.watch(questionProvider);
    
    // ✅ FIX: Handle null values properly
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

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(
          child: Text('Không tìm thấy câu hỏi'),
        ),
      );
    }

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return WillPopScope(
      onWillPop: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Thoát quiz?'),
            content: const Text('Bài làm của bạn sẽ không được lưu nếu thoát.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Thoát'),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          actions: [
            // Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300 ? Colors.red : Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _answers.length / questions.length,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_answers.length}/${questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Questions
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  final selectedAnswer = _answers[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Câu ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  question.questionText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(question.choices.length, (choiceIndex) {
                            final isSelected = selectedAnswer == choiceIndex;
                            
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
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  border: Border.all(
                                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.blue : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? Colors.blue : Colors.grey,
                                          width: 2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${String.fromCharCode(65 + choiceIndex)}. ${question.choices[choiceIndex]}',
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
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
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _answers.length == questions.length && !_isSubmitting
                    ? _submitQuiz
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Nộp bài (${_answers.length}/${questions.length})',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuiz() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    // Confirm submission
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nộp bài?'),
        content: Text('Bạn đã trả lời ${_answers.length}/${widget.quiz.questionIds.length} câu hỏi.\nXác nhận nộp bài?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      _timer?.cancel();

      final allQuestions = ref.read(questionProvider);
      
      // ✅ FIX: Handle null values properly
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
        // Show result dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Kết quả'),
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
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}