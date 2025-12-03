// lib/screens/instructor/ai_quiz_generator_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
import '../../models/course.dart';
import '../../models/question.dart';
import '../../providers/quiz_provider.dart';
import '../../main.dart';

class AIQuizGeneratorScreen extends ConsumerStatefulWidget {
  final Course course;

  const AIQuizGeneratorScreen({super.key, required this.course});

  @override
  ConsumerState<AIQuizGeneratorScreen> createState() => _AIQuizGeneratorScreenState();
}

class _AIQuizGeneratorScreenState extends ConsumerState<AIQuizGeneratorScreen> {
  final _materialController = TextEditingController();
  final _topicController = TextEditingController();
  final _titleController = TextEditingController();
  
  // Difficulty counts
  int _easyCount = 2;
  int _mediumCount = 3;
  int _hardCount = 2;
  
  // Quiz settings
  int _durationMinutes = 30;
  int _maxAttempts = 2;
  
  // Generation state
  bool _isGenerating = false;
  String _currentStep = '';
  List<Map<String, dynamic>> _generatedQuestions = [];
  List<Map<String, dynamic>> _validatedQuestions = [];
  String? _error;
  
  // Progress tracking
  int _totalSteps = 4;
  int _currentStepIndex = 0;

  int get _totalQuestions => _easyCount + _mediumCount + _hardCount;

  bool _isVietnamese() => ref.watch(localeProvider).languageCode == 'vi';

  @override
  void initState() {
    super.initState();
    _titleController.text = '${widget.course.code} - Quiz';
  }

