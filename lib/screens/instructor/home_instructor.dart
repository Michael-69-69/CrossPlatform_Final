// screens/instructor/home_instructor.dart
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
import '../shared/inbox_screen.dart';
import 'csv_preview_screen.dart';
import 'test_screen.dart';
import 'cache_management_screen.dart';
import 'instructor_dashboard_widget.dart'; // ✅ Import the dashboard widget
import '../../widgets/language_switcher.dart';
import '../../main.dart'; // for localeProvider

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

  // Secret test button tracking
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // ✅ 3 tabs now
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

      print('✅ All data refreshed');
      print('  - Semesters: ${ref.read(semesterProvider).length}');
      print('  - Courses: ${ref.read(courseProvider).length}');
      print('  - Students: ${ref.read(studentProvider).length}');
      print('  - Groups: ${ref.read(groupProvider).length}');
    } catch (e, stack) {
      print('Refresh error: $e\n$stack');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConversations() async {
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(conversationProvider.notifier).loadConversations(
            user.id,
            true,
          );
    }
  }

  void _handleSecretCode(BuildContext dialogContext, String code) {
    Navigator.pop(dialogContext);

    switch (code.toLowerCase().trim()) {
      case 'tester':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TestScreen()),
        );
        break;

      case 'cache':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CacheManagementScreen()),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Invalid access code'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _showSecretDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.deepPurple),
            SizedBox(width: 12),
            Text('🔐 Admin Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter access code to continue:'),
            const SizedBox(height: 8),
            Text(
              'Hint: "tester" hoặc "cache"',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Access Code',
                border: OutlineInputBorder(),
                hintText: 'Enter code...',
              ),
              obscureText: true,
              onSubmitted: (value) => _handleSecretCode(ctx, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _handleSecretCode(ctx, codeController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Enter'),
          ),
        ],
      ),
    );
  }

  // Helper method to check if Vietnamese
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
        : courses
            .where((c) =>
                c.instructorId == user.id && c.semesterId == _selectedSemesterId)
            .toList();

    final unreadCount = conversations.fold<int>(
      0,
      (sum, c) => sum + c.unreadCountInstructor,
    );

    final pages = [
      _buildHomeTab(user, semesters, filteredCourses, students),
      const InboxScreen(),
    ];

    return Scaffold(
      appBar: _currentBottomNavIndex == 0
          ? AppBar(
              title: Text(isVietnamese ? 'GV: ${user.fullName}' : 'Instructor: ${user.fullName}'),
              actions: [
                // Language switcher
                const LanguageSwitcher(),
                // Test access button
                IconButton(
                  icon: const Icon(Icons.science),
                  tooltip: 'Test Dashboard',
                  onPressed: () {
                    final now = DateTime.now();
                    if (_lastTapTime != null &&
                        now.difference(_lastTapTime!).inSeconds > 2) {
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
                        ),
                      );
                    }
                  },
                ),
                // Message icon with badge
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.message),
                      onPressed: () => setState(() => _currentBottomNavIndex = 1),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/');
                  },
                ),
              ],
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) => setState(() => _currentBottomNavIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: isVietnamese ? 'Trang chủ' : 'Home',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.message),
                if (unreadCount > 0)
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
                        unreadCount > 9 ? '9+' : '$unreadCount',
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

  Widget _buildHomeTab(
    AppUser user,
    List<Semester> semesters,
    List<Course> filteredCourses,
    List<AppUser> students,
  ) {
    return Column(
      children: [
        // Semester Selector
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.all(12),
          child: _buildSemesterSelector(semesters),
        ),

        // ✅ 3 Tabs: Tổng quan (Dashboard), Môn học, Sinh viên
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard), text: _isVietnamese() ? 'Tổng quan' : 'Overview'),
            Tab(icon: const Icon(Icons.book), text: _isVietnamese() ? 'Môn học' : 'Courses'),
            Tab(icon: const Icon(Icons.people), text: _isVietnamese() ? 'Sinh viên' : 'Students'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // ✅ USE THE SEPARATE DASHBOARD WIDGET
                    InstructorDashboardWidget(
                      semesterId: _selectedSemesterId,
                    ),
                    _buildCoursesTab(filteredCourses, semesters, user),
                    _buildStudentsTab(students),
                  ],
                ),
        ),
      ],
    );
  }

