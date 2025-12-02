// lib/screens/instructor/ai_quiz_generator_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
import '../../models/course.dart';
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
  
  int _numberOfQuestions = 5;
  QuizDifficulty _difficulty = QuizDifficulty.medium;
  final Set<QuestionType> _selectedTypes = {QuestionType.multipleChoice};
  
  bool _isGenerating = false;
  List<Map<String, dynamic>> _generatedQuestions = [];
  String? _error;

  bool _isVietnamese() => ref.watch(localeProvider).languageCode == 'vi';

  Future<void> _generateQuestions() async {
    if (_materialController.text.trim().isEmpty) {
      setState(() => _error = _isVietnamese() 
          ? 'Vui lòng nhập tài liệu hoặc nội dung bài học' 
          : 'Please enter material or lesson content');
      return;
    }

    if (_selectedTypes.isEmpty) {
      setState(() => _error = _isVietnamese()
          ? 'Vui lòng chọn ít nhất một loại câu hỏi'
          : 'Please select at least one question type');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedQuestions = [];
    });

    try {
      final questions = await AIService.generateQuizQuestions(
        material: _materialController.text,
        numberOfQuestions: _numberOfQuestions,
        difficulty: _difficulty,
        questionTypes: _selectedTypes.toList(),
        topic: _topicController.text.isNotEmpty ? _topicController.text : null,
        language: _isVietnamese() ? 'vi' : 'en',
      );

      final validated = AIService.validateQuestions(questions);

      setState(() {
        _generatedQuestions = validated;
        if (validated.isEmpty) {
          _error = _isVietnamese()
              ? 'Không thể tạo câu hỏi hợp lệ. Vui lòng thử lại.'
              : 'Could not generate valid questions. Please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveToQuiz() async {
    if (_generatedQuestions.isEmpty) return;

    final isVi = _isVietnamese();
    
    // Show dialog to get quiz title
    final titleController = TextEditingController(
      text: _topicController.text.isNotEmpty 
          ? _topicController.text 
          : '${widget.course.code} - AI Generated Quiz',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVi ? 'Lưu vào Quiz' : 'Save to Quiz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: isVi ? 'Tên Quiz' : 'Quiz Title',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isVi 
                  ? 'Sẽ tạo quiz mới với ${_generatedQuestions.length} câu hỏi'
                  : 'Will create new quiz with ${_generatedQuestions.length} questions',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVi ? 'Tạo Quiz' : 'Create Quiz'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      // Convert generated questions to quiz format
      // This depends on your quiz model structure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? '✅ Đã lưu quiz thành công!' : '✅ Quiz saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
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
        title: Text(isVi ? '🤖 AI Tạo Câu Hỏi' : '🤖 AI Quiz Generator'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
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
            const SizedBox(height: 24),

            // Material Input
            Text(
              isVi ? '📚 Tài liệu / Nội dung bài học *' : '📚 Material / Lesson Content *',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _materialController,
              maxLines: 8,
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

            // Settings
            Text(
              isVi ? '⚙️ Cài đặt' : '⚙️ Settings',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Number of questions
            Row(
              children: [
                Text(isVi ? 'Số câu hỏi:' : 'Questions:'),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _numberOfQuestions,
                  items: [3, 5, 10, 15, 20].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                  onChanged: (v) => setState(() => _numberOfQuestions = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Difficulty
            Text(isVi ? 'Độ khó:' : 'Difficulty:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: QuizDifficulty.values.map((d) {
                final isSelected = _difficulty == d;
                final label = {
                  QuizDifficulty.easy: isVi ? '🟢 Dễ' : '🟢 Easy',
                  QuizDifficulty.medium: isVi ? '🟡 Trung bình' : '🟡 Medium',
                  QuizDifficulty.hard: isVi ? '🔴 Khó' : '🔴 Hard',
                }[d]!;
                
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _difficulty = d),
                  selectedColor: Colors.deepPurple.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Question Types
            Text(isVi ? 'Loại câu hỏi:' : 'Question Types:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuestionType.values.map((t) {
                final isSelected = _selectedTypes.contains(t);
                final label = {
                  QuestionType.multipleChoice: isVi ? 'Trắc nghiệm' : 'Multiple Choice',
                  QuestionType.trueFalse: isVi ? 'Đúng/Sai' : 'True/False',
                  QuestionType.shortAnswer: isVi ? 'Tự luận ngắn' : 'Short Answer',
                  QuestionType.fillInBlank: isVi ? 'Điền khuyết' : 'Fill in Blank',
                }[t]!;
                
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTypes.add(t);
                      } else {
                        _selectedTypes.remove(t);
                      }
                    });
                  },
                  selectedColor: Colors.deepPurple.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Error
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
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating || !AIService.isConfigured ? null : _generateQuestions,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGenerating
                    ? (isVi ? 'Đang tạo câu hỏi...' : 'Generating...')
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

            // Generated Questions
            if (_generatedQuestions.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    isVi ? '📝 Câu hỏi đã tạo (${_generatedQuestions.length})' : '📝 Generated Questions (${_generatedQuestions.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saveToQuiz,
                    icon: const Icon(Icons.save),
                    label: Text(isVi ? 'Lưu vào Quiz' : 'Save to Quiz'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              ..._generatedQuestions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return _buildQuestionCard(index + 1, question);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int number, Map<String, dynamic> question) {
    final isVi = _isVietnamese();
    final type = question['type'] as String? ?? 'multipleChoice';
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(type, style: const TextStyle(fontSize: 10)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () {
                    setState(() {
                      _generatedQuestions.removeAt(number - 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question
            Text(
              question['question'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),

            // Options (for multiple choice)
            if (type == 'multipleChoice' && question['options'] != null) ...[
              const SizedBox(height: 12),
              ...((question['options'] as List).map((option) {
                final isCorrect = option.toString().startsWith(question['correctAnswer'] ?? '');
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
                      if (isCorrect) const SizedBox(width: 8),
                      Expanded(child: Text(option.toString())),
                    ],
                  ),
                );
              })),
            ],

            // Correct Answer (for other types)
            if (type != 'multipleChoice') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${isVi ? "Đáp án" : "Answer"}: ${question['correctAnswer']}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Explanation
            if (question['explanation'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? '💡 Giải thích:' : '💡 Explanation:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question['explanation'] as String,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
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

  @override
  void dispose() {
    _materialController.dispose();
    _topicController.dispose();
    super.dispose();
  }
}