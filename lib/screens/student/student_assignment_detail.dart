// screens/student/student_assignment_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/assignment.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/course_provider.dart';
import '../../utils/file_upload_helper.dart';
import '../../utils/file_download_helper.dart';
import '../../main.dart'; // for localeProvider

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

  // Helper method to check if Vietnamese
  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
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
        title: Text(isVietnamese ? 'Bài tập' : 'Assignment'),
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
                          label: isVietnamese ? 'Hạn nộp' : 'Deadline',
                          value: '${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.repeat,
                          label: isVietnamese ? 'Số lần nộp' : 'Attempts',
                          value: '$attemptCount/${assignment.maxAttempts}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (latestSubmission?.grade != null)
                    _InfoCard(
                      icon: Icons.grade,
                      label: isVietnamese ? 'Điểm' : 'Grade',
                      value: latestSubmission!.grade!.toString(),
                      color: Colors.green,
                    ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Description
                  Text(
                    isVietnamese ? 'Mô tả:' : 'Description:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(assignment.description),
                  const SizedBox(height: 16),

                  // Attachments from instructor
                  if (assignment.attachments.isNotEmpty) ...[
                    Text(
                      isVietnamese ? 'Tệp đính kèm từ giáo viên:' : 'Attachments from instructor:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  Text(
                    isVietnamese ? 'Lịch sử nộp bài:' : 'Submission history:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  if (mySubmissions.isEmpty)
                    Text(isVietnamese ? 'Chưa nộp bài lần nào' : 'No submissions yet')
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
                          title: Text(isVietnamese ? 'Lần ${submission.attemptNumber}' : 'Attempt ${submission.attemptNumber}'),
                          subtitle: Text(
                            '${submission.submittedAt.day}/${submission.submittedAt.month}/${submission.submittedAt.year} ${submission.submittedAt.hour}:${submission.submittedAt.minute.toString().padLeft(2, '0')}'
                            '${submission.isLate ? (isVietnamese ? " • Nộp muộn" : " • Late") : ""}',
                          ),
                          trailing: submission.grade != null
                              ? Chip(
                                  label: Text('${submission.grade}'),
                                  backgroundColor: Colors.green.withOpacity(0.2),
                                )
                              : Chip(label: Text(isVietnamese ? 'Chưa chấm' : 'Not graded')),
                          children: [
                            if (submission.feedback != null)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVietnamese ? 'Nhận xét:' : 'Feedback:',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                                    Text(
                                      isVietnamese ? 'Tệp đã nộp:' : 'Submitted files:',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                    Text(
                      isVietnamese ? 'Nộp bài:' : 'Submit:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: Text(isVietnamese ? 'Chọn tệp' : 'Select files'),
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
                    : Text(isVietnamese ? 'Nộp bài' : 'Submit'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final isVietnamese = _isVietnamese();
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
          SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
        );
      }
    }
  }

  Future<void> _downloadInstructorFile(AssignmentAttachment attachment) async {
    final isVietnamese = _isVietnamese();
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVietnamese ? 'Đang tải xuống...' : 'Downloading...')),
        );
      }

      String result;

      if (attachment.fileUrl.startsWith('http://') ||
          attachment.fileUrl.startsWith('https://')) {
        final path = await FileDownloadHelper.downloadFile(
          url: attachment.fileUrl,
          fileName: attachment.fileName,
        );
        result = isVietnamese ? 'Đã tải: $path' : 'Downloaded: $path';
      }
      else if (attachment.fileUrl.startsWith('/') ||
               attachment.fileUrl.contains('\\')) {
        final downloaded = await FileDownloadHelper.downloadFromLocalPath(
          localPath: attachment.fileUrl,
          fileName: attachment.fileName,
        );
        result = downloaded != null
            ? (isVietnamese ? 'Đã tải: $downloaded' : 'Downloaded: $downloaded')
            : (isVietnamese ? 'Không thể tải file' : 'Cannot download file');
      }
      else if (attachment.fileUrl.isNotEmpty) {
        final path = await FileDownloadHelper.downloadFromBase64(
          base64Data: attachment.fileUrl,
          fileName: attachment.fileName,
        );
        result = isVietnamese ? 'Đã tải: $path' : 'Downloaded: $path';
      }
      else {
        throw Exception(isVietnamese ? 'Không có nguồn file hợp lệ' : 'No valid file source');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isVietnamese ? 'Lỗi tải file' : 'Download error'}: $e')),
        );
      }
    }
  }

  Future<void> _downloadSubmittedFile(AssignmentAttachment file) async {
    final isVietnamese = _isVietnamese();
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVietnamese ? 'Đang tải xuống...' : 'Downloading...')),
        );
      }

      String result;

      if (file.fileUrl.isNotEmpty) {
        final isLikelyBase64 = !file.fileUrl.startsWith('http://') &&
                               !file.fileUrl.startsWith('https://') &&
                               !file.fileUrl.startsWith('/') &&
                               !file.fileUrl.contains('\\');

        if (isLikelyBase64) {
          final path = await FileDownloadHelper.downloadFromBase64(
            base64Data: file.fileUrl,
            fileName: file.fileName,
          );
          result = isVietnamese ? 'Đã tải: $path' : 'Downloaded: $path';
        } else if (file.fileUrl.startsWith('http://') ||
                   file.fileUrl.startsWith('https://')) {
          final path = await FileDownloadHelper.downloadFile(
            url: file.fileUrl,
            fileName: file.fileName,
          );
          result = isVietnamese ? 'Đã tải: $path' : 'Downloaded: $path';
        } else {
          final downloaded = await FileDownloadHelper.downloadFromLocalPath(
            localPath: file.fileUrl,
            fileName: file.fileName,
          );
          result = downloaded != null
              ? (isVietnamese ? 'Đã tải: $downloaded' : 'Downloaded: $downloaded')
              : (isVietnamese ? 'Không thể tải file' : 'Cannot download file');
        }
      } else {
        throw Exception(isVietnamese ? 'File không có dữ liệu' : 'File has no data');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isVietnamese ? 'Lỗi tải file' : 'Download error'}: $e')),
        );
      }
    }
  }

  // ✅ UPDATED: Submit assignment with email notification
  Future<void> _submitAssignment() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final groups = ref.read(groupProvider);
    
    try {
      final studentGroup = groups.firstWhere(
        (g) => g.courseId == widget.assignment.courseId && g.studentIds.contains(user.id),
      );

      // ✅ Get course info for email
      final courses = ref.read(courseProvider);
      final course = courses.firstWhere(
        (c) => c.id == widget.assignment.courseId,
        orElse: () => throw Exception('Course not found'),
      );

      setState(() => _isSubmitting = true);

      final attachments = _selectedFiles.map((fileData) {
        return AssignmentAttachment(
          fileName: fileData['fileName'],
          fileUrl: fileData['fileData'] ?? '',
          fileSize: fileData['fileSize'],
          mimeType: fileData['mimeType'],
        );
      }).toList();

      // ✅ Submit with email notification
      await ref.read(assignmentProvider.notifier).submitAssignment(
            assignmentId: widget.assignment.id,
            studentId: user.id,
            studentName: user.fullName,
            studentEmail: user.email, // ✅ ADD
            courseName: course.name, // ✅ ADD
            groupId: studentGroup.id,
            groupName: studentGroup.name,
            files: attachments,
          );

      setState(() {
        _selectedFiles.clear();
      });

      if (mounted) {
        final isVietnamese = _isVietnamese();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVietnamese
                ? 'Đã nộp bài thành công! Email xác nhận đã được gửi.'
                : 'Successfully submitted! Confirmation email has been sent.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isVietnamese = _isVietnamese();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
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