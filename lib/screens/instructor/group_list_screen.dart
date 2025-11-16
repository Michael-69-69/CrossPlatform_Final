// screens/instructor/group_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';

import '../../providers/course_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';
import '../../models/course.dart';
import '../../models/user.dart';           // <-- ADD THIS
import '../../models/group.dart' as app;

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});
  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  final _nameCtrl = TextEditingController();
  String? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(courseProvider);
    final groups = ref.watch(groupProvider);
    final students = ref.watch(studentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý nhóm')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên nhóm (VD: Nhóm 1)'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      hint: const Text('Chọn môn học'),
                      value: _selectedCourseId,
                      items: courses
                          .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.code}: ${c.name}')))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCourseId = v),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (_nameCtrl.text.isNotEmpty && _selectedCourseId != null) {
                          ref.read(groupProvider.notifier).createGroup(
                                name: _nameCtrl.text.trim(),
                                courseId: _selectedCourseId!,
                              );
                          _nameCtrl.clear();
                          _selectedCourseId = null;           // <-- FIXED: was _selectedSemesterId
                          setState(() {});
                        }
                      },
                      child: const Text('Tạo nhóm'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (c, i) {
                  final g = groups[i];
                  final course = courses.firstWhere(
                    (c) => c.id == g.courseId,
                    orElse: () => Course(
                      id: '',
                      code: '??',
                      name: '??',
                      sessions: 10,
                      semesterId: '',
                      instructorId: '',
                      instructorName: '',
                    ),
                  );
                  final groupStudents = students.where((s) => g.studentIds.contains(s.id)).toList();

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.group, color: Colors.orange),
                      title: Text(g.name),
                      subtitle: Text('Môn: ${course.code} – ${groupStudents.length} SV'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showGroupDetail(g, course, groupStudents),
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

  void _showGroupDetail(app.Group group, Course course, List<AppUser> currentStudents) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${group.name} – ${course.code}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sinh viên hiện tại:'),
              ...currentStudents.map((s) => ListTile(
                    title: Text(s.fullName),
                    subtitle: Text('${s.code} – ${s.email}'),
                  )),
              const Divider(),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Thêm SV từ CSV'),
                onPressed: () => _showCsvImport(group.id),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  void _showCsvImport(String groupId) async {
    final csvCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dán CSV: code,name,email'),
        content: TextField(
          controller: csvCtrl,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '2023001,Nguyễn Văn A,a@example.com\n2023002,...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, csvCtrl.text),
            child: const Text('Nhập'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final created = await ref.read(studentProvider.notifier).importStudentsFromCsv(result);
    final newIds = created.map((u) => u.id).toList();
    if (newIds.isNotEmpty) {
      await ref.read(groupProvider.notifier).addStudents(groupId, newIds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm ${newIds.length} sinh viên vào nhóm')),
      );
    }
  }
}