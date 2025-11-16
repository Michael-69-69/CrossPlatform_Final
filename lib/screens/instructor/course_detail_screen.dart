// screens/instructor/course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/group.dart' as app;
import '../../models/semester.dart';
import '../../models/user.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final Course course;
  final Semester semester;
  final List<app.Group> groups;
  final List<AppUser> students;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.semester,
    required this.groups,
    required this.students,
  });

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  late List<AppUser> currentStudents;

  @override
  void initState() {
    super.initState();
    currentStudents = List.from(widget.students);
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = currentStudents.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.school, color: Colors.indigo),
                title: Text(widget.semester.name),
                subtitle: Text('Học kỳ: ${widget.semester.code}'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.book, color: Colors.green),
                title: Text('${widget.course.code}: ${widget.course.name}'),
                subtitle: Text('${widget.course.sessions} buổi • $totalStudents học sinh'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Danh sách nhóm (${widget.groups.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.groups.isEmpty
                  ? const Center(child: Text('Chưa có nhóm'))
                  : ListView.builder(
                      itemCount: widget.groups.length,
                      itemBuilder: (context, index) {
                        final group = widget.groups[index];
                        final groupStudents = currentStudents
                            .where((s) => group.studentIds.contains(s.id))
                            .toList();

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.group, color: Colors.orange),
                            title: Text(group.name),
                            subtitle: Text('${groupStudents.length} học sinh'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              context.go(
                                '/instructor/group/${group.id}',
                                extra: {
                                  'group': group,
                                  'course': widget.course,
                                  'semester': widget.semester,
                                  'students': groupStudents,
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle),
              label: const Text('Thêm nhóm mới'),
              onPressed: () => _showCreateGroupDialog(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo nhóm mới'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Tên nhóm (VD: Nhóm 1)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                ref.read(groupProvider.notifier).createGroup(
                  name: nameCtrl.text,
                  courseId: widget.course.id,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}