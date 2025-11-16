// screens/instructor/group_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/group.dart' as app;
import '../../models/course.dart';
import '../../models/semester.dart';
import '../../models/user.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final app.Group group;
  final Course course;
  final Semester semester;
  final List<AppUser> students;

  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.course,
    required this.semester,
    required this.students,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late List<AppUser> currentStudents;

  @override
  void initState() {
    super.initState();
    currentStudents = List.from(widget.students);
  }

  Future<void> _addStudentFromList() async {
    if (!mounted) return;

    final allStudents = ref.read(studentProvider);
    final groupStudentIds = currentStudents.map((s) => s.id).toSet();
    final availableStudents = allStudents.where((s) => !groupStudentIds.contains(s.id)).toList();

    if (availableStudents.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả học sinh đã có trong nhóm')),
      );
      return;
    }

    final AppUser? selected = await showDialog<AppUser>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn học sinh'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availableStudents.length,
            itemBuilder: (ctx, i) {
              final student = availableStudents[i];
              return ListTile(
leading: CircleAvatar(
  child: Text(student.code.isNotEmpty ? student.code[0] : '?'),
),                title: Text(student.name),
                subtitle: Text('${student.code} • ${student.email}'),
                trailing: IconButton(
                  icon: const Icon(Icons.add, color: Colors.green),
                  onPressed: () => Navigator.pop(ctx, student),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ],
      ),
    );

    if (selected == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Thêm ${selected.name} vào nhóm ${widget.group.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(groupProvider.notifier).addStudents(widget.group.id, [selected.id]);
      if (mounted) {
        setState(() => currentStudents.add(selected));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${selected.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _importFromCsv() async {
    if (!mounted) return;

    final csvCtrl = TextEditingController();
    final List<AppUser>? created = await showDialog<List<AppUser>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập CSV'),
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
              final imported = await ref.read(studentProvider.notifier).importStudentsFromCsv(csvCtrl.text);
              Navigator.pop(ctx, imported);
            },
            child: const Text('Nhập'),
          ),
        ],
      ),
    );

    if (created == null || created.isEmpty || !mounted) return;

    final groupStudentIds = currentStudents.map((s) => s.id).toSet();
    final newStudents = created.where((s) => !groupStudentIds.contains(s.id)).toList();

    if (newStudents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có học sinh mới')));
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Thêm ${newStudents.length} học sinh vào nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final ids = newStudents.map((s) => s.id).toList();
      await ref.read(groupProvider.notifier).addStudents(widget.group.id, ids);
      if (mounted) {
        setState(() => currentStudents.addAll(newStudents));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${newStudents.length} học sinh')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nhóm: ${widget.group.name}'),
leading: IconButton(
  icon: const Icon(Icons.arrow_back),
  onPressed: () {
    if (context.canPop()) {
      context.pop(); // Safe pop
    } else {
      context.go('/home'); // Fallback
    }
  },
),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.person_add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: Text(widget.semester.name),
                subtitle: Text('Học kỳ: ${widget.semester.code}'),
                leading: const Icon(Icons.school, color: Colors.indigo),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text(widget.course.name),
                subtitle: Text('Môn: ${widget.course.code} • ${widget.course.sessions} buổi'),
                leading: const Icon(Icons.book, color: Colors.green),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách học sinh (${currentStudents.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (currentStudents.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Làm mới'),
                    onPressed: () => ref.read(groupProvider.notifier).loadGroups(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: currentStudents.isEmpty
                  ? const Center(child: Text('Chưa có học sinh'))
                  : ListView.builder(
                      itemCount: currentStudents.length,
                      itemBuilder: (context, index) {
                        final student = currentStudents[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(student.code.isNotEmpty ? student.code[0] : '?'),
                            ),
                            title: Text(student.name),
                            subtitle: Text('${student.code} • ${student.email}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeStudent(student),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_search, color: Colors.blue),
              title: const Text('Chọn từ danh sách'),
              onTap: () {
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _addStudentFromList();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.green),
              title: const Text('Nhập từ CSV'),
              onTap: () {
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _importFromCsv();
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Hủy'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeStudent(AppUser student) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xóa ${student.name} khỏi nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(groupProvider.notifier).removeStudent(widget.group.id, student.id);
      if (mounted) {
        setState(() => currentStudents.removeWhere((s) => s.id == student.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa ${student.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}