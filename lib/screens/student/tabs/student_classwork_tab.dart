// screens/student/tabs/student_classwork_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/assignment.dart';
import '../../../../models/quiz.dart';
import '../../../../models/material.dart' as app;
import '../../../../providers/assignment_provider.dart';
import '../../../../providers/quiz_provider.dart';
import '../../../../providers/material_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../student_assignment_detail.dart';
import '../student_quiz_take.dart';
import '../student_material_view.dart';
import '../../../main.dart'; // for localeProvider

class StudentClassworkTab extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  final bool isPastSemester;

  const StudentClassworkTab({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.isPastSemester,
  });

  @override
  ConsumerState<StudentClassworkTab> createState() => _StudentClassworkTabState();
}

class _StudentClassworkTabState extends ConsumerState<StudentClassworkTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignmentProvider.notifier).loadAssignments(widget.courseId);
      ref.read(quizProvider.notifier).loadQuizzes(courseId: widget.courseId);
      ref.read(materialProvider.notifier).loadMaterials(courseId: widget.courseId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper method to check if Vietnamese
  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  @override
  Widget build(BuildContext context) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: isVietnamese ? 'Tìm kiếm...' : 'Search...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: isVietnamese ? 'Bài tập' : 'Assignments'),
            Tab(text: 'Quiz'),
            Tab(text: isVietnamese ? 'Tài liệu' : 'Materials'),
          ],
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAssignmentsView(),
              _buildQuizzesView(),
              _buildMaterialsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsView() {
    final user = ref.watch(authProvider);
    final isVietnamese = _isVietnamese();
    final assignments = ref.watch(assignmentProvider)
        .where((a) => a.courseId == widget.courseId)
        .toList();

    var filtered = assignments;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) =>
        a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        a.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? (isVietnamese ? 'Không tìm thấy' : 'Not found')
                  : (isVietnamese ? 'Chưa có bài tập nào' : 'No assignments yet'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final assignment = filtered[index];
        final hasSubmitted = assignment.submissions.any((s) => s.studentId == user?.id);
        final isLate = DateTime.now().isAfter(assignment.deadline) && !hasSubmitted;
        final canSubmit = !widget.isPastSemester && 
                         (DateTime.now().isBefore(assignment.deadline) || 
                         (assignment.allowLateSubmission && assignment.lateDeadline != null && 
                          DateTime.now().isBefore(assignment.lateDeadline!)));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentAssignmentDetail(
                    assignment: assignment,
                    canSubmit: canSubmit,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasSubmitted 
                              ? Colors.green.withOpacity(0.2)
                              : isLate
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasSubmitted ? Icons.check_circle : Icons.assignment,
                          color: hasSubmitted ? Colors.green : isLate ? Colors.red : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              assignment.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          hasSubmitted
                              ? (isVietnamese ? 'Đã nộp' : 'Submitted')
                              : isLate
                                  ? (isVietnamese ? 'Trễ hạn' : 'Late')
                                  : (isVietnamese ? 'Chưa nộp' : 'Pending'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: hasSubmitted
                            ? Colors.green.withOpacity(0.2)
                            : isLate
                                ? Colors.red.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        isVietnamese
                            ? 'Hạn: ${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year}'
                            : 'Due: ${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (hasSubmitted) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.grade, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          assignment.submissions
                                      .firstWhere((s) => s.studentId == user?.id)
                                      .grade
                                      ?.toString() ??
                                  (isVietnamese ? 'Chưa chấm' : 'Not graded'),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizzesView() {
    final user = ref.watch(authProvider);
    final isVietnamese = _isVietnamese();
    final quizzes = ref.watch(quizProvider)
        .where((q) => q.courseId == widget.courseId)
        .toList();
    final submissions = ref.watch(quizSubmissionProvider)
        .where((s) => s.studentId == user?.id)
        .toList();

    var filtered = quizzes;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((q) =>
        q.title.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? (isVietnamese ? 'Không tìm thấy' : 'Not found')
                  : (isVietnamese ? 'Chưa có quiz nào' : 'No quizzes yet'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final quiz = filtered[index];
        final hasCompleted = submissions.any((s) => s.quizId == quiz.id);
        final isOpen = DateTime.now().isAfter(quiz.openTime) && 
                      DateTime.now().isBefore(quiz.closeTime);
        final canTake = !widget.isPastSemester && isOpen && !hasCompleted;

        final submission = submissions.where((s) => s.quizId == quiz.id).firstOrNull;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: canTake
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentQuizTake(quiz: quiz),
                      ),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasCompleted
                              ? Colors.green.withOpacity(0.2)
                              : isOpen
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasCompleted ? Icons.check_circle : Icons.quiz,
                          color: hasCompleted ? Colors.green : isOpen ? Colors.blue : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quiz.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (quiz.description != null)
                              Text(
                                quiz.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          hasCompleted
                              ? (isVietnamese ? 'Đã làm' : 'Completed')
                              : isOpen
                                  ? (isVietnamese ? 'Đang mở' : 'Open')
                                  : (isVietnamese ? 'Đã đóng' : 'Closed'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: hasCompleted
                            ? Colors.green.withOpacity(0.2)
                            : isOpen
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        isVietnamese ? '${quiz.durationMinutes} phút' : '${quiz.durationMinutes} min',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.question_answer, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        isVietnamese ? '${quiz.questionIds.length} câu' : '${quiz.questionIds.length} questions',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (submission != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.grade, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${submission.score}/${submission.maxScore}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        isVietnamese
                            ? 'Đóng: ${quiz.closeTime.day}/${quiz.closeTime.month}/${quiz.closeTime.year} ${quiz.closeTime.hour}:${quiz.closeTime.minute.toString().padLeft(2, '0')}'
                            : 'Closes: ${quiz.closeTime.day}/${quiz.closeTime.month}/${quiz.closeTime.year} ${quiz.closeTime.hour}:${quiz.closeTime.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaterialsView() {
    final isVietnamese = _isVietnamese();
    final materials = ref.watch(materialProvider)
        .where((m) => m.courseId == widget.courseId)
        .toList();

    var filtered = materials;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((m) =>
        m.title.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? (isVietnamese ? 'Không tìm thấy' : 'Not found')
                  : (isVietnamese ? 'Chưa có tài liệu nào' : 'No materials yet'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final material = filtered[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentMaterialView(material: material),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (material.description != null)
                          Text(
                            material.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.attach_file, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              isVietnamese
                                  ? '${material.attachments.length} tệp'
                                  : '${material.attachments.length} files',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}