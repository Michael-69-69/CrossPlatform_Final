// screens/instructor/semester_create_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/semester_provider.dart';

class SemesterCreateScreen extends ConsumerStatefulWidget {
  const SemesterCreateScreen({super.key});
  @override ConsumerState<SemesterCreateScreen> createState() => _SemesterCreateScreenState();
}

class _SemesterCreateScreenState extends ConsumerState<SemesterCreateScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo học kỳ mới')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Mã học kỳ (VD: 2025-1)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên học kỳ (VD: Học kỳ 1 - 2025)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(_isLoading ? 'Đang tạo...' : 'Tạo học kỳ'),
              onPressed: _isLoading ? null : _createSemester,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSemester() async {
    if (_codeCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(semesterProvider.notifier).createSemester(
        code: _codeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}