// screens/instructor/instructor_class_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/class.dart';                 // <-- Your existing ClassModel
import '../../providers/class_provider.dart';      // <-- MongoDB-backed provider
import '../../providers/group_provider.dart';      // <-- For future group linking
import '../../models/group.dart' as app;          // <-- Avoid mongo_dart Group conflict

class InstructorClassDetail extends ConsumerStatefulWidget {
  final ClassModel cls;
  const InstructorClassDetail({super.key, required this.cls});

  @override
  ConsumerState<InstructorClassDetail> createState() => _InstructorClassDetailState();
}

class _InstructorClassDetailState extends ConsumerState<InstructorClassDetail> {
  final _contentCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  String _selectedDay = 'Monday';
  String _selectedTime = '08:00 - 09:30';

  // Editing state
  final Map<int, TextEditingController> _contentEditCtrls = {};
  final Map<int, Map<String, String>> _scheduleEditValues = {};

  int? _editingContentIndex;
  int? _editingScheduleIndex;

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Rebuild when provider updates
    ref.read(classProvider.notifier).addListener((state) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _contentEditCtrls.values.forEach((c) => c.dispose());
    _contentCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classProvider);
    final currentClass = classes.firstWhere(
      (c) => c.id == widget.cls.id,
      orElse: () => widget.cls,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(currentClass.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              onTap: (i) => setState(() => _currentTabIndex = i),
              tabs: const [
                Tab(text: 'Nội dung'),
                Tab(text: 'Lịch học'),
                Tab(text: 'Bài kiểm tra'),
                Tab(text: 'Học sinh'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildContentTab(currentClass),
                  _buildScheduleTab(currentClass),
                  _buildExamTab(currentClass),
                  _buildStudentsTab(currentClass),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(currentClass),
    );
  }

  // === FAB ===
  Widget? _buildFAB(ClassModel cls) {
    if (_currentTabIndex == 0) {
      return FloatingActionButton(
        onPressed: () {
          if (_contentCtrl.text.isNotEmpty) {
            ref.read(classProvider.notifier).addContent(cls.id, {
              'text': _contentCtrl.text,
              'link': _linkCtrl.text,
              'date': DateTime.now().toIso8601String(),
              'type': _linkCtrl.text.isEmpty ? 'text' : 'link',
            });
            _contentCtrl.clear();
            _linkCtrl.clear();
          }
        },
        child: const Icon(Icons.send),
        backgroundColor: Colors.green,
      );
    } else if (_currentTabIndex == 1) {
      return FloatingActionButton(
        onPressed: () {
          ref.read(classProvider.notifier).addSchedule(cls.id, {
            'day': _selectedDay,
            'time': _selectedTime,
          });
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.green,
      );
    } else if (_currentTabIndex == 2) {
      return FloatingActionButton(
        onPressed: () => context.go('/instructor/exam/create', extra: cls.id),
        child: const Icon(Icons.add_task),
        backgroundColor: Colors.green,
      );
    }
    return null;
  }

  // === CONTENT TAB ===
  Widget _buildContentTab(ClassModel cls) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_editingContentIndex == null) ...[
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(labelText: 'Nội dung'),
            ),
            TextField(
              controller: _linkCtrl,
              decoration: const InputDecoration(labelText: 'Link (tùy chọn)'),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: cls.content.length,
              itemBuilder: (context, i) {
                final c = cls.content[i];
                final isEditing = _editingContentIndex == i;

                if (isEditing && !_contentEditCtrls.containsKey(i)) {
                  _contentEditCtrls[i] = TextEditingController(text: c['text']);
                }

                return Card(
                  child: ListTile(
                    title: isEditing
                        ? TextField(
                            controller: _contentEditCtrls[i],
                            decoration: const InputDecoration(border: InputBorder.none),
                          )
                        : Text(c['text']),
                    subtitle: c['link'].isEmpty ? null : Text(c['link']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c['date'].substring(11, 16)),
                        const SizedBox(width: 8),
                        if (isEditing)
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () {
                              final updated = Map<String, dynamic>.from(c);
                              updated['text'] = _contentEditCtrls[i]!.text;
                              ref.read(classProvider.notifier).updateContent(cls.id, i, updated);
                              _contentEditCtrls[i]!.dispose();
                              _contentEditCtrls.remove(i);
                              setState(() => _editingContentIndex = null);
                            },
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => setState(() => _editingContentIndex = i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => ref.read(classProvider.notifier).deleteContent(cls.id, i),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // === SCHEDULE TAB ===
  Widget _buildScheduleTab(ClassModel cls) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_editingScheduleIndex == null) ...[
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedDay,
                  items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDay = v!),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedTime,
                  items: ['08:00 - 09:30', '10:00 - 11:30', '14:00 - 15:30']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTime = v!),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: cls.schedule.length,
              itemBuilder: (context, i) {
                final s = cls.schedule[i];
                final isEditing = _editingScheduleIndex == i;

                if (isEditing && !_scheduleEditValues.containsKey(i)) {
                  _scheduleEditValues[i] = {'day': s['day'], 'time': s['time']};
                }

                return Card(
                  child: ListTile(
                    title: isEditing
                        ? Row(
                            children: [
                              DropdownButton<String>(
                                value: _scheduleEditValues[i]!['day'],
                                items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _scheduleEditValues[i]!['day'] = v!;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _scheduleEditValues[i]!['time'],
                                items: ['08:00 - 09:30', '10:00 - 11:30', '14:00 - 15:30']
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _scheduleEditValues[i]!['time'] = v!;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () {
                                  final updated = {
                                    'day': _scheduleEditValues[i]!['day'],
                                    'time': _scheduleEditValues[i]!['time'],
                                  };
                                  ref.read(classProvider.notifier).updateSchedule(cls.id, i, updated);
                                  _scheduleEditValues.remove(i);
                                  setState(() => _editingScheduleIndex = null);
                                },
                              ),
                            ],
                          )
                        : Text('${s['day']} - ${s['time']}'),
                    trailing: isEditing
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => setState(() => _editingScheduleIndex = i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => ref.read(classProvider.notifier).deleteSchedule(cls.id, i),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // === EXAM TAB ===
  Widget _buildExamTab(ClassModel cls) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: cls.exams.length,
        itemBuilder: (context, i) {
          final exam = cls.exams[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _showExamOptions(context, cls.id, i),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                title: Text(exam['title'] ?? 'Bài kiểm tra'),
                subtitle: Text('Tạo: ${exam['createdAt'].substring(0, 10)}'),
                trailing: const Icon(Icons.more_vert),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExamOptions(BuildContext context, String classId, int index) {
    final currentClass = ref.read(classProvider).firstWhere((c) => c.id == classId);
    final exam = currentClass.exams[index];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Chỉnh sửa'),
            onTap: () {
              Navigator.pop(ctx);
              context.go('/instructor/exam/edit', extra: {
                'classId': classId,
                'examIndex': index,
                'examData': exam,
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Xóa'),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDeleteExam(context, classId, index);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExam(BuildContext context, String classId, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài kiểm tra?'),
        content: const Text('Bạn có chắc muốn xóa bài kiểm tra này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              ref.read(classProvider.notifier).deleteExam(classId, index);
              Navigator.pop(ctx);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // === STUDENTS TAB ===
  Widget _buildStudentsTab(ClassModel cls) {
    return ListView.builder(
      itemCount: cls.studentIds.length,
      itemBuilder: (context, i) {
        final sid = cls.studentIds[i];
        return Card(
          child: ListTile(
            title: Text('Student ID: $sid'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.warning, color: Colors.orange),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cảnh cáo gửi đến $sid')),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => ref.read(classProvider.notifier).kickStudent(cls.id, sid),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}