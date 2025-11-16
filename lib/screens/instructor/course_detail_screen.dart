// screens/instructor/course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/group.dart' as app;
import '../../models/semester.dart';
import '../../models/user.dart';
import 'announcements_tab.dart';
import 'assignments_tab.dart';
import 'groups_tab.dart';
import 'quiz_tab.dart';
import 'material_tab.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final Course course;
  final Semester semester;
  final List<app.Group> groups;
  final List<AppUser> students;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.semester,
    required this.groups,
    required this.students,
  });

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> with TickerProviderStateMixin {
  late List<AppUser> currentStudents;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    currentStudents = List.from(widget.students);
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = currentStudents.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tabs: const [
            Tab(icon: Icon(Icons.announcement), text: 'Thông báo'),
            Tab(icon: Icon(Icons.assignment), text: 'Bài tập'),
            Tab(icon: Icon(Icons.quiz), text: 'Quiz'),
            Tab(icon: Icon(Icons.folder), text: 'Tài liệu'),
            Tab(icon: Icon(Icons.group), text: 'Nhóm'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Course Info Header
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text('${widget.course.sessions} buổi'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.book, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${widget.course.code}: ${widget.course.name}'),
                    ),
                    Text('$totalStudents học sinh'),
                  ],
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnnouncementsTab(),
                _buildAssignmentsTab(),
                _buildQuizTab(),
                _buildMaterialTab(),
                _buildGroupsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return AnnouncementsTab(
      courseId: widget.course.id,
      groups: widget.groups,
      students: widget.students,
    );
  }

  Widget _buildAssignmentsTab() {
    return AssignmentsTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
      groups: widget.groups,
      students: widget.students,
      instructorId: widget.course.instructorId,
      instructorName: widget.course.instructorName,
    );
  }

  Widget _buildGroupsTab() {
    return GroupsTab(
      courseId: widget.course.id,
      groups: widget.groups,
    );
  }

  Widget _buildQuizTab() {
    return QuizTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
      students: widget.students,
    );
  }

  Widget _buildMaterialTab() {
    return MaterialTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
      students: widget.students,
    );
  }
}