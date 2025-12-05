// lib/screens/instructor/home_instructor.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/message_provider.dart';
import '../../models/semester.dart';
import '../../models/course.dart';
import '../../models/user.dart';
import '../../services/ai_service.dart';
import '../shared/inbox_screen.dart';
import '../shared/ai_chatbot_screen.dart';
import 'csv_preview_screen.dart';
import 'material_summarizer_screen.dart';
import 'test_screen.dart';
import 'cache_management_screen.dart';
import 'ai_quiz_generator_screen.dart';
import 'instructor_dashboard_widget.dart';
import '../../widgets/language_switcher.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class HomeInstructor extends ConsumerStatefulWidget {
  const HomeInstructor({super.key});
  @override
  ConsumerState<HomeInstructor> createState() => _HomeInstructorState();
}

class _HomeInstructorState extends ConsumerState<HomeInstructor>
    with TickerProviderStateMixin {
  String? _selectedSemesterId;
  bool _isLoading = false;
  late TabController _tabController;
  int _currentBottomNavIndex = 0;

  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

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

    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        ref.read(semesterProvider.notifier).loadSemesters(),
        ref.read(courseProvider.notifier).loadCourses(),
        ref.read(studentProvider.notifier).loadStudents(),
        ref.read(groupProvider.notifier).loadGroups(),
        _loadConversations(),
      ]);

      // Start animations after data loads
      _fadeController.forward();
      _slideController.forward();

      print('All data refreshed');
    } catch (e, stack) {
      print('Refresh error: $e\n$stack');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConversations() async {
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(conversationProvider.notifier).loadConversations(user.id, true);
    }
  }

  void _handleSecretCode(BuildContext dialogContext, String code) {
    Navigator.pop(dialogContext);

    switch (code.toLowerCase().trim()) {
      case 'tester':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TestScreen()));
        break;
      case 'cache':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CacheManagementScreen()));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Invalid access code'), backgroundColor: AppTheme.error),
        );
    }
  }

  void _showSecretDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.lock, color: AppTheme.primaryPurple),
            ),
            const SizedBox(width: 12),
            const Text('Admin Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter access code to continue:'),
            const SizedBox(height: 8),
            Text('Hint: "tester" or "cache"', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: AppTheme.inputDecoration(hintText: 'Enter code...', prefixIcon: Icons.key),
              obscureText: true,
              onSubmitted: (value) => _handleSecretCode(ctx, value),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _handleSecretCode(ctx, codeController.text),
            style: AppTheme.primaryButtonStyle,
            child: const Text('Enter'),
          ),
        ],
      ),
    );
  }

  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)!;
    final semesters = ref.watch(semesterProvider);
    final courses = ref.watch(courseProvider);
    final students = ref.watch(studentProvider);
    final conversations = ref.watch(conversationProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    final filteredCourses = _selectedSemesterId == null
        ? courses.where((c) => c.instructorId == user.id).toList()
        : courses.where((c) => c.instructorId == user.id && c.semesterId == _selectedSemesterId).toList();

    final unreadCount = conversations.fold<int>(0, (sum, c) => sum + c.unreadCountInstructor);

    final pages = [
      _buildHomeTab(user, semesters, filteredCourses, students),
      const InboxScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: _currentBottomNavIndex == 0
          ? _buildModernAppBar(user, unreadCount, isVietnamese)
          : null,
      bottomNavigationBar: _buildModernBottomNav(unreadCount, isVietnamese),
      floatingActionButton: _buildFloatingActionButton(isVietnamese),
      body: pages[_currentBottomNavIndex],
    );
  }

  PreferredSizeWidget _buildModernAppBar(AppUser user, int unreadCount, bool isVietnamese) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
          ),
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
                  user.fullName,
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
          icon: Icons.science_outlined,
          onPressed: () {
            final now = DateTime.now();
            if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 2) {
              _secretTapCount = 0;
            }
            _lastTapTime = now;
            _secretTapCount++;

            if (_secretTapCount >= 5) {
              _secretTapCount = 0;
              _showSecretDialog();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tap ${5 - _secretTapCount} more times...'),
                  duration: const Duration(milliseconds: 500),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                ),
              );
            }
          },
        ),
        _buildAppBarIconButton(
          icon: Icons.message_outlined,
          badge: unreadCount,
          onPressed: () => setState(() => _currentBottomNavIndex = 1),
        ),
        _buildAppBarIconButton(
          icon: Icons.logout_rounded,
          onPressed: () {
            ref.read(authProvider.notifier).logout();
            context.go('/');
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                icon: Icons.home_rounded,
                label: isVietnamese ? 'Trang chủ' : 'Home',
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

  Widget _buildHomeTab(
    AppUser user,
    List<Semester> semesters,
    List<Course> filteredCourses,
    List<AppUser> students,
  ) {
    final isVietnamese = _isVietnamese();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Modern Semester Selector
            _buildModernSemesterSelector(semesters, isVietnamese),

            // Modern Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.primaryPurple,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorColor: AppTheme.primaryPurple,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(icon: const Icon(Icons.dashboard_rounded, size: 20), text: isVietnamese ? 'Tổng quan' : 'Overview'),
                  Tab(icon: const Icon(Icons.auto_awesome_rounded, size: 20), text: 'AI Tools'),
                  Tab(icon: const Icon(Icons.book_rounded, size: 20), text: isVietnamese ? 'Môn học' : 'Courses'),
                  Tab(icon: const Icon(Icons.people_rounded, size: 20), text: isVietnamese ? 'Sinh viên' : 'Students'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isVietnamese ? 'Đang tải...' : 'Loading...',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        InstructorDashboardWidget(semesterId: _selectedSemesterId),
                        _buildAIToolsTab(filteredCourses),
                        _buildCoursesTab(filteredCourses, semesters, user),
                        _buildStudentsTab(students),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSemesterSelector(List<Semester> semesters, bool isVietnamese) {
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
                labelText: isVietnamese ? 'Chọn học kỳ' : 'Select semester',
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
              items: [
                DropdownMenuItem(value: null, child: Text(isVietnamese ? 'Tất cả học kỳ' : 'All semesters')),
                ...semesters.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Row(
                        children: [
                          Expanded(child: Text('${s.code}: ${s.name}', overflow: TextOverflow.ellipsis)),
                          if (s.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedSemesterId = v),
            ),
          ),
          const SizedBox(width: 8),
          _buildSemesterActions(semesters, isVietnamese),
        ],
      ),
    );
  }

  Widget _buildSemesterActions(List<Semester> semesters, bool isVietnamese) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedSemesterId != null &&
            !semesters.any((s) => s.id == _selectedSemesterId && s.isActive))
          _buildIconButton(
            icon: Icons.play_arrow_rounded,
            color: AppTheme.success,
            tooltip: isVietnamese ? 'Kích hoạt học kỳ' : 'Activate semester',
            onPressed: () => _activateSemester(semesters),
          ),
        _buildIconButton(
          icon: Icons.add_circle_rounded,
          color: AppTheme.success,
          tooltip: isVietnamese ? 'Thêm học kỳ' : 'Add semester',
          onPressed: () => context.push('/instructor/semester/create'),
        ),
        if (_selectedSemesterId != null &&
            !semesters.any((s) => s.id == _selectedSemesterId && s.isActive))
          _buildIconButton(
            icon: Icons.delete_rounded,
            color: AppTheme.error,
            tooltip: isVietnamese ? 'Xóa học kỳ' : 'Delete semester',
            onPressed: () => _deleteSemester(semesters),
          ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: IconButton(
          icon: Icon(icon, color: color, size: 22),
          onPressed: onPressed,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AI TOOLS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAIToolsTab(List<Course> courses) {
    final isVietnamese = _isVietnamese();
    final isConfigured = AIService.isConfigured;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryPurple,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI Status Card
          _buildAIStatusCard(isConfigured, isVietnamese),
          const SizedBox(height: 24),

          // AI Features Section
          _buildSectionTitle(isVietnamese ? 'Tính năng AI' : 'AI Features', Icons.auto_awesome_rounded),
          const SizedBox(height: 16),

          // AI Chatbot Card
          _buildModernAIFeatureCard(
            icon: Icons.smart_toy_rounded,
            title: isVietnamese ? 'Trợ lý AI' : 'AI Assistant',
            subtitle: isVietnamese
                ? 'Chat hỗ trợ học tập cho sinh viên'
                : 'Learning support chat for students',
            features: isVietnamese
                ? ['Giải thích khái niệm khó', 'Trả lời câu hỏi bài học', 'Hướng dẫn làm bài tập', 'Gợi ý cách học hiệu quả']
                : ['Explain difficult concepts', 'Answer lesson questions', 'Guide through assignments', 'Suggest study methods'],
            color: AppTheme.primaryPurple,
            onTap: isConfigured ? () => context.push('/ai-chat') : null,
          ),
          const SizedBox(height: 12),

          // AI Quiz Generator Card
          _buildModernAIFeatureCard(
            icon: Icons.quiz_rounded,
            title: isVietnamese ? 'Tạo Quiz bằng AI' : 'AI Quiz Generator',
            subtitle: isVietnamese
                ? 'Tự động tạo câu hỏi từ tài liệu'
                : 'Auto-generate questions from materials',
            features: isVietnamese
                ? ['Tạo câu hỏi trắc nghiệm', 'Điều chỉnh độ khó', 'Tự động giải thích đáp án', 'Nhiều loại câu hỏi']
                : ['Generate multiple choice questions', 'Adjust difficulty level', 'Auto-explain answers', 'Multiple question types'],
            color: const Color(0xFFFF9500),
            onTap: isConfigured && courses.isNotEmpty
                ? () => _showSelectCourseForQuizDialog(courses)
                : null,
          ),
          const SizedBox(height: 12),

          // AI Material Summarizer Card
          _buildModernAIFeatureCard(
            icon: Icons.summarize_rounded,
            title: isVietnamese ? 'Tóm tắt tài liệu' : 'Material Summarizer',
            subtitle: isVietnamese
                ? 'Tóm tắt nội dung bài học'
                : 'Summarize lesson content',
            features: isVietnamese
                ? ['Tóm tắt ngắn gọn', 'Trích xuất điểm chính', 'Tạo câu hỏi ôn tập', 'Gợi ý cách học']
                : ['Concise summary', 'Extract key points', 'Generate review questions', 'Study suggestions'],
            color: const Color(0xFF00BFA5),
            onTap: isConfigured ? () => _showMaterialSummarizerDialog() : null,
          ),

          const SizedBox(height: 24),

          // Quick Actions
          _buildSectionTitle(isVietnamese ? 'Truy cập nhanh' : 'Quick Access', Icons.flash_on_rounded),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionChip(
                icon: Icons.chat_rounded,
                label: isVietnamese ? 'Mở AI Chat' : 'Open AI Chat',
                color: AppTheme.primaryPurple,
                onTap: isConfigured ? () => context.push('/ai-chat') : null,
              ),
              if (courses.isNotEmpty)
                ...courses.take(3).map((course) => _buildQuickActionChip(
                      icon: Icons.auto_awesome_rounded,
                      label: '${isVietnamese ? 'Tạo Quiz' : 'Generate Quiz'}: ${course.code}',
                      color: const Color(0xFFFF9500),
                      onTap: isConfigured
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => AIQuizGeneratorScreen(course: course),
                                ),
                              )
                          : null,
                    )),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAIStatusCard(bool isConfigured, bool isVietnamese) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isConfigured ? AppTheme.primaryGradient : const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)]),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVietnamese ? 'Công cụ AI' : 'AI Tools',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConfigured ? AppTheme.success : AppTheme.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConfigured
                              ? (isVietnamese ? 'Đã kết nối' : 'Connected')
                              : (isVietnamese ? 'Chưa cấu hình API' : 'API not configured'),
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isConfigured) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isVietnamese
                          ? 'Thêm GEMINI_API_KEY vào file .env để sử dụng AI'
                          : 'Add GEMINI_API_KEY to .env file to use AI',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: AppTheme.primaryPurple, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildModernAIFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> features,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.5,
      duration: AppAnimations.fast,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                            ),
                            if (!isEnabled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Text(
                                  _isVietnamese() ? 'Cần API' : 'Need API',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: features.map((f) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: color, size: 14),
                              const SizedBox(width: 4),
                              Text(f, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                  if (isEnabled)
                    Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      child: Material(
        color: onTap != null ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: onTap != null ? color : Colors.grey, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: onTap != null ? color : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSelectCourseForQuizDialog(List<Course> courses) {
    final isVietnamese = _isVietnamese();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.quiz_rounded, color: Color(0xFFFF9500)),
            ),
            const SizedBox(width: 12),
            Text(isVietnamese ? 'Chọn môn học' : 'Select Course'),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(Icons.book_rounded, color: Color(0xFFFF9500), size: 20),
                  ),
                  title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(course.code, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => AIQuizGeneratorScreen(course: course)),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
          ),
        ],
      ),
    );
  }

