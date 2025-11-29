// lib/screens/instructor/instructor_dashboard_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/assignment.dart';
import '../../models/group.dart' as app;
import '../../models/user.dart';
import '../../providers/course_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/semester_provider.dart';

// ✅ Provider to cache dashboard data
final _dashboardDataProvider = StateProvider<_DashboardData?>((ref) => null);

class _DashboardData {
  final String? semesterId;
  final int coursesCount;
  final int groupsCount;
  final int studentsCount;
  final List<Assignment> allAssignments;
  final List<Course> courses;
  final DateTime loadedAt;

  _DashboardData({
    required this.semesterId,
    required this.coursesCount,
    required this.groupsCount,
    required this.studentsCount,
    required this.allAssignments,
    required this.courses,
    required this.loadedAt,
  });

  // Check if cache is still valid (5 minutes)
  bool get isValid => DateTime.now().difference(loadedAt).inMinutes < 5;
}

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
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataIfNeeded();
    });
  }

  @override
  void didUpdateWidget(InstructorDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if semester changed
    if (oldWidget.semesterId != widget.semesterId) {
      _loadDataIfNeeded(forceReload: true);
    }
  }

  // ✅ Only load if cache is invalid or semester changed
  Future<void> _loadDataIfNeeded({bool forceReload = false}) async {
    final cachedData = ref.read(_dashboardDataProvider);
    
    // Check if we have valid cached data for the same semester
    if (!forceReload && 
        cachedData != null && 
        cachedData.isValid && 
        cachedData.semesterId == widget.semesterId) {
      print('📦 Using cached dashboard data (loaded ${DateTime.now().difference(cachedData.loadedAt).inSeconds}s ago)');
      return;
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted || _isLoading) return;

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

      // Get courses for this instructor
      final allCourses = ref.read(courseProvider);
      final courses = widget.semesterId != null
          ? allCourses.where((c) => c.semesterId == widget.semesterId && c.instructorId == user.id).toList()
          : allCourses.where((c) => c.instructorId == user.id).toList();

      // Get groups and students
      final allGroups = ref.read(groupProvider);
      final groups = allGroups.where((g) => courses.any((c) => c.id == g.courseId)).toList();

      final allStudents = ref.read(studentProvider);
      final studentIds = <String>{};
      for (final g in groups) {
        studentIds.addAll(g.studentIds);
      }
      final studentsCount = allStudents.where((s) => studentIds.contains(s.id)).length;

      // Load assignments for each course and collect them all
      final allAssignments = <Assignment>[];
      for (final course in courses) {
        try {
          await ref.read(assignmentProvider.notifier).loadAssignments(course.id);
          final courseAssignments = ref.read(assignmentProvider)
              .where((a) => a.courseId == course.id)
              .toList();
          allAssignments.addAll(courseAssignments);
        } catch (e) {
          print('Error loading assignments for ${course.code}: $e');
        }
      }

      // Remove duplicates
      final seenIds = <String>{};
      final uniqueAssignments = allAssignments.where((a) {
        if (seenIds.contains(a.id)) return false;
        seenIds.add(a.id);
        return true;
      }).toList();

      // ✅ Cache the data
      ref.read(_dashboardDataProvider.notifier).state = _DashboardData(
        semesterId: widget.semesterId,
        coursesCount: courses.length,
        groupsCount: groups.length,
        studentsCount: studentsCount,
        allAssignments: uniqueAssignments,
        courses: courses,
        loadedAt: DateTime.now(),
      );

      print('✅ Dashboard data loaded and cached: ${uniqueAssignments.length} assignments from ${courses.length} courses');

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

  // ✅ Force refresh (for pull-to-refresh)
  Future<void> _forceRefresh() async {
    ref.read(_dashboardDataProvider.notifier).state = null;
    await _loadData();
  }

  // Get cached data
  _DashboardData? get _cachedData => ref.watch(_dashboardDataProvider);

  // Stats from cached data
  int get _totalSubmissions {
    final data = _cachedData;
    if (data == null) return 0;
    int count = 0;
    for (final a in data.allAssignments) {
      count += a.submissions.length;
    }
    return count;
  }

  int get _gradedSubmissions {
    final data = _cachedData;
    if (data == null) return 0;
    int count = 0;
    for (final a in data.allAssignments) {
      count += a.submissions.where((s) => s.grade != null).length;
    }
    return count;
  }

  int get _ungradedSubmissions => _totalSubmissions - _gradedSubmissions;

  // Get assignments with ungraded submissions, categorized by submission age
  List<Map<String, dynamic>> _getUngradedAssignments({
    required int maxDaysOld,
    int? minDaysOld,
  }) {
    final data = _cachedData;
    if (data == null) return [];

    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    for (final assignment in data.allAssignments) {
      if (assignment.id.isEmpty || assignment.title.isEmpty) continue;

      final ungradedSubs = assignment.submissions.where((s) {
        if (s.grade != null) return false;
        if (s.studentId.isEmpty) return false;

        final daysOld = now.difference(s.submittedAt).inDays;
        
        if (minDaysOld != null) {
          return daysOld >= minDaysOld && daysOld < maxDaysOld;
        }
        return daysOld < maxDaysOld;
      }).toList();

      if (ungradedSubs.isEmpty) continue;

      final course = data.courses.firstWhere(
        (c) => c.id == assignment.courseId,
        orElse: () => Course(
          id: '',
          code: '???',
          name: 'Unknown',
          sessions: 0,
          semesterId: '',
          instructorId: '',
          instructorName: '',
        ),
      );

      result.add({
        'assignment': assignment,
        'course': course,
        'ungradedCount': ungradedSubs.length,
        'submissions': ungradedSubs.map((s) => {
          'submission': s,
          'daysOld': now.difference(s.submittedAt).inDays,
        }).toList(),
      });
    }

    // Sort by oldest submission first
    result.sort((a, b) {
      final aOldest = (a['submissions'] as List).isNotEmpty
          ? (a['submissions'] as List).map((s) => s['daysOld'] as int).reduce((x, y) => x > y ? x : y)
          : 0;
      final bOldest = (b['submissions'] as List).isNotEmpty
          ? (b['submissions'] as List).map((s) => s['daysOld'] as int).reduce((x, y) => x > y ? x : y)
          : 0;
      return bOldest.compareTo(aOldest);
    });

    return result;
  }

  void _navigateToAssignment(String courseId, String assignmentId) {
    final data = _cachedData;
    if (data == null) return;

    final course = data.courses.firstWhere((c) => c.id == courseId, orElse: () => data.courses.first);

    final semesters = ref.read(semesterProvider);
    final semester = semesters.firstWhere(
      (s) => s.id == course.semesterId,
      orElse: () => semesters.first,
    );

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
    final data = _cachedData;

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_isLoading && data == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải dữ liệu...'),
          ],
        ),
      );
    }

    if (data == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    // Categorize by submission age
    final recentUngraded = _getUngradedAssignments(maxDaysOld: 7);
    final weekOldUngraded = _getUngradedAssignments(minDaysOld: 7, maxDaysOld: 30);
    final monthOldUngraded = _getUngradedAssignments(minDaysOld: 30, maxDaysOld: 9999);

    final hasContent = recentUngraded.isNotEmpty || 
                       weekOldUngraded.isNotEmpty || 
                       monthOldUngraded.isNotEmpty ||
                       _totalSubmissions > 0;

    return RefreshIndicator(
      onRefresh: _forceRefresh, // ✅ Use force refresh for pull-to-refresh
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 16),
              _buildQuickStats(data),
              const SizedBox(height: 16),
              _buildGradingProgress(),
              
              // 30+ days old (URGENT)
              if (monthOldUngraded.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAssignmentsSection(
                  title: '🚨 Quá 30 ngày chưa chấm',
                  subtitle: 'Cần xử lý ngay!',
                  assignments: monthOldUngraded,
                  color: Colors.red[700]!,
                  icon: Icons.error,
                ),
              ],
              
              // 7-30 days old
              if (weekOldUngraded.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAssignmentsSection(
                  title: '⚠️ 7-30 ngày chưa chấm',
                  subtitle: 'Nên chấm sớm',
                  assignments: weekOldUngraded,
                  color: Colors.orange,
                  icon: Icons.warning_amber,
                ),
              ],
              
              // Recent (0-7 days)
              if (recentUngraded.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAssignmentsSection(
                  title: '📝 Mới nộp (< 7 ngày)',
                  subtitle: 'Bài nộp gần đây',
                  assignments: recentUngraded,
                  color: Colors.blue,
                  icon: Icons.schedule,
                ),
              ],
              
              if (!hasContent) ...[
                const SizedBox(height: 16),
                _buildEmptyState(),
              ],
              
              const SizedBox(height: 16),
            ],
          ),
          
          // ✅ Show loading indicator overlay when refreshing with existing data
          if (_isLoading && data != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Đang cập nhật...', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
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
              onPressed: _forceRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final allGraded = _totalSubmissions > 0 && _ungradedSubmissions == 0;
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: allGraded ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            allGraded ? Icons.check_circle : Icons.inbox_outlined,
            size: 64,
            color: allGraded ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            allGraded ? 'Đã chấm hết! 🎉' : 'Chưa có bài nộp',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: allGraded ? Colors.green[700] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            allGraded 
                ? 'Tất cả $_totalSubmissions bài nộp đã được chấm điểm'
                : 'Tạo bài tập để sinh viên nộp bài',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
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
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)],
        ),
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

  Widget _buildQuickStats(_DashboardData data) {
    return Row(
      children: [
        _statCard(Icons.book, data.coursesCount, 'Môn học', Colors.blue),
        const SizedBox(width: 10),
        _statCard(Icons.group_work, data.groupsCount, 'Nhóm', Colors.orange),
        const SizedBox(width: 10),
        _statCard(Icons.people, data.studentsCount, 'Sinh viên', Colors.green),
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
    final total = _totalSubmissions;
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
          if (total == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.hourglass_empty, size: 32, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Chưa có bài nộp nào', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: progressColor),
                ),
                Text('$_gradedSubmissions / $total bài nộp', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _progressLabel(Colors.green, 'Đã chấm', _gradedSubmissions),
                _progressLabel(Colors.orange, 'Chưa chấm', _ungradedSubmissions),
              ],
            ),
          ],
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

  Widget _buildAssignmentsSection({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> assignments,
    required Color color,
    required IconData icon,
  }) {
    final totalUngraded = assignments.fold<int>(0, (sum, a) => sum + (a['ungradedCount'] as int));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '$totalUngraded',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...assignments.map((data) => _AssignmentFolderTile(
                assignment: data['assignment'] as Assignment,
                course: data['course'] as Course,
                ungradedCount: data['ungradedCount'] as int,
                submissions: data['submissions'] as List,
                color: color,
                onTap: () => _navigateToAssignment(
                  (data['course'] as Course).id,
                  (data['assignment'] as Assignment).id,
                ),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ASSIGNMENT FOLDER TILE
// ═══════════════════════════════════════════════════════════════════════════

class _AssignmentFolderTile extends StatefulWidget {
  final Assignment assignment;
  final Course course;
  final int ungradedCount;
  final List submissions;
  final Color color;
  final VoidCallback onTap;

  const _AssignmentFolderTile({
    required this.assignment,
    required this.course,
    required this.ungradedCount,
    required this.submissions,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AssignmentFolderTile> createState() => _AssignmentFolderTileState();
}

class _AssignmentFolderTileState extends State<_AssignmentFolderTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.folder_open : Icons.folder,
                    color: widget.color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.assignment.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.course.code,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.ungradedCount}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  ...widget.submissions.take(5).map((data) {
                    final sub = data['submission'] as AssignmentSubmission;
                    final daysOld = data['daysOld'] as int;
                    return _buildSubmissionTile(sub, daysOld);
                  }),
                  if (widget.submissions.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'và ${widget.submissions.length - 5} bài nộp khác...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onTap,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Mở bài tập', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTile(AssignmentSubmission sub, int daysOld) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: widget.color.withOpacity(0.1),
            child: Text(
              sub.studentName.isNotEmpty ? sub.studentName[0].toUpperCase() : '?',
              style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.studentName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
                Text(
                  '${sub.submittedAt.day}/${sub.submittedAt.month}/${sub.submittedAt.year}',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: daysOld >= 30 ? Colors.red : (daysOld >= 7 ? Colors.orange : Colors.blue),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$daysOld ngày',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}