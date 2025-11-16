// screens/instructor/course_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/course_provider.dart';
import '../../models/semester.dart';

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});
  @override ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  int _sessions = 10;
  String? _selectedSemesterId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)!;
    final semesters = ref.watch(semesterProvider);
    final courses = ref.watch(courseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý môn học')),
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
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mã môn (VD: WEB101)',
                        prefixIcon: Icon(Icons.code),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên môn học',
                        prefixIcon: Icon(Icons.book),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _sessions,
                      decoration: const InputDecoration(labelText: 'Số buổi'),
                      items: [10, 15].map((s) => DropdownMenuItem(value: s, child: Text('$s buổi'))).toList(),
                      onChanged: (v) => setState(() => _sessions = v!),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      hint: const Text('Chọn học kỳ'),
                      value: _selectedSemesterId,
                      items: semesters
                          .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.code}: ${s.name}')))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSemesterId = v),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (_codeCtrl.text.isNotEmpty &&
                            _nameCtrl.text.isNotEmpty &&
                            _selectedSemesterId != null) {
                          ref.read(courseProvider.notifier).createCourse(
                                code: _codeCtrl.text.trim(),
                                name: _nameCtrl.text.trim(),
                                sessions: _sessions,
                                semesterId: _selectedSemesterId!,
                                instructorId: user.id,
                                instructorName: user.fullName,
                              );
                          _codeCtrl.clear();
                          _nameCtrl.clear();
                          _selectedSemesterId = null;
                          setState(() {});
                        }
                      },
                      child: const Text('Tạo môn học'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: courses.length,
                itemBuilder: (c, i) {
                  final course = courses[i];
                  final sem = semesters.firstWhere(
                    (s) => s.id == course.semesterId,
                    orElse: () => Semester(id: '', code: '??', name: '??'),
                  );
                  return ListTile(
                    leading: const Icon(Icons.book, color: Colors.green),
                    title: Text('${course.code}: ${course.name}'),
                    subtitle: Text('Học kỳ: ${sem.code} – ${course.sessions} buổi'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => ref.read(courseProvider.notifier).deleteCourse(course.id),
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
}