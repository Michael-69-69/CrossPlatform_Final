// screens/instructor/announcements_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/announcement.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';

class AnnouncementsTab extends ConsumerStatefulWidget {
  final String courseId;
  final List<Group> groups;
  final List<AppUser> students;

  const AnnouncementsTab({
    super.key,
    required this.courseId,
    required this.groups,
    required this.students,
  });

  @override
  ConsumerState<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends ConsumerState<AnnouncementsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(announcementProvider.notifier).loadAnnouncements(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementProvider);
    final user = ref.watch(authProvider);

    return Column(
      children: [
        // Create Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Tạo thông báo'),
            onPressed: () => _showCreateAnnouncementDialog(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        // Announcements List
        Expanded(
          child: announcements.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.announcement, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Chưa có thông báo nào'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(announcementProvider.notifier).loadAnnouncements(widget.courseId);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final announcement = announcements[index];
                      return _AnnouncementCard(
                        announcement: announcement,
                        groups: widget.groups,
                        onTap: () => _showAnnouncementDetail(context, announcement, user!),
                        onDelete: () => _deleteAnnouncement(announcement.id),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showCreateAnnouncementDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    AnnouncementScope selectedScope = AnnouncementScope.allGroups;
    final selectedGroupIds = <String>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Tạo thông báo'),
            content: SingleChildScrollView(
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
                      controller: contentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Phạm vi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<AnnouncementScope>(
                      title: const Text('Tất cả nhóm'),
                      value: AnnouncementScope.allGroups,
                      groupValue: selectedScope,
                      onChanged: (v) => setDialogState(() {
                        selectedScope = v!;
                        selectedGroupIds.clear();
                      }),
                    ),
                    RadioListTile<AnnouncementScope>(
                      title: const Text('Một nhóm'),
                      value: AnnouncementScope.oneGroup,
                      groupValue: selectedScope,
                      onChanged: (v) => setDialogState(() {
                        selectedScope = v!;
                        selectedGroupIds.clear();
                      }),
                    ),
                    RadioListTile<AnnouncementScope>(
                      title: const Text('Nhiều nhóm'),
                      value: AnnouncementScope.multipleGroups,
                      groupValue: selectedScope,
                      onChanged: (v) => setDialogState(() {
                        selectedScope = v!;
                      }),
                    ),
                    if (selectedScope != AnnouncementScope.allGroups) ...[
                      const SizedBox(height: 8),
                      ...widget.groups.map((group) {
                        final isSelected = selectedGroupIds.contains(group.id);
                        return CheckboxListTile(
                          title: Text(group.name),
                          value: isSelected,
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                if (selectedScope == AnnouncementScope.oneGroup) {
                                  selectedGroupIds.clear();
                                }
                                selectedGroupIds.add(group.id);
                              } else {
                                selectedGroupIds.remove(group.id);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ],
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
                  if (selectedScope != AnnouncementScope.allGroups && selectedGroupIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn ít nhất một nhóm')),
                    );
                    return;
                  }

                  final user = ref.read(authProvider);
                  if (user == null) return;

                  try {
                    // ✅ Get course info for email
                    final courses = ref.read(courseProvider);
                    final course = courses.firstWhere(
                      (c) => c.id == widget.courseId,
                      orElse: () => throw Exception('Course not found'),
                    );

                    // ✅ Get students who will receive this announcement
                    List<AppUser> recipientStudents;
                    if (selectedScope == AnnouncementScope.allGroups) {
                      recipientStudents = widget.students;
                    } else {
                      recipientStudents = widget.students.where((s) {
                        return widget.groups
                            .where((g) => selectedGroupIds.contains(g.id))
                            .any((g) => g.studentIds.contains(s.id));
                      }).toList();
                    }

                    // ✅ Create announcement with email notification
                    await ref.read(announcementProvider.notifier).createAnnouncement(
                      courseId: widget.courseId,
                      courseName: course.name, // ✅ ADD
                      title: titleCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                      scope: selectedScope,
                      groupIds: selectedGroupIds,
                      instructorId: user.id,
                      instructorName: user.fullName,
                      students: recipientStudents, // ✅ ADD
                    );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã tạo thông báo và gửi email đến ${recipientStudents.length} học sinh'
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                },
                child: const Text('Đăng'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAnnouncementDetail(BuildContext context, Announcement announcement, AppUser user) {
    ref.read(announcementProvider.notifier).markAsViewed(announcement.id, user.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AnnouncementDetailSheet(
        announcement: announcement,
        groups: widget.groups,
        currentUser: user,
        onComment: (content) {
          ref.read(announcementProvider.notifier).addComment(
            announcement.id,
            user.id,
            user.fullName,
            content,
          );
        },
      ),
    );
  }

  void _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thông báo'),
        content: const Text('Bạn có chắc muốn xóa thông báo này?'),
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
      await ref.read(announcementProvider.notifier).deleteAnnouncement(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa thông báo')),
        );
      }
    }
  }
}

// ... (keep all the existing _AnnouncementCard, _AnnouncementDetailSheet classes unchanged)
class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final List<Group> groups;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.groups,
    required this.onTap,
    required this.onDelete,
  });

  String _getScopeText() {
    switch (announcement.scope) {
      case AnnouncementScope.allGroups:
        return 'Tất cả nhóm';
      case AnnouncementScope.oneGroup:
        if (announcement.groupIds.isNotEmpty) {
          final group = groups.firstWhere(
            (g) => g.id == announcement.groupIds.first,
            orElse: () => Group(id: '', name: 'N/A', courseId: ''),
          );
          return group.name;
        }
        return 'Một nhóm';
      case AnnouncementScope.multipleGroups:
        return '${announcement.groupIds.length} nhóm';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      announcement.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                announcement.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(_getScopeText(), style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${announcement.viewedBy.length}', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${announcement.comments.length}', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Đăng bởi ${announcement.instructorName} • ${_formatDate(announcement.publishedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    }
    return 'Vừa xong';
  }
}

class _AnnouncementDetailSheet extends ConsumerStatefulWidget {
  final Announcement announcement;
  final List<Group> groups;
  final AppUser currentUser;
  final Function(String) onComment;

  const _AnnouncementDetailSheet({
    required this.announcement,
    required this.groups,
    required this.currentUser,
    required this.onComment,
  });

  @override
  ConsumerState<_AnnouncementDetailSheet> createState() => _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState extends ConsumerState<_AnnouncementDetailSheet> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcement = ref.watch(announcementProvider)
        .firstWhere((a) => a.id == widget.announcement.id, orElse: () => widget.announcement);

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
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      announcement.title,
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
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.content,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (announcement.attachments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Tệp đính kèm:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...announcement.attachments.map((attachment) {
                        return ListTile(
                          leading: const Icon(Icons.attachment),
                          title: Text(attachment.fileName),
                          subtitle: Text('${(attachment.fileSize / 1024).toStringAsFixed(1)} KB'),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              ref.read(announcementProvider.notifier).trackDownload(
                                announcement.id,
                                widget.currentUser.id,
                                attachment.fileName,
                              );
                            },
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Bình luận',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...announcement.comments.map((comment) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(comment.userName[0].toUpperCase()),
                          ),
                          title: Text(comment.userName),
                          subtitle: Text(comment.content),
                          trailing: Text(
                            _formatDate(comment.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Viết bình luận...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            if (_commentController.text.trim().isNotEmpty) {
                              widget.onComment(_commentController.text.trim());
                              _commentController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (widget.currentUser.role.toString().contains('instructor')) ...[
                      const Divider(),
                      const Text(
                        'Thống kê',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Đã xem: ${announcement.viewedBy.length} người'),
                      Text('Đã tải: ${announcement.downloadTracking.length} lượt'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    }
    return 'Vừa xong';
  }
}