void _showMaterialSummarizerDialog() {
  // Navigate to the new full-screen summarizer
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const MaterialSummarizerScreen(),
    ),
  );
}

  void _showSummaryResultDialog(Map<String, dynamic> summary) {
    final isVietnamese = _isVietnamese();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success),
            ),
            const SizedBox(width: 12),
            Text(isVietnamese ? 'Kết quả tóm tắt' : 'Summary Result'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary['summary'] != null) ...[
                  _buildSummarySection(isVietnamese ? 'Tóm tắt:' : 'Summary:', Icons.description_rounded, AppTheme.primaryPurple),
                  const SizedBox(height: 8),
                  Text(summary['summary']),
                  const SizedBox(height: 16),
                ],
                if (summary['keyPoints'] != null) ...[
                  _buildSummarySection(isVietnamese ? 'Điểm chính:' : 'Key Points:', Icons.star_rounded, const Color(0xFFFF9500)),
                  const SizedBox(height: 8),
                  ...((summary['keyPoints'] as List).map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(point.toString())),
                          ],
                        ),
                      ))),
                  const SizedBox(height: 16),
                ],
                if (summary['reviewQuestions'] != null) ...[
                  _buildSummarySection(isVietnamese ? 'Các câu hỏi ôn tập:' : 'Review Questions:', Icons.help_rounded, AppTheme.info),
                  const SizedBox(height: 8),
                  ...((summary['reviewQuestions'] as List).asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${entry.key + 1}. ${entry.value}'),
                      ))),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: AppTheme.primaryButtonStyle,
            child: Text(isVietnamese ? 'Đóng' : 'Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _activateSemester(List<Semester> semesters) async {
    final selectedSemester = semesters.firstWhere((s) => s.id == _selectedSemesterId);
    final isVietnamese = _isVietnamese();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: AppTheme.success),
            ),
            const SizedBox(width: 12),
            Text(isVietnamese ? 'Kích hoạt học kỳ' : 'Activate Semester'),
          ],
        ),
        content: Text(
          isVietnamese
              ? 'Đặt "${selectedSemester.name}" làm học kỳ hiện tại?'
              : 'Set "${selectedSemester.name}" as the current semester?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isVietnamese ? 'Hủy' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVietnamese ? 'Kích hoạt' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm == true && _selectedSemesterId != null) {
      try {
        await ref.read(semesterProvider.notifier).setActiveSemester(_selectedSemesterId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isVietnamese ? 'Đã kích hoạt: ${selectedSemester.name}' : 'Activated: ${selectedSemester.name}'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  Future<void> _deleteSemester(List<Semester> semesters) async {
    final semesterToDelete = semesters.firstWhere((s) => s.id == _selectedSemesterId);
    final isVietnamese = _isVietnamese();

    final confirm = await showDialog<bool>(
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
              child: const Icon(Icons.delete_rounded, color: AppTheme.error),
            ),
            const SizedBox(width: 12),
            Text(isVietnamese ? 'Xóa học kỳ' : 'Delete Semester'),
          ],
        ),
        content: Text(isVietnamese ? 'Xóa "${semesterToDelete.name}"?' : 'Delete "${semesterToDelete.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isVietnamese ? 'Hủy' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVietnamese ? 'Xóa' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(semesterProvider.notifier).deleteSemester(_selectedSemesterId!);
      setState(() => _selectedSemesterId = null);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COURSES TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCoursesTab(List<Course> courses, List<Semester> semesters, AppUser user) {
    final isVietnamese = _isVietnamese();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryPurple,
      child: courses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.book_rounded, size: 48, color: AppTheme.primaryPurple),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isVietnamese ? 'Chưa có môn học nào' : 'No courses yet',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: Text(isVietnamese ? 'Thêm môn học' : 'Add course'),
                    onPressed: () => _showCreateCourseDialog(context, semesters, user),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: Text(isVietnamese ? 'Thêm môn học mới' : 'Add new course'),
                      onPressed: () => _showCreateCourseDialog(context, semesters, user),
                      style: AppTheme.primaryButtonStyle.copyWith(
                        minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
                      ),
                    ),
                  );
                }

                final course = courses[i - 1];
                final semester = semesters.firstWhere(
                  (s) => s.id == course.semesterId,
                  orElse: () => Semester(id: '', code: 'N/A', name: 'Unknown'),
                );

                return _buildModernCourseCard(course, semester, isVietnamese);
              },
            ),
    );
  }

  Widget _buildModernCourseCard(Course course, Semester semester, bool isVietnamese) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          onTap: () async {
            final currentGroups = ref.read(groupProvider);
            if (currentGroups.isEmpty) {
              await ref.read(groupProvider.notifier).loadGroups();
            }

            final allGroups = ref.read(groupProvider);
            final groups = allGroups.where((g) => g.courseId == course.id).toList();

            final allStudents = ref.read(studentProvider);
            final courseStudents = allStudents
                .where((s) => groups.any((g) => g.studentIds.contains(s.id)))
                .toList();

            if (mounted) {
              context.push(
                '/instructor/course/${course.id}',
                extra: {
                  'course': course,
                  'semester': semester,
                  'groups': groups,
                  'students': courseStudents,
                },
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.primaries[course.code.hashCode % Colors.primaries.length],
                        Colors.primaries[course.code.hashCode % Colors.primaries.length].withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.book_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Text(
                              course.code,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                          ),
                          if (semester.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.success),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${semester.name} - ${course.sessions} ${isVietnamese ? 'buổi' : 'sessions'}',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENTS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStudentsTab(List<AppUser> students) {
    final isVietnamese = _isVietnamese();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(isVietnamese ? 'Thêm Sinh viên' : 'Add Student'),
            onPressed: _showAddStudentOptions,
            style: AppTheme.primaryButtonStyle.copyWith(
              minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
            ),
          ),
        ),
        Expanded(
          child: students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_rounded, size: 48, color: AppTheme.primaryPurple),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isVietnamese ? 'Chưa có sinh viên' : 'No students yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return _buildModernStudentCard(s, isVietnamese);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModernStudentCard(AppUser student, bool isVietnamese) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Center(
            child: Text(
              student.code != null && student.code!.isNotEmpty ? student.code![0] : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          '${student.code ?? 'N/A'} - ${student.email}',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: IconButton(
            icon: const Icon(Icons.message_rounded, color: AppTheme.primaryPurple, size: 20),
            onPressed: () async {
              final user = ref.read(authProvider)!;
              await ref.read(conversationProvider.notifier).getOrCreateConversation(
                    instructorId: user.id,
                    instructorName: user.fullName,
                    studentId: student.id,
                    studentName: student.fullName,
                  );

              if (mounted) {
                setState(() => _currentBottomNavIndex = 1);
              }
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════
  void _showCreateCourseDialog(BuildContext context, List<Semester> semesters, AppUser user) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final sessionsCtrl = TextEditingController(text: '10');
    String? selectedSemesterId;
    final formKey = GlobalKey<FormState>();
    final isVietnamese = _isVietnamese();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(Icons.add_rounded, color: AppTheme.success),
              ),
              const SizedBox(width: 12),
              Text(isVietnamese ? 'Thêm Môn Học' : 'Add Course'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: AppTheme.inputDecoration(
                      hintText: isVietnamese ? 'VD: WEB101' : 'e.g. WEB101',
                      prefixIcon: Icons.code_rounded,
                    ).copyWith(labelText: isVietnamese ? 'Mã môn học *' : 'Course code *'),
                    validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Mã môn học là bắt buộc' : 'Required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: AppTheme.inputDecoration(
                      hintText: isVietnamese ? 'VD: Lập trình Web' : 'e.g. Web Programming',
                      prefixIcon: Icons.book_rounded,
                    ).copyWith(labelText: isVietnamese ? 'Tên môn học *' : 'Course name *'),
                    validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: sessionsCtrl,
                    decoration: AppTheme.inputDecoration(
                      hintText: '10',
                      prefixIcon: Icons.calendar_today_rounded,
                    ).copyWith(labelText: isVietnamese ? 'Số buổi học *' : 'Number of sessions *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return isVietnamese ? 'Bắt buộc' : 'Required';
                      final n = int.tryParse(v!);
                      if (n == null || n < 1) return isVietnamese ? 'Phải là số dương' : 'Must be positive';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedSemesterId,
                    decoration: AppTheme.inputDecoration(
                      hintText: isVietnamese ? 'Chọn học kỳ' : 'Select semester',
                      prefixIcon: Icons.school_rounded,
                    ).copyWith(labelText: isVietnamese ? 'Học kỳ *' : 'Semester *'),
                    items: semesters.isEmpty
                        ? [DropdownMenuItem(value: null, child: Text(isVietnamese ? 'Chưa có học kỳ' : 'No semesters'))]
                        : [
                            DropdownMenuItem(value: null, child: Text(isVietnamese ? 'Chọn học kỳ' : 'Select semester')),
                            ...semesters.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.code}: ${s.name}'))),
                          ],
                    onChanged: semesters.isEmpty ? null : (v) => setDialogState(() => selectedSemesterId = v),
                    validator: (v) => v == null ? (isVietnamese ? 'Bắt buộc chọn học kỳ' : 'Please select a semester') : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isVietnamese ? 'Hủy' : 'Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedSemesterId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isVietnamese ? 'Vui lòng chọn học kỳ' : 'Please select a semester')),
                  );
                  return;
                }

                try {
                  await ref.read(courseProvider.notifier).createCourse(
                        code: codeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        sessions: int.parse(sessionsCtrl.text.trim()),
                        semesterId: selectedSemesterId!,
                        instructorId: user.id,
                        instructorName: user.fullName,
                      );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isVietnamese
                          ? 'Đã thêm môn học: ${nameCtrl.text.trim()}'
                          : 'Added course: ${nameCtrl.text.trim()}'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  await _refreshData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              style: AppTheme.primaryButtonStyle,
              child: Text(isVietnamese ? 'Tạo' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStudentOptions() {
    final isVietnamese = _isVietnamese();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            const SizedBox(height: 24),
            Text(
              isVietnamese ? 'Chọn cách thêm sinh viên' : 'Choose how to add students',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.upload_file_rounded,
              title: isVietnamese ? 'Nhập từ CSV' : 'Import from CSV',
              subtitle: isVietnamese ? 'Thêm nhiều sinh viên cùng lúc' : 'Add multiple students at once',
              color: AppTheme.info,
              onTap: () {
                Navigator.pop(ctx);
                _showCsvImportDialog(context);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.person_add_rounded,
              title: isVietnamese ? 'Thêm thủ công / Tạo nhanh' : 'Add manually / Quick create',
              subtitle: isVietnamese ? 'Nhập từng người hoặc tạo mẫu' : 'Enter individually or create samples',
              color: AppTheme.success,
              onTap: () {
                Navigator.pop(ctx);
                _showAddStudentDialog();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      ),
    );
  }

  void _showAddStudentDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final quickCountCtrl = TextEditingController(text: '1');
    final quickBaseCodeCtrl = TextEditingController(text: '2023001');
    final quickFormKey = GlobalKey<FormState>();
    final isVietnamese = _isVietnamese();

    final firstNames = ['Nguyen', 'Tran', 'Le', 'Pham', 'Hoang', 'Huynh', 'Vu', 'Dang', 'Bui', 'Do'];
    final lastNames = ['An', 'Binh', 'Cuong', 'Dung', 'Ha', 'Khoa', 'Lan', 'Minh', 'Nam', 'Oanh'];

    showDialog(
      context: context,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: Builder(
            builder: (tabContext) {
              final tabController = DefaultTabController.of(tabContext);

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: AppTheme.success),
                    ),
                    const SizedBox(width: 12),
                    Text(isVietnamese ? 'Thêm sinh viên' : 'Add Student'),
                  ],
                ),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: TabBar(
                          labelColor: AppTheme.primaryPurple,
                          unselectedLabelColor: AppTheme.textSecondary,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          tabs: [
                            Tab(text: isVietnamese ? 'Thủ công' : 'Manual'),
                            Tab(text: isVietnamese ? 'Tạo nhanh' : 'Quick Create'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 280,
                        child: TabBarView(
                          children: [
                            Form(
                              key: formKey,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextFormField(
                                      controller: codeCtrl,
                                      decoration: AppTheme.inputDecoration(
                                        hintText: isVietnamese ? 'VD: 2023001' : 'e.g. 2023001',
                                        prefixIcon: Icons.badge_rounded,
                                      ).copyWith(labelText: isVietnamese ? 'Mã SV *' : 'Student ID *'),
                                      validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: nameCtrl,
                                      decoration: AppTheme.inputDecoration(
                                        hintText: isVietnamese ? 'VD: Nguyen Van A' : 'e.g. John Doe',
                                        prefixIcon: Icons.person_rounded,
                                      ).copyWith(labelText: isVietnamese ? 'Họ và tên *' : 'Full name *'),
                                      validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: emailCtrl,
                                      decoration: AppTheme.inputDecoration(
                                        hintText: 'student@school.edu',
                                        prefixIcon: Icons.email_rounded,
                                      ).copyWith(labelText: 'Email'),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Form(
                              key: quickFormKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: quickBaseCodeCtrl,
                                    decoration: AppTheme.inputDecoration(
                                      hintText: '2023001',
                                      prefixIcon: Icons.numbers_rounded,
                                    ).copyWith(labelText: isVietnamese ? 'Mã SV bắt đầu *' : 'Starting ID *'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v?.trim().isEmpty == true) return isVietnamese ? 'Bắt buộc' : 'Required';
                                      if (int.tryParse(v!) == null) return isVietnamese ? 'Phải là số' : 'Must be a number';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: quickCountCtrl,
                                    decoration: AppTheme.inputDecoration(
                                      hintText: '1-50',
                                      prefixIcon: Icons.group_rounded,
                                    ).copyWith(labelText: isVietnamese ? 'Số lượng *' : 'Count *'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v?.trim().isEmpty == true) return isVietnamese ? 'Bắt buộc' : 'Required';
                                      final n = int.tryParse(v!);
                                      if (n == null || n < 1 || n > 50) return '1-50';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.info.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isVietnamese
                                                ? 'Tên & email sẽ được tạo tự động'
                                                : 'Name & email will be auto-generated',
                                            style: TextStyle(fontSize: 12, color: AppTheme.info),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isVietnamese ? 'Hủy' : 'Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      final tabIndex = tabController.index;

                      if (tabIndex == 0) {
                        if (!formKey.currentState!.validate()) return;
                        final code = codeCtrl.text.trim();
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();

                        final exists = ref.read(studentProvider).any((s) => s.code == code);
                        if (exists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isVietnamese ? 'Mã SV đã tồn tại' : 'Student ID already exists'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                          return;
                        }

                        try {
                          await ref.read(studentProvider.notifier).createStudent(code: code, fullName: name, email: email);
                          await ref.read(studentProvider.notifier).loadStudents();
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isVietnamese ? 'Đã thêm: $name' : 'Added: $name'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e'), backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      } else {
                        if (!quickFormKey.currentState!.validate()) return;
                        final baseCode = int.parse(quickBaseCodeCtrl.text.trim());
                        final count = int.parse(quickCountCtrl.text.trim());
                        final existingCodes = ref.read(studentProvider).map((s) => s.code).toSet();
                        int created = 0;

                        for (int i = 0; i < count; i++) {
                          final code = '${baseCode + i}';
                          if (existingCodes.contains(code)) continue;

                          final first = firstNames[DateTime.now().millisecond % firstNames.length];
                          final last = lastNames[(baseCode + i) % lastNames.length];
                          final name = '$first $last';
                          final email = '${last.toLowerCase()}$code@school.com';

                          try {
                            await ref.read(studentProvider.notifier).createStudent(code: code, fullName: name, email: email);
                            created++;
                          } catch (e) {
                            print('Quick create error: $e');
                          }
                        }

                        await ref.read(studentProvider.notifier).loadStudents();
                        Navigator.pop(ctx);
                        if (mounted && created > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isVietnamese ? 'Đã tạo $created sinh viên' : 'Created $created students'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      }
                    },
                    style: AppTheme.primaryButtonStyle,
                    child: Text(isVietnamese ? 'Thêm' : 'Add'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showCsvImportDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const CsvPreviewScreen()),
    ).then((_) {
      ref.read(studentProvider.notifier).loadStudents();
    });
  }
}
