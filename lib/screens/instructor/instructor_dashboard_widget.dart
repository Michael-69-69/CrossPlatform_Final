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
import '../../main.dart';

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

  bool get isValid => DateTime.now().difference(loadedAt).inMinutes < 5;
}

class _GroupedSubmissionData {
  final Assignment assignment;
  final Course course;
  final List<AssignmentSubmission> submissions;

  _GroupedSubmissionData({
    required this.assignment,
    required this.course,
    required this.submissions,
  });
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
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDataWithRefresh();
  }

  @override
  void didUpdateWidget(covariant InstructorDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.semesterId != widget.semesterId) {
      _loadDataWithRefresh();
    }
  }

  bool _isVietnamese() {
    return ref.watch(localeProvider).languageCode == 'vi';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ FIXED: Actually load data from database, not just read from providers
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadDataWithRefresh() async {
    final cachedData = ref.read(_dashboardDataProvider);
    
    // If we have valid cached data for the same semester, show it first
    if (cachedData != null && 
        cachedData.isValid && 
        cachedData.semesterId == widget.semesterId) {
      // Still refresh in background
      _refreshInBackground();
      return;
    }

    // No valid cache - load fresh data with loading indicator
    await _loadFreshData();
  }

  Future<void> _loadFreshData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _fetchAndCacheData();
    } catch (e, stack) {
      print('Dashboard load error: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = _isVietnamese() ? 'Lỗi: $e' : 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _fetchAndCacheData();
    } catch (e) {
      print('Background refresh error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

// In _fetchAndCacheData() method, replace the assignment loading section:

Future<void> _fetchAndCacheData() async {
  final user = ref.read(authProvider);
  if (user == null) {
    throw Exception('User not logged in');
  }

  // ✅ Step 1: Get courses
  final allCourses = ref.read(courseProvider);
  final courses = allCourses
      .where((c) => widget.semesterId == null || c.semesterId == widget.semesterId)
      .toList();
  
  print('📊 Dashboard: Found ${courses.length} courses for semester ${widget.semesterId ?? "all"}');

  // ✅ Step 2: Get groups for these courses
  final allGroups = ref.read(groupProvider);
  final groups = allGroups
      .where((g) => courses.any((c) => c.id == g.courseId))
      .toList();
  
  final studentIds = groups.expand((g) => g.studentIds).toSet();
  print('📊 Dashboard: Found ${groups.length} groups, ${studentIds.length} students');

  // ✅ Step 3: Load and ACCUMULATE assignments for each course
  final List<Assignment> allAssignments = [];
  
  for (final course in courses) {
    try {
      // Load assignments for this course
      await ref.read(assignmentProvider.notifier).loadAssignments(course.id);
      
      // Read the loaded assignments for THIS course immediately after loading
      final courseAssignments = ref.read(assignmentProvider)
          .where((a) => a.courseId == course.id)
          .toList();
      
      print('📊 Course ${course.code}: ${courseAssignments.length} assignments');
      
      // Count submissions for this course
      int courseSubs = 0;
      for (final a in courseAssignments) {
        courseSubs += a.submissions.length;
      }
      print('   └─ ${courseSubs} submissions');
      
      allAssignments.addAll(courseAssignments);
    } catch (e) {
      print('⚠️ Error loading assignments for course ${course.id}: $e');
    }
  }
  
  // Count total submissions
  int totalSubmissions = 0;
  for (final a in allAssignments) {
    totalSubmissions += a.submissions.length;
  }
  
  print('📊 Dashboard TOTAL: ${allAssignments.length} assignments with $totalSubmissions submissions');

  // ✅ Step 4: Cache the data
  ref.read(_dashboardDataProvider.notifier).state = _DashboardData(
    semesterId: widget.semesterId,
    coursesCount: courses.length,
    groupsCount: groups.length,
    studentsCount: studentIds.length,
    allAssignments: allAssignments,
    courses: courses,
    loadedAt: DateTime.now(),
  );
}

  Future<void> _forceRefresh() async {
    ref.read(_dashboardDataProvider.notifier).state = null;
    await _loadFreshData();
  }

  _DashboardData? get _cachedData => ref.watch(_dashboardDataProvider);

  // ══════════════════════════════════════════════════════════════════════════
  // SUBMISSION STATS FOR LAST 7 DAYS
  // ══════════════════════════════════════════════════════════════════════════

  List<AssignmentSubmission> _getSubmissionsLast7Days() {
    final data = _cachedData;
    if (data == null) return [];

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    final submissions = <AssignmentSubmission>[];
    for (final assignment in data.allAssignments) {
      for (final submission in assignment.submissions) {
        if (submission.submittedAt.isAfter(sevenDaysAgo)) {
          submissions.add(submission);
        }
      }
    }
    return submissions;
  }

  List<_GroupedSubmissionData> _getSubmissionsGroupedByAssignment({required bool graded}) {
    final data = _cachedData;
    if (data == null) return [];

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final result = <_GroupedSubmissionData>[];

    for (final assignment in data.allAssignments) {
      final filteredSubmissions = assignment.submissions.where((s) {
        final isInLast7Days = s.submittedAt.isAfter(sevenDaysAgo);
        final isGraded = s.grade != null;
        return isInLast7Days && (graded ? isGraded : !isGraded);
      }).toList();

      if (filteredSubmissions.isEmpty) continue;

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

      result.add(_GroupedSubmissionData(
        assignment: assignment,
        course: course,
        submissions: filteredSubmissions,
      ));
    }

    return result;
  }

  int get _onTimeSubmissionsLast7Days {
    return _getSubmissionsLast7Days().where((s) => !s.isLate).length;
  }

  int get _lateSubmissionsLast7Days {
    return _getSubmissionsLast7Days().where((s) => s.isLate).length;
  }

  int get _pendingGradingLast7Days {
    return _getSubmissionsLast7Days().where((s) => s.grade == null).length;
  }

  int get _gradedLast7Days {
    return _getSubmissionsLast7Days().where((s) => s.grade != null).length;
  }

  int get _totalSubmissionsLast7Days {
    return _getSubmissionsLast7Days().length;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXISTING STATS
  // ══════════════════════════════════════════════════════════════════════════

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

    result.sort((a, b) {
      final aSubs = a['submissions'] as List?;
      final bSubs = b['submissions'] as List?;
      final aOldest = (aSubs != null && aSubs.isNotEmpty)
          ? aSubs.map((s) => (s as Map)['daysOld'] as int? ?? 0).reduce((x, y) => x > y ? x : y)
          : 0;
      final bOldest = (bSubs != null && bSubs.isNotEmpty)
          ? bSubs.map((s) => (s as Map)['daysOld'] as int? ?? 0).reduce((x, y) => x > y ? x : y)
          : 0;
      return bOldest.compareTo(aOldest);
    });

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION HELPER
  // ══════════════════════════════════════════════════════════════════════════

  void _navigateToCourseAssignments(Course course) {
    final semesters = ref.read(semesterProvider);
    if (semesters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isVietnamese() ? 'Không tìm thấy học kỳ' : 'No semesters found')),
      );
      return;
    }
    
    final semester = semesters.firstWhere(
      (s) => s.id == course.semesterId,
      orElse: () => semesters.first,
    );

    final allGroups = ref.read(groupProvider);
    final groups = allGroups.where((g) => g.courseId == course.id).toList();

    final allStudents = ref.read(studentProvider);
    final studentIds = <String>{};
    for (final g in groups) {
      studentIds.addAll(g.studentIds);
    }
    final students = allStudents.where((s) => studentIds.contains(s.id)).toList();

    context.push(
      '/instructor/course/${course.id}/assignments',
      extra: {
        'course': course,
        'semester': semester,
        'groups': groups,
        'students': students,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD METHODS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final data = _cachedData;

    if (_error != null && data == null) {
      return _buildErrorWidget();
    }

    if (_isLoading && data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_isVietnamese() ? 'Đang tải dữ liệu...' : 'Loading data...'),
            const SizedBox(height: 8),
            Text(
              _isVietnamese() ? 'Đang tải bài tập và bài nộp...' : 'Loading assignments and submissions...',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_isVietnamese() ? 'Không có dữ liệu' : 'No data'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _forceRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(_isVietnamese() ? 'Tải lại' : 'Reload'),
            ),
          ],
        ),
      );
    }

    final recentUngraded = _getUngradedAssignments(maxDaysOld: 7);
    final weekOldUngraded = _getUngradedAssignments(minDaysOld: 7, maxDaysOld: 30);
    final monthOldUngraded = _getUngradedAssignments(minDaysOld: 30, maxDaysOld: 9999);

    final hasContent = recentUngraded.isNotEmpty || 
                       weekOldUngraded.isNotEmpty || 
                       monthOldUngraded.isNotEmpty ||
                       _totalSubmissions > 0;

    return RefreshIndicator(
      onRefresh: _forceRefresh,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildWelcomeCard(),
              
              // ✅ Show refresh indicator when updating in background
              if (_isRefreshing)
                _buildRefreshingBanner(),
              
              const SizedBox(height: 16),
              _buildQuickStats(data),
              const SizedBox(height: 16),
              
              // ✅ Debug info (can be removed later)
              _buildDebugInfo(data),
              const SizedBox(height: 16),
              
              _buildLast7DaysSubmissionStats(),
              const SizedBox(height: 16),
              
              _buildGradingProgress(),
              
              if (monthOldUngraded.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAssignmentsSection(
                  title: _isVietnamese() ? '🚨 Quá 30 ngày chưa chấm' : '🚨 Over 30 days ungraded',
                  subtitle: _isVietnamese() ? 'Cần xử lý ngay!' : 'Needs immediate attention!',
                  assignments: monthOldUngraded,
                  color: Colors.red[700]!,
                  icon: Icons.error,
                ),
              ],

              if (weekOldUngraded.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAssignmentsSection(
                  title: _isVietnamese() ? '⚠️ 7-30 ngày chưa chấm' : '⚠️ 7-30 days ungraded',
                  subtitle: _isVietnamese() ? 'Nên chấm sớm' : 'Should grade soon',
                  assignments: weekOldUngraded,
                  color: Colors.orange,
                  icon: Icons.warning_amber,
                ),
              ],

              if (recentUngraded.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAssignmentsSection(
                  title: _isVietnamese() ? '📝 Mới nộp (< 7 ngày)' : '📝 Recent (< 7 days)',
                  subtitle: _isVietnamese() ? 'Bài nộp gần đây' : 'Recent submissions',
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
        ],
      ),
    );
  }

  // ✅ Debug info widget to help diagnose issues
  Widget _buildDebugInfo(_DashboardData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Debug Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              const Spacer(),
              Text(
                'Loaded: ${data.loadedAt.hour}:${data.loadedAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('📚 ${data.coursesCount} courses', style: const TextStyle(fontSize: 11)),
              Text('📝 ${data.allAssignments.length} assignments', style: const TextStyle(fontSize: 11)),
              Text('📤 $_totalSubmissions total subs', style: const TextStyle(fontSize: 11)),
              Text('⏰ $_totalSubmissionsLast7Days last 7d', style: const TextStyle(fontSize: 11)),
            ],
          ),
          if (data.allAssignments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'First assignment: ${data.allAssignments.first.title} (${data.allAssignments.first.submissions.length} subs)',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefreshingBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            _isVietnamese() ? 'Đang cập nhật dữ liệu...' : 'Updating data...',
            style: TextStyle(fontSize: 12, color: Colors.blue[700]),
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
            Text(_error ?? (_isVietnamese() ? 'Đã xảy ra lỗi' : 'An error occurred'), 
                 textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _forceRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(_isVietnamese() ? 'Thử lại' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final allGraded = _totalSubmissions > 0 && _ungradedSubmissions == 0;
    final isVietnamese = _isVietnamese();

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
            allGraded
                ? (isVietnamese ? 'Đã chấm hết! 🎉' : 'All graded! 🎉')
                : (isVietnamese ? 'Chưa có bài nộp' : 'No submissions yet'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: allGraded ? Colors.green[700] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            allGraded
                ? (isVietnamese
                    ? 'Tất cả $_totalSubmissions bài nộp đã được chấm điểm'
                    : 'All $_totalSubmissions submissions have been graded')
                : (isVietnamese ? 'Tạo bài tập để sinh viên nộp bài' : 'Create assignments for students to submit'),
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
    final isVietnamese = _isVietnamese();

    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? (isVietnamese ? 'Chào buổi sáng' : 'Good morning')
        : (hour < 18
            ? (isVietnamese ? 'Chào buổi chiều' : 'Good afternoon')
            : (isVietnamese ? 'Chào buổi tối' : 'Good evening'));
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
                    Text(user?.fullName ?? (isVietnamese ? 'Giảng viên' : 'Instructor'), 
                         style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
    final isVietnamese = _isVietnamese();
    return Row(
      children: [
        _statCard(Icons.book, data.coursesCount, isVietnamese ? 'Môn học' : 'Courses', Colors.blue),
        const SizedBox(width: 10),
        _statCard(Icons.group_work, data.groupsCount, isVietnamese ? 'Nhóm' : 'Groups', Colors.orange),
        const SizedBox(width: 10),
        _statCard(Icons.people, data.studentsCount, isVietnamese ? 'Sinh viên' : 'Students', Colors.green),
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

  // ══════════════════════════════════════════════════════════════════════════
  // LAST 7 DAYS SUBMISSION STATS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLast7DaysSubmissionStats() {
    final isVietnamese = _isVietnamese();
    final total = _totalSubmissionsLast7Days;
    final onTime = _onTimeSubmissionsLast7Days;
    final late = _lateSubmissionsLast7Days;
    final pending = _pendingGradingLast7Days;
    final graded = _gradedLast7Days;

    final gradedGrouped = _getSubmissionsGroupedByAssignment(graded: true);
    final pendingGrouped = _getSubmissionsGroupedByAssignment(graded: false);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  isVietnamese ? 'Bài nộp 7 ngày qua' : 'Submissions (Last 7 Days)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$total ${isVietnamese ? 'bài' : 'total'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (total == 0)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      isVietnamese ? 'Không có bài nộp trong 7 ngày qua' : 'No submissions in the last 7 days',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _submissionStatusCard(
                      icon: Icons.check_circle,
                      value: onTime,
                      label: isVietnamese ? 'Đúng hạn' : 'On Time',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _submissionStatusCard(
                      icon: Icons.schedule,
                      value: late,
                      label: isVietnamese ? 'Trễ hạn' : 'Late',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            if (total > 0) 
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStatusBreakdownBar(onTime, late, total),
              ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            
            _buildExpandableSubmissionSection(
              title: isVietnamese ? 'Chờ chấm điểm' : 'Pending Grading',
              count: pending,
              color: Colors.red,
              icon: Icons.pending_actions,
              groupedData: pendingGrouped,
              isGraded: false,
            ),
            
            const Divider(height: 1),
            
            _buildExpandableSubmissionSection(
              title: isVietnamese ? 'Đã chấm điểm' : 'Already Graded',
              count: graded,
              color: Colors.blue,
              icon: Icons.grading,
              groupedData: gradedGrouped,
              isGraded: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _submissionStatusCard({
    required IconData icon,
    required int value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdownBar(int onTime, int late, int total) {
    final isVietnamese = _isVietnamese();
    final onTimePercent = total > 0 ? (onTime / total * 100) : 0.0;
    final latePercent = total > 0 ? (late / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isVietnamese ? 'Tỷ lệ nộp bài' : 'Submission Breakdown', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              if (onTime > 0) Expanded(flex: onTime, child: Container(height: 8, color: Colors.green)),
              if (late > 0) Expanded(flex: late, child: Container(height: 8, color: Colors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(width: 10, height: 10, color: Colors.green),
              const SizedBox(width: 4),
              Text('${isVietnamese ? 'Đúng hạn' : 'On Time'}: ${onTimePercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10)),
            ]),
            Row(children: [
              Container(width: 10, height: 10, color: Colors.orange),
              const SizedBox(width: 4),
              Text('${isVietnamese ? 'Trễ hạn' : 'Late'}: ${latePercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10)),
            ]),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPANDABLE SUBMISSION SECTION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildExpandableSubmissionSection({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required List<_GroupedSubmissionData> groupedData,
    required bool isGraded,
  }) {
    final isVietnamese = _isVietnamese();

    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        if (groupedData.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(isVietnamese ? 'Không có bài nộp' : 'No submissions', style: TextStyle(color: Colors.grey[500])),
          )
        else
          ...groupedData.map((data) => _buildAssignmentDropdown(
            assignment: data.assignment,
            course: data.course,
            submissions: data.submissions,
            isGraded: isGraded,
            color: color,
          )),
      ],
    );
  }

  Widget _buildAssignmentDropdown({
    required Assignment assignment,
    required Course course,
    required List<AssignmentSubmission> submissions,
    required bool isGraded,
    required Color color,
  }) {
    final isVietnamese = _isVietnamese();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          radius: 18,
          child: Icon(Icons.assignment, color: color, size: 18),
        ),
        title: Text(assignment.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(course.name, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text('${submissions.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        children: [
          ...submissions.map((submission) {
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: submission.isLate ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                child: Icon(submission.isLate ? Icons.schedule : Icons.check, size: 14, color: submission.isLate ? Colors.orange : Colors.green),
              ),
              title: Text(submission.studentName, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${submission.submittedAt.day}/${submission.submittedAt.month}/${submission.submittedAt.year} ${submission.submittedAt.hour}:${submission.submittedAt.minute.toString().padLeft(2, '0')}'
                '${submission.isLate ? (isVietnamese ? ' • Trễ' : ' • Late') : ''}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              trailing: isGraded && submission.grade != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('${submission.grade}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  : Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              onTap: () => _navigateToCourseAssignments(course),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => _navigateToCourseAssignments(course),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(isVietnamese ? 'Xem tất cả bài tập' : 'View all assignments', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GRADING PROGRESS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGradingProgress() {
    final total = _totalSubmissions;
    final progress = total > 0 ? _gradedSubmissions / total : 0.0;
    final progressColor = progress >= 0.8 ? Colors.green : (progress >= 0.5 ? Colors.orange : Colors.red);
    final isVietnamese = _isVietnamese();

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
              Text(isVietnamese ? 'Tiến độ chấm bài (Tổng)' : 'Grading Progress (All Time)', 
                   style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                    Text(isVietnamese ? 'Chưa có bài nộp' : 'No submissions yet', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: progressColor)),
                          const SizedBox(width: 8),
                          Text('$_gradedSubmissions/$total', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation(progressColor)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (_ungradedSubmissions > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Text('$_ungradedSubmissions', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                        Text(isVietnamese ? 'chờ chấm' : 'pending', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ASSIGNMENTS SECTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAssignmentsSection({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> assignments,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Text('${assignments.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          ...assignments.take(5).map((item) {
            final assignment = item['assignment'] as Assignment?;
            final course = item['course'] as Course?;
            final ungradedCount = item['ungradedCount'] as int? ?? 0;

            if (assignment == null || course == null) return const SizedBox.shrink();

            return ListTile(
              onTap: () => _navigateToCourseAssignments(course),
              leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(Icons.assignment, color: color, size: 20)),
              title: Text(assignment.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(course.name, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('$ungradedCount', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
            );
          }),
          if (assignments.length > 5)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  _isVietnamese() ? '+${assignments.length - 5} bài tập khác...' : '+${assignments.length - 5} more...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
