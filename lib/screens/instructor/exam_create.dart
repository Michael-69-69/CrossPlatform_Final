// screens/instructor/exam_create.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/class_provider.dart';

class ExamCreateScreen extends ConsumerStatefulWidget {
  final String classId;
  final Map<String, dynamic>? initialExam;
  final int? examIndex;

  const ExamCreateScreen({
    super.key,
    required this.classId,
    this.initialExam,
    this.examIndex,
  });

  @override
  ConsumerState<ExamCreateScreen> createState() => _ExamCreateScreenState();
}

class _ExamCreateScreenState extends ConsumerState<ExamCreateScreen> {
  late final List<Map<String, dynamic>> _questions;
  late final List<Map<String, dynamic>> _originalQuestions;
  int? _editingIndex;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _isNavigating = false; // PREVENT DOUBLE POP

  final Map<int, _QuestionEditControllers> _editControllers = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExam?['questions'] as List? ?? [];
    _questions = initial.map((q) => Map<String, dynamic>.from(q)).toList();
    _originalQuestions = initial.map((q) => Map<String, dynamic>.from(q)).toList();
    _updateDirtyState();
  }

  @override
  void dispose() {
    _editControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _updateDirtyState() {
    final isDirty = _questions.length != _originalQuestions.length ||
        _questions.asMap().entries.any((e) {
          final i = e.key;
          final q = e.value;
          final orig = i < _originalQuestions.length ? _originalQuestions[i] : null;
          if (orig == null) return true;
          return q['question'] != orig['question'] ||
              !_listEquals(q['options'], orig['options']) ||
              q['correct'] != orig['correct'];
        });
    if (_hasUnsavedChanges != isDirty) {
      if (mounted) setState(() => _hasUnsavedChanges = isDirty);
    }
  }

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialExam != null;

    return PopScope(
      canPop: !_hasUnsavedChanges && !_isNavigating && !_isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isNavigating || _isSaving) return;
        if (_hasUnsavedChanges) {
          final save = await _showUnsavedDialog();
          if (save == true) {
            await _saveAndPop();
          } else if (save == false) {
            if (mounted) context.pop();
          }
        } else {
          if (mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditMode ? 'Chỉnh sửa bài kiểm tra' : 'Tạo bài kiểm tra'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            TextButton(
              onPressed: (_hasUnsavedChanges && !_isSaving && !_isNavigating) ? _saveAndPop : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isEditMode ? 'Cập nhật' : 'Lưu',
                      style: TextStyle(
                        color: _hasUnsavedChanges ? Colors.white : Colors.white70,
                        fontWeight: _hasUnsavedChanges ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton(
          onPressed: _showQuestionDialog,
          child: const Icon(Icons.add),
          backgroundColor: Colors.green,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return _questions.isEmpty
        ? Center(
            child: Text(
              widget.initialExam != null
                  ? 'Không có câu hỏi nào\nNhấn + để thêm'
                  : 'Chưa có câu hỏi\nNhấn + để thêm',
              textAlign: TextAlign.center,
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            itemBuilder: (context, i) => _buildQuestionCard(i),
          );
  }

  Widget _buildQuestionCard(int i) {
    final q = _questions[i];
    final isEditing = _editingIndex == i;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showQuestionOptions(i),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Câu ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _saveEdit(i),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              isEditing
                  ? _buildEditQuestionForm(q, i)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q['question'], style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        _buildPunnettSquare(q['options'], q['correct']),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // === PUNNETT SQUARE ===
  Widget _buildPunnettSquare(List<String> options, int correct) {
    final colors = [Colors.red, Colors.green, Colors.purple, Colors.orange];
    return Column(
      children: [
        Row(children: [
          _optionBox(options[0], colors[0], 0 == correct),
          _optionBox(options[1], colors[1], 1 == correct),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _optionBox(options[2], colors[2], 2 == correct),
          _optionBox(options[3], colors[3], 3 == correct),
        ]),
      ],
    );
  }

  Widget _optionBox(String text, Color color, bool isCorrect) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
            if (isCorrect) const Icon(Icons.check, color: Colors.green),
          ],
        ),
      ),
    );
  }

  // === EDIT FORM ===
  Widget _buildEditQuestionForm(Map<String, dynamic> q, int index) {
    if (!_editControllers.containsKey(index)) {
      _editControllers[index] = _QuestionEditControllers(
        question: TextEditingController(text: q['question']),
        options: List.generate(4, (i) => TextEditingController(text: q['options'][i])),
        correct: q['correct'],
      );
    }

    final ctrl = _editControllers[index]!;

    return StatefulBuilder(
      builder: (context, setStateDialog) => Column(
        children: [
          TextField(controller: ctrl.question, decoration: const InputDecoration(hintText: 'Câu hỏi'), maxLines: 3),
          const SizedBox(height: 12),
          ...List.generate(4, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: ctrl.options[i],
              decoration: InputDecoration(
                labelText: 'Đáp án ${i + 1}',
                prefixIcon: Icon(Icons.circle, color: [Colors.red, Colors.green, Colors.purple, Colors.orange][i]),
              ),
            ),
          )),
          DropdownButtonFormField<int>(
            value: ctrl.correct,
            decoration: const InputDecoration(labelText: 'Đáp án đúng'),
            items: List.generate(4, (i) => DropdownMenuItem(value: i, child: Text('Đáp án ${i + 1}'))),
            onChanged: (v) => setStateDialog(() => ctrl.correct = v!),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _saveEdit(int index) {
    final ctrl = _editControllers[index];
    if (ctrl == null) return;

    final updated = {
      'question': ctrl.question.text,
      'options': ctrl.options.map((c) => c.text).toList(),
      'correct': ctrl.correct,
    };

    setState(() {
      _questions[index] = updated;
      _editingIndex = null;
    });
    _updateDirtyState();
  }

  // === QUESTION OPTIONS ===
  void _showQuestionOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Chỉnh sửa'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _editingIndex = index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.content_copy, color: Colors.orange),
            title: const Text('Sao chép câu hỏi'),
            onTap: () {
              Navigator.pop(ctx);
              final copy = Map<String, dynamic>.from(_questions[index]);
              setState(() {
                _questions.insert(index + 1, copy);
                _updateDirtyState();
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Xóa câu hỏi'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _questions.removeAt(index);
                _editControllers.remove(index);
                _updateDirtyState();
              });
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // === ADD NEW QUESTION ===
  void _showQuestionDialog() {
    final qCtrl = TextEditingController();
    final opts = List.generate(4, (_) => TextEditingController());
    int correct = 0;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Thêm câu hỏi'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'Câu hỏi'), maxLines: 3),
                const SizedBox(height: 16),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: opts[i],
                    decoration: InputDecoration(
                      labelText: 'Đáp án ${i + 1}',
                      prefixIcon: Icon(Icons.circle, color: [Colors.red, Colors.green, Colors.purple, Colors.orange][i]),
                    ),
                  ),
                )),
                DropdownButtonFormField<int>(
                  value: correct,
                  decoration: const InputDecoration(labelText: 'Đáp án đúng'),
                  items: List.generate(4, (i) => DropdownMenuItem(value: i, child: Text('Đáp án ${i + 1}'))),
                  onChanged: (v) => setState(() => correct = v!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (qCtrl.text.isNotEmpty && opts.every((c) => c.text.isNotEmpty)) {
                final question = {
                  'question': qCtrl.text,
                  'options': opts.map((c) => c.text).toList(),
                  'correct': correct,
                };
                setState(() {
                  _questions.add(question);
                  _updateDirtyState();
                });
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  // === SAVE + POP (ONE FUNCTION) ===
Future<void> _saveAndPop() async {
  if (_isSaving || _isNavigating || _questions.isEmpty || !mounted) return;

  setState(() {
    _isSaving = true;
    _isNavigating = true;
  });

  final examData = {
    'title': widget.initialExam?['title'] ?? 'Bài kiểm tra ngày ${DateTime.now().toIso8601String().substring(0, 10)}',
    'questions': _questions,
    'createdAt': widget.initialExam?['createdAt'] ?? DateTime.now().toIso8601String(),
  };

  try {
    if (widget.examIndex != null) {
      await ref.read(classProvider.notifier).updateExam(widget.classId, widget.examIndex!, examData);
    } else {
      await ref.read(classProvider.notifier).addExam(widget.classId, examData);
    }

    if (!mounted) return;

    _originalQuestions.clear();
    _originalQuestions.addAll(_questions.map((q) => Map<String, dynamic>.from(q)));
    _hasUnsavedChanges = false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.examIndex != null ? 'Đã cập nhật!' : 'Đã tạo!')),
    );

    // GO_ROUTER SAFE POP
    context.pop();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi lưu')));
    }
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

  // === BACK HANDLER ===
void _handleBack() async {
  if (_isNavigating || _isSaving || !mounted) return;

  if (_hasUnsavedChanges) {
    final save = await _showUnsavedDialog();
    if (save == true) {
      await _saveAndPop();
    } else if (save == false && mounted) {
      context.pop(); // GO_ROUTER
    }
  } else if (mounted) {
    context.pop(); // GO_ROUTER
  }
}

  // === UNSAVED DIALOG ===
  Future<bool?> _showUnsavedDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thay đổi chưa lưu'),
        content: const Text('Bạn có thay đổi chưa lưu. Lưu trước khi thoát?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không lưu')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
  }
}

class _QuestionEditControllers {
  final TextEditingController question;
  final List<TextEditingController> options;
  int correct;

  _QuestionEditControllers({
    required this.question,
    required this.options,
    required this.correct,
  });

  void dispose() {
    question.dispose();
    options.forEach((c) => c.dispose());
  }
}