Widget _buildSemesterSelector(List<Semester> semesters) {
  final isVietnamese = _isVietnamese();

  return Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          value: _selectedSemesterId,
          isExpanded: true, // ✅ FIX: Allow dropdown to expand properly
          decoration: InputDecoration(
            labelText: isVietnamese ? 'Chọn học kỳ' : 'Select semester',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.school),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: _selectedSemesterId != null &&
                    semesters.any((s) => s.id == _selectedSemesterId && s.isActive)
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : null,
          ),
          items: [
            DropdownMenuItem(value: null, child: Text(isVietnamese ? 'Tất cả học kỳ' : 'All semesters')),
            ...semesters.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Row(
                    children: [
                      Expanded( // ✅ FIX: Use Expanded instead of Flexible with MainAxisSize.min
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
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
      // Action buttons in a more compact layout
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Activate Button
          if (_selectedSemesterId != null &&
              !semesters.any((s) => s.id == _selectedSemesterId && s.isActive))
            Tooltip(
              message: isVietnamese ? 'Kích hoạt học kỳ' : 'Activate semester',
              child: IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                onPressed: () => _activateSemester(semesters),
              ),
            ),
          // Add semester button
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.green),
            tooltip: isVietnamese ? 'Thêm học kỳ' : 'Add semester',
            onPressed: () => context.push('/instructor/semester/create'),
          ),
          // Delete semester button
          if (_selectedSemesterId != null &&
              !semesters.any((s) => s.id == _selectedSemesterId && s.isActive))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: isVietnamese ? 'Xóa học kỳ' : 'Delete semester',
              onPressed: () => _deleteSemester(semesters),
            ),
        ],
      ),
    ],
  );
}

  Future<void> _activateSemester(List<Semester> semesters) async {
    final selectedSemester =
        semesters.firstWhere((s) => s.id == _selectedSemesterId);
    final isVietnamese = _isVietnamese();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVietnamese ? 'Kích hoạt học kỳ' : 'Activate Semester'),
        content: Text(
          isVietnamese
              ? 'Đặt "${selectedSemester.name}" làm học kỳ hiện tại?\n\n'
                '• Sinh viên chỉ có thể nộp bài/làm quiz trong học kỳ này\n'
                '• Các học kỳ khác sẽ chuyển sang chế độ chỉ xem'
              : 'Set "${selectedSemester.name}" as the current semester?\n\n'
                '• Students can only submit assignments/take quizzes in this semester\n'
                '• Other semesters will become view-only',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVietnamese ? 'Kích hoạt' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm == true && _selectedSemesterId != null) {
      try {
        await ref
            .read(semesterProvider.notifier)
            .setActiveSemester(_selectedSemesterId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isVietnamese
                  ? '✅ Đã kích hoạt: ${selectedSemester.name}'
                  : '✅ Activated: ${selectedSemester.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ ${isVietnamese ? 'Lỗi' : 'Error'}: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteSemester(List<Semester> semesters) async {
    final semesterToDelete =
        semesters.firstWhere((s) => s.id == _selectedSemesterId);
    final isVietnamese = _isVietnamese();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVietnamese ? 'Xóa học kỳ' : 'Delete Semester'),
        content: Text(isVietnamese
            ? 'Xóa "${semesterToDelete.name}"?'
            : 'Delete "${semesterToDelete.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVietnamese ? 'Xóa' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(semesterProvider.notifier)
          .deleteSemester(_selectedSemesterId!);
      setState(() => _selectedSemesterId = null);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COURSES TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCoursesTab(
      List<Course> courses, List<Semester> semesters, AppUser user) {
    final isVietnamese = _isVietnamese();

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: courses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.book, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(isVietnamese ? 'Chưa có môn học nào' : 'No courses yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(isVietnamese ? 'Thêm môn học' : 'Add course'),
                    onPressed: () =>
                        _showCreateCourseDialog(context, semesters, user),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              itemBuilder: (context, i) {
                final course = courses[i];
                final semester = semesters.firstWhere(
                  (s) => s.id == course.semesterId,
                  orElse: () =>
                      Semester(id: '', code: 'N/A', name: 'Không xác định'),
                );

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.book, color: Colors.green),
                    title: Text('${course.code}: ${course.name}'),
                    subtitle: Row(
                      children: [
                        Flexible(
                          child: Text(
                            isVietnamese
                                ? '${semester.name} • ${course.sessions} buổi'
                                : '${semester.name} • ${course.sessions} sessions',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (semester.isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      final currentGroups = ref.read(groupProvider);
                      if (currentGroups.isEmpty) {
                        await ref.read(groupProvider.notifier).loadGroups();
                      }

                      final allGroups = ref.read(groupProvider);
                      final groups =
                          allGroups.where((g) => g.courseId == course.id).toList();

                      final allStudents = ref.read(studentProvider);
                      final courseStudents = allStudents
                          .where(
                              (s) => groups.any((g) => g.studentIds.contains(s.id)))
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
                  ),
                );
              },
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
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(isVietnamese ? 'Thêm Sinh viên' : 'Add Student'),
            onPressed: _showAddStudentOptions,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: students.isEmpty
              ? Center(child: Text(isVietnamese ? 'Chưa có sinh viên' : 'No students yet'))
              : ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            s.code != null && s.code!.isNotEmpty
                                ? s.code![0]
                                : '?',
                          ),
                        ),
                        title: Text(s.fullName),
                        subtitle: Text('${s.code} • ${s.email}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.message),
                          onPressed: () async {
                            final user = ref.read(authProvider)!;
                            await ref
                                .read(conversationProvider.notifier)
                                .getOrCreateConversation(
                                  instructorId: user.id,
                                  instructorName: user.fullName,
                                  studentId: s.id,
                                  studentName: s.fullName,
                                );

                            if (mounted) {
                              setState(() => _currentBottomNavIndex = 1);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════
  void _showCreateCourseDialog(
      BuildContext context, List<Semester> semesters, AppUser user) {
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
          title: Text(isVietnamese ? 'Thêm Môn Học' : 'Add Course'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Mã môn học *' : 'Course code *',
                      hintText: isVietnamese ? 'VD: WEB101' : 'e.g. WEB101',
                      prefixIcon: const Icon(Icons.code),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Tên môn học *' : 'Course name *',
                      hintText: isVietnamese ? 'VD: Lập trình Web' : 'e.g. Web Programming',
                      prefixIcon: const Icon(Icons.book),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sessionsCtrl,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Số buổi học *' : 'Number of sessions *',
                      hintText: isVietnamese ? 'VD: 10, 15, 20' : 'e.g. 10, 15, 20',
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return isVietnamese ? 'Bắt buộc' : 'Required';
                      final n = int.tryParse(v!);
                      if (n == null || n < 1) return isVietnamese ? 'Phải là số dương' : 'Must be positive';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSemesterId,
                    decoration: InputDecoration(
                      labelText: isVietnamese ? 'Học kỳ *' : 'Semester *',
                      prefixIcon: const Icon(Icons.school),
                    ),
                    items: semesters.isEmpty
                        ? [
                            DropdownMenuItem(
                                value: null, child: Text(isVietnamese ? 'Chưa có học kỳ' : 'No semesters'))
                          ]
                        : [
                            DropdownMenuItem(
                                value: null, child: Text(isVietnamese ? 'Chọn học kỳ' : 'Select semester')),
                            ...semesters.map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text('${s.code}: ${s.name}'),
                                )),
                          ],
                    onChanged: semesters.isEmpty
                        ? null
                        : (v) => setDialogState(() => selectedSemesterId = v),
                    validator: (v) => v == null ? (isVietnamese ? 'Bắt buộc chọn học kỳ' : 'Please select a semester') : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
            ),
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
                        content:
                            Text(isVietnamese
                                ? 'Đã thêm môn học: ${nameCtrl.text.trim()}'
                                : 'Added course: ${nameCtrl.text.trim()}')),
                  );
                  await _refreshData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
                    );
                  }
                }
              },
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
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isVietnamese ? 'Chọn cách thêm sinh viên' : 'Choose how to add students',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: Text(isVietnamese ? 'Nhập từ CSV' : 'Import from CSV'),
              subtitle: Text(isVietnamese ? 'Thêm nhiều sinh viên cùng lúc' : 'Add multiple students at once'),
              onTap: () {
                Navigator.pop(ctx);
                _showCsvImportDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.green),
              title: Text(isVietnamese ? 'Thêm thủ công / Tạo nhanh' : 'Add manually / Quick create'),
              subtitle: Text(isVietnamese ? 'Nhập từng người hoặc tạo mẫu' : 'Enter individually or create samples'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddStudentDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
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

    final firstNames = [
      'Nguyễn',
      'Trần',
      'Lê',
      'Phạm',
      'Hoàng',
      'Huỳnh',
      'Vũ',
      'Đặng',
      'Bùi',
      'Đỗ'
    ];
    final lastNames = [
      'An',
      'Bình',
      'Cường',
      'Dũng',
      'Hà',
      'Khoa',
      'Lan',
      'Minh',
      'Nam',
      'Oanh'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: Builder(
            builder: (tabContext) {
              final tabController = DefaultTabController.of(tabContext);

              return AlertDialog(
                title: Text(isVietnamese ? 'Thêm sinh viên' : 'Add Student'),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: isVietnamese ? 'Thủ công' : 'Manual'),
                          Tab(text: isVietnamese ? 'Tạo nhanh' : 'Quick Create'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 280,
                        child: TabBarView(
                          children: [
                            // Manual Tab
                            Form(
                              key: formKey,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextFormField(
                                      controller: codeCtrl,
                                      decoration: InputDecoration(
                                        labelText: isVietnamese ? 'Mã SV *' : 'Student ID *',
                                        hintText: isVietnamese ? 'VD: 2023001' : 'e.g. 2023001',
                                        prefixIcon: const Icon(Icons.badge),
                                        helperText: isVietnamese ? 'Mã sinh viên (bắt buộc)' : 'Student ID (required)',
                                      ),
                                      validator: (v) =>
                                          v?.trim().isEmpty == true
                                              ? (isVietnamese ? 'Bắt buộc' : 'Required')
                                              : null,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: nameCtrl,
                                      decoration: InputDecoration(
                                        labelText: isVietnamese ? 'Họ và tên *' : 'Full name *',
                                        hintText: isVietnamese ? 'VD: Nguyễn Văn An' : 'e.g. John Doe',
                                        prefixIcon: const Icon(Icons.person),
                                        helperText: isVietnamese ? 'Tên đầy đủ (bắt buộc)' : 'Full name (required)',
                                      ),
                                      validator: (v) =>
                                          v?.trim().isEmpty == true
                                              ? (isVietnamese ? 'Bắt buộc' : 'Required')
                                              : null,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: emailCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        hintText: isVietnamese ? 'VD: an@school.com' : 'e.g. john@school.com',
                                        prefixIcon: const Icon(Icons.email),
                                        helperText: isVietnamese ? 'Email (tùy chọn)' : 'Email (optional)',
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v?.trim().isEmpty == true)
                                          return null;
                                        if (!RegExp(
                                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                            .hasMatch(v!)) {
                                          return isVietnamese ? 'Email không hợp lệ' : 'Invalid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    Text(
                                      isVietnamese ? 'Thông tin tài khoản:' : 'Account info:',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isVietnamese
                                          ? '• Mật khẩu mặc định: Mã SV\n• Vai trò: Sinh viên'
                                          : '• Default password: Student ID\n• Role: Student',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Quick Create Tab
                            Form(
                              key: quickFormKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: quickBaseCodeCtrl,
                                    decoration: InputDecoration(
                                        labelText: isVietnamese ? 'Mã SV bắt đầu *' : 'Starting ID *'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v?.trim().isEmpty == true)
                                        return isVietnamese ? 'Bắt buộc' : 'Required';
                                      if (int.tryParse(v!) == null)
                                        return isVietnamese ? 'Phải là số' : 'Must be a number';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: quickCountCtrl,
                                    decoration: InputDecoration(
                                        labelText: isVietnamese ? 'Số lượng *' : 'Count *'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v?.trim().isEmpty == true)
                                        return isVietnamese ? 'Bắt buộc' : 'Required';
                                      final n = int.tryParse(v!);
                                      if (n == null || n < 1 || n > 50)
                                        return '1-50';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isVietnamese
                                        ? 'Tên & email sẽ được tạo tự động\nVD: Nguyễn An → an2023001@school.com'
                                        : 'Name & email will be auto-generated\ne.g. Nguyen An → an2023001@school.com',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                    textAlign: TextAlign.center,
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
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isVietnamese ? 'Hủy' : 'Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      final tabIndex = tabController.index;

                      if (tabIndex == 0) {
                        // Manual creation
                        if (!formKey.currentState!.validate()) return;
                        final code = codeCtrl.text.trim();
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();

                        final exists = ref
                            .read(studentProvider)
                            .any((s) => s.code == code);
                        if (exists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isVietnamese ? 'Mã SV đã tồn tại' : 'Student ID already exists')),
                          );
                          return;
                        }

                        try {
                          await ref.read(studentProvider.notifier).createStudent(
                                code: code,
                                fullName: name,
                                email: email,
                              );
                          await ref
                              .read(studentProvider.notifier)
                              .loadStudents();
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(isVietnamese
                                      ? 'Đã thêm: $name (Mật khẩu: $code)'
                                      : 'Added: $name (Password: $code)')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')));
                          }
                        }
                      } else {
                        // Quick creation
                        if (!quickFormKey.currentState!.validate()) return;
                        final baseCode =
                            int.parse(quickBaseCodeCtrl.text.trim());
                        final count = int.parse(quickCountCtrl.text.trim());
                        final existingCodes = ref
                            .read(studentProvider)
                            .map((s) => s.code)
                            .toSet();
                        final created = <AppUser>[];

                        for (int i = 0; i < count; i++) {
                          final code = '${baseCode + i}';
                          if (existingCodes.contains(code)) continue;

                          final first = firstNames[
                              DateTime.now().millisecond % firstNames.length];
                          final last =
                              lastNames[(baseCode + i) % lastNames.length];
                          final name = '$first $last';
                          final email =
                              '${last.toLowerCase()}$code@school.com';

                          try {
                            await ref
                                .read(studentProvider.notifier)
                                .createStudent(
                                  code: code,
                                  fullName: name,
                                  email: email,
                                );
                            final now = DateTime.now();
                            created.add(AppUser(
                              id: '',
                              fullName: name,
                              email: email,
                              role: UserRole.student,
                              createdAt: now,
                              updatedAt: now,
                              code: code,
                            ));
                          } catch (e) {
                            print('Quick create error: $e');
                          }
                        }

                        await ref.read(studentProvider.notifier).loadStudents();
                        Navigator.pop(ctx);
                        if (mounted && created.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(isVietnamese
                                    ? 'Đã tạo ${created.length} sinh viên mẫu (Mật khẩu = Mã SV)'
                                    : 'Created ${created.length} sample students (Password = Student ID)')),
                          );
                        }
                      }
                    },
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
      MaterialPageRoute(
        builder: (ctx) => const CsvPreviewScreen(),
      ),
    ).then((_) {
      ref.read(studentProvider.notifier).loadStudents();
    });
  }
}