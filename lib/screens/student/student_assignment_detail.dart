// screens/student/tabs/student_assignment_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/assignment.dart';
import '../../../providers/assignment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../utils/file_upload_helper.dart';
import '../../../utils/file_download_helper.dart';

class StudentAssignmentDetail extends ConsumerStatefulWidget {
  final Assignment assignment;
  final bool canSubmit;

  const StudentAssignmentDetail({
    super.key,
    required this.assignment,
    required this.canSubmit,
  });

  @override
  ConsumerState<StudentAssignmentDetail> createState() => _StudentAssignmentDetailState();
}

class _StudentAssignmentDetailState extends ConsumerState<StudentAssignmentDetail> {
  final List<Map<String, dynamic>> _selectedFiles = [];
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final assignment = ref.watch(assignmentProvider)
        .firstWhere((a) => a.id == widget.assignment.id, orElse: () => widget.assignment);
    
    final mySubmissions = assignment.submissions
        .where((s) => s.studentId == user?.id)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final latestSubmission = mySubmissions.isNotEmpty ? mySubmissions.first : null;
    final attemptCount = mySubmissions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài tập'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    assignment.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Instructor
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(assignment.instructorName[0]),
                      ),
                      const SizedBox(width: 12),
                      Text(assignment.instructorName),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.calendar_today,
                          label: 'Hạn nộp',
                          value: '${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.repeat,
                          label: 'Số lần nộp',
                          value: '$attemptCount/${assignment.maxAttempts}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (latestSubmission?.grade != null)
                    _InfoCard(
                      icon: Icons.grade,
                      label: 'Điểm',
                      value: latestSubmission!.grade!.toString(),
                      color: Colors.green,
                    ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Description
                  const Text(
                    'Mô tả:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(assignment.description),
                  const SizedBox(height: 16),
                  
                  // Attachments from instructor
                  if (assignment.attachments.isNotEmpty) ...[
                    const Text(
                      'Tệp đính kèm từ giáo viên:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...assignment.attachments.map((attachment) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(attachment.fileName),
                          subtitle: Text('${(attachment.fileSize / 1024).toStringAsFixed(1)} KB'),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadInstructorFile(attachment),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  
                  const Divider(),
                  
                  // Submission History
                  const Text(
                    'Lịch sử nộp bài:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  
                  if (mySubmissions.isEmpty)
                    const Text('Chưa nộp bài lần nào')
                  else
                    ...mySubmissions.map((submission) {
                      return Card(
                        color: submission.isLate ? Colors.orange.withOpacity(0.1) : null,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: submission.isLate 
                                ? Colors.orange 
                                : Colors.green,
                            child: Text(
                              submission.attemptNumber.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('Lần ${submission.attemptNumber}'),
                          subtitle: Text(
                            '${submission.submittedAt.day}/${submission.submittedAt.month}/${submission.submittedAt.year} ${submission.submittedAt.hour}:${submission.submittedAt.minute.toString().padLeft(2, '0')}'
                            '${submission.isLate ? " • Nộp muộn" : ""}',
                          ),
                          trailing: submission.grade != null
                              ? Chip(
                                  label: Text('${submission.grade}'),
                                  backgroundColor: Colors.green.withOpacity(0.2),
                                )
                              : const Chip(label: Text('Chưa chấm')),
                          children: [
                            if (submission.feedback != null)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Nhận xét:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(submission.feedback!),
                                  ],
                                ),
                              ),
                            if (submission.files.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tệp đã nộp:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    ...submission.files.map((file) {
                                      return ListTile(
                                        leading: const Icon(Icons.attach_file),
                                        title: Text(file.fileName),
                                        subtitle: Text('${(file.fileSize / 1024).toStringAsFixed(1)} KB'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.download),
                                          onPressed: () => _downloadSubmittedFile(file),
                                        ),
                                        dense: true,
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Submit Section
                  if (widget.canSubmit && attemptCount < assignment.maxAttempts) ...[
                    const Text(
                      'Nộp bài:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Chọn tệp'),
                      onPressed: _pickFiles,
                    ),
                    
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._selectedFiles.map((fileData) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.attach_file),
                            title: Text(fileData['fileName']),
                            subtitle: Text('${(fileData['fileSize'] / 1024).toStringAsFixed(1)} KB'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.remove(fileData);
                                });
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ),
          
          // Submit Button
          if (widget.canSubmit && attemptCount < assignment.maxAttempts)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _selectedFiles.isEmpty || _isSubmitting ? null : _submitAssignment,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Nộp bài'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      final encodedFiles = await FileUploadHelper.pickAndEncodeMultipleFiles();
      if (encodedFiles.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(encodedFiles);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  // ✅ FIX: Download instructor's attachment files
  Future<void> _downloadInstructorFile(AssignmentAttachment attachment) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải xuống...')),
        );
      }

      String result;
      
      // Check if it's a URL
      if (attachment.fileUrl.startsWith('http://') || 
          attachment.fileUrl.startsWith('https://')) {
        final path = await FileDownloadHelper.downloadFile(
          url: attachment.fileUrl,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } 
      // Check if it's a local path
      else if (attachment.fileUrl.startsWith('/') || 
               attachment.fileUrl.contains('\\')) {
        final downloaded = await FileDownloadHelper.downloadFromLocalPath(
          localPath: attachment.fileUrl,
          fileName: attachment.fileName,
        );
        result = downloaded != null ? 'Đã tải: $downloaded' : 'Không thể tải file';
      }
      // Otherwise it might be base64 encoded
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

  // ✅ FIX: Download student's submitted files (stored as base64 in fileUrl)
  Future<void> _downloadSubmittedFile(AssignmentAttachment file) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải xuống...')),
        );
      }

      String result;
      
      // Student submitted files are stored as base64 in fileUrl
      if (file.fileUrl.isNotEmpty) {
        // Try to detect if it's base64 (doesn't start with http/https or path separators)
        final isLikelyBase64 = !file.fileUrl.startsWith('http://') && 
                               !file.fileUrl.startsWith('https://') &&
                               !file.fileUrl.startsWith('/') &&
                               !file.fileUrl.contains('\\');
        
        if (isLikelyBase64) {
          // Download from base64
          final path = await FileDownloadHelper.downloadFromBase64(
            base64Data: file.fileUrl,
            fileName: file.fileName,
          );
          result = 'Đã tải: $path';
        } else if (file.fileUrl.startsWith('http://') || 
                   file.fileUrl.startsWith('https://')) {
          // Download from URL
          final path = await FileDownloadHelper.downloadFile(
            url: file.fileUrl,
            fileName: file.fileName,
          );
          result = 'Đã tải: $path';
        } else {
          // Try local path
          final downloaded = await FileDownloadHelper.downloadFromLocalPath(
            localPath: file.fileUrl,
            fileName: file.fileName,
          );
          result = downloaded != null ? 'Đã tải: $downloaded' : 'Không thể tải file';
        }
      } else {
        throw Exception('File không có dữ liệu');
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

  Future<void> _submitAssignment() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    // Get student's group
    final groups = ref.read(groupProvider);
    
    try {
      final studentGroup = groups.firstWhere(
        (g) => g.courseId == widget.assignment.courseId && g.studentIds.contains(user.id),
      );

      setState(() => _isSubmitting = true);

      // ✅ FIX: Store base64 data properly in fileUrl field
      final attachments = _selectedFiles.map((fileData) {
        return AssignmentAttachment(
          fileName: fileData['fileName'],
          fileUrl: fileData['fileData'] ?? '', // Base64 data stored in fileUrl
          fileSize: fileData['fileSize'],
          mimeType: fileData['mimeType'],
        );
      }).toList();

      await ref.read(assignmentProvider.notifier).submitAssignment(
            assignmentId: widget.assignment.id,
            studentId: user.id,
            studentName: user.fullName,
            groupId: studentGroup.id,
            groupName: studentGroup.name,
            files: attachments,
          );

      setState(() {
        _selectedFiles.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nộp bài thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color ?? Colors.blue),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}