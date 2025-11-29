// lib/screens/instructor/instructor_dashboard_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/group.dart' as app;
import '../../providers/course_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/semester_provider.dart';

class InstructorDashboardWidget extends ConsumerStatefulWidget {
  final String? semesterId;

  const InstructorDashboardWidget({
    super.key,
    this.semesterId,
  });

  @override
  ConsumerState<InstructorDashboardWidget> createState() =>
      _InstructorDashboardWidgetState();
}

class _InstructorDashboardWidgetState extends ConsumerState<InstructorDashboardWidget> {
  bool _isLoading = true;
  String? _error;

  int _coursesCount = 0;
  int _groupsCount = 0;
  int _studentsCount = 0;
  int _totalSubmissions = 0;
  int _gradedSubmissions = 0;
  int _ungradedSubmissions = 0;
  int _lateSubmissions = 0;

  List<Map<String, dynamic>> _coursesFolders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(InstructorDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.semesterId != widget.semesterId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = ref.read(authProvider);
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Chưa đăng nhập';
          });
        }
        return;
      }

      final allCourses = ref.read(courseProvider);
      final courses = widget.semesterId != null
          ? allCourses.where((c) => c.semesterId == widget.semesterId && c.instructorId == user.id).toList()
          : allCourses.where((c) => c.instructorId == user.id).toList();

      _coursesCount = courses.length;

      final allGroups = ref.read(groupProvider);
      final groups = allGroups.where((g) => courses.any((c) => c.id == g.courseId)).toList();
      _groupsCount = groups.length;

      final allStudents = ref.read(studentProvider);
      final studentIds = <String>{};
      for (final g in groups) {
        studentIds.addAll(g.studentIds);
      }
      _studentsCount = allStudents.where((s) => studentIds.contains(s.id)).length;

      for (final course in courses) {
        try {
          await ref.read(assignmentProvider.notifier).loadAssignments(course.id);
        } catch (e) {
          print('Error loading assignments for ${course.id}: $e');
        }
      }

      _processAssignments(courses);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stack) {
      print('Dashboard error: $e');
      print('Stack: $stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Lỗi: $e';
        });
      }
    }
  }

  void _processAssignments(List<Course> courses) {
    _totalSubmissions = 0;
    _gradedSubmissions = 0;
    _ungradedSubmissions = 0;
    _lateSubmissions = 0;
    _coursesFolders = [];

    final assignments = ref.read(assignmentProvider);

    for (final course in courses) {
      final courseAssignments = assignments.where((a) => a.courseId == course.id).toList();

      List<Map<String, dynamic>> assignmentFolders = [];

      for (final assignment in courseAssignments) {
        List<Map<String, dynamic>> ungradedSubs = [];

        for (final sub in assignment.submissions) {
          _totalSubmissions++;

          if (sub.grade != null) {
            _gradedSubmissions++;
          } else {
            _ungradedSubmissions++;
            ungradedSubs.add({
              'studentId': sub.studentId,
              'studentName': sub.studentName,
              'submittedAt': sub.submittedAt,
              'isLate': sub.isLate,
            });
          }

          if (sub.isLate) {
            _lateSubmissions++;
          }
        }

        if (ungradedSubs.isNotEmpty) {
          assignmentFolders.add({
            'id': assignment.id,
            'title': assignment.title,
            'deadline': assignment.deadline,
            'submissions': ungradedSubs,
          });
        }
      }

      if (assignmentFolders.isNotEmpty) {
        _coursesFolders.add({
          'id': course.id,
          'code': course.code,
          'name': course.name,
          'assignments': assignmentFolders,
        });
      }
    }
  }

  // ✅ NEW: Navigation method
  void _navigateToCourseDetail(String courseId, String assignmentId) {
    final courses = ref.read(courseProvider);
    final course = courses.where((c) => c.id == courseId).firstOrNull;

    if (course == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy môn học')),
      );
      return;
    }

    final semesters = ref.read(semesterProvider);
    final semester = semesters.where((s) => s.id == course.semesterId).firstOrNull;

    if (semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy học kỳ')),
      );
      return;
    }

    final allGroups = ref.read(groupProvider);
    final groups = allGroups.where((g) => g.courseId == courseId).toList();

    final allStudents = ref.read(studentProvider);
    final studentIds = <String>{};
    for (final g in groups) {
      studentIds.addAll(g.studentIds);
    }
    final students = allStudents.where((s) => studentIds.contains(s.id)).toList();

    context.push(
      '/instructor/course/$courseId',
      extra: {
        'course': course,
        'semester': semester,
        'groups': groups,
        'students': students,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          if (_ungradedSubmissions > 0 || _lateSubmissions > 0) _buildActionRequired(),
          const SizedBox(height: 16),
          _buildQuickStats(),
          const SizedBox(height: 16),
          _buildGradingProgress(),
          const SizedBox(height: 16),
          if (_coursesFolders.isNotEmpty) _buildUngradedFolders(),
          if (_coursesFolders.isEmpty && _totalSubmissions == 0) _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error ?? 'Đã xảy ra lỗi', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Chưa có dữ liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Tạo bài tập để xem thống kê', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final user = ref.watch(authProvider);
    final semesters = ref.watch(semesterProvider);
    final activeSemester = semesters.where((s) => s.isActive).firstOrNull;

    final hour = DateTime.now().hour;
    String greeting = hour < 12 ? 'Chào buổi sáng' : (hour < 18 ? 'Chào buổi chiều' : 'Chào buổi tối');
    IconData icon = hour < 12 ? Icons.wb_sunny : (hour < 18 ? Icons.wb_cloudy : Icons.nights_stay);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(user?.fullName ?? 'Giảng viên', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (activeSemester != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('📚 ${activeSemester.name}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRequired() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red.shade400, Colors.orange.shade400]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text('CẦN XỬ LÝ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_ungradedSubmissions > 0) _actionChip(Icons.grading, '$_ungradedSubmissions chưa chấm'),
              if (_lateSubmissions > 0) _actionChip(Icons.schedule, '$_lateSubmissions nộp trễ'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _statCard(Icons.book, _coursesCount, 'Môn học', Colors.blue),
        const SizedBox(width: 10),
        _statCard(Icons.group_work, _groupsCount, 'Nhóm', Colors.orange),
        const SizedBox(width: 10),
        _statCard(Icons.people, _studentsCount, 'Sinh viên', Colors.green),
      ],
    );
  }

  Widget _statCard(IconData icon, int value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildGradingProgress() {
    final total = _gradedSubmissions + _ungradedSubmissions;
    final progress = total > 0 ? _gradedSubmissions / total : 0.0;
    final progressColor = progress >= 0.8 ? Colors.green : (progress >= 0.5 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text('Tiến độ chấm bài', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: total > 0 ? progressColor : Colors.grey)),
              Text('$_gradedSubmissions / $total', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(total > 0 ? progressColor : Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _progressLabel(Colors.green, 'Đã chấm', _gradedSubmissions),
              _progressLabel(Colors.orange, 'Chưa chấm', _ungradedSubmissions),
              _progressLabel(Colors.red, 'Nộp trễ', _lateSubmissions),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressLabel(Color color, String label, int value) {
    return Column(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 4),
        Text('$value', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ],
    );
  }

  // ✅ FIXED: Updated to use new navigation method
  Widget _buildUngradedFolders() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Bài cần chấm điểm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(12)),
                child: Text('$_ungradedSubmissions', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._coursesFolders.map((course) => _CourseFolderTile(
            courseData: course,
            onSubmissionTap: (courseId, assignmentId) {
              _navigateToCourseDetail(courseId, assignmentId); // ✅ Use new method
            },
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOLDER TILES
// ═══════════════════════════════════════════════════════════════════════════

class _CourseFolderTile extends StatefulWidget {
  final Map<String, dynamic> courseData;
  final Function(String courseId, String assignmentId) onSubmissionTap;

  const _CourseFolderTile({required this.courseData, required this.onSubmissionTap});

  @override
  State<_CourseFolderTile> createState() => _CourseFolderTileState();
}

class _CourseFolderTileState extends State<_CourseFolderTile> {
  bool _isExpanded = false;

  int get _totalUngraded {
    int count = 0;
    final assignments = widget.courseData['assignments'] as List<Map<String, dynamic>>? ?? [];
    for (final a in assignments) {
      final subs = a['submissions'] as List<Map<String, dynamic>>? ?? [];
      count += subs.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.courseData['code'] as String? ?? '';
    final name = widget.courseData['name'] as String? ?? '';
    final assignments = widget.courseData['assignments'] as List<Map<String, dynamic>>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(_isExpanded ? Icons.folder_open : Icons.folder, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(name, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                    child: Text('$_totalUngraded', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: assignments.map((assignment) {
                  return _AssignmentFolderTile(
                    assignmentData: assignment,
                    courseId: widget.courseData['id'] as String? ?? '',
                    onSubmissionTap: widget.onSubmissionTap,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentFolderTile extends StatefulWidget {
  final Map<String, dynamic> assignmentData;
  final String courseId;
  final Function(String courseId, String assignmentId) onSubmissionTap;

  const _AssignmentFolderTile({required this.assignmentData, required this.courseId, required this.onSubmissionTap});

  @override
  State<_AssignmentFolderTile> createState() => _AssignmentFolderTileState();
}

class _AssignmentFolderTileState extends State<_AssignmentFolderTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.assignmentData['id'] as String? ?? '';
    final title = widget.assignmentData['title'] as String? ?? '';
    final deadline = widget.assignmentData['deadline'] as DateTime?;
    final submissions = widget.assignmentData['submissions'] as List<Map<String, dynamic>>? ?? [];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(_isExpanded ? Icons.assignment : Icons.assignment_outlined, color: Colors.purple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (deadline != null)
                          Text('Deadline: ${deadline.day}/${deadline.month}/${deadline.year}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(10)),
                    child: Text('${submissions.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: submissions.map((sub) {
                  return _SubmissionTile(
                    submissionData: sub,
                    onTap: () => widget.onSubmissionTap(widget.courseId, id),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Map<String, dynamic> submissionData;
  final VoidCallback onTap;

  const _SubmissionTile({required this.submissionData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final studentName = submissionData['studentName'] as String? ?? 'Không rõ';
    final submittedAt = submissionData['submittedAt'] as DateTime?;
    final isLate = submissionData['isLate'] as bool? ?? false;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isLate ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isLate ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isLate ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              child: Text(
                studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                style: TextStyle(color: isLate ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (submittedAt != null)
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${submittedAt.day}/${submittedAt.month} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        if (isLate) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                            child: const Text('TRỄ', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grading, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Chấm', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}