// screens/student/student_course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/course.dart';
import '../../models/semester.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';
import 'tabs/student_stream_tab.dart';
import 'tabs/student_classwork_tab.dart';
import 'tabs/student_people_tab.dart';

class StudentCourseDetailScreen extends ConsumerStatefulWidget {
  final Course course;
  final Semester semester;
  final bool isPastSemester;

  const StudentCourseDetailScreen({
    super.key,
    required this.course,
    required this.semester,
    required this.isPastSemester,
  });

  @override
  ConsumerState<StudentCourseDetailScreen> createState() =>
      _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState
    extends ConsumerState<StudentCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ FIX: Remove courseId parameter
      ref.read(groupProvider.notifier).loadGroups();
      ref.read(studentProvider.notifier).loadStudents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref
        .watch(groupProvider)
        .where((g) => g.courseId == widget.course.id)
        .toList();

    final allStudents = ref.watch(studentProvider);

    final studentIds = groups.expand((g) => g.studentIds).toSet();
    final students =
        allStudents.where((s) => studentIds.contains(s.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.stream), text: 'Bảng tin'),
            Tab(icon: Icon(Icons.assignment), text: 'Bài tập'),
            Tab(icon: Icon(Icons.people), text: 'Mọi người'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Course info header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.school, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.semester.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text('${widget.course.sessions} buổi'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('GV: ${widget.course.instructorName}'),
                    ),
                    Text('${students.length} học sinh'),
                  ],
                ),
              ],
            ),
          ),

          // Past semester warning
          if (widget.isPastSemester)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Học kỳ cũ - Chỉ xem, không thể nộp bài hoặc làm quiz',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StudentStreamTab(
                  courseId: widget.course.id,
                  groups: groups,
                  isPastSemester: widget.isPastSemester,
                ),
                StudentClassworkTab(
                  courseId: widget.course.id,
                  courseName: widget.course.name,
                  isPastSemester: widget.isPastSemester,
                ),
                StudentPeopleTab(
                  groups: groups,
                  students: students,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}