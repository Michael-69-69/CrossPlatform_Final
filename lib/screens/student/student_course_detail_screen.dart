// screens/student/student_course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/course.dart';
import '../../models/semester.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/network_service.dart';
import '../../main.dart'; // for localeProvider
import 'tabs/student_stream_tab.dart';
import 'tabs/student_classwork_tab.dart';
import 'tabs/student_people_tab.dart';
import '../shared/forum_list_widget.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load both groups and students
      await Future.wait([
        ref.read(groupProvider.notifier).loadGroups(),
        ref.read(studentProvider.notifier).loadStudents(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch providers for real-time updates
    final allGroups = ref.watch(groupProvider);
    final allStudents = ref.watch(studentProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    // ✅ Filter groups for this course
    final groups = allGroups.where((g) => g.courseId == widget.course.id).toList();

    // ✅ Get all student IDs from groups
    final studentIds = groups.expand((g) => g.studentIds).toSet();

    // ✅ Filter students that belong to these groups
    final students = allStudents.where((s) => studentIds.contains(s.id)).toList();

    // ✅ Debug logging
    print('═══════════════════════════════════════');
    print('📱 StudentCourseDetailScreen Build');
    print('🌐 Network: ${NetworkService().isOnline ? "ONLINE" : "OFFLINE"}');
    print('📚 Course: ${widget.course.name}');
    print('👥 Groups in course: ${groups.length}');
    for (var g in groups) {
      print('   - ${g.name}: ${g.studentIds.length} studentIds');
    }
    print('🎓 Total studentIds: ${studentIds.length}');
    print('👤 Matched students: ${students.length}');
    print('📦 All students in provider: ${allStudents.length}');
    print('═══════════════════════════════════════');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        actions: [
          // ✅ Show offline indicator
          if (NetworkService().isOffline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.cloud_off, size: 16, color: Colors.white),
                label: Text('Offline', style: TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.orange,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          // ✅ Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: isVietnamese ? 'Làm mới dữ liệu' : 'Refresh data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.stream), text: isVietnamese ? 'Bảng tin' : 'Stream'),
            Tab(icon: const Icon(Icons.assignment), text: isVietnamese ? 'Bài tập' : 'Classwork'),
            Tab(icon: const Icon(Icons.people), text: isVietnamese ? 'Mọi người' : 'People'),
            Tab(icon: const Icon(Icons.forum), text: isVietnamese ? 'Diễn đàn' : 'Forum'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                            child: Row(
                              children: [
                                Text(
                                  widget.semester.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.semester.isActive) ...[
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      isVietnamese ? 'Đang hoạt động' : 'Active',
                                      style: const TextStyle(fontSize: 9, color: Colors.white),
                                    ),
                                    backgroundColor: Colors.green,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(isVietnamese ? '${widget.course.sessions} buổi' : '${widget.course.sessions} sessions'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(isVietnamese ? 'GV: ${widget.course.instructorName}' : 'Instructor: ${widget.course.instructorName}'),
                          ),
                          // ✅ Show student count from groups (works offline)
                          Text(isVietnamese ? '${studentIds.length} học sinh' : '${studentIds.length} students'),
                        ],
                      ),
                      // ✅ Show offline warning if students not loaded
                      if (NetworkService().isOffline && students.isEmpty && studentIds.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isVietnamese
                                      ? 'Chi tiết học sinh chưa được cache. Kết nối mạng để xem.'
                                      : 'Student details not cached. Connect to network to view.',
                                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Warning for non-active semesters
                if (widget.isPastSemester)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange[100],
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[800]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isVietnamese
                                ? 'Đây là học kỳ đã kết thúc. Bạn chỉ có thể xem nội dung.'
                                : 'This semester has ended. You can only view content.',
                            style: TextStyle(color: Colors.orange[800]),
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
                      // ✅ FIXED: StudentClassworkTab doesn't take groups parameter
                      StudentClassworkTab(
                        courseId: widget.course.id,
                        courseName: widget.course.name,
                        isPastSemester: widget.isPastSemester,
                      ),
                      // ✅ Pass groups with studentIds count for offline display
                      StudentPeopleTab(
                        groups: groups,
                        students: students,
                      ),
                      ForumListWidget(
                        courseId: widget.course.id,
                        courseName: widget.course.name,
                        isInstructor: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}