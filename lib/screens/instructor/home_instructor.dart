// screens/instructor/home_instructor.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/message_provider.dart'; // ✅ ADD
import '../../models/semester.dart';
import '../../models/course.dart';
import '../../models/user.dart';
import '../shared/inbox_screen.dart'; // ✅ ADD
import 'csv_preview_screen.dart';

class HomeInstructor extends ConsumerStatefulWidget {
  const HomeInstructor({super.key});
  @override ConsumerState<HomeInstructor> createState() => _HomeInstructorState();
}

class _HomeInstructorState extends ConsumerState<HomeInstructor>
    with TickerProviderStateMixin {
  String? _selectedSemesterId;
  bool _isLoading = false;
  late TabController _tabController;
  int _currentBottomNavIndex = 0; // ✅ ADD

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        ref.read(semesterProvider.notifier).loadSemesters(),
        ref.read(courseProvider.notifier).loadCourses(),
        ref.read(studentProvider.notifier).loadStudents(),
        ref.read(groupProvider.notifier).loadGroups(),
        _loadConversations(), // ✅ ADD
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

  // ✅ ADD THIS METHOD
  Future<void> _loadConversations() async {
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(conversationProvider.notifier).loadConversations(
            user.id,
            true, // isInstructor
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)!;
    final semesters = ref.watch(semesterProvider);
    final courses = ref.watch(courseProvider);
    final students = ref.watch(studentProvider);
    final conversations = ref.watch(conversationProvider); // ✅ ADD

    final filteredCourses = _selectedSemesterId == null
        ? courses.where((c) => c.instructorId == user.id).toList()
        : courses.where((c) => c.instructorId == user.id && c.semesterId == _selectedSemesterId).toList();

    // ✅ ADD: Calculate unread count
    final unreadCount = conversations.fold<int>(
      0,
      (sum, c) => sum + c.unreadCountInstructor,
    );

    // ✅ ADD: Bottom navigation pages
    final pages = [
      _buildHomeTab(user, semesters, filteredCourses, students),
      const InboxScreen(),
    ];

    return Scaffold(
      appBar: _currentBottomNavIndex == 0 // ✅ Only show AppBar on home tab
          ? AppBar(
              title: Text('GV: ${user.fullName}'),
              actions: [
                // ✅ ADD: Message icon with badge
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.message),
                      onPressed: () {
                        setState(() => _currentBottomNavIndex = 1);
                      },
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
      // ✅ ADD: Bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          setState(() => _currentBottomNavIndex = index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
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
            label: 'Tin nhắn',
          ),
        ],
      ),
      body: pages[_currentBottomNavIndex], // ✅ Show selected page
    );
  }

  // ✅ EXTRACT HOME TAB INTO METHOD
  Widget _buildHomeTab(
    AppUser user,
    List<Semester> semesters,
    List<Course> filteredCourses,
    List<AppUser> students,
  ) {
    return Column(
      children: [
        // ────── SEMESTER FILTER + ADD ──────
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSemesterId,
                  decoration: InputDecoration(
                    labelText: 'Chọn học kỳ',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.school),
                    suffixIcon: _selectedSemesterId != null
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Xóa học kỳ'),
                                  content: Text(
                                      'Xóa "${semesters.firstWhere((s) => s.id == _selectedSemesterId).name}"?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Hủy')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(semesterProvider.notifier).deleteSemester(_selectedSemesterId!);
                                setState(() => _selectedSemesterId = null);
                              }
                            },
                          )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả học kỳ')),
                    ...semesters.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.code}: ${s.name}'))),
                  ],
                  onChanged: (v) => setState(() => _selectedSemesterId = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                tooltip: 'Thêm học kỳ',
                onPressed: () => context.push('/instructor/semester/create'),
              ),
            ],
          ),
        ),

        // ────── TABS ──────
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.book), text: 'Môn học'),
            Tab(icon: Icon(Icons.people), text: 'Sinh viên'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCoursesTab(filteredCourses, semesters, user),
                    _buildStudentsTab(students),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCoursesTab(List<Course> courses, List<Semester> semesters, AppUser user) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: courses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.book, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Chưa có môn học nào'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm môn học'),
                    onPressed: () => _showCreateCourseDialog(context, semesters, user),
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
                  orElse: () => Semester(id: '', code: 'N/A', name: 'Không xác định'),
                );
                
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.book, color: Colors.green),
                    title: Text('${course.code}: ${course.name}'),
                    subtitle: Text('${semester.name} • ${course.sessions} buổi'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      print('🔄 Loading groups for course: ${course.name}');
                      
                      final currentGroups = ref.read(groupProvider);
                      if (currentGroups.isEmpty) {
                        print('⚠️ Group provider empty, loading...');
                        await ref.read(groupProvider.notifier).loadGroups();
                      }
                      
                      final allGroups = ref.read(groupProvider);
                      final groups = allGroups.where((g) => g.courseId == course.id).toList();
                      
                      print('✅ Found ${groups.length} groups for course ${course.id}');
                      
                      final allStudents = ref.read(studentProvider);
                      final courseStudents = allStudents.where((s) {
                        return groups.any((g) => g.studentIds.contains(s.id));
                      }).toList();
                      
                      print('✅ Found ${courseStudents.length} students in these groups');

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

  Widget _buildStudentsTab(List<AppUser> students) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Thêm Sinh viên'),
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
              ? const Center(child: Text('Chưa có sinh viên'))
              : ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            s.code != null && s.code!.isNotEmpty ? s.code![0] : '?',
                          ),
                        ),
                        title: Text(s.fullName),
                        subtitle: Text('${s.code} • ${s.email}'),
                        // ✅ ADD: Message button
                        trailing: IconButton(
                          icon: const Icon(Icons.message),
                          onPressed: () async {
                            final user = ref.read(authProvider)!;
                            await ref.read(conversationProvider.notifier).getOrCreateConversation(
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

  // Keep all existing methods below...
  void _showCreateCourseDialog(BuildContext context, List<Semester> semesters, AppUser user) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final sessionsCtrl = TextEditingController(text: '10');
    String? selectedSemesterId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm Môn Học'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mã môn học *',
                      hintText: 'VD: WEB101',
                      prefixIcon: Icon(Icons.code),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên môn học *',
                      hintText: 'VD: Lập trình Web',
                      prefixIcon: Icon(Icons.book),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sessionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Số buổi học *',
                      hintText: 'VD: 10, 15, 20',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return 'Bắt buộc';
                      final n = int.tryParse(v!);
                      if (n == null || n < 1) return 'Phải là số dương';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSemesterId,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ *',
                      prefixIcon: Icon(Icons.school),
                    ),
                    items: semesters.isEmpty
                        ? [const DropdownMenuItem(value: null, child: Text('Chưa có học kỳ'))]
                        : [
                            const DropdownMenuItem(value: null, child: Text('Chọn học kỳ')),
                            ...semesters.map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text('${s.code}: ${s.name}'),
                                )),
                          ],
                    onChanged: semesters.isEmpty
                        ? null
                        : (v) => setDialogState(() => selectedSemesterId = v),
                    validator: (v) => v == null ? 'Bắt buộc chọn học kỳ' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedSemesterId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn học kỳ')),
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
                    SnackBar(content: Text('Đã thêm môn học: ${nameCtrl.text.trim()}')),
                  );
                  await _refreshData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStudentOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chọn cách thêm sinh viên',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Nhập từ CSV'),
              subtitle: const Text('Thêm nhiều sinh viên cùng lúc'),
              onTap: () {
                Navigator.pop(ctx);
                _showCsvImportDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.green),
              title: const Text('Thêm thủ công / Tạo nhanh'),
              subtitle: const Text('Nhập từng người hoặc tạo mẫu'),
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

    final firstNames = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Vũ', 'Đặng', 'Bùi', 'Đỗ'];
    final lastNames = ['An', 'Bình', 'Cường', 'Dũng', 'Hà', 'Khoa', 'Lan', 'Minh', 'Nam', 'Oanh'];

    showDialog(
      context: context,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: Builder(
            builder: (tabContext) {
              final tabController = DefaultTabController.of(tabContext);
              
              return AlertDialog(
                title: const Text('Thêm sinh viên'),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Thủ công'),
                          Tab(text: 'Tạo nhanh'),
                        ],
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
                                      decoration: const InputDecoration(
                                        labelText: 'Mã SV *',
                                        hintText: 'VD: 2023001',
                                        prefixIcon: Icon(Icons.badge),
                                        helperText: 'Mã sinh viên (bắt buộc)',
                                      ),
                                      validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: nameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Họ và tên *',
                                        hintText: 'VD: Nguyễn Văn An',
                                        prefixIcon: Icon(Icons.person),
                                        helperText: 'Tên đầy đủ (bắt buộc)',
                                      ),
                                      validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: emailCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'VD: an@school.com',
                                        prefixIcon: Icon(Icons.email),
                                        helperText: 'Email (tùy chọn, mặc định: mãSV@school.com)',
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v?.trim().isEmpty == true) return null;
                                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                                          return 'Email không hợp lệ';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const Text(
                                      'Thông tin tài khoản:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '• Mật khẩu mặc định: Mã SV\n• Vai trò: Sinh viên\n• Tài khoản sẽ được tạo tự động',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
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
                                    decoration: const InputDecoration(labelText: 'Mã SV bắt đầu *'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v?.trim().isEmpty == true) return 'Bắt buộc';
                                      if (int.tryParse(v!) == null) return 'Phải là số';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: quickCountCtrl,
                                    decoration: const InputDecoration(labelText: 'Số lượng *'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v?.trim().isEmpty == true) return 'Bắt buộc';
                                      final n = int.tryParse(v!);
                                      if (n == null || n < 1 || n > 50) return '1-50';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tên & email sẽ được tạo tự động\nVD: Nguyễn An → an2023001@school.com',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
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
                            const SnackBar(content: Text('Mã SV đã tồn tại')),
                          );
                          return;
                        }

                        try {
                          await ref.read(studentProvider.notifier).createStudent(
                            code: code,
                            fullName: name,
                            email: email,
                          );
                          await ref.read(studentProvider.notifier).loadStudents();
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã thêm: $name (Mật khẩu: $code)')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        }
                      } else {
                        if (!quickFormKey.currentState!.validate()) return;
                        final baseCode = int.parse(quickBaseCodeCtrl.text.trim());
                        final count = int.parse(quickCountCtrl.text.trim());
                        final existingCodes = ref.read(studentProvider).map((s) => s.code).toSet();
                        final created = <AppUser>[];

                        for (int i = 0; i < count; i++) {
                          final code = '${baseCode + i}';
                          if (existingCodes.contains(code)) continue;

                          final first = firstNames[DateTime.now().millisecond % firstNames.length];
                          final last = lastNames[(baseCode + i) % lastNames.length];
                          final name = '$first $last';
                          final email = '${last.toLowerCase()}$code@school.com';

                          try {
                            await ref.read(studentProvider.notifier).createStudent(
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
                            SnackBar(content: Text('Đã tạo ${created.length} sinh viên mẫu (Mật khẩu = Mã SV)')),
                          );
                        }
                      }
                    },
                    child: const Text('Thêm'),
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