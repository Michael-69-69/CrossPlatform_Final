// screens/instructor/course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/group.dart' as app;
import '../../models/semester.dart';
import '../../models/user.dart';
import '../../main.dart'; // for localeProvider
import 'announcements_tab.dart';
import 'assignments_tab.dart';
import 'groups_tab.dart';
import 'quiz_tab.dart';
import 'material_tab.dart';
import 'analytics_tab.dart';
import '../shared/forum_list_widget.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final Course course;
  final Semester semester;
  final List<app.Group> groups;
  final List<AppUser> students;
  final int initialTabIndex; // ✅ NEW: Initial tab to open

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.semester,
    required this.groups,
    required this.students,
    this.initialTabIndex = 0, // ✅ Default to Announcements (index 0)
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
    _tabController = TabController(
      length: 7, 
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6), // ✅ Use initial tab index (clamped to valid range)
    );
    
    print('🏫 CourseDetailScreen initialized');
    print('📚 Course: ${widget.course.name}');
    print('📑 Initial tab index: ${widget.initialTabIndex}');
    print('👥 Groups count: ${widget.groups.length}');
    for (var group in widget.groups) {
      print('  - ${group.name} (ID: ${group.id}, Students: ${group.studentIds.length})');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = currentStudents.length;
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tabs: [
            Tab(icon: const Icon(Icons.announcement), text: isVietnamese ? 'Thông báo' : 'Announcements'),
            Tab(icon: const Icon(Icons.assignment), text: isVietnamese ? 'Bài tập' : 'Assignments'),
            Tab(icon: const Icon(Icons.quiz), text: 'Quiz'),
            Tab(icon: const Icon(Icons.folder), text: isVietnamese ? 'Tài liệu' : 'Materials'),
            Tab(icon: const Icon(Icons.group), text: isVietnamese ? 'Nhóm' : 'Groups'),
            Tab(icon: const Icon(Icons.forum), text: isVietnamese ? 'Diễn đàn' : 'Forum'),
            Tab(icon: const Icon(Icons.analytics), text: isVietnamese ? 'Thống kê' : 'Analytics'),
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
                    Text(isVietnamese ? '${widget.course.sessions} buổi' : '${widget.course.sessions} sessions'),
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
                    Text(isVietnamese ? '$totalStudents học sinh' : '$totalStudents students'),
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
                _buildForumTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    print('📢 Building AnnouncementsTab with ${widget.groups.length} groups');
    return AnnouncementsTab(
      courseId: widget.course.id,
      groups: widget.groups,
      students: widget.students,
    );
  }

  Widget _buildAssignmentsTab() {
    print('📝 Building AssignmentsTab with ${widget.groups.length} groups');
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
    print('👥 Building GroupsTab with ${widget.groups.length} groups');
    return GroupsTab(
      courseId: widget.course.id,
      groups: widget.groups,
    );
  }

  Widget _buildQuizTab() {
    print('❓ Building QuizTab');
    return QuizTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
    );
  }

  Widget _buildMaterialTab() {
    print('📁 Building MaterialTab');
    return MaterialTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
      students: widget.students,
    );
  }

  Widget _buildForumTab() {
    print('💬 Building ForumTab');
    return ForumListWidget(
      courseId: widget.course.id,
      courseName: widget.course.name,
      isInstructor: true,
    );
  }

  Widget _buildAnalyticsTab() {
    print('📊 Building AnalyticsTab');
    return AnalyticsTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
      students: widget.students,
    );
  }
}