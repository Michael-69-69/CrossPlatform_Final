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
                        onTap: () => _showGroupDetailSheet(
                          context,
                          group,
                          groupStudents,
                          allStudents,
                          courseGroups,
                        ),
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

  void _showGroupDetailSheet(
    BuildContext context,
    Group group,
    List<AppUser> groupStudents,
    List<AppUser> allStudents,
    List<Group> courseGroups,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GroupDetailSheet(
        group: group,
        initialGroupStudents: groupStudents,
        allStudents: allStudents,
        courseGroups: courseGroups,
        courseId: widget.courseId,
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

// ══════════════════════════════════════════════════════════════
// GROUP CARD
// ══════════════════════════════════════════════════════════════

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

// ══════════════════════════════════════════════════════════════
// GROUP DETAIL SHEET - IMPROVED
// ══════════════════════════════════════════════════════════════

class _GroupDetailSheet extends ConsumerStatefulWidget {
  final Group group;
  final List<AppUser> initialGroupStudents;
  final List<AppUser> allStudents;
  final List<Group> courseGroups;
  final String courseId;

  const _GroupDetailSheet({
    required this.group,
    required this.initialGroupStudents,
    required this.allStudents,
    required this.courseGroups,
    required this.courseId,
  });

  @override
  ConsumerState<_GroupDetailSheet> createState() => _GroupDetailSheetState();
}

class _GroupDetailSheetState extends ConsumerState<_GroupDetailSheet> {
  late List<AppUser> _groupStudents;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _groupStudents = List.from(widget.initialGroupStudents);
  }

  // Find which group a student belongs to in this course
  Group? _findStudentGroup(String studentId) {
    for (final group in widget.courseGroups) {
      if (group.studentIds.contains(studentId)) {
        return group;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group, size: 32, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_groupStudents.length} sinh viên',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                  label: const Text('Thêm sinh viên'),
                  onPressed: _isLoading ? null : () => _showAddStudentDialog(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),

              // Students List
              Expanded(
                child: _groupStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có sinh viên trong nhóm',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _groupStudents.length,
                        itemBuilder: (context, index) {
                          final student = _groupStudents[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  student.code != null && student.code!.isNotEmpty
                                      ? student.code![0]
                                      : '?',
                                  style: TextStyle(color: Colors.blue[700]),
                                ),
                              ),
                              title: Text(student.fullName),
                              subtitle: Text('${student.code ?? ''} • ${student.email ?? ''}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: _isLoading ? null : () => _removeStudent(student),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ADD STUDENT DIALOG - MULTI-SELECT WITH STATUS
  // ══════════════════════════════════════════════════════════════

  void _showAddStudentDialog(BuildContext context) {
    // Get students NOT in this group
    final groupStudentIds = _groupStudents.map((s) => s.id).toSet();
    final availableStudents = widget.allStudents
        .where((s) => !groupStudentIds.contains(s.id))
        .toList();

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả sinh viên đã có trong nhóm này')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _AddStudentDialog(
        availableStudents: availableStudents,
        currentGroup: widget.group,
        findStudentGroup: _findStudentGroup,
        onConfirm: (selectedStudents) => _addStudents(selectedStudents),
      ),
    );
  }

  Future<void> _addStudents(List<AppUser> students) async {
    if (students.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final studentIds = students.map((s) => s.id).toList();
      await ref.read(groupProvider.notifier).addStudents(widget.group.id, studentIds);

      // Update local state
      setState(() {
        for (final student in students) {
          if (!_groupStudents.any((s) => s.id == student.id)) {
            _groupStudents.add(student);
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm ${students.length} sinh viên')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeStudent(AppUser student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xóa ${student.fullName} khỏi nhóm?'),
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

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(groupProvider.notifier).removeStudent(widget.group.id, student.id);

      setState(() {
        _groupStudents.removeWhere((s) => s.id == student.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa ${student.fullName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ══════════════════════════════════════════════════════════════
// ADD STUDENT DIALOG - MULTI-SELECT WITH GROUP STATUS
// ══════════════════════════════════════════════════════════════

class _AddStudentDialog extends StatefulWidget {
  final List<AppUser> availableStudents;
  final Group currentGroup;
  final Group? Function(String studentId) findStudentGroup;
  final Future<void> Function(List<AppUser> students) onConfirm;

  const _AddStudentDialog({
    required this.availableStudents,
    required this.currentGroup,
    required this.findStudentGroup,
    required this.onConfirm,
  });

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  bool _isAdding = false;

  List<AppUser> get _filteredStudents {
    if (_searchQuery.isEmpty) return widget.availableStudents;
    final query = _searchQuery.toLowerCase();
    return widget.availableStudents.where((s) {
      return s.fullName.toLowerCase().contains(query) ||
          (s.code?.toLowerCase().contains(query) ?? false) ||
          (s.email?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Thêm sinh viên',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_selectedIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Đã chọn: ${_selectedIds.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Search & Legend
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, mã SV, email...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Row(
                    children: [
                      _buildLegendItem(Colors.grey, 'Chưa có nhóm'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.blue, 'Đã có nhóm khác'),
                    ],
                  ),
                ],
              ),
            ),

            // Student List
            Expanded(
              child: _filteredStudents.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy sinh viên',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final existingGroup = widget.findStudentGroup(student.id);
                        final hasOtherGroup = existingGroup != null &&
                            existingGroup.id != widget.currentGroup.id;
                        final isSelected = _selectedIds.contains(student.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? Colors.blue[50] : null,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(student.id);
                                } else {
                                  _selectedIds.add(student.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: hasOtherGroup
                                        ? Colors.blue[100]
                                        : Colors.grey[200],
                                    child: Text(
                                      student.code != null && student.code!.isNotEmpty
                                          ? student.code![0]
                                          : '?',
                                      style: TextStyle(
                                        color: hasOtherGroup
                                            ? Colors.blue[700]
                                            : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                student.fullName,
                                                style: const TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            // Status badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: hasOtherGroup
                                                    ? Colors.blue[100]
                                                    : Colors.grey[200],
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                hasOtherGroup
                                                    ? existingGroup.name
                                                    : 'Chưa có nhóm',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: hasOtherGroup
                                                      ? Colors.blue[700]
                                                      : Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${student.code ?? ''} • ${student.email ?? ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Action button
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue : Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? null
                                          : Border.all(color: Colors.green),
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check : Icons.add,
                                      color: isSelected ? Colors.white : Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAdding ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedIds.isEmpty || _isAdding
                          ? null
                          : _handleConfirm,
                      child: _isAdding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Thêm${_selectedIds.isEmpty ? '' : ' (${_selectedIds.length})'}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(MaterialColor color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color[100],
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Future<void> _handleConfirm() async {
    final selectedStudents = widget.availableStudents
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    // Check for students with existing groups
    final studentsWithGroup = <AppUser>[];
    for (final student in selectedStudents) {
      final group = widget.findStudentGroup(student.id);
      if (group != null && group.id != widget.currentGroup.id) {
        studentsWithGroup.add(student);
      }
    }

    // Show confirmation if moving students from other groups
    if (studentsWithGroup.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận chuyển nhóm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Các sinh viên sau đã có nhóm khác:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...studentsWithGroup.map((s) {
                final group = widget.findStudentGroup(s.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.fullName)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group?.name ?? '',
                          style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Text(
                'Họ sẽ được chuyển sang nhóm "${widget.currentGroup.name}".\nBạn có chắc chắn?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Chuyển nhóm'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isAdding = true);

    try {
      await widget.onConfirm(selectedStudents);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }
}