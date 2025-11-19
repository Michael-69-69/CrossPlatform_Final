// screens/instructor/quiz_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/question.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_provider.dart';

class QuizTab extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;

  const QuizTab({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  ConsumerState<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends ConsumerState<QuizTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(questionProvider.notifier).loadQuestions(courseId: widget.courseId);
      ref.read(quizProvider.notifier).loadQuizzes(courseId: widget.courseId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.question_answer), text: 'Ngân hàng câu hỏi'),
            Tab(icon: Icon(Icons.quiz), text: 'Danh sách Quiz'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _QuestionBankTab(courseId: widget.courseId),
              _QuizListTab(courseId: widget.courseId),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// QUESTION BANK TAB
// ============================================================================

class _QuestionBankTab extends ConsumerStatefulWidget {
  final String courseId;

  const _QuestionBankTab({required this.courseId});

  @override
  ConsumerState<_QuestionBankTab> createState() => _QuestionBankTabState();
}

class _QuestionBankTabState extends ConsumerState<_QuestionBankTab> {
  String _searchQuery = '';
  QuestionDifficulty? _filterDifficulty;

  @override
  Widget build(BuildContext context) {
    final allQuestions = ref.watch(questionProvider)
        .where((q) => q.courseId == widget.courseId)
        .toList();

    // Apply filters
    var filteredQuestions = allQuestions;
    
    if (_searchQuery.isNotEmpty) {
      filteredQuestions = filteredQuestions.where((q) {
        return q.questionText.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               q.choices.any((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    if (_filterDifficulty != null) {
      filteredQuestions = filteredQuestions
          .where((q) => q.difficulty == _filterDifficulty)
          .toList();
    }

    return Column(
      children: [
        // Header with Add Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm câu hỏi'),
            onPressed: () => _showAddQuestionDialog(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        
        // Search and Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm câu hỏi...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<QuestionDifficulty?>(
                  value: _filterDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Độ khó',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả')),
                    DropdownMenuItem(
                      value: QuestionDifficulty.easy,
                      child: Row(
                        children: [
                          _buildDifficultyDot(QuestionDifficulty.easy),
                          const SizedBox(width: 8),
                          const Text('Dễ'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: QuestionDifficulty.medium,
                      child: Row(
                        children: [
                          _buildDifficultyDot(QuestionDifficulty.medium),
                          const SizedBox(width: 8),
                          const Text('Trung bình'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: QuestionDifficulty.hard,
                      child: Row(
                        children: [
                          _buildDifficultyDot(QuestionDifficulty.hard),
                          const SizedBox(width: 8),
                          const Text('Khó'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _filterDifficulty = value),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('Tổng', allQuestions.length, Colors.blue),
              _buildStatChip(
                'Dễ',
                allQuestions.where((q) => q.difficulty == QuestionDifficulty.easy).length,
                Colors.green,
              ),
              _buildStatChip(
                'TB',
                allQuestions.where((q) => q.difficulty == QuestionDifficulty.medium).length,
                Colors.orange,
              ),
              _buildStatChip(
                'Khó',
                allQuestions.where((q) => q.difficulty == QuestionDifficulty.hard).length,
                Colors.red,
              ),
            ],
          ),
        ),
        
        const Divider(),
        
        // Questions List
        Expanded(
          child: filteredQuestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.question_answer, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _filterDifficulty != null
                            ? 'Không tìm thấy câu hỏi'
                            : 'Chưa có câu hỏi nào',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredQuestions.length,
                  itemBuilder: (context, index) {
                    final question = filteredQuestions[index];
                    return _QuestionCard(
                      question: question,
                      onEdit: () => _showEditQuestionDialog(context, question),
                      onDelete: () => _deleteQuestion(question.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDifficultyDot(QuestionDifficulty difficulty) {
    Color color;
    switch (difficulty) {
      case QuestionDifficulty.easy:
        color = Colors.green;
        break;
      case QuestionDifficulty.medium:
        color = Colors.orange;
        break;
      case QuestionDifficulty.hard:
        color = Colors.red;
        break;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          count.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  void _showAddQuestionDialog(BuildContext context) {
    final questionCtrl = TextEditingController();
    final choiceCtrls = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    QuestionDifficulty difficulty = QuestionDifficulty.medium;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm câu hỏi'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: questionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Câu hỏi *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Đáp án:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(4, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: correctIndex,
                            onChanged: (v) => setDialogState(() => correctIndex = v!),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: choiceCtrls[i],
                              decoration: InputDecoration(
                                labelText: 'Đáp án ${String.fromCharCode(65 + i)} *',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<QuestionDifficulty>(
                    value: difficulty,
                    decoration: const InputDecoration(
                      labelText: 'Độ khó *',
                      border: OutlineInputBorder(),
                    ),
                    items: QuestionDifficulty.values.map((d) {
                      String label;
                      switch (d) {
                        case QuestionDifficulty.easy:
                          label = 'Dễ';
                          break;
                        case QuestionDifficulty.medium:
                          label = 'Trung bình';
                          break;
                        case QuestionDifficulty.hard:
                          label = 'Khó';
                          break;
                      }
                      return DropdownMenuItem(
                        value: d,
                        child: Row(
                          children: [
                            _buildDifficultyDot(d),
                            const SizedBox(width: 8),
                            Text(label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => difficulty = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ref.read(questionProvider.notifier).createQuestion(
                        courseId: widget.courseId,
                        questionText: questionCtrl.text.trim(),
                        choices: choiceCtrls.map((c) => c.text.trim()).toList(),
                        correctAnswerIndex: correctIndex,
                        difficulty: difficulty,
                      );
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã thêm câu hỏi')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQuestionDialog(BuildContext context, Question question) {
    final questionCtrl = TextEditingController(text: question.questionText);
    final choiceCtrls = question.choices.map((c) => TextEditingController(text: c)).toList();
    int correctIndex = question.correctAnswerIndex;
    QuestionDifficulty difficulty = question.difficulty;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sửa câu hỏi'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: questionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Câu hỏi *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Đáp án:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(choiceCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: correctIndex,
                            onChanged: (v) => setDialogState(() => correctIndex = v!),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: choiceCtrls[i],
                              decoration: InputDecoration(
                                labelText: 'Đáp án ${String.fromCharCode(65 + i)} *',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<QuestionDifficulty>(
                    value: difficulty,
                    decoration: const InputDecoration(
                      labelText: 'Độ khó *',
                      border: OutlineInputBorder(),
                    ),
                    items: QuestionDifficulty.values.map((d) {
                      String label;
                      switch (d) {
                        case QuestionDifficulty.easy:
                          label = 'Dễ';
                          break;
                        case QuestionDifficulty.medium:
                          label = 'Trung bình';
                          break;
                        case QuestionDifficulty.hard:
                          label = 'Khó';
                          break;
                      }
                      return DropdownMenuItem(
                        value: d,
                        child: Row(
                          children: [
                            _buildDifficultyDot(d),
                            const SizedBox(width: 8),
                            Text(label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => difficulty = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final updatedQuestion = question.copyWith(
                    questionText: questionCtrl.text.trim(),
                    choices: choiceCtrls.map((c) => c.text.trim()).toList(),
                    correctAnswerIndex: correctIndex,
                    difficulty: difficulty,
                  );
                  
                  await ref.read(questionProvider.notifier).updateQuestion(updatedQuestion);
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật câu hỏi')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteQuestion(String questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa câu hỏi?'),
        content: const Text('Bạn có chắc muốn xóa câu hỏi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(questionProvider.notifier).deleteQuestion(questionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa câu hỏi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }
}

// Question Card Widget
class _QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color difficultyColor;
    String difficultyLabel;
    switch (question.difficulty) {
      case QuestionDifficulty.easy:
        difficultyColor = Colors.green;
        difficultyLabel = 'Dễ';
        break;
      case QuestionDifficulty.medium:
        difficultyColor = Colors.orange;
        difficultyLabel = 'Trung bình';
        break;
      case QuestionDifficulty.hard:
        difficultyColor = Colors.red;
        difficultyLabel = 'Khó';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: difficultyColor,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          question.questionText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(difficultyLabel, style: TextStyle(color: difficultyColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đáp án:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(question.choices.length, (index) {
                  final isCorrect = index == question.correctAnswerIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isCorrect ? Colors.green : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? Colors.green : Colors.grey[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            question.choices[index],
                            style: TextStyle(
                              color: isCorrect ? Colors.green[700] : null,
                              fontWeight: isCorrect ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (isCorrect)
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QUIZ LIST TAB
// ============================================================================

class _QuizListTab extends ConsumerStatefulWidget {
  final String courseId;

  const _QuizListTab({required this.courseId});

  @override
  ConsumerState<_QuizListTab> createState() => _QuizListTabState();
}

class _QuizListTabState extends ConsumerState<_QuizListTab> {
  @override
  Widget build(BuildContext context) {
    final quizzes = ref.watch(quizProvider)
        .where((q) => q.courseId == widget.courseId)
        .toList();

    final questions = ref.watch(questionProvider)
        .where((q) => q.courseId == widget.courseId)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Tạo Quiz'),
            onPressed: questions.isEmpty
                ? null
                : () => _showCreateQuizDialog(context, questions),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        if (questions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Vui lòng thêm câu hỏi vào ngân hàng trước',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        Expanded(
          child: quizzes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có quiz nào',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = quizzes[index];
                    return _QuizCard(
                      quiz: quiz,
                      onDelete: () => _deleteQuiz(quiz.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

void _showCreateQuizDialog(BuildContext context, List<Question> questions) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final maxAttemptsCtrl = TextEditingController(text: '1');
  final durationCtrl = TextEditingController(text: '60');
  
  // Automatic mode controllers
  final easyCountCtrl = TextEditingController();
  final mediumCountCtrl = TextEditingController();
  final hardCountCtrl = TextEditingController();
  
  DateTime openTime = DateTime.now();
  DateTime closeTime = DateTime.now().add(const Duration(days: 7));
  final selectedQuestionIds = <String>{};
  final formKey = GlobalKey<FormState>();
  
  // Selection mode: 'manual' or 'auto'
  String selectionMode = 'manual';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        // Calculate available questions by difficulty
        final easyQuestions = questions.where((q) => q.difficulty == QuestionDifficulty.easy).toList();
        final mediumQuestions = questions.where((q) => q.difficulty == QuestionDifficulty.medium).toList();
        final hardQuestions = questions.where((q) => q.difficulty == QuestionDifficulty.hard).toList();

        return AlertDialog(
          title: const Text('Tạo Quiz'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maxAttemptsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Số lần làm *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty == true) return 'Bắt buộc';
                            if (int.tryParse(v!) == null) return 'Số không hợp lệ';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: durationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Thời gian (phút) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty == true) return 'Bắt buộc';
                            if (int.tryParse(v!) == null) return 'Số không hợp lệ';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Thời gian mở'),
                    subtitle: Text('${openTime.day}/${openTime.month}/${openTime.year} ${openTime.hour}:${openTime.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: openTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(openTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            openTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Thời gian đóng'),
                    subtitle: Text('${closeTime.day}/${closeTime.month}/${closeTime.year} ${closeTime.hour}:${closeTime.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: closeTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(closeTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            closeTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // ✅ NEW: Mode Selection
                  const Text(
                    'Chế độ chọn câu hỏi:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'manual',
                        label: Text('Chọn thủ công'),
                        icon: Icon(Icons.touch_app),
                      ),
                      ButtonSegment(
                        value: 'auto',
                        label: Text('Tự động'),
                        icon: Icon(Icons.auto_awesome),
                      ),
                    ],
                    selected: {selectionMode},
                    onSelectionChanged: (Set<String> newSelection) {
                      setDialogState(() {
                        selectionMode = newSelection.first;
                        // Clear selections when switching modes
                        selectedQuestionIds.clear();
                        easyCountCtrl.clear();
                        mediumCountCtrl.clear();
                        hardCountCtrl.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // ✅ Manual Mode
                  if (selectionMode == 'manual') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Câu hỏi đã chọn:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${selectedQuestionIds.length}/${questions.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.question_answer),
                      label: const Text('Chọn câu hỏi'),
                      onPressed: () {
                        _showSelectQuestionsDialog(
                          context,
                          questions,
                          selectedQuestionIds,
                          (selected) {
                            setDialogState(() {
                              selectedQuestionIds.clear();
                              selectedQuestionIds.addAll(selected);
                            });
                          },
                        );
                      },
                    ),
                    if (selectedQuestionIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: selectedQuestionIds.map((id) {
                            final question = questions.firstWhere((q) => q.id == id);
                            return Chip(
                              label: Text(
                                question.questionText.length > 30
                                    ? '${question.questionText.substring(0, 30)}...'
                                    : question.questionText,
                                style: const TextStyle(fontSize: 11),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setDialogState(() {
                                  selectedQuestionIds.remove(id);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                  
                  // ✅ Automatic Mode
                  if (selectionMode == 'auto') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hệ thống sẽ tự động chọn ngẫu nhiên câu hỏi theo số lượng bạn nhập',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ngân hàng câu hỏi: ${easyQuestions.length} dễ, ${mediumQuestions.length} TB, ${hardQuestions.length} khó',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: easyCountCtrl,
                            decoration: InputDecoration(
                              labelText: 'Câu dễ',
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(Icons.circle, color: Colors.green, size: 16),
                              helperText: 'Tối đa: ${easyQuestions.length}',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                final num = int.tryParse(v);
                                if (num == null) return 'Số không hợp lệ';
                                if (num > easyQuestions.length) return 'Vượt quá ${easyQuestions.length}';
                                if (num < 0) return 'Phải >= 0';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: mediumCountCtrl,
                            decoration: InputDecoration(
                              labelText: 'Câu TB',
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(Icons.circle, color: Colors.orange, size: 16),
                              helperText: 'Tối đa: ${mediumQuestions.length}',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                final num = int.tryParse(v);
                                if (num == null) return 'Số không hợp lệ';
                                if (num > mediumQuestions.length) return 'Vượt quá ${mediumQuestions.length}';
                                if (num < 0) return 'Phải >= 0';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: hardCountCtrl,
                            decoration: InputDecoration(
                              labelText: 'Câu khó',
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(Icons.circle, color: Colors.red, size: 16),
                              helperText: 'Tối đa: ${hardQuestions.length}',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                final num = int.tryParse(v);
                                if (num == null) return 'Số không hợp lệ';
                                if (num > hardQuestions.length) return 'Vượt quá ${hardQuestions.length}';
                                if (num < 0) return 'Phải >= 0';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Preview selected count
                    if (easyCountCtrl.text.isNotEmpty ||
                        mediumCountCtrl.text.isNotEmpty ||
                        hardCountCtrl.text.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Tổng: ${(int.tryParse(easyCountCtrl.text) ?? 0) + (int.tryParse(mediumCountCtrl.text) ?? 0) + (int.tryParse(hardCountCtrl.text) ?? 0)} câu hỏi',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                // ✅ Validate based on mode
                List<String> finalQuestionIds = [];
                int? easyCount;
                int? mediumCount;
                int? hardCount;

                if (selectionMode == 'manual') {
                  // Manual mode: must have selected questions
                  if (selectedQuestionIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn ít nhất 1 câu hỏi')),
                    );
                    return;
                  }
                  finalQuestionIds = selectedQuestionIds.toList();
                } else {
                  // Auto mode: must have at least one count
                  final easy = int.tryParse(easyCountCtrl.text) ?? 0;
                  final medium = int.tryParse(mediumCountCtrl.text) ?? 0;
                  final hard = int.tryParse(hardCountCtrl.text) ?? 0;

                  if (easy + medium + hard == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập số lượng câu hỏi')),
                    );
                    return;
                  }

                  // ✅ Auto-select random questions
                  final selectedEasy = easyQuestions.toList()..shuffle();
                  final selectedMedium = mediumQuestions.toList()..shuffle();
                  final selectedHard = hardQuestions.toList()..shuffle();

                  finalQuestionIds.addAll(selectedEasy.take(easy).map((q) => q.id));
                  finalQuestionIds.addAll(selectedMedium.take(medium).map((q) => q.id));
                  finalQuestionIds.addAll(selectedHard.take(hard).map((q) => q.id));
                  
                  // Shuffle final list
                  finalQuestionIds.shuffle();

                  // Store counts for auto mode
                  easyCount = easy > 0 ? easy : null;
                  mediumCount = medium > 0 ? medium : null;
                  hardCount = hard > 0 ? hard : null;
                }

                try {
                  await ref.read(quizProvider.notifier).createQuiz(
                        courseId: widget.courseId,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        openTime: openTime,
                        closeTime: closeTime,
                        maxAttempts: int.parse(maxAttemptsCtrl.text),
                        durationMinutes: int.parse(durationCtrl.text),
                        easyCount: easyCount,
                        mediumCount: mediumCount,
                        hardCount: hardCount,
                        questionIds: finalQuestionIds,
                      );
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          selectionMode == 'manual'
                              ? 'Đã tạo quiz với ${finalQuestionIds.length} câu hỏi'
                              : 'Đã tạo quiz tự động với ${finalQuestionIds.length} câu hỏi',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showSelectQuestionsDialog(
    BuildContext context,
    List<Question> questions,
    Set<String> currentSelected,
    Function(Set<String>) onConfirm,
  ) {
    final selected = Set<String>.from(currentSelected);
    String searchQuery = '';
    QuestionDifficulty? filterDifficulty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Apply filters
          var filteredQuestions = questions;
          
          if (searchQuery.isNotEmpty) {
            filteredQuestions = filteredQuestions.where((q) {
              return q.questionText.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();
          }

          if (filterDifficulty != null) {
            filteredQuestions = filteredQuestions
                .where((q) => q.difficulty == filterDifficulty)
                .toList();
          }

          return AlertDialog(
            title: const Text('Chọn câu hỏi'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: Column(
                children: [
                  // Search
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) => setDialogState(() => searchQuery = value),
                  ),
                  const SizedBox(height: 8),
                  // Filter
                  DropdownButtonFormField<QuestionDifficulty?>(
                    value: filterDifficulty,
                    decoration: const InputDecoration(
                      labelText: 'Lọc theo độ khó',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tất cả')),
                      DropdownMenuItem(value: QuestionDifficulty.easy, child: Text('Dễ')),
                      DropdownMenuItem(value: QuestionDifficulty.medium, child: Text('Trung bình')),
                      DropdownMenuItem(value: QuestionDifficulty.hard, child: Text('Khó')),
                    ],
                    onChanged: (value) => setDialogState(() => filterDifficulty = value),
                  ),
                  const SizedBox(height: 8),
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Đã chọn: ${selected.length}'),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (selected.length == filteredQuestions.length) {
                              selected.clear();
                            } else {
                              selected.addAll(filteredQuestions.map((q) => q.id));
                            }
                          });
                        },
                        child: Text(
                          selected.length == filteredQuestions.length
                              ? 'Bỏ chọn tất cả'
                              : 'Chọn tất cả',
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  // Questions list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredQuestions.length,
                      itemBuilder: (context, index) {
                        final q = filteredQuestions[index];
                        final isSelected = selected.contains(q.id);
                        
                        Color difficultyColor;
                        String difficultyLabel;
                        switch (q.difficulty) {
                          case QuestionDifficulty.easy:
                            difficultyColor = Colors.green;
                            difficultyLabel = 'Dễ';
                            break;
                          case QuestionDifficulty.medium:
                            difficultyColor = Colors.orange;
                            difficultyLabel = 'Trung bình';
                            break;
                          case QuestionDifficulty.hard:
                            difficultyColor = Colors.red;
                            difficultyLabel = 'Khó';
                            break;
                        }

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selected.add(q.id);
                              } else {
                                selected.remove(q.id);
                              }
                            });
                          },
                          title: Text(q.questionText),
                          subtitle: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: difficultyColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(difficultyLabel),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  onConfirm(selected);
                  Navigator.pop(ctx);
                },
                child: Text('Xác nhận (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteQuiz(String quizId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa quiz?'),
        content: const Text('Bạn có chắc muốn xóa quiz này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(quizProvider.notifier).deleteQuiz(quizId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa quiz')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }
}

// Quiz Card Widget
class _QuizCard extends StatelessWidget {
  final Quiz quiz;
  final VoidCallback onDelete;

  const _QuizCard({
    required this.quiz,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOpen = now.isAfter(quiz.openTime) && now.isBefore(quiz.closeTime);
    final isClosed = now.isAfter(quiz.closeTime);

    Color statusColor;
    String statusText;
    if (isClosed) {
      statusColor = Colors.red;
      statusText = 'Đã đóng';
    } else if (isOpen) {
      statusColor = Colors.green;
      statusText = 'Đang mở';
    } else {
      statusColor = Colors.orange;
      statusText = 'Sắp mở';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quiz.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(statusText),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (quiz.description != null) ...[
              const SizedBox(height: 8),
              Text(quiz.description!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.question_answer, '${quiz.questionIds.length} câu hỏi'),
                _buildInfoChip(Icons.timer, '${quiz.durationMinutes} phút'),
                _buildInfoChip(Icons.repeat, '${quiz.maxAttempts} lần làm'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Mở: ${quiz.openTime.day}/${quiz.openTime.month} ${quiz.openTime.hour}:${quiz.openTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.lock_clock, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Đóng: ${quiz.closeTime.day}/${quiz.closeTime.month} ${quiz.closeTime.hour}:${quiz.closeTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.grey[200],
    );
  }
}