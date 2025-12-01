// screens/student/tabs/student_stream_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/announcement.dart';
import '../../../../models/group.dart';
import '../../../../providers/announcement_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../student_announcement_detail.dart';
import '../../../main.dart'; // for localeProvider

class StudentStreamTab extends ConsumerStatefulWidget {
  final String courseId;
  final List<Group> groups;
  final bool isPastSemester;

  const StudentStreamTab({
    super.key,
    required this.courseId,
    required this.groups,
    required this.isPastSemester,
  });

  @override
  ConsumerState<StudentStreamTab> createState() => _StudentStreamTabState();
}

class _StudentStreamTabState extends ConsumerState<StudentStreamTab> {
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
    final user = ref.watch(authProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
    final announcements = ref.watch(announcementProvider)
        .where((a) => a.courseId == widget.courseId)
        .toList();

    // Filter announcements for student's groups
    final studentGroupIds = widget.groups
        .where((g) => g.studentIds.contains(user?.id ?? ''))
        .map((g) => g.id)
        .toSet();

    final visibleAnnouncements = announcements.where((a) {
      if (a.scope == AnnouncementScope.allGroups) return true;
      return a.groupIds.any((gid) => studentGroupIds.contains(gid));
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(announcementProvider.notifier).loadAnnouncements(widget.courseId);
      },
      child: visibleAnnouncements.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.announcement, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    isVietnamese ? 'Chưa có thông báo nào' : 'No announcements yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleAnnouncements.length,
              itemBuilder: (context, index) {
                final announcement = visibleAnnouncements[index];
                final hasViewed = announcement.viewedBy.contains(user?.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentAnnouncementDetail(
                            announcement: announcement,
                            isPastSemester: widget.isPastSemester,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Text(announcement.instructorName[0]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      announcement.instructorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _formatDate(announcement.publishedAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!hasViewed)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            announcement.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            announcement.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (announcement.attachments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.attach_file, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  isVietnamese
                                      ? '${announcement.attachments.length} tệp đính kèm'
                                      : '${announcement.attachments.length} attachments',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                          if (announcement.comments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  isVietnamese
                                      ? '${announcement.comments.length} bình luận'
                                      : '${announcement.comments.length} comments',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final isVietnamese = _isVietnamese();

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return isVietnamese ? '${diff.inMinutes} phút trước' : '${diff.inMinutes}m ago';
      }
      return isVietnamese ? '${diff.inHours} giờ trước' : '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return isVietnamese ? '${diff.inDays} ngày trước' : '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}