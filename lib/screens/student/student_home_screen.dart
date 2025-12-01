// screens/student/student_home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/semester.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/in_app_notification_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/quiz_provider.dart';
import '../shared/inbox_screen.dart';
import '../student/in_app_notification_screen.dart';
import 'student_course_detail_screen.dart';
import 'student_dashboard_screen.dart';
import '../../widgets/language_switcher.dart';
import '../../main.dart'; // for localeProvider

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  String? _selectedSemesterId;
  bool _showDashboard = false;
  int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(semesterProvider.notifier).loadSemesters();
      ref.read(courseProvider.notifier).loadCourses();
      ref.read(groupProvider.notifier).loadGroups();
      _loadConversations();
      _loadNotifications();
    });
  }

  Future<void> _loadConversations() async {
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(conversationProvider.notifier).loadConversations(
            user.id,
            false, // isInstructor = false
          );
    }
  }

  Future<void> _loadNotifications() async {
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(inAppNotificationProvider.notifier).loadNotifications(user.id);
    }
  }

  Future<void> _loadDashboardData() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    // Get student's enrolled courses
    final allGroups = ref.read(groupProvider);
    
    final studentGroups = allGroups.where((g) => 
      g.studentIds.contains(user.id)
    ).toList();

    final enrolledCourseIds = studentGroups
        .map((g) => g.courseId)
        .toSet()
        .toList();

    // Load assignments and quizzes for all enrolled courses
    for (final courseId in enrolledCourseIds) {
      await ref.read(assignmentProvider.notifier).loadAssignments(courseId);
      await ref.read(quizProvider.notifier).loadQuizzes(courseId: courseId);
    }
    
    // Load ALL quiz submissions for the student (not filtered by course)
    await ref.read(quizSubmissionProvider.notifier).loadSubmissions();
    
    print('✅ Loaded dashboard data for ${enrolledCourseIds.length} courses');
  }

  // ✅ NEW: Build user avatar widget
  Widget _buildUserAvatar(dynamic user) {
    if (user == null) {
      return const Icon(Icons.account_circle);
    }

    // Check for base64 avatar first
    if (user.avatarBase64 != null && user.avatarBase64!.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 14,
          backgroundImage: MemoryImage(base64Decode(user.avatarBase64!)),
        );
      } catch (e) {
        print('Error decoding avatar: $e');
      }
    }

    // Check for URL avatar
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(user.avatarUrl!),
      );
    }

    // Fallback: Show initial letter
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.blue[100],
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  // Helper method to check if Vietnamese
  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final semesters = ref.watch(semesterProvider);
    final allCourses = ref.watch(courseProvider);
    final allGroups = ref.watch(groupProvider);
    final conversations = ref.watch(conversationProvider);
    final notifications = ref.watch(inAppNotificationProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    // ✅ UPDATED: Auto-select active semester (or first if none active)
    if (_selectedSemesterId == null && semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          // Try to find active semester first
          final activeSemester = semesters.firstWhere(
            (s) => s.isActive,
            orElse: () => semesters.first,
          );
          _selectedSemesterId = activeSemester.id;
        });
      });
    }

    final selectedSemester = semesters.firstWhere(
      (s) => s.id == _selectedSemesterId,
      orElse: () => semesters.isNotEmpty ? semesters.first : Semester(id: '', code: '', name: ''),
    );

    // Get student's enrolled courses
    final studentGroups = allGroups.where((g) => 
      g.studentIds.contains(user?.id ?? '')
    ).toList();

    final enrolledCourses = allCourses.where((course) {
      return course.semesterId == _selectedSemesterId &&
             studentGroups.any((g) => g.courseId == course.id);
    }).toList();

    // ✅ UPDATED: Check if semester is active (students can only submit in active semester)
    final activeSemester = semesters.firstWhere(
      (s) => s.isActive,
      orElse: () => semesters.isNotEmpty ? semesters.first : Semester(id: '', code: '', name: ''),
    );
    
    final isPastSemester = selectedSemester.id != activeSemester.id;

    // Calculate unread counts
    final unreadMessageCount = conversations.fold<int>(
      0,
      (sum, c) => sum + c.unreadCountStudent,
    );
    final unreadNotificationCount = notifications.where((n) => !n.isRead).length;

    // Bottom navigation pages
    final pages = [
      _buildHomeTab(
        semesters,
        selectedSemester,
        enrolledCourses,
        studentGroups,
        isPastSemester,
      ),
      const InboxScreen(),
    ];

    return Scaffold(
      appBar: _currentBottomNavIndex == 0 // Only show AppBar on home tab
          ? AppBar(
              title: Text(isVietnamese ? 'Khóa học của tôi' : 'My Courses'),
              actions: [
                // Language switcher
                const LanguageSwitcher(),
                // Dashboard toggle
                IconButton(
                  icon: Icon(_showDashboard ? Icons.grid_view : Icons.dashboard),
                  onPressed: () => setState(() => _showDashboard = !_showDashboard),
                  tooltip: _showDashboard
                      ? (isVietnamese ? 'Xem khóa học' : 'View courses')
                      : (isVietnamese ? 'Xem dashboard' : 'View dashboard'),
                ),
                // Notification bell
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InAppNotificationScreen(),
                          ),
                        );
                      },
                      tooltip: isVietnamese ? 'Thông báo' : 'Notifications',
                    ),
                    if (unreadNotificationCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadNotificationCount > 99 ? '99+' : '$unreadNotificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                // ✅ UPDATED: Profile button with actual avatar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButton(
                    icon: _buildUserAvatar(user),
                    onPressed: () => context.push('/student/profile'),
                    tooltip: isVietnamese ? 'Hồ sơ cá nhân' : 'Profile',
                  ),
                ),
                // Logout
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    _showLogoutConfirmDialog(context, ref, isVietnamese);
                  },
                  tooltip: isVietnamese ? 'Đăng xuất' : 'Logout',
                ),
              ],
            )
          : null,
      // Bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          setState(() => _currentBottomNavIndex = index);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.school),
            label: isVietnamese ? 'Khóa học' : 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.message),
                if (unreadMessageCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        unreadMessageCount > 9 ? '9+' : '$unreadMessageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: isVietnamese ? 'Tin nhắn' : 'Messages',
          ),
        ],
      ),
      body: pages[_currentBottomNavIndex],
    );
  }

  // ✅ NEW: Logout confirmation dialog
  void _showLogoutConfirmDialog(BuildContext context, WidgetRef ref, bool isVietnamese) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            Text(isVietnamese ? 'Đăng xuất' : 'Logout'),
          ],
        ),
        content: Text(isVietnamese ? 'Bạn có chắc muốn đăng xuất?' : 'Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isVietnamese ? 'Đăng xuất' : 'Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(
    List<Semester> semesters,
    Semester selectedSemester,
    List<Course> enrolledCourses,
    List<Group> studentGroups,
    bool isPastSemester,
  ) {
    final isVietnamese = _isVietnamese();

    return Column(
      children: [
        // Semester Switcher
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSemesterId,
                  decoration: InputDecoration(
                    labelText: isVietnamese ? 'Học kỳ' : 'Semester',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: semesters.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${s.code}: ${s.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (s.isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isVietnamese ? 'Hiện tại' : 'Current',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedSemesterId = value),
                ),
              ),
            ],
          ),
        ),

        // Warning for non-active semesters
        if (isPastSemester)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVietnamese
                        ? 'Học kỳ cũ - Chỉ xem và tải tài liệu, không thể nộp bài hoặc làm quiz'
                        : 'Past semester - View only, cannot submit assignments or take quizzes',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),

        // Content: Dashboard or Course Cards
        Expanded(
          child: _showDashboard
              ? _buildDashboardView(enrolledCourses)
              : _buildCourseCards(enrolledCourses, selectedSemester, studentGroups, isPastSemester),
        ),
      ],
    );
  }

  Widget _buildDashboardView(List<Course> enrolledCourses) {
    // Load dashboard data when switching to dashboard view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
    
    return StudentDashboardScreen(
      semesterId: _selectedSemesterId ?? '',
      courses: enrolledCourses,
    );
  }

  Widget _buildCourseCards(
    List<Course> courses,
    Semester semester,
    List<Group> studentGroups,
    bool isPastSemester,
  ) {
    final isVietnamese = _isVietnamese();

    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isVietnamese ? 'Chưa có khóa học nào' : 'No courses yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        
        final courseGroup = studentGroups.firstWhere(
          (g) => g.courseId == course.id,
          orElse: () => Group(
            id: '',
            name: 'N/A',
            courseId: '',
          ),
        );

        return _CourseCard(
          course: course,
          semester: semester,
          groupName: courseGroup.name,
          isPastSemester: isPastSemester,
          isVietnamese: isVietnamese,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentCourseDetailScreen(
                  course: course,
                  semester: semester,
                  isPastSemester: isPastSemester,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final Semester semester;
  final String groupName;
  final bool isPastSemester;
  final bool isVietnamese;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.semester,
    required this.groupName,
    required this.isPastSemester,
    required this.isVietnamese,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.primaries[course.code.hashCode % Colors.primaries.length],
                    Colors.primaries[course.code.hashCode % Colors.primaries.length].withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        course.code,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Show "Past" badge for non-active semesters
                  if (isPastSemester)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isVietnamese ? 'Cũ' : 'Past',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Course Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course.instructorName,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.group, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            groupName,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}