  @override
  void dispose() {
    _materialController.dispose();
    _topicController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _generateQuestions() async {
    final isVi = _isVietnamese();
    
    if (_materialController.text.trim().isEmpty) {
      setState(() => _error = isVi 
          ? 'Vui lòng nhập tài liệu hoặc nội dung bài học' 
          : 'Please enter material or lesson content');
      return;
    }

    if (_totalQuestions < 1) {
      setState(() => _error = isVi
          ? 'Vui lòng chọn ít nhất 1 câu hỏi'
          : 'Please select at least 1 question');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedQuestions = [];
      _validatedQuestions = [];
      _currentStepIndex = 0;
    });

    try {
      // ════════════════════════════════════════════════════════════════════
      // STEP 1: Generate questions with AI
      // ════════════════════════════════════════════════════════════════════
      setState(() {
        _currentStep = isVi ? '🤖 Đang tạo câu hỏi bằng AI...' : '🤖 Generating questions with AI...';
        _currentStepIndex = 1;
      });

      final questions = await AIService.generateQuizQuestionsWithDifficulty(
        material: _materialController.text,
        easyCount: _easyCount,
        mediumCount: _mediumCount,
        hardCount: _hardCount,
        topic: _topicController.text.isNotEmpty ? _topicController.text : null,
        language: isVi ? 'vi' : 'en',
      );

      setState(() {
        _generatedQuestions = questions;
        _currentStep = isVi 
            ? '✅ Đã tạo ${questions.length} câu hỏi' 
            : '✅ Generated ${questions.length} questions';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      // ════════════════════════════════════════════════════════════════════
      // STEP 2: Validate and format questions
      // ════════════════════════════════════════════════════════════════════
      setState(() {
        _currentStep = isVi ? '🔍 Đang kiểm tra định dạng...' : '🔍 Validating format...';
        _currentStepIndex = 2;
      });

      final validated = AIService.validateAndFormatQuestions(questions);

      setState(() {
        _validatedQuestions = validated;
        _currentStep = isVi 
            ? '✅ ${validated.length}/${questions.length} câu hỏi hợp lệ' 
            : '✅ ${validated.length}/${questions.length} questions valid';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (validated.isEmpty) {
        setState(() {
          _error = isVi
              ? 'Không thể tạo câu hỏi hợp lệ. Vui lòng thử lại với nội dung khác.'
              : 'Could not generate valid questions. Please try again with different content.';
          _isGenerating = false;
        });
        return;
      }

      // ════════════════════════════════════════════════════════════════════
      // STEP 3: Ready to save
      // ════════════════════════════════════════════════════════════════════
      setState(() {
        _currentStep = isVi ? '✨ Sẵn sàng lưu Quiz!' : '✨ Ready to save Quiz!';
        _currentStepIndex = 3;
        _isGenerating = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveToQuiz() async {
    if (_validatedQuestions.isEmpty) return;

    final isVi = _isVietnamese();

    // Validate title
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Vui lòng nhập tên Quiz' : 'Please enter Quiz title'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _currentStep = isVi ? '📝 Đang tạo câu hỏi trong hệ thống...' : '📝 Creating questions in system...';
      _currentStepIndex = 3;
    });

    try {
      final questionIds = <String>[];
      int createdCount = 0;

      // ════════════════════════════════════════════════════════════════════
      // STEP 3: Create questions in database
      // ════════════════════════════════════════════════════════════════════
      for (final q in _validatedQuestions) {
        setState(() {
          _currentStep = isVi 
              ? '📝 Đang tạo câu hỏi ${createdCount + 1}/${_validatedQuestions.length}...' 
              : '📝 Creating question ${createdCount + 1}/${_validatedQuestions.length}...';
        });

        // Parse difficulty
        final difficultyStr = (q['difficulty'] as String?) ?? 'medium';
        final difficulty = QuestionDifficulty.values.firstWhere(
          (d) => d.toString().split('.').last == difficultyStr,
          orElse: () => QuestionDifficulty.medium,
        );

        // Parse choices and correct answer
        final options = (q['options'] as List?)?.cast<String>() ?? [];
        final correctAnswer = q['correctAnswer'] as String? ?? 'A';
        
        // Convert "A", "B", "C", "D" to index
        int correctIndex = 0;
        if (correctAnswer.isNotEmpty) {
          final letter = correctAnswer[0].toUpperCase();
          correctIndex = ['A', 'B', 'C', 'D'].indexOf(letter);
          if (correctIndex < 0) correctIndex = 0;
        }

        // Clean options (remove "A. ", "B. ", etc. prefixes if present)
        final cleanedChoices = options.map((opt) {
          final cleaned = opt.replaceFirst(RegExp(r'^[A-Da-d][\.\)\s]+'), '');
          return cleaned.trim();
        }).toList();

        // Ensure we have at least 2 choices
        if (cleanedChoices.length < 2) {
          cleanedChoices.addAll(['Option 1', 'Option 2']);
        }
        
        // Ensure correctIndex is valid
        if (correctIndex >= cleanedChoices.length) {
          correctIndex = 0;
        }

        // Create question
        await ref.read(questionProvider.notifier).createQuestion(
          courseId: widget.course.id,
          questionText: q['question'] as String? ?? '',
          choices: cleanedChoices,
          correctAnswerIndex: correctIndex,
          difficulty: difficulty,
        );

        // Get the created question ID
        final questions = ref.read(questionProvider);
        if (questions.isNotEmpty) {
          questionIds.add(questions.first.id);
        }

        createdCount++;
      }

      // ════════════════════════════════════════════════════════════════════
      // STEP 4: Create Quiz
      // ════════════════════════════════════════════════════════════════════
      setState(() {
        _currentStep = isVi ? '🎯 Đang tạo Quiz...' : '🎯 Creating Quiz...';
        _currentStepIndex = 4;
      });

      // Count by difficulty
      int easyCount = 0, mediumCount = 0, hardCount = 0;
      for (final q in _validatedQuestions) {
        final diff = (q['difficulty'] as String?) ?? 'medium';
        if (diff == 'easy') easyCount++;
        else if (diff == 'hard') hardCount++;
        else mediumCount++;
      }

      // Create quiz with "(AI GENERATED)" in title
      final quizTitle = '${_titleController.text.trim()} (AI GENERATED)';
      
      final now = DateTime.now();
      await ref.read(quizProvider.notifier).createQuiz(
        courseId: widget.course.id,
        title: quizTitle,
        description: _topicController.text.isNotEmpty 
            ? '${isVi ? 'Chủ đề' : 'Topic'}: ${_topicController.text}' 
            : null,
        openTime: now,
        closeTime: now.add(const Duration(days: 7)),
        maxAttempts: _maxAttempts,
        durationMinutes: _durationMinutes,
        easyCount: easyCount,
        mediumCount: mediumCount,
        hardCount: hardCount,
        questionIds: questionIds,
      );

      setState(() {
        _currentStep = isVi ? '✅ Hoàn thành!' : '✅ Complete!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVi 
                ? '✅ Đã tạo Quiz "$quizTitle" với ${questionIds.length} câu hỏi!' 
                : '✅ Created Quiz "$quizTitle" with ${questionIds.length} questions!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = _isVietnamese();

    return Scaffold(
      appBar: AppBar(
        title: Text(isVi ? '🤖 Tạo Quiz bằng AI' : '🤖 AI Quiz Generator'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Info
            Card(
              color: Colors.deepPurple.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(widget.course.code, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quiz Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: isVi ? '📝 Tên Quiz' : '📝 Quiz Title',
                hintText: isVi ? 'VD: Kiểm tra giữa kỳ' : 'e.g., Midterm Quiz',
                border: const OutlineInputBorder(),
                suffixText: '(AI GENERATED)',
                suffixStyle: TextStyle(color: Colors.deepPurple, fontSize: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Material Input
            Text(
              isVi ? '📚 Tài liệu nguồn' : '📚 Source Material',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _materialController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: isVi 
                    ? 'Dán nội dung bài học, tài liệu, hoặc ghi chú vào đây...'
                    : 'Paste lesson content, materials, or notes here...',
                border: const OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // Topic (optional)
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: isVi ? '🎯 Chủ đề cụ thể (tùy chọn)' : '🎯 Specific Topic (optional)',
                hintText: isVi ? 'VD: Chương 3 - Cấu trúc dữ liệu' : 'e.g., Chapter 3 - Data Structures',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // ════════════════════════════════════════════════════════════════
            // DIFFICULTY SETTINGS (Number of questions per difficulty)
            // ════════════════════════════════════════════════════════════════
            Text(
              isVi ? '⚙️ Số câu hỏi theo độ khó' : '⚙️ Questions per Difficulty',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(child: _buildDifficultyCounter(
                  label: isVi ? '🟢 Dễ' : '🟢 Easy',
                  value: _easyCount,
                  color: Colors.green,
                  onChanged: (v) => setState(() => _easyCount = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildDifficultyCounter(
                  label: isVi ? '🟡 TB' : '🟡 Medium',
                  value: _mediumCount,
                  color: Colors.orange,
                  onChanged: (v) => setState(() => _mediumCount = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildDifficultyCounter(
                  label: isVi ? '🔴 Khó' : '🔴 Hard',
                  value: _hardCount,
                  color: Colors.red,
                  onChanged: (v) => setState(() => _hardCount = v),
                )),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isVi ? 'Tổng: $_totalQuestions câu hỏi' : 'Total: $_totalQuestions questions',
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),

            // ════════════════════════════════════════════════════════════════
            // QUIZ SETTINGS
            // ════════════════════════════════════════════════════════════════
            Text(
              isVi ? '⏱️ Cài đặt Quiz' : '⏱️ Quiz Settings',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isVi ? 'Thời gian (phút):' : 'Duration (min):', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: _durationMinutes,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [10, 15, 20, 30, 45, 60, 90, 120]
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                            .toList(),
                        onChanged: (v) => setState(() => _durationMinutes = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isVi ? 'Số lần làm:' : 'Max attempts:', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: _maxAttempts,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [1, 2, 3, 5, 10]
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                            .toList(),
                        onChanged: (v) => setState(() => _maxAttempts = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),

            // ════════════════════════════════════════════════════════════════
            // PROGRESS INDICATOR
            // ════════════════════════════════════════════════════════════════
            if (_currentStep.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    // Progress bar
                    LinearProgressIndicator(
                      value: _currentStepIndex / _totalSteps,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_isGenerating)
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
                          ),
                        if (!_isGenerating)
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_currentStep, style: const TextStyle(fontWeight: FontWeight.w500))),
                        Text('${_currentStepIndex}/$_totalSteps', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateQuestions,
                icon: _isGenerating && _currentStepIndex < 3
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGenerating && _currentStepIndex < 3
                    ? (isVi ? 'Đang xử lý...' : 'Processing...')
                    : (isVi ? 'Tạo câu hỏi bằng AI' : 'Generate with AI')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            if (!AIService.isConfigured)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isVi ? '⚠️ Chưa cấu hình AI. Thêm API key vào .env' : '⚠️ AI not configured. Add API key to .env',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                ),
              ),

            // ════════════════════════════════════════════════════════════════
            // GENERATED QUESTIONS PREVIEW
            // ════════════════════════════════════════════════════════════════
            if (_validatedQuestions.isNotEmpty) ...[
              const SizedBox(height: 32),
              
              // Summary
              Card(
                color: Colors.green.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isVi 
                                  ? '${_validatedQuestions.length} câu hỏi sẵn sàng' 
                                  : '${_validatedQuestions.length} questions ready',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDifficultyBadge('Easy', _validatedQuestions.where((q) => q['difficulty'] == 'easy').length, Colors.green),
                          _buildDifficultyBadge('Medium', _validatedQuestions.where((q) => q['difficulty'] == 'medium').length, Colors.orange),
                          _buildDifficultyBadge('Hard', _validatedQuestions.where((q) => q['difficulty'] == 'hard').length, Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Questions list
              Text(
                isVi ? '📝 Xem trước câu hỏi' : '📝 Preview Questions',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              ..._validatedQuestions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return _buildQuestionCard(index + 1, question);
              }),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _saveToQuiz,
                  icon: _isGenerating && _currentStepIndex >= 3
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isGenerating && _currentStepIndex >= 3
                      ? (isVi ? 'Đang lưu...' : 'Saving...')
                      : (isVi ? '💾 Lưu Quiz vào hệ thống' : '💾 Save Quiz to System')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyCounter({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: value > 0 ? () => onChanged(value - 1) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: value > 0 ? color : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, color: Colors.white, size: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ),
              InkWell(
                onTap: () => onChanged(value + 1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildQuestionCard(int number, Map<String, dynamic> question) {
    final difficulty = question['difficulty'] as String? ?? 'medium';
    final difficultyColor = {
      'easy': Colors.green,
      'medium': Colors.orange,
      'hard': Colors.red,
    }[difficulty] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  radius: 14,
                  child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    difficulty.toUpperCase(),
                    style: TextStyle(color: difficultyColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _validatedQuestions.removeAt(number - 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question text
            Text(
              question['question'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),

            // Options
            if (question['options'] != null) ...[
              const SizedBox(height: 12),
              ...((question['options'] as List).asMap().entries.map((entry) {
                final idx = entry.key;
                final option = entry.value.toString();
                final letter = ['A', 'B', 'C', 'D'][idx];
                final correctAnswer = question['correctAnswer'] as String? ?? 'A';
                final isCorrect = correctAnswer.startsWith(letter);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect ? Colors.green : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isCorrect) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      if (!isCorrect) Icon(Icons.circle_outlined, color: Colors.grey[400], size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(option, style: TextStyle(
                        color: isCorrect ? Colors.green[700] : null,
                        fontWeight: isCorrect ? FontWeight.w500 : null,
                      ))),
                    ],
                  ),
                );
              })),
            ],

            // Explanation
            if (question['explanation'] != null && (question['explanation'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question['explanation'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}