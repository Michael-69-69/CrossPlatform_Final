// screens/instructor/semester_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/semester_provider.dart';

class SemesterListScreen extends ConsumerStatefulWidget {
  const SemesterListScreen({super.key});
  @override ConsumerState<SemesterListScreen> createState() => _SemesterListScreenState();
}

class _SemesterListScreenState extends ConsumerState<SemesterListScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final semesters = ref.watch(semesterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý học kỳ')),
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
                        labelText: 'Mã học kỳ (VD: 2025-1)',
                        prefixIcon: Icon(Icons.code),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên học kỳ (VD: Học kỳ 1 - 2025)',
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (_codeCtrl.text.isNotEmpty && _nameCtrl.text.isNotEmpty) {
                          ref.read(semesterProvider.notifier).createSemester(
                                code: _codeCtrl.text.trim(),
                                name: _nameCtrl.text.trim(),
                              );
                          _codeCtrl.clear();
                          _nameCtrl.clear();
                        }
                      },
                      child: const Text('Tạo học kỳ'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: semesters.length,
                itemBuilder: (c, i) {
                  final s = semesters[i];
                  return ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                    title: Text('${s.code}: ${s.name}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => ref.read(semesterProvider.notifier).deleteSemester(s.id),
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