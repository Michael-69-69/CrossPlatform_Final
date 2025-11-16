// screens/instructor/groups_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/group_provider.dart';
import '../../providers/student_provider.dart';

class GroupsTab extends ConsumerStatefulWidget {
  final String courseId;
  final List<Group> groups;

  const GroupsTab({
    super.key,
    required this.courseId,
    required this.groups,
  });

  @override
  ConsumerState<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<GroupsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupProvider.notifier).loadGroups();
      ref.read(studentProvider.notifier).loadStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allGroups = ref.watch(groupProvider);
    final allStudents = ref.watch(studentProvider);
    final courseGroups = allGroups.where((g) => g.courseId == widget.courseId).toList();

    return Column(
      children: [
        // Create Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Tạo nhóm mới'),
            onPressed: () => _showCreateGroupDialog(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        // Groups List
        Expanded(
          child: courseGroups.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Chưa có nhóm nào'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(groupProvider.notifier).loadGroups();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: courseGroups.length,
                    itemBuilder: (context, index) {
                      final group = courseGroups[index];
                      final groupStudents = allStudents
                          .where((s) => group.studentIds.contains(s.id))
                          .toList();
                      return _GroupCard(
                        group: group,
                        studentCount: groupStudents.length,
                        onTap: () => _showGroupDetailDialog(context, group, groupStudents, allStudents),
                        onEdit: () => _showEditGroupDialog(context, group),
                        onDelete: () => _deleteGroup(group.id),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo nhóm mới'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tên nhóm *',
              hintText: 'VD: Nhóm 1',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
            autofocus: true,
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

              try {
                await ref.read(groupProvider.notifier).createGroup(
                  name: nameCtrl.text.trim(),
                  courseId: widget.courseId,
                );
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã tạo nhóm')),
                  );
                }
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
    );
  }

  void _showEditGroupDialog(BuildContext context, Group group) {
    final nameCtrl = TextEditingController(text: group.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa nhóm'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tên nhóm *',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
            autofocus: true,
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

              try {
                await ref.read(groupProvider.notifier).updateGroup(
                  group.id,
                  nameCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã cập nhật nhóm')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showGroupDetailDialog(BuildContext context, Group group, List<AppUser> groupStudents, List<AppUser> allStudents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GroupDetailSheet(
        group: group,
        groupStudents: groupStudents,
        allStudents: allStudents,
        onAddStudent: (studentId) async {
          await ref.read(groupProvider.notifier).addStudents(group.id, [studentId]);
          Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã thêm sinh viên vào nhóm')),
            );
          }
        },
        onRemoveStudent: (studentId) async {
          await ref.read(groupProvider.notifier).removeStudent(group.id, studentId);
          Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã xóa sinh viên khỏi nhóm')),
            );
          }
        },
      ),
    );
  }

  void _deleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhóm'),
        content: const Text('Bạn có chắc muốn xóa nhóm này? Tất cả sinh viên sẽ bị xóa khỏi nhóm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(groupProvider.notifier).deleteGroup(groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa nhóm')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final int studentCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupCard({
    required this.group,
    required this.studentCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.group, size: 40, color: Colors.orange),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$studentCount sinh viên',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa'),
                      ],
                    ),
                    onTap: onEdit,
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupDetailSheet extends ConsumerStatefulWidget {
  final Group group;
  final List<AppUser> groupStudents;
  final List<AppUser> allStudents;
  final Function(String) onAddStudent;
  final Function(String) onRemoveStudent;

  const _GroupDetailSheet({
    required this.group,
    required this.groupStudents,
    required this.allStudents,
    required this.onAddStudent,
    required this.onRemoveStudent,
  });

  @override
  ConsumerState<_GroupDetailSheet> createState() => _GroupDetailSheetState();
}

class _GroupDetailSheetState extends ConsumerState<_GroupDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final groupStudentIds = widget.groupStudents.map((s) => s.id).toSet();
    final availableStudents = widget.allStudents
        .where((s) => !groupStudentIds.contains(s.id))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Add Student Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: Text('Thêm sinh viên (${availableStudents.length} có sẵn)'),
                onPressed: availableStudents.isEmpty
                    ? null
                    : () => _showAddStudentDialog(context, availableStudents),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            // Students List
            Expanded(
              child: widget.groupStudents.isEmpty
                  ? const Center(
                      child: Text('Chưa có sinh viên trong nhóm'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.groupStudents.length,
                      itemBuilder: (context, index) {
                        final student = widget.groupStudents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                student.code != null && student.code!.isNotEmpty
                                    ? student.code![0]
                                    : '?',
                              ),
                            ),
                            title: Text(student.fullName),
                            subtitle: Text('${student.code} • ${student.email}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => widget.onRemoveStudent(student.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddStudentDialog(BuildContext context, List<AppUser> availableStudents) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn sinh viên'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availableStudents.length,
            itemBuilder: (ctx, i) {
              final student = availableStudents[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    student.code != null && student.code!.isNotEmpty
                        ? student.code![0]
                        : '?',
                  ),
                ),
                title: Text(student.fullName),
                subtitle: Text('${student.code} • ${student.email}'),
                trailing: IconButton(
                  icon: const Icon(Icons.add, color: Colors.green),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onAddStudent(student.id);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }
}

