// screens/instructor/quiz_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../models/quiz.dart';
import '../../models/question.dart';
import '../../models/user.dart';
import '../../providers/quiz_provider.dart';

class QuizTab extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  final List<AppUser> students;

  const QuizTab({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.students,
  });

  @override
  ConsumerState<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends ConsumerState<QuizTab> {
  String _searchQuery = '';
  String _sortBy = 'time'; // name, time
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quizProvider.notifier).loadQuizzes(courseId: widget.courseId);
      ref.read(questionProvider.notifier).loadQuestions(courseId: widget.courseId);
      ref.read(quizSubmissionProvider.notifier).loadSubmissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = ref.watch(quizProvider)
        .where((q) => q.courseId == widget.courseId)
        .toList();
    final questions = ref.watch(questionProvider)
        .where((q) => q.courseId == widget.courseId)
        .toList();

    final filteredQuizzes = _filterAndSort(quizzes);

    return Column(
      children: [
        // Header with Create buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.quiz),
                  label: const Text('Tạo Quiz'),
                  onPressed: () => _showCreateQuizDialog(context, questions),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle),
                label: const Text('Thêm câu hỏi'),
                onPressed: () => _showCreateQuestionDialog(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 48),
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm quiz...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(height: 8),
        // Sort
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Sắp xếp: '),
              DropdownButton<String>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Tên')),
                  DropdownMenuItem(value: 'time', child: Text('Thời gian')),
                ],
                onChanged: (v) => setState(() => _sortBy = v!),
              ),
              IconButton(
                icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () => setState(() => _sortAscending = !_sortAscending),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Quiz List
        Expanded(
          child: filteredQuizzes.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'Không tìm thấy quiz nào'
                        : 'Chưa có quiz nào',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredQuizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = filteredQuizzes[index];
                    return _QuizCard(
                      quiz: quiz,
                      questions: questions,
                      students: widget.students,
                      onTap: () => _showQuizDetail(context, quiz, questions),
                      onDelete: () => _deleteQuiz(quiz.id),
                      onExport: () => _exportQuizCSV(quiz),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Quiz> _filterAndSort(List<Quiz> quizzes) {
    var filtered = quizzes.where((q) {
      if (_searchQuery.isEmpty) return true;
      return q.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      if (_sortBy == 'name') {
        comparison = a.title.compareTo(b.title);
      } else if (_sortBy == 'time') {
        comparison = a.openTime.compareTo(b.openTime);
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _showCreateQuestionDialog(BuildContext context) {
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
                children: [
                  TextFormField(
                    controller: questionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Câu hỏi *',
                      hintText: 'Nhập câu hỏi...',
                    ),
                    maxLines: 3,
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 16),
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
                                labelText: 'Đáp án ${i + 1} *',
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
                      String label = '';
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
                      return DropdownMenuItem(value: d, child: Text(label));
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

  void _showCreateQuizDialog(BuildContext context, List<Question> questions) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime openTime = DateTime.now();
    DateTime closeTime = DateTime.now().add(const Duration(days: 7));
    int maxAttempts = 1;
    int durationMinutes = 60;
    int? easyCount;
    int? mediumCount;
    int? hardCount;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo Quiz'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text('Mở: ${DateFormat('dd/MM/yyyy HH:mm').format(openTime)}'),
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
                            openTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  ListTile(
                    title: Text('Đóng: ${DateFormat('dd/MM/yyyy HH:mm').format(closeTime)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: closeTime,
                        firstDate: openTime,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(closeTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            closeTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: maxAttempts.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Số lần làm tối đa *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) {
                        setDialogState(() => maxAttempts = n);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: durationMinutes.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Thời gian (phút) *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) {
                        setDialogState(() => durationMinutes = n);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Cấu trúc câu hỏi (để trống để chọn thủ công):'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Dễ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            setDialogState(() => easyCount = n);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Trung bình',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            setDialogState(() => mediumCount = n);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Khó',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            setDialogState(() => hardCount = n);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showSelectQuestionsDialog(
                      context,
                      questions,
                      easyCount,
                      mediumCount,
                      hardCount,
                      (selectedIds) {
                        setDialogState(() {
                          // Store selected question IDs
                          Navigator.pop(ctx);
                          _createQuizWithQuestions(
                            titleCtrl.text.trim(),
                            descCtrl.text.trim(),
                            openTime,
                            closeTime,
                            maxAttempts,
                            durationMinutes,
                            easyCount,
                            mediumCount,
                            hardCount,
                            selectedIds,
                          );
                        });
                      },
                    ),
                    child: const Text('Chọn câu hỏi'),
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
          ],
        ),
      ),
    );
  }

  void _showSelectQuestionsDialog(
    BuildContext context,
    List<Question> questions,
    int? easyCount,
    int? mediumCount,
    int? hardCount,
    Function(List<String>) onSelect,
  ) {
    final selectedIds = <String>{};

    // Auto-select if counts are specified
    if (easyCount != null || mediumCount != null || hardCount != null) {
      final easy = questions
          .where((q) => q.difficulty == QuestionDifficulty.easy)
          .toList()
        ..shuffle();
      final medium = questions
          .where((q) => q.difficulty == QuestionDifficulty.medium)
          .toList()
        ..shuffle();
      final hard = questions
          .where((q) => q.difficulty == QuestionDifficulty.hard)
          .toList()
        ..shuffle();

      if (easyCount != null) {
        selectedIds.addAll(easy.take(easyCount).map((q) => q.id));
      }
      if (mediumCount != null) {
        selectedIds.addAll(medium.take(mediumCount).map((q) => q.id));
      }
      if (hardCount != null) {
        selectedIds.addAll(hard.take(hardCount).map((q) => q.id));
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chọn câu hỏi'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Đã chọn: ${selectedIds.length} câu hỏi'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
                  child: ListView.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      final isSelected = selectedIds.contains(q.id);
                      String difficultyLabel = '';
                      switch (q.difficulty) {
                        case QuestionDifficulty.easy:
                          difficultyLabel = 'Dễ';
                          break;
                        case QuestionDifficulty.medium:
                          difficultyLabel = 'Trung bình';
                          break;
                        case QuestionDifficulty.hard:
                          difficultyLabel = 'Khó';
                          break;
                      }
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(q.questionText),
                        subtitle: Text('Độ khó: $difficultyLabel'),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selectedIds.add(q.id);
                            } else {
                              selectedIds.remove(q.id);
                            }
                          });
                        },
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
                Navigator.pop(ctx);
                onSelect(selectedIds.toList());
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createQuizWithQuestions(
    String title,
    String? description,
    DateTime openTime,
    DateTime closeTime,
    int maxAttempts,
    int durationMinutes,
    int? easyCount,
    int? mediumCount,
    int? hardCount,
    List<String> questionIds,
  ) async {
    try {
      await ref.read(quizProvider.notifier).createQuiz(
            courseId: widget.courseId,
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
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo quiz')),
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

  void _showQuizDetail(BuildContext context, Quiz quiz, List<Question> questions) {
    final submissions = ref.read(quizSubmissionProvider)
        .where((s) => s.quizId == quiz.id)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _QuizDetailSheet(
        quiz: quiz,
        questions: questions,
        students: widget.students,
        submissions: submissions,
        onExport: () => _exportQuizCSV(quiz),
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

  Future<void> _exportQuizCSV(Quiz quiz) async {
    try {
      final submissions = ref.read(quizSubmissionProvider)
          .where((s) => s.quizId == quiz.id)
          .toList();

      final csvData = <List<dynamic>>[];
      csvData.add(['Tên SV', 'Mã SV', 'Email', 'Điểm', 'Tổng điểm', 'Lần làm', 'Thời gian nộp']);

      for (final submission in submissions) {
        final student = widget.students.firstWhere(
          (s) => s.id == submission.studentId,
          orElse: () => AppUser(
            id: submission.studentId,
            fullName: 'Unknown',
            email: '',
            role: UserRole.student,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        csvData.add([
          student.fullName,
          student.code ?? '',
          student.email,
          submission.score,
          submission.maxScore,
          submission.attemptNumber,
          DateFormat('dd/MM/yyyy HH:mm').format(submission.submittedAt),
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/quiz_${quiz.id}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xuất CSV: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất CSV: $e')),
        );
      }
    }
  }
}

class _QuizCard extends StatelessWidget {
  final Quiz quiz;
  final List<Question> questions;
  final List<AppUser> students;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _QuizCard({
    required this.quiz,
    required this.questions,
    required this.students,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOpen = now.isAfter(quiz.openTime) && now.isBefore(quiz.closeTime);
    final isClosed = now.isAfter(quiz.closeTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          isOpen ? Icons.quiz : isClosed ? Icons.lock : Icons.schedule,
          color: isOpen ? Colors.green : isClosed ? Colors.grey : Colors.orange,
        ),
        title: Text(quiz.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mở: ${DateFormat('dd/MM/yyyy HH:mm').format(quiz.openTime)}'),
            Text('Đóng: ${DateFormat('dd/MM/yyyy HH:mm').format(quiz.closeTime)}'),
            Text('${quiz.questionIds.length} câu hỏi • ${quiz.durationMinutes} phút • ${quiz.maxAttempts} lần'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'detail',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Chi tiết'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Xuất CSV'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Xóa', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'detail') onTap();
            if (value == 'export') onExport();
            if (value == 'delete') onDelete();
          },
        ),
        onTap: onTap,
      ),
    );
  }
}

class _QuizDetailSheet extends ConsumerWidget {
  final Quiz quiz;
  final List<Question> questions;
  final List<AppUser> students;
  final List<QuizSubmission> submissions;
  final VoidCallback onExport;

  const _QuizDetailSheet({
    required this.quiz,
    required this.questions,
    required this.students,
    required this.submissions,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submittedStudentIds = submissions.map((s) => s.studentId).toSet();
    final notSubmitted = students.where((s) => !submittedStudentIds.contains(s.id)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (quiz.description != null)
                          Text(quiz.description!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Xuất CSV'),
                    onPressed: onExport,
                  ),
                  const Spacer(),
                  Text('Đã làm: ${submissions.length}/${students.length}'),
                ],
              ),
            ),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Đã làm'),
                        Tab(text: 'Chưa làm'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildSubmittedList(submissions, students),
                          _buildNotSubmittedList(notSubmitted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubmittedList(List<QuizSubmission> submissions, List<AppUser> students) {
    return ListView.builder(
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final submission = submissions[index];
        final student = students.firstWhere(
          (s) => s.id == submission.studentId,
          orElse: () => AppUser(
            id: submission.studentId,
            fullName: 'Unknown',
            email: '',
            role: UserRole.student,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        return ListTile(
          leading: CircleAvatar(child: Text(student.fullName[0])),
          title: Text(student.fullName),
          subtitle: Text('${student.code} • Lần ${submission.attemptNumber}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${submission.score}/${submission.maxScore}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat('dd/MM HH:mm').format(submission.submittedAt),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotSubmittedList(List<AppUser> students) {
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return ListTile(
          leading: CircleAvatar(child: Text(student.fullName[0])),
          title: Text(student.fullName),
          subtitle: Text('${student.code} • ${student.email}'),
          trailing: const Icon(Icons.close, color: Colors.red),
        );
      },
    );
  }
}

