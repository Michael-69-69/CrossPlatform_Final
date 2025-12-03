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
import '../../main.dart';
import '../../theme/app_theme.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen>
    with TickerProviderStateMixin {
  String? _selectedSemesterId;
  bool _showDashboard = false;
  int _currentBottomNavIndex = 0;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _slideController = AnimationController(
      vsync: this,
      duration: AppAnimations.slow,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: AppAnimations.defaultCurve),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: AppAnimations.defaultCurve),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      ref.read(semesterProvider.notifier).loadSemesters(),
      ref.read(courseProvider.notifier).loadCourses(),
      ref.read(groupProvider.notifier).loadGroups(),
      _loadConversations(),
      _loadNotifications(),
    ]);

    // Start animations after data loads
    _fadeController.forward();
    _slideController.forward();
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

    print('Loaded dashboard data for ${enrolledCourseIds.length} courses');
  }

  Widget _buildUserAvatar(dynamic user) {
    if (user == null) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      );
    }

    // Check for base64 avatar first
    if (user.avatarBase64 != null && user.avatarBase64!.isNotEmpty) {
      try {
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            image: DecorationImage(
              image: MemoryImage(base64Decode(user.avatarBase64!)),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (e) {
        print('Error decoding avatar: $e');
      }
    }

    // Check for URL avatar
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          image: DecorationImage(
            image: NetworkImage(user.avatarUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback: Show initial letter
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Center(
        child: Text(
          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

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

    // Auto-select active semester (or first if none active)
    if (_selectedSemesterId == null && semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
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

    // Check if semester is active
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
      backgroundColor: AppTheme.backgroundWhite,
      appBar: _currentBottomNavIndex == 0
          ? _buildModernAppBar(user, unreadNotificationCount, isVietnamese)
          : null,
      bottomNavigationBar: _buildModernBottomNav(unreadMessageCount, isVietnamese),
      floatingActionButton: _buildFloatingActionButton(isVietnamese),
      body: pages[_currentBottomNavIndex],
    );
  }

  PreferredSizeWidget _buildModernAppBar(dynamic user, int notificationCount, bool isVietnamese) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          _buildUserAvatar(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVietnamese ? 'Xin chào' : 'Hello',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  user?.fullName ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const LanguageSwitcher(),
        _buildAppBarIconButton(
          icon: _showDashboard ? Icons.grid_view_rounded : Icons.dashboard_rounded,
          onPressed: () => setState(() => _showDashboard = !_showDashboard),
          tooltip: _showDashboard
              ? (isVietnamese ? 'Xem khóa học' : 'View courses')
              : (isVietnamese ? 'Xem dashboard' : 'View dashboard'),
        ),
        _buildAppBarIconButton(
          icon: Icons.notifications_outlined,
          badge: notificationCount,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InAppNotificationScreen(),
              ),
            );
          },
        ),
        _buildAppBarIconButton(
          icon: Icons.person_outline_rounded,
          onPressed: () => context.push('/student/profile'),
        ),
        _buildAppBarIconButton(
          icon: Icons.logout_rounded,
          onPressed: () {
            _showLogoutConfirmDialog(context, ref, isVietnamese);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarIconButton({
    required IconData icon,
    int badge = 0,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip ?? '',
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: IconButton(
                icon: Icon(icon, color: AppTheme.primaryPurple, size: 22),
                onPressed: onPressed,
              ),
            ),
            if (badge > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBottomNav(int unreadCount, bool isVietnamese) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.school_rounded,
                label: isVietnamese ? 'Khóa học' : 'Courses',
                isSelected: _currentBottomNavIndex == 0,
                onTap: () => setState(() => _currentBottomNavIndex = 0),
              ),
              _buildNavItem(
                icon: Icons.message_rounded,
                label: isVietnamese ? 'Tin nhắn' : 'Messages',
                isSelected: _currentBottomNavIndex == 1,
                badge: unreadCount,
                onTap: () => setState(() => _currentBottomNavIndex = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryPurple : AppTheme.textSecondary,
                  size: 24,
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isVietnamese) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: FloatingActionButton.extended(
        onPressed: () => context.push('/ai-chat'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
        label: Text(
          'AI Chat',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, WidgetRef ref, bool isVietnamese) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.error),
            ),
            const SizedBox(width: 12),
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
              backgroundColor: AppTheme.error,
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Modern Semester Switcher
            _buildModernSemesterSelector(semesters, isPastSemester, isVietnamese),

            // Warning for non-active semesters
            if (isPastSemester) _buildPastSemesterWarning(isVietnamese),

            // Content: Dashboard or Course Cards
            Expanded(
              child: _showDashboard
                  ? _buildDashboardView(enrolledCourses)
                  : _buildCourseCards(enrolledCourses, selectedSemester, studentGroups, isPastSemester),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSemesterSelector(List<Semester> semesters, bool isPastSemester, bool isVietnamese) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedSemesterId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isVietnamese ? 'Học kỳ' : 'Semester',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
    );
  }

  Widget _buildPastSemesterWarning(bool isVietnamese) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isVietnamese
                  ? 'Học kỳ cũ - Chỉ xem và tải tài liệu, không thể nộp bài hoặc làm quiz'
                  : 'Past semester - View only, cannot submit assignments or take quizzes',
              style: TextStyle(color: Colors.orange[800], fontSize: 13),
            ),
          ),
        ],
      ),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, size: 48, color: AppTheme.primaryPurple),
            ),
            const SizedBox(height: 16),
            Text(
              isVietnamese ? 'Chưa có khóa học nào' : 'No courses yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              isVietnamese ? 'Hãy liên hệ giáo viên để được thêm vào lớp' : 'Contact your instructor to be added to a class',
              style: TextStyle(color: AppTheme.textHint, fontSize: 13),
              textAlign: TextAlign.center,
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
        childAspectRatio: 0.78,
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

        return _ModernCourseCard(
          course: course,
          semester: semester,
          groupName: courseGroup.name,
          isPastSemester: isPastSemester,
          isVietnamese: isVietnamese,
          index: index,
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

class _ModernCourseCard extends StatefulWidget {
  final Course course;
  final Semester semester;
  final String groupName;
  final bool isPastSemester;
  final bool isVietnamese;
  final int index;
  final VoidCallback onTap;

  const _ModernCourseCard({
    required this.course,
    required this.semester,
    required this.groupName,
    required this.isPastSemester,
    required this.isVietnamese,
    required this.index,
    required this.onTap,
  });

  @override
  State<_ModernCourseCard> createState() => _ModernCourseCardState();
}

class _ModernCourseCardState extends State<_ModernCourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + (widget.index * 100)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Colors.primaries[widget.course.code.hashCode % Colors.primaries.length];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image with Gradient
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cardColor, cardColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Stack(
                    children: [
                      // Pattern overlay
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PatternPainter(color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                      // Course code badge
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.course.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cardColor,
                            ),
                          ),
                        ),
                      ),
                      // Past badge
                      if (widget.isPastSemester)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warning,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                            child: Text(
                              widget.isVietnamese ? 'Cũ' : 'Past',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Course icon
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: const Icon(Icons.book_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // Course Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // Instructor
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.person_rounded, size: 12, color: AppTheme.primaryPurple),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.course.instructorName,
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Group
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.group_rounded, size: 12, color: cardColor),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.groupName,
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
        ),
      ),
    );
  }
}

// Custom painter for pattern overlay
class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double i = -size.height; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
