// screens/instructor/assignments_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../../models/assignment.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/course_provider.dart'; // ✅ ADD
import '../../utils/file_upload_helper.dart';
import '../../utils/file_download_helper.dart';

class AssignmentsTab extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  final List<Group> groups;
  final List<AppUser> students;
  final String instructorId;
  final String instructorName;

  const AssignmentsTab({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.groups,
    required this.students,
    required this.instructorId,
    required this.instructorName,
  });

  @override
  ConsumerState<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends ConsumerState<AssignmentsTab> {
  String _searchQuery = '';
  String? _selectedGroupFilter;
  AssignmentStatus? _selectedStatusFilter;
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignmentProvider.notifier).loadAssignments(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignments = ref.watch(assignmentProvider)
        .where((a) => a.courseId == widget.courseId)
        .toList();

    return Column(
      children: [
        // Create Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Tạo bài tập'),
            onPressed: () => _showCreateAssignmentDialog(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        // Filters and Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGroupFilter,
                      decoration: const InputDecoration(
                        labelText: 'Lọc theo nhóm',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tất cả')),
                        ...widget.groups.map((g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.name),
                            )),
                      ],
                      onChanged: (value) => setState(() => _selectedGroupFilter = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<AssignmentStatus>(
                      value: _selectedStatusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Lọc theo trạng thái',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tất cả')),
                        ...AssignmentStatus.values.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_getStatusText(s)),
                            )),
                      ],
                      onChanged: (value) => setState(() => _selectedStatusFilter = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Sắp xếp theo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('Tên')),
                        DropdownMenuItem(value: 'group', child: Text('Nhóm')),
                        DropdownMenuItem(value: 'time', child: Text('Thời gian')),
                        DropdownMenuItem(value: 'status', child: Text('Trạng thái')),
                      ],
                      onChanged: (value) => setState(() => _sortBy = value!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                    onPressed: () => setState(() => _sortAscending = !_sortAscending),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Assignments List
        Expanded(
          child: assignments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Chưa có bài tập nào'),
                    ],
                  ),
                )
              : _buildAssignmentsList(_filterAndSort(assignments)),
        ),
      ],
    );
  }

  List<Assignment> _filterAndSort(List<Assignment> assignments) {
    var filtered = assignments;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((a) {
        return a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            a.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.title.compareTo(b.title);
          break;
        case 'time':
          comparison = a.deadline.compareTo(b.deadline);
          break;
        case 'status':
          comparison = a.submissions.length.compareTo(b.submissions.length);
          break;
        case 'group':
          comparison = a.groupIds.length.compareTo(b.groupIds.length);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Widget _buildAssignmentsList(List<Assignment> assignments) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(assignmentProvider.notifier).loadAssignments(widget.courseId);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return _AssignmentCard(
            assignment: assignment,
            groups: widget.groups,
            students: widget.students,
            onTap: () => _showAssignmentDetail(context, assignment),
            onDelete: () => _deleteAssignment(assignment.id),
            onExport: () => _exportAssignmentToCSV(assignment),
          );
        },
      ),
    );
  }

  void _showCreateAssignmentDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final startDateCtrl = TextEditingController();
    final deadlineCtrl = TextEditingController();
    final lateDeadlineCtrl = TextEditingController();
    final maxAttemptsCtrl = TextEditingController(text: '1');
    final maxFileSizeCtrl = TextEditingController(text: '10485760');
    final allowedFormatsCtrl = TextEditingController(text: 'pdf,doc,docx');
    final formKey = GlobalKey<FormState>();
    bool allowLateSubmission = false;
    final selectedGroupIds = <String>[];
    final List<Map<String, dynamic>> selectedFiles = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Tạo bài tập'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.7,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // File upload section
                      const Text('Tệp đính kèm:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Chọn tệp'),
                        onPressed: () async {
                          try {
                            final encodedFiles = await FileUploadHelper.pickAndEncodeMultipleFiles();
                            if (encodedFiles.isNotEmpty) {
                              setDialogState(() {
                                selectedFiles.addAll(encodedFiles);
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi chọn file: $e')),
                            );
                          }
                        },
                      ),
                      if (selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...selectedFiles.map((fileData) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.attachment),
                              title: Text(fileData['fileName']),
                              subtitle: Text('${(fileData['fileSize'] / 1024).toStringAsFixed(1)} KB'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedFiles.remove(fileData);
                                  });
                                },
                              ),
                              dense: true,
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      
                      // Date fields
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startDateCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ngày bắt đầu *',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              readOnly: true,
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  startDateCtrl.text = '${date.day}/${date.month}/${date.year}';
                                }
                              },
                              validator: (v) => v?.isEmpty == true ? 'Bắt buộc' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: deadlineCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Hạn nộp *',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              readOnly: true,
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: DateTime.now().add(const Duration(days: 7)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  deadlineCtrl.text = '${date.day}/${date.month}/${date.year}';
                                }
                              },
                              validator: (v) => v?.isEmpty == true ? 'Bắt buộc' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Cho phép nộp muộn'),
                        value: allowLateSubmission,
                        onChanged: (v) => setDialogState(() => allowLateSubmission = v!),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (allowLateSubmission) ...[
                        TextFormField(
                          controller: lateDeadlineCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Hạn nộp muộn',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: DateTime.now().add(const Duration(days: 14)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              lateDeadlineCtrl.text = '${date.day}/${date.month}/${date.year}';
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      TextFormField(
                        controller: maxAttemptsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Số lần nộp tối đa *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Bắt buộc';
                          final n = int.tryParse(v!);
                          if (n == null || n < 1) return 'Phải >= 1';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: allowedFormatsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Định dạng cho phép (VD: pdf,doc,docx)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: maxFileSizeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kích thước tối đa (bytes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      
                      // Group Selection
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.group, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Chọn nhóm áp dụng:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Đã chọn: ${selectedGroupIds.length}/${widget.groups.length} nhóm',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: Text(
                                selectedGroupIds.isEmpty 
                                  ? 'Chọn nhóm' 
                                  : 'Sửa nhóm đã chọn',
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              onPressed: () async {
                                final result = await _showGroupSelectionDialog(
                                  dialogContext,
                                  selectedGroupIds,
                                  widget.groups,
                                );
                                if (result != null) {
                                  setDialogState(() {
                                    selectedGroupIds.clear();
                                    selectedGroupIds.addAll(result);
                                  });
                                }
                              },
                            ),
                            
                            if (selectedGroupIds.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedGroupIds.map((groupId) {
                                  final group = widget.groups.firstWhere(
                                    (g) => g.id == groupId,
                                    orElse: () => Group(id: '', name: 'Unknown', courseId: ''),
                                  );
                                  return Chip(
                                    label: Text(group.name),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () {
                                      setDialogState(() {
                                        selectedGroupIds.remove(groupId);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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

                  if (selectedGroupIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn ít nhất một nhóm')),
                    );
                    return;
                  }

                  DateTime? startDate = _parseDate(startDateCtrl.text);
                  DateTime? deadline = _parseDate(deadlineCtrl.text);
                  DateTime? lateDeadline = allowLateSubmission && lateDeadlineCtrl.text.isNotEmpty
                      ? _parseDate(lateDeadlineCtrl.text)
                      : null;

                  if (startDate == null || deadline == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn ngày hợp lệ')),
                    );
                    return;
                  }

                  if (deadline.isBefore(startDate)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hạn nộp phải sau ngày bắt đầu')),
                    );
                    return;
                  }

                  final allowedFormats = allowedFormatsCtrl.text
                      .split(',')
                      .map((f) => f.trim())
                      .where((f) => f.isNotEmpty)
                      .toList();

                  final attachments = selectedFiles.map((fileData) {
                    return AssignmentAttachment(
                      fileName: fileData['fileName'],
                      fileUrl: fileData['fileData'] ?? '',
                      fileSize: fileData['fileSize'],
                      mimeType: fileData['mimeType'],
                    );
                  }).toList();

                  try {
                    await ref.read(assignmentProvider.notifier).createAssignment(
                      courseId: widget.courseId,
                      title: titleCtrl.text.trim(),
                      description: descriptionCtrl.text.trim(),
                      startDate: startDate,
                      deadline: deadline,
                      allowLateSubmission: allowLateSubmission,
                      lateDeadline: lateDeadline,
                      maxAttempts: int.parse(maxAttemptsCtrl.text),
                      allowedFileFormats: allowedFormats,
                      maxFileSize: int.tryParse(maxFileSizeCtrl.text) ?? 10485760,
                      groupIds: selectedGroupIds,
                      instructorId: widget.instructorId,
                      instructorName: widget.instructorName,
                      attachments: attachments,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã tạo bài tập cho ${selectedGroupIds.length} nhóm'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                },
                child: const Text('Tạo'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<String>?> _showGroupSelectionDialog(
    BuildContext context,
    List<String> currentSelectedIds,
    List<Group> groups,
  ) async {
    final tempSelectedIds = List<String>.from(currentSelectedIds);
    
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allSelected = tempSelectedIds.length == groups.length;
          
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.group, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Chọn nhóm'),
                const Spacer(),
                Text(
                  '${tempSelectedIds.length}/${groups.length}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: allSelected ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: allSelected ? Colors.green : Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        allSelected ? Icons.check_circle : Icons.add_circle_outline,
                        color: allSelected ? Colors.green : Colors.blue,
                      ),
                      title: Text(
                        allSelected ? 'Đã chọn tất cả' : 'Chọn tất cả nhóm',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: allSelected ? Colors.green : Colors.blue,
                        ),
                      ),
                      subtitle: Text('${groups.length} nhóm'),
                      onTap: () {
                        setDialogState(() {
                          if (allSelected) {
                            tempSelectedIds.clear();
                          } else {
                            tempSelectedIds.clear();
                            tempSelectedIds.addAll(groups.map((g) => g.id));
                          }
                        });
                      },
                    ),
                  ),
                  
                  const Divider(),
                  
                  Expanded(
                    child: groups.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Chưa có nhóm nào'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            final isSelected = tempSelectedIds.contains(group.id);
                            
                            return Card(
                              color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? Colors.blue : Colors.grey,
                                  child: Icon(
                                    isSelected ? Icons.check : Icons.add,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  group.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text('${group.studentIds.length} học sinh'),
                                trailing: isSelected 
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.add_circle_outline, color: Colors.grey),
                                onTap: () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      tempSelectedIds.remove(group.id);
                                    } else {
                                      tempSelectedIds.add(group.id);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: tempSelectedIds.isEmpty 
                  ? null 
                  : () => Navigator.pop(ctx, tempSelectedIds),
                child: Text('Xác nhận (${tempSelectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // ✅ UPDATED: Add email notification when grading
  void _showAssignmentDetail(BuildContext context, Assignment assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AssignmentDetailSheet(
        assignment: assignment,
        groups: widget.groups,
        students: widget.students,
        onGrade: (submissionId, grade, feedback) async {
          // ✅ Get student info for email
          final submission = assignment.submissions.firstWhere(
            (s) => s.id == submissionId,
          );
          
          final student = widget.students.firstWhere(
            (s) => s.id == submission.studentId,
            orElse: () => AppUser(
              id: '',
              fullName: 'Unknown',
              email: '',
              role: UserRole.student,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          // ✅ Grade with email notification
          await ref.read(assignmentProvider.notifier).gradeSubmission(
            assignmentId: assignment.id,
            submissionId: submissionId,
            studentEmail: student.email, // ✅ ADD
            studentName: student.fullName, // ✅ ADD
            courseName: widget.courseName, // ✅ ADD
            grade: grade,
            feedback: feedback,
          );
        },
        onExport: () => _exportAssignmentToCSV(assignment),
      ),
    );
  }

  void _deleteAssignment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài tập'),
        content: const Text('Bạn có chắc muốn xóa bài tập này?'),
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
      await ref.read(assignmentProvider.notifier).deleteAssignment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài tập')),
        );
      }
    }
  }

  Future<void> _exportAssignmentToCSV(Assignment assignment) async {
    try {
      final rows = <List<dynamic>>[
        ['Tên', 'Nhóm', 'Trạng thái', 'Lần nộp', 'Thời gian nộp', 'Điểm', 'Nhận xét'],
      ];

      final relevantStudents = assignment.groupIds.isEmpty
          ? widget.students
          : widget.students.where((s) {
              return widget.groups
                  .where((g) => assignment.groupIds.contains(g.id))
                  .any((g) => g.studentIds.contains(s.id));
            }).toList();

      for (final student in relevantStudents) {
        final group = widget.groups.firstWhere(
          (g) => g.studentIds.contains(student.id),
          orElse: () => Group(id: '', name: 'N/A', courseId: ''),
        );
        final submissions = assignment.submissions
            .where((s) => s.studentId == student.id)
            .toList();
        
        if (submissions.isEmpty) {
          rows.add([
            student.fullName,
            group.name,
            'Chưa nộp',
            '0',
            '',
            '',
            '',
          ]);
        } else {
          for (final submission in submissions) {
            rows.add([
              student.fullName,
              group.name,
              submission.isLate ? 'Nộp muộn' : 'Đã nộp',
              '${submission.attemptNumber}',
              submission.submittedAt.toString(),
              submission.grade?.toString() ?? '',
              submission.feedback ?? '',
            ]);
          }
        }
      }

      final csv = const ListToCsvConverter().convert(rows);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/assignment_${assignment.id}.csv');
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xuất CSV: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất CSV: $e')),
        );
      }
    }
  }

  static String _getStatusText(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.notStarted:
        return 'Chưa bắt đầu';
      case AssignmentStatus.inProgress:
        return 'Đang làm';
      case AssignmentStatus.submitted:
        return 'Đã nộp';
      case AssignmentStatus.late:
        return 'Nộp muộn';
      case AssignmentStatus.graded:
        return 'Đã chấm';
    }
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final List<Group> groups;
  final List<AppUser> students;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _AssignmentCard({
    required this.assignment,
    required this.groups,
    required this.students,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final submittedCount = assignment.submissions.length;
    final totalStudents = assignment.groupIds.isEmpty
        ? students.length
        : students.where((s) {
            return groups
                .where((g) => assignment.groupIds.contains(g.id))
                .any((g) => g.studentIds.contains(s.id));
          }).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.file_download),
                            SizedBox(width: 8),
                            Text('Xuất CSV'),
                          ],
                        ),
                        onTap: onExport,
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
              const SizedBox(height: 8),
              Text(
                assignment.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('$submittedCount/$totalStudents đã nộp', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Hạn: ${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year}',
                    style: TextStyle(color: Colors.grey[600]),
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

class _AssignmentDetailSheet extends ConsumerStatefulWidget {
  final Assignment assignment;
  final List<Group> groups;
  final List<AppUser> students;
  final Function(String, double, String?) onGrade;
  final VoidCallback onExport;

  const _AssignmentDetailSheet({
    required this.assignment,
    required this.groups,
    required this.students,
    required this.onGrade,
    required this.onExport,
  });

  @override
  ConsumerState<_AssignmentDetailSheet> createState() => _AssignmentDetailSheetState();
}

class _AssignmentDetailSheetState extends ConsumerState<_AssignmentDetailSheet> {
  String _searchQuery = '';
  String? _selectedGroupFilter;
  String _sortBy = 'name';
  bool _sortAscending = true;

  Future<void> _downloadFile(BuildContext context, AssignmentAttachment attachment) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải xuống...')),
        );
      }

      String result;
      
      if (attachment.fileUrl.startsWith('http://') || 
          attachment.fileUrl.startsWith('https://')) {
        final path = await FileDownloadHelper.downloadFile(
          url: attachment.fileUrl,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      }
      else if (attachment.fileUrl.startsWith('/') || 
               attachment.fileUrl.contains('\\')) {
        final sourceFile = File(attachment.fileUrl);
        if (await sourceFile.exists()) {
          final directory = await getApplicationDocumentsDirectory();
          final destinationFile = File('${directory.path}/${attachment.fileName}');
          await sourceFile.copy(destinationFile.path);
          result = 'Đã tải: ${destinationFile.path}';
        } else {
          throw Exception('Tệp không tồn tại');
        }
      }
      else if (attachment.fileUrl.isNotEmpty) {
        final path = await FileDownloadHelper.downloadFromBase64(
          base64Data: attachment.fileUrl,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } 
      else {
        throw Exception('No valid file source');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = ref.watch(assignmentProvider)
        .firstWhere((a) => a.id == widget.assignment.id, orElse: () => widget.assignment);

    final relevantStudents = assignment.groupIds.isEmpty
        ? widget.students
        : widget.students.where((s) {
            return widget.groups
                .where((g) => assignment.groupIds.contains(g.id))
                .any((g) => g.studentIds.contains(s.id));
          }).toList();

    final trackingData = relevantStudents.map((student) {
      final group = widget.groups.firstWhere(
        (g) => g.studentIds.contains(student.id),
        orElse: () => Group(id: '', name: 'N/A', courseId: ''),
      );
      final submissions = assignment.submissions
          .where((s) => s.studentId == student.id)
          .toList();
      final status = assignment.getStatusForStudent(student.id, group.id);
      final latestSubmission = submissions.isNotEmpty
          ? submissions.reduce((a, b) => a.submittedAt.isAfter(b.submittedAt) ? a : b)
          : null;

      return _TrackingRow(
        student: student,
        group: group,
        submissions: submissions,
        status: status,
        latestSubmission: latestSubmission,
        onGrade: widget.onGrade,
      );
    }).toList();

    var filtered = trackingData;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((row) {
        return row.student.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            row.group.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    if (_selectedGroupFilter != null) {
      filtered = filtered.where((row) => row.group.id == _selectedGroupFilter).toList();
    }

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.student.fullName.compareTo(b.student.fullName);
          break;
        case 'group':
          comparison = a.group.name.compareTo(b.group.name);
          break;
        case 'time':
          final aTime = a.latestSubmission?.submittedAt ?? DateTime(1970);
          final bTime = b.latestSubmission?.submittedAt ?? DateTime(1970);
          comparison = aTime.compareTo(bTime);
          break;
        case 'status':
          comparison = a.status.name.compareTo(b.status.name);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Hạn: ${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    onPressed: widget.onExport,
                    tooltip: 'Xuất CSV',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            if (assignment.attachments.isNotEmpty || assignment.description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (assignment.description.isNotEmpty) ...[
                      const Text(
                        'Mô tả:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(assignment.description),
                      const SizedBox(height: 16),
                    ],
                    if (assignment.attachments.isNotEmpty) ...[
                      const Text(
                        'Tệp đính kèm:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...assignment.attachments.map((attachment) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.attachment),
                            title: Text(attachment.fileName),
                            subtitle: Text('${(attachment.fileSize / 1024).toStringAsFixed(1)} KB'),
                            trailing: IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _downloadFile(context, attachment),
                            ),
                            dense: true,
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGroupFilter,
                          decoration: const InputDecoration(
                            labelText: 'Nhóm',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tất cả')),
                            ...widget.groups.map((g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.name),
                                )),
                          ],
                          onChanged: (value) => setState(() => _selectedGroupFilter = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sortBy,
                          decoration: const InputDecoration(
                            labelText: 'Sắp xếp',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'name', child: Text('Tên')),
                            DropdownMenuItem(value: 'group', child: Text('Nhóm')),
                            DropdownMenuItem(value: 'time', child: Text('Thời gian')),
                            DropdownMenuItem(value: 'status', child: Text('Trạng thái')),
                          ],
                          onChanged: (value) => setState(() => _sortBy = value!),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                        onPressed: () => setState(() => _sortAscending = !_sortAscending),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Tên')),
                      DataColumn(label: Text('Nhóm')),
                      DataColumn(label: Text('Trạng thái')),
                      DataColumn(label: Text('Lần nộp')),
                      DataColumn(label: Text('Thời gian')),
                      DataColumn(label: Text('Điểm')),
                      DataColumn(label: Text('Hành động')),
                    ],
                    rows: filtered.map((row) => row.buildDataRow(context)).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrackingRow {
  final AppUser student;
  final Group group;
  final List<AssignmentSubmission> submissions;
  final AssignmentStatus status;
  final AssignmentSubmission? latestSubmission;
  final Function(String, double, String?) onGrade;

  _TrackingRow({
    required this.student,
    required this.group,
    required this.submissions,
    required this.status,
    required this.latestSubmission,
    required this.onGrade,
  });

  DataRow buildDataRow(BuildContext context) {
    return DataRow(
      cells: [
        DataCell(Text(student.fullName)),
        DataCell(Text(group.name)),
        DataCell(_buildStatusChip()),
        DataCell(Text('${submissions.length}')),
        DataCell(Text(
          latestSubmission != null
              ? '${latestSubmission!.submittedAt.day}/${latestSubmission!.submittedAt.month}/${latestSubmission!.submittedAt.year}'
              : '-',
        )),
        DataCell(Text(
          latestSubmission?.grade?.toString() ?? '-',
        )),
        DataCell(
          latestSubmission != null && latestSubmission!.grade == null
              ? ElevatedButton(
                  onPressed: () => _showGradeDialog(context),
                  child: const Text('Chấm điểm'),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;
    switch (status) {
      case AssignmentStatus.notStarted:
        color = Colors.grey;
        text = 'Chưa bắt đầu';
        break;
      case AssignmentStatus.inProgress:
        color = Colors.blue;
        text = 'Đang làm';
        break;
      case AssignmentStatus.submitted:
        color = Colors.green;
        text = 'Đã nộp';
        break;
      case AssignmentStatus.late:
        color = Colors.orange;
        text = 'Nộp muộn';
        break;
      case AssignmentStatus.graded:
        color = Colors.purple;
        text = 'Đã chấm';
        break;
    }
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showGradeDialog(BuildContext context) {
    if (latestSubmission == null) return;

    final gradeCtrl = TextEditingController();
    final feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chấm điểm - ${student.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gradeCtrl,
              decoration: const InputDecoration(
                labelText: 'Điểm *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackCtrl,
              decoration: const InputDecoration(
                labelText: 'Nhận xét',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final grade = double.tryParse(gradeCtrl.text);
              if (grade == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập điểm hợp lệ')),
                );
                return;
              }
              onGrade(
                latestSubmission!.id,
                grade,
                feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã chấm điểm và gửi email thông báo')), // ✅ UPDATED MESSAGE
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}