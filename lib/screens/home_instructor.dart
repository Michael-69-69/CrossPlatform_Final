// screens/home_instructor.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/semester_provider.dart';
import '../providers/course_provider.dart';
import '../providers/student_provider.dart';
import '../providers/group_provider.dart';
import '../models/semester.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../screens/instructor/course_detail_screen.dart';
import '../screens/instructor/semester_create_screen.dart';

class HomeInstructor extends ConsumerStatefulWidget {
  const HomeInstructor({super.key});
  @override ConsumerState<HomeInstructor> createState() => _HomeInstructorState();
}

class _HomeInstructorState extends ConsumerState<HomeInstructor>
    with TickerProviderStateMixin {
  String? _selectedSemesterId;
  bool _isLoading = false;
  String? _errorMessage;
  late TabController _tabController;

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
      _errorMessage = null;
    });

    try {
      await Future.wait([
        ref.read(semesterProvider.notifier).loadSemesters(),
        ref.read(courseProvider.notifier).loadCourses(),
        ref.read(studentProvider.notifier).loadStudents(),
      ]);
    } catch (e, stack) {
      print('Refresh error: $e\n$stack');
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)!;
    final semesters = ref.watch(semesterProvider);
    final courses = ref.watch(courseProvider);
    final students = ref.watch(studentProvider);

    final filteredCourses = _selectedSemesterId == null
        ? courses.where((c) => c.instructorId == user.id).toList()
        : courses.where((c) => c.instructorId == user.id && c.semesterId == _selectedSemesterId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('GV: ${user.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/');
            },
          ),
        ],
      ),
      body: Column(
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // ────── TAB 1: COURSES ──────
                _buildCoursesTab(filteredCourses, semesters, user),

                // ────── TAB 2: STUDENTS ──────
                _buildStudentsTab(students),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab(List<Course> courses, List<Semester> semesters, AppUser user) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, size: 64, color: Colors.grey),
            const Text('Chưa có môn học'),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
              onPressed: _refreshData,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courses.length,
      itemBuilder: (context, i) {
        final course = courses[i];
        final semester = semesters.firstWhere((s) => s.id == course.semesterId,
            orElse: () => Semester(id: '', code: 'N/A', name: 'Không xác định'));
        return Card(
          child: ListTile(
            leading: const Icon(Icons.book, color: Colors.green),
            title: Text('${course.code}: ${course.name}'),
            subtitle: Text('${semester.name} • ${course.sessions} buổi'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final groups = ref.read(groupProvider).where((g) => g.courseId == course.id).toList();
              final allStudents = ref.read(studentProvider);
              final courseStudents = allStudents.where((s) => groups.any((g) => g.studentIds.contains(s.id))).toList();

              context.go(
                '/instructor/course/${course.id}',
                extra: {
                  'course': course,
                  'semester': semester,
                  'groups': groups,
                  'students': courseStudents,
                },
              );
            },
          ),
        );
      },
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
                            s.code.isNotEmpty ? s.code[0] : '?',
                          ),
                        ),
                        title: Text(s.name),
                        subtitle: Text('${s.code} • ${s.email}'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ────── SHOW ADD STUDENT OPTIONS (CSV or Manual/Quick) ──────
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

  // ────── ADD SINGLE STUDENT DIALOG WITH TABS ──────
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
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm sinh viên'),
        content: DefaultTabController(
          length: 2,
          child: SizedBox(
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
                        child: Column(
                          children: [
                            TextFormField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(labelText: 'Mã SV *'),
                              validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(labelText: 'Họ tên *'),
                              validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v?.trim().isEmpty == true) return null;
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                                  return 'Email không hợp lệ';
                                }
                                return null;
                              },
                            ),
                          ],
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
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final tabIndex = DefaultTabController.of(ctx).index;

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
                    name: name,
                    email: email,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã thêm: $name')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
                      name: name,
                      email: email,
                    );
                    created.add(AppUser(id: '', code: code, name: name, email: email, role: UserRole.student));
                  } catch (e) {
                    print('Quick create error: $e');
                  }
                }

                Navigator.pop(ctx);
                if (created.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã tạo ${created.length} sinh viên mẫu')),
                  );
                }
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showCsvImportDialog(BuildContext context) {
    final csvCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập từ CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dòng 1: Mã SV,Tên,Email\nDòng 2+: dữ liệu'),
            const SizedBox(height: 8),
            TextField(
              controller: csvCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '2023001,Nguyễn Văn A,a@example.com\n...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final created = await ref.read(studentProvider.notifier).importStudentsFromCsv(csvCtrl.text);
              Navigator.pop(ctx);
              if (created.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã thêm ${created.length} sinh viên')),
                );
              }
            },
            child: const Text('Nhập'),
          ),
        ],
      ),
    );
  }
}