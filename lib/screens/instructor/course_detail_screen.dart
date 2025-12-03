// screens/instructor/course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/course.dart';
import '../../models/group.dart' as app;
import '../../models/semester.dart';
import '../../models/user.dart';
import '../../main.dart'; // for localeProvider
import '../../theme/app_theme.dart';
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
  final int initialTabIndex;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.semester,
    required this.groups,
    required this.students,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with TickerProviderStateMixin {
  late List<AppUser> currentStudents;
  late TabController _tabController;
  late AnimationController _headerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    currentStudents = List.from(widget.students);
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
    );

    // Header animation setup
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _headerAnimationController.forward();

    print('CourseDetailScreen initialized');
    print('Course: ${widget.course.name}');
    print('Initial tab index: ${widget.initialTabIndex}');
    print('Groups count: ${widget.groups.length}');
    for (var group in widget.groups) {
      print('  - ${group.name} (ID: ${group.id}, Students: ${group.studentIds.length})');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = currentStudents.length;
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildModernAppBar(isVietnamese),
          _buildCourseInfoHeader(isVietnamese, totalStudents),
          _buildTabBarSliver(isVietnamese),
        ],
        body: TabBarView(
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
    );
  }

  Widget _buildModernAppBar(bool isVietnamese) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 16, 16, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.course.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.course.code} • ${widget.semester.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onPressed: () => _showCourseOptionsMenu(isVietnamese),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseInfoHeader(bool isVietnamese, int totalStudents) {
    return SliverToBoxAdapter(
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildStatCard(
                    icon: Icons.people_alt_rounded,
                    value: totalStudents.toString(),
                    label: isVietnamese ? 'Sinh viên' : 'Students',
                    color: AppTheme.primaryPurple,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    icon: Icons.group_work_rounded,
                    value: widget.groups.length.toString(),
                    label: isVietnamese ? 'Nhóm' : 'Groups',
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    icon: Icons.calendar_today_rounded,
                    value: widget.course.sessions.toString(),
                    label: isVietnamese ? 'Buổi học' : 'Sessions',
                    color: AppTheme.info,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarSliver(bool isVietnamese) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryPurple,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            _buildAnimatedTab(Icons.campaign_rounded, isVietnamese ? 'Thông báo' : 'Announcements', 0),
            _buildAnimatedTab(Icons.assignment_rounded, isVietnamese ? 'Bài tập' : 'Assignments', 1),
            _buildAnimatedTab(Icons.quiz_rounded, 'Quiz', 2),
            _buildAnimatedTab(Icons.folder_rounded, isVietnamese ? 'Tài liệu' : 'Materials', 3),
            _buildAnimatedTab(Icons.groups_rounded, isVietnamese ? 'Nhóm' : 'Groups', 4),
            _buildAnimatedTab(Icons.forum_rounded, isVietnamese ? 'Diễn đàn' : 'Forum', 5),
            _buildAnimatedTab(Icons.analytics_rounded, isVietnamese ? 'Thống kê' : 'Analytics', 6),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTab(IconData icon, String text, int index) {
    return Tab(
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          final isSelected = _tabController.index == index;
          return AnimatedContainer(
            duration: AppAnimations.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryPurple.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(text),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCourseOptionsMenu(bool isVietnamese) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isVietnamese ? 'Tùy chọn khóa học' : 'Course Options',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.edit_rounded,
              title: isVietnamese ? 'Chỉnh sửa khóa học' : 'Edit Course',
              color: AppTheme.primaryPurple,
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.share_rounded,
              title: isVietnamese ? 'Chia sẻ mã khóa học' : 'Share Course Code',
              color: AppTheme.success,
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.download_rounded,
              title: isVietnamese ? 'Xuất danh sách sinh viên' : 'Export Student List',
              color: AppTheme.info,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    print('Building AnnouncementsTab with ${widget.groups.length} groups');
    return AnnouncementsTab(
      courseId: widget.course.id,
      groups: widget.groups,
      students: widget.students,
    );
  }

  Widget _buildAssignmentsTab() {
    print('Building AssignmentsTab with ${widget.groups.length} groups');
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
    print('Building GroupsTab with ${widget.groups.length} groups');
    return GroupsTab(
      courseId: widget.course.id,
      groups: widget.groups,
    );
  }

  Widget _buildQuizTab() {
    print('Building QuizTab');
    return QuizTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
    );
  }

  Widget _buildMaterialTab() {
    print('Building MaterialTab');
    return MaterialTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
      students: widget.students,
    );
  }

  Widget _buildForumTab() {
    print('Building ForumTab');
    return ForumListWidget(
      courseId: widget.course.id,
      courseName: widget.course.name,
      isInstructor: true,
    );
  }

  Widget _buildAnalyticsTab() {
    print('Building AnalyticsTab');
    return AnalyticsTab(
      courseId: widget.course.id,
      courseName: widget.course.name,
      students: widget.students,
    );
  }
}

// Custom delegate for the sticky tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.backgroundWhite,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
