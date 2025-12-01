// screens/instructor/announcements_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/announcement.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../main.dart'; // for localeProvider

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

  // Helper method to check if Vietnamese
  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementProvider);
    final user = ref.watch(authProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Column(
      children: [
        // Create Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(isVietnamese ? 'Tạo thông báo' : 'Create announcement'),
            onPressed: () => _showCreateAnnouncementDialog(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        // Announcements List
        Expanded(
          child: announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.announcement, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(isVietnamese ? 'Chưa có thông báo nào' : 'No announcements yet'),
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
    final isVietnamese = _isVietnamese();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(isVietnamese ? 'Tạo thông báo' : 'Create announcement'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: isVietnamese ? 'Tiêu đề *' : 'Title *',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: contentCtrl,
                      decoration: InputDecoration(
                        labelText: isVietnamese ? 'Nội dung *' : 'Content *',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                    ),
                    const SizedBox(height: 16),
                    Text(isVietnamese ? 'Phạm vi:' : 'Scope:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<AnnouncementScope>(
                      title: Text(isVietnamese ? 'Tất cả nhóm' : 'All groups'),
                      value: AnnouncementScope.allGroups,
                      groupValue: selectedScope,
                      onChanged: (v) => setDialogState(() {
                        selectedScope = v!;
                        selectedGroupIds.clear();
                      }),
                    ),
                    RadioListTile<AnnouncementScope>(
                      title: Text(isVietnamese ? 'Một nhóm' : 'One group'),
                      value: AnnouncementScope.oneGroup,
                      groupValue: selectedScope,
                      onChanged: (v) => setDialogState(() {
                        selectedScope = v!;
                        selectedGroupIds.clear();
                      }),
                    ),
                    RadioListTile<AnnouncementScope>(
                      title: Text(isVietnamese ? 'Nhiều nhóm' : 'Multiple groups'),
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
                child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (selectedScope != AnnouncementScope.allGroups && selectedGroupIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isVietnamese ? 'Vui lòng chọn ít nhất một nhóm' : 'Please select at least one group')),
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
                          isVietnamese
                              ? 'Đã tạo thông báo và gửi email đến ${recipientStudents.length} học sinh'
                              : 'Created announcement and sent email to ${recipientStudents.length} students'
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
                    );
                  }
                },
                child: Text(isVietnamese ? 'Đăng' : 'Post'),
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
    final isVietnamese = _isVietnamese();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVietnamese ? 'Xóa thông báo' : 'Delete announcement'),
        content: Text(isVietnamese ? 'Bạn có chắc muốn xóa thông báo này?' : 'Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isVietnamese ? 'Xóa' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(announcementProvider.notifier).deleteAnnouncement(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVietnamese ? 'Đã xóa thông báo' : 'Announcement deleted')),
        );
      }
    }
  }
}

class _AnnouncementCard extends ConsumerWidget {
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

  String _getScopeText(bool isVietnamese) {
    switch (announcement.scope) {
      case AnnouncementScope.allGroups:
        return isVietnamese ? 'Tất cả nhóm' : 'All groups';
      case AnnouncementScope.oneGroup:
        if (announcement.groupIds.isNotEmpty) {
          final group = groups.firstWhere(
            (g) => g.id == announcement.groupIds.first,
            orElse: () => Group(id: '', name: 'N/A', courseId: ''),
          );
          return group.name;
        }
        return isVietnamese ? 'Một nhóm' : 'One group';
      case AnnouncementScope.multipleGroups:
        return isVietnamese ? '${announcement.groupIds.length} nhóm' : '${announcement.groupIds.length} groups';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

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
                  Text(_getScopeText(isVietnamese), style: TextStyle(color: Colors.grey[600])),
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
                isVietnamese
                    ? 'Đăng bởi ${announcement.instructorName} • ${_formatDate(announcement.publishedAt, isVietnamese)}'
                    : 'Posted by ${announcement.instructorName} • ${_formatDate(announcement.publishedAt, isVietnamese)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, bool isVietnamese) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return isVietnamese ? '${diff.inDays} ngày trước' : '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return isVietnamese ? '${diff.inHours} giờ trước' : '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return isVietnamese ? '${diff.inMinutes} phút trước' : '${diff.inMinutes}m ago';
    }
    return isVietnamese ? 'Vừa xong' : 'Just now';
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
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

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
                      Text(
                        isVietnamese ? 'Tệp đính kèm:' : 'Attachments:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                    Text(
                      isVietnamese ? 'Bình luận' : 'Comments',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            _formatDate(comment.createdAt, isVietnamese),
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
                            decoration: InputDecoration(
                              hintText: isVietnamese ? 'Viết bình luận...' : 'Write a comment...',
                              border: const OutlineInputBorder(),
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
                      Text(
                        isVietnamese ? 'Thống kê' : 'Statistics',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(isVietnamese
                          ? 'Đã xem: ${announcement.viewedBy.length} người'
                          : 'Viewed by: ${announcement.viewedBy.length} people'),
                      Text(isVietnamese
                          ? 'Đã tải: ${announcement.downloadTracking.length} lượt'
                          : 'Downloaded: ${announcement.downloadTracking.length} times'),
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

  String _formatDate(DateTime date, bool isVietnamese) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return isVietnamese ? '${diff.inDays} ngày trước' : '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return isVietnamese ? '${diff.inHours} giờ trước' : '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return isVietnamese ? '${diff.inMinutes} phút trước' : '${diff.inMinutes}m ago';
    }
    return isVietnamese ? 'Vừa xong' : 'Just now';
  }
}