// screens/student/tabs/student_announcement_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/announcement.dart';
import '../../../models/user.dart';
import '../../../providers/announcement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/file_download_helper.dart';

class StudentAnnouncementDetail extends ConsumerStatefulWidget {
  final Announcement announcement;
  final bool isPastSemester;

  const StudentAnnouncementDetail({
    super.key,
    required this.announcement,
    required this.isPastSemester,
  });

  @override
  ConsumerState<StudentAnnouncementDetail> createState() => _StudentAnnouncementDetailState();
}

class _StudentAnnouncementDetailState extends ConsumerState<StudentAnnouncementDetail> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Mark as viewed
      final user = ref.read(authProvider);
      if (user != null && !widget.announcement.viewedBy.contains(user.id)) {
        ref.read(announcementProvider.notifier).markAsViewed(
              widget.announcement.id,
              user.id,
            );
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final announcement = ref.watch(announcementProvider)
        .firstWhere((a) => a.id == widget.announcement.id, orElse: () => widget.announcement);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        child: Text(announcement.instructorName[0]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              announcement.instructorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${announcement.publishedAt.day}/${announcement.publishedAt.month}/${announcement.publishedAt.year} ${announcement.publishedAt.hour}:${announcement.publishedAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Content
                  Text(
                    announcement.content,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  
                  // Attachments
                  if (announcement.attachments.isNotEmpty) ...[
                    const Divider(),
                    const Text(
                      'Tệp đính kèm:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...announcement.attachments.map((attachment) {
                      // ✅ FIX: Check if it's a link by looking at fileUrl
                      final isLink = attachment.fileUrl.startsWith('http://') || 
                                    attachment.fileUrl.startsWith('https://');
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isLink ? Icons.link : Icons.attach_file,
                          ),
                          title: Text(attachment.fileName),
                          subtitle: Text('${(attachment.fileSize / 1024).toStringAsFixed(1)} KB'),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadFile(attachment),
                          ),
                        ),
                      );
                    }),
                  ],
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Comments Section
                  Text(
                    'Bình luận (${announcement.comments.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (announcement.comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Chưa có bình luận nào',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ...announcement.comments.map((comment) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(comment.userName[0]),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${comment.createdAt.day}/${comment.createdAt.month}/${comment.createdAt.year}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(comment.content),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          
          // Comment Input
          if (!widget.isPastSemester)
            Container(
              padding: const EdgeInsets.all(8),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Viết bình luận...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _addComment(user),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(AnnouncementAttachment attachment) async {
    try {
      // ✅ FIX: Check if it's a link
      final isLink = attachment.fileUrl.startsWith('http://') || 
                     attachment.fileUrl.startsWith('https://');
      
      if (isLink) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Link: ${attachment.fileUrl}')),
          );
        }
        return;
      }

      // ✅ FIX: AnnouncementAttachment only has fileUrl, not fileData
      String result;
      if (attachment.fileUrl.isNotEmpty) {
        // Try to download the file from URL or local path
        if (attachment.fileUrl.startsWith('http://') || attachment.fileUrl.startsWith('https://')) {
          final path = await FileDownloadHelper.downloadFile(
            url: attachment.fileUrl,
            fileName: attachment.fileName,
          );
          result = 'Đã tải: $path';
        } else {
          // Local file path
          final path = await FileDownloadHelper.downloadFromLocalPath(
            localPath: attachment.fileUrl,
            fileName: attachment.fileName,
          );
          result = path != null ? 'Đã tải: $path' : 'Không thể tải file';
        }
      } else {
        throw Exception('No valid file source');
      }

      // Track download
      final user = ref.read(authProvider);
      if (user != null) {
        ref.read(announcementProvider.notifier).trackDownload(
              widget.announcement.id,
              user.id,
              attachment.fileName,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
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

  Future<void> _addComment(AppUser? user) async {
    if (_commentController.text.trim().isEmpty || user == null) return;

    try {
      await ref.read(announcementProvider.notifier).addComment(
            widget.announcement.id,
            user.id,
            user.fullName,
            _commentController.text.trim(),
          );
      
      _commentController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm bình luận')),
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