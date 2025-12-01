// screens/instructor/quiz_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart'; // for localeProvider
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
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.question_answer), text: isVietnamese ? 'Ngân hàng câu hỏi' : 'Question Bank'),
            Tab(icon: const Icon(Icons.quiz), text: isVietnamese ? 'Danh sách Quiz' : 'Quiz List'),
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
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
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
            label: Text(isVietnamese ? 'Thêm câu hỏi' : 'Add Question'),
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
                    hintText: isVietnamese ? 'Tìm kiếm câu hỏi...' : 'Search questions...',
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
                  decoration: InputDecoration(
                    labelText: isVietnamese ? 'Độ khó' : 'Difficulty',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isVietnamese ? 'Tất cả' : 'All')),
                    DropdownMenuItem(
                      value: QuestionDifficulty.easy,
                      child: Row(
                        children: [
                          _buildDifficultyDot(QuestionDifficulty.easy),
                          const SizedBox(width: 8),
                          Text(isVietnamese ? 'Dễ' : 'Easy'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: QuestionDifficulty.medium,
                      child: Row(
                        children: [
                          _buildDifficultyDot(QuestionDifficulty.medium),
                          const SizedBox(width: 8),
                          Text(isVietnamese ? 'Trung bình' : 'Medium'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: QuestionDifficulty.hard,
                      child: Row(
                        children: [
                          _buildDifficultyDot(QuestionDifficulty.hard),
                          const SizedBox(width: 8),
                          Text(isVietnamese ? 'Khó' : 'Hard'),
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
              _buildStatChip(isVietnamese ? 'Tổng' : 'Total', allQuestions.length, Colors.blue),
              _buildStatChip(
                isVietnamese ? 'Dễ' : 'Easy',
                allQuestions.where((q) => q.difficulty == QuestionDifficulty.easy).length,
                Colors.green,
              ),
              _buildStatChip(
                isVietnamese ? 'TB' : 'Med',
                allQuestions.where((q) => q.difficulty == QuestionDifficulty.medium).length,
                Colors.orange,
              ),
              _buildStatChip(
                isVietnamese ? 'Khó' : 'Hard',
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
                            ? (isVietnamese ? 'Không tìm thấy câu hỏi' : 'No questions found')
                            : (isVietnamese ? 'Chưa có câu hỏi nào' : 'No questions yet'),
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
    final isVietnamese = ref.read(localeProvider).languageCode == 'vi';
    final questionCtrl = TextEditingController();
    final choiceCtrls = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    QuestionDifficulty difficulty = QuestionDifficulty.medium;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isVietnamese ? 'Thêm câu hỏi' : 'Add Question'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: questionCtrl,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Câu hỏi *' : 'Question *',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                  ),
                  const SizedBox(height: 16),
                  Text(isVietnamese ? 'Đáp án:' : 'Answers:', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                labelText: isVietnamese ? 'Đáp án ${String.fromCharCode(65 + i)} *' : 'Answer ${String.fromCharCode(65 + i)} *',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<QuestionDifficulty>(
                    value: difficulty,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Độ khó *' : 'Difficulty *',
                      border: const OutlineInputBorder(),
                    ),
                    items: QuestionDifficulty.values.map((d) {
                      String label;
                      switch (d) {
                        case QuestionDifficulty.easy:
                          label = isVietnamese ? 'Dễ' : 'Easy';
                          break;
                        case QuestionDifficulty.medium:
                          label = isVietnamese ? 'Trung bình' : 'Medium';
                          break;
                        case QuestionDifficulty.hard:
                          label = isVietnamese ? 'Khó' : 'Hard';
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
              child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
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
                      SnackBar(content: Text(isVietnamese ? 'Đã thêm câu hỏi' : 'Question added')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
                    );
                  }
                }
              },
              child: Text(isVietnamese ? 'Thêm' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQuestionDialog(BuildContext context, Question question) {
    final isVietnamese = ref.read(localeProvider).languageCode == 'vi';
    final questionCtrl = TextEditingController(text: question.questionText);
    final choiceCtrls = question.choices.map((c) => TextEditingController(text: c)).toList();
    int correctIndex = question.correctAnswerIndex;
    QuestionDifficulty difficulty = question.difficulty;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isVietnamese ? 'Sửa câu hỏi' : 'Edit Question'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: questionCtrl,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Câu hỏi *' : 'Question *',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                  ),
                  const SizedBox(height: 16),
                  Text(isVietnamese ? 'Đáp án:' : 'Answers:', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                labelText: isVietnamese ? 'Đáp án ${String.fromCharCode(65 + i)} *' : 'Answer ${String.fromCharCode(65 + i)} *',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<QuestionDifficulty>(
                    value: difficulty,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Độ khó *' : 'Difficulty *',
                      border: const OutlineInputBorder(),
                    ),
                    items: QuestionDifficulty.values.map((d) {
                      String label;
                      switch (d) {
                        case QuestionDifficulty.easy:
                          label = isVietnamese ? 'Dễ' : 'Easy';
                          break;
                        case QuestionDifficulty.medium:
                          label = isVietnamese ? 'Trung bình' : 'Medium';
                          break;
                        case QuestionDifficulty.hard:
                          label = isVietnamese ? 'Khó' : 'Hard';
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
              child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
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
                      SnackBar(content: Text(isVietnamese ? 'Đã cập nhật câu hỏi' : 'Question updated')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
                    );
                  }
                }
              },
              child: Text(isVietnamese ? 'Lưu' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteQuestion(String questionId) async {
    final isVietnamese = ref.read(localeProvider).languageCode == 'vi';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVietnamese ? 'Xóa câu hỏi?' : 'Delete Question?'),
        content: Text(isVietnamese ? 'Bạn có chắc muốn xóa câu hỏi này?' : 'Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isVietnamese ? 'Xóa' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(questionProvider.notifier).deleteQuestion(questionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVietnamese ? 'Đã xóa câu hỏi' : 'Question deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
          );
        }
      }
    }
  }
}

// Question Card Widget
class _QuestionCard extends ConsumerWidget {
  final Question question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
    Color difficultyColor;
    String difficultyLabel;
    switch (question.difficulty) {
      case QuestionDifficulty.easy:
        difficultyColor = Colors.green;
        difficultyLabel = isVietnamese ? 'Dễ' : 'Easy';
        break;
      case QuestionDifficulty.medium:
        difficultyColor = Colors.orange;
        difficultyLabel = isVietnamese ? 'Trung bình' : 'Medium';
        break;
      case QuestionDifficulty.hard:
        difficultyColor = Colors.red;
        difficultyLabel = isVietnamese ? 'Khó' : 'Hard';
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
                Text(
                  isVietnamese ? 'Đáp án:' : 'Answers:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
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
            label: Text(isVietnamese ? 'Tạo Quiz' : 'Create Quiz'),
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
              isVietnamese ? 'Vui lòng thêm câu hỏi vào ngân hàng trước' : 'Please add questions to the bank first',
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
                        isVietnamese ? 'Chưa có quiz nào' : 'No quizzes yet',
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
  final isVietnamese = ref.read(localeProvider).languageCode == 'vi';
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
          title: Text(isVietnamese ? 'Tạo Quiz' : 'Create Quiz'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Tiêu đề *' : 'Title *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Mô tả' : 'Description',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maxAttemptsCtrl,
                          decoration: InputDecoration(
                            labelText: isVietnamese ? 'Số lần làm *' : 'Max Attempts *',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty == true) return isVietnamese ? 'Bắt buộc' : 'Required';
                            if (int.tryParse(v!) == null) return isVietnamese ? 'Số không hợp lệ' : 'Invalid number';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: durationCtrl,
                          decoration: InputDecoration(
                            labelText: isVietnamese ? 'Thời gian (phút) *' : 'Duration (min) *',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty == true) return isVietnamese ? 'Bắt buộc' : 'Required';
                            if (int.tryParse(v!) == null) return isVietnamese ? 'Số không hợp lệ' : 'Invalid number';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(isVietnamese ? 'Thời gian mở' : 'Open Time'),
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
                    title: Text(isVietnamese ? 'Thời gian đóng' : 'Close Time'),
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
                  Text(
                    isVietnamese ? 'Chế độ chọn câu hỏi:' : 'Question Selection Mode:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'manual',
                        label: Text(isVietnamese ? 'Chọn thủ công' : 'Manual'),
                        icon: const Icon(Icons.touch_app),
                      ),
                      ButtonSegment(
                        value: 'auto',
                        label: Text(isVietnamese ? 'Tự động' : 'Auto'),
                        icon: const Icon(Icons.auto_awesome),
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
                        Text(
                          isVietnamese ? 'Câu hỏi đã chọn:' : 'Selected Questions:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                      label: Text(isVietnamese ? 'Chọn câu hỏi' : 'Select Questions'),
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
                                  isVietnamese
                                    ? 'Hệ thống sẽ tự động chọn ngẫu nhiên câu hỏi theo số lượng bạn nhập'
                                    : 'System will randomly select questions based on the quantity you enter',
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
                            isVietnamese
                              ? 'Ngân hàng câu hỏi: ${easyQuestions.length} dễ, ${mediumQuestions.length} TB, ${hardQuestions.length} khó'
                              : 'Question bank: ${easyQuestions.length} easy, ${mediumQuestions.length} med, ${hardQuestions.length} hard',
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
                              labelText: isVietnamese ? 'Câu dễ' : 'Easy',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.circle, color: Colors.green, size: 16),
                              helperText: '${isVietnamese ? 'Tối đa' : 'Max'}: ${easyQuestions.length}',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                final num = int.tryParse(v);
                                if (num == null) return isVietnamese ? 'Số không hợp lệ' : 'Invalid';
                                if (num > easyQuestions.length) return '${isVietnamese ? 'Vượt quá' : 'Max'} ${easyQuestions.length}';
                                if (num < 0) return '>= 0';
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
                              labelText: isVietnamese ? 'Câu TB' : 'Medium',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.circle, color: Colors.orange, size: 16),
                              helperText: '${isVietnamese ? 'Tối đa' : 'Max'}: ${mediumQuestions.length}',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                final num = int.tryParse(v);
                                if (num == null) return isVietnamese ? 'Số không hợp lệ' : 'Invalid';
                                if (num > mediumQuestions.length) return '${isVietnamese ? 'Vượt quá' : 'Max'} ${mediumQuestions.length}';
                                if (num < 0) return '>= 0';
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
                              labelText: isVietnamese ? 'Câu khó' : 'Hard',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.circle, color: Colors.red, size: 16),
                              helperText: '${isVietnamese ? 'Tối đa' : 'Max'}: ${hardQuestions.length}',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                final num = int.tryParse(v);
                                if (num == null) return isVietnamese ? 'Số không hợp lệ' : 'Invalid';
                                if (num > hardQuestions.length) return '${isVietnamese ? 'Vượt quá' : 'Max'} ${hardQuestions.length}';
                                if (num < 0) return '>= 0';
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
                              isVietnamese
                                ? 'Tổng: ${(int.tryParse(easyCountCtrl.text) ?? 0) + (int.tryParse(mediumCountCtrl.text) ?? 0) + (int.tryParse(hardCountCtrl.text) ?? 0)} câu hỏi'
                                : 'Total: ${(int.tryParse(easyCountCtrl.text) ?? 0) + (int.tryParse(mediumCountCtrl.text) ?? 0) + (int.tryParse(hardCountCtrl.text) ?? 0)} questions',
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
              child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
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
                      SnackBar(content: Text(isVietnamese ? 'Vui lòng chọn ít nhất 1 câu hỏi' : 'Please select at least 1 question')),
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
                      SnackBar(content: Text(isVietnamese ? 'Vui lòng nhập số lượng câu hỏi' : 'Please enter question quantity')),
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
                              ? (isVietnamese ? 'Đã tạo quiz với ${finalQuestionIds.length} câu hỏi' : 'Created quiz with ${finalQuestionIds.length} questions')
                              : (isVietnamese ? 'Đã tạo quiz tự động với ${finalQuestionIds.length} câu hỏi' : 'Auto-created quiz with ${finalQuestionIds.length} questions'),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
                    );
                  }
                }
              },
              child: Text(isVietnamese ? 'Tạo' : 'Create'),
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
    final isVietnamese = ref.read(localeProvider).languageCode == 'vi';
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
            title: Text(isVietnamese ? 'Chọn câu hỏi' : 'Select Questions'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: Column(
                children: [
                  // Search
                  TextField(
                    decoration: InputDecoration(
                      hintText: isVietnamese ? 'Tìm kiếm...' : 'Search...',
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
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Lọc theo độ khó' : 'Filter by difficulty',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(isVietnamese ? 'Tất cả' : 'All')),
                      DropdownMenuItem(value: QuestionDifficulty.easy, child: Text(isVietnamese ? 'Dễ' : 'Easy')),
                      DropdownMenuItem(value: QuestionDifficulty.medium, child: Text(isVietnamese ? 'Trung bình' : 'Medium')),
                      DropdownMenuItem(value: QuestionDifficulty.hard, child: Text(isVietnamese ? 'Khó' : 'Hard')),
                    ],
                    onChanged: (value) => setDialogState(() => filterDifficulty = value),
                  ),
                  const SizedBox(height: 8),
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isVietnamese ? 'Đã chọn: ${selected.length}' : 'Selected: ${selected.length}'),
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
                              ? (isVietnamese ? 'Bỏ chọn tất cả' : 'Deselect All')
                              : (isVietnamese ? 'Chọn tất cả' : 'Select All'),
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
                            difficultyLabel = isVietnamese ? 'Dễ' : 'Easy';
                            break;
                          case QuestionDifficulty.medium:
                            difficultyColor = Colors.orange;
                            difficultyLabel = isVietnamese ? 'Trung bình' : 'Medium';
                            break;
                          case QuestionDifficulty.hard:
                            difficultyColor = Colors.red;
                            difficultyLabel = isVietnamese ? 'Khó' : 'Hard';
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
                child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  onConfirm(selected);
                  Navigator.pop(ctx);
                },
                child: Text(isVietnamese ? 'Xác nhận (${selected.length})' : 'Confirm (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteQuiz(String quizId) async {
    final isVietnamese = ref.read(localeProvider).languageCode == 'vi';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVietnamese ? 'Xóa quiz?' : 'Delete Quiz?'),
        content: Text(isVietnamese ? 'Bạn có chắc muốn xóa quiz này?' : 'Are you sure you want to delete this quiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isVietnamese ? 'Xóa' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(quizProvider.notifier).deleteQuiz(quizId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVietnamese ? 'Đã xóa quiz' : 'Quiz deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
          );
        }
      }
    }
  }
}

// Quiz Card Widget
class _QuizCard extends ConsumerWidget {
  final Quiz quiz;
  final VoidCallback onDelete;

  const _QuizCard({
    required this.quiz,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
    final now = DateTime.now();
    final isOpen = now.isAfter(quiz.openTime) && now.isBefore(quiz.closeTime);
    final isClosed = now.isAfter(quiz.closeTime);

    Color statusColor;
    String statusText;
    if (isClosed) {
      statusColor = Colors.red;
      statusText = isVietnamese ? 'Đã đóng' : 'Closed';
    } else if (isOpen) {
      statusColor = Colors.green;
      statusText = isVietnamese ? 'Đang mở' : 'Open';
    } else {
      statusColor = Colors.orange;
      statusText = isVietnamese ? 'Sắp mở' : 'Coming Soon';
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
                _buildInfoChip(Icons.question_answer, '${quiz.questionIds.length} ${isVietnamese ? 'câu hỏi' : 'questions'}'),
                _buildInfoChip(Icons.timer, '${quiz.durationMinutes} ${isVietnamese ? 'phút' : 'min'}'),
                _buildInfoChip(Icons.repeat, '${quiz.maxAttempts} ${isVietnamese ? 'lần làm' : 'attempts'}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${isVietnamese ? 'Mở' : 'Open'}: ${quiz.openTime.day}/${quiz.openTime.month} ${quiz.openTime.hour}:${quiz.openTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.lock_clock, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${isVietnamese ? 'Đóng' : 'Close'}: ${quiz.closeTime.day}/${quiz.closeTime.month} ${quiz.closeTime.hour}:${quiz.closeTime.minute.toString().padLeft(2, '0')}',
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