// screens/shared/forum_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/forum.dart';
import '../../models/user.dart';
import '../../providers/forum_provider.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart'; // for localeProvider
import 'forum_thread_screen.dart';

class ForumListWidget extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  final bool isInstructor;

  const ForumListWidget({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.isInstructor,
  });

  @override
  ConsumerState<ForumListWidget> createState() => _ForumListWidgetState();
}

class _ForumListWidgetState extends ConsumerState<ForumListWidget> {
  String _searchQuery = '';
  String _sortBy = 'recent'; // recent, oldest, replies

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(forumTopicProvider.notifier).loadTopics(widget.courseId);
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
    var topics = ref.watch(forumTopicProvider);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      topics = ref.read(forumTopicProvider.notifier).searchTopics(_searchQuery);
    }

    // Apply sorting
    final sortedTopics = _sortTopics(topics);

    return Column(
      children: [
        // Create Topic Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(isVietnamese ? 'Tạo chủ đề mới' : 'Create new topic'),
            onPressed: () => _showCreateTopicDialog(context, user),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: isVietnamese ? 'Tìm kiếm chủ đề...' : 'Search topics...',
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
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onSelected: (value) => setState(() => _sortBy = value),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'recent',
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: _sortBy == 'recent' ? Colors.blue : null,
                        ),
                        const SizedBox(width: 8),
                        Text(isVietnamese ? 'Mới nhất' : 'Most recent'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'oldest',
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: _sortBy == 'oldest' ? Colors.blue : null,
                        ),
                        const SizedBox(width: 8),
                        Text(isVietnamese ? 'Cũ nhất' : 'Oldest'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'replies',
                    child: Row(
                      children: [
                        Icon(
                          Icons.forum,
                          color: _sortBy == 'replies' ? Colors.blue : null,
                        ),
                        const SizedBox(width: 8),
                        Text(isVietnamese ? 'Nhiều trả lời nhất' : 'Most replies'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Topics List
        Expanded(
          child: sortedTopics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? (isVietnamese ? 'Chưa có chủ đề nào' : 'No topics yet')
                            : (isVietnamese ? 'Không tìm thấy chủ đề phù hợp' : 'No matching topics found'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(forumTopicProvider.notifier).loadTopics(widget.courseId),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedTopics.length,
                    itemBuilder: (context, index) {
                      final topic = sortedTopics[index];
                      return _TopicCard(
                        topic: topic,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => ForumThreadScreen(
                                topic: topic,
                                isInstructor: widget.isInstructor,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  List<ForumTopic> _sortTopics(List<ForumTopic> topics) {
    final sorted = List<ForumTopic>.from(topics);
    
    switch (_sortBy) {
      case 'oldest':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'replies':
        sorted.sort((a, b) => b.replyCount.compareTo(a.replyCount));
        break;
      case 'recent':
      default:
        // Already sorted by pinned + lastReplyAt + createdAt in provider
        break;
    }
    
    return sorted;
  }

  void _showCreateTopicDialog(BuildContext context, AppUser? user) {
    if (user == null) return;
    final isVietnamese = _isVietnamese();

    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVietnamese ? 'Tạo chủ đề mới' : 'Create new topic'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: isVietnamese ? 'Tiêu đề *' : 'Title *',
                    hintText: isVietnamese ? 'Nhập tiêu đề chủ đề' : 'Enter topic title',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: contentCtrl,
                  decoration: InputDecoration(
                    labelText: isVietnamese ? 'Nội dung *' : 'Content *',
                    hintText: isVietnamese ? 'Nhập nội dung thảo luận' : 'Enter discussion content',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (v) => v?.trim().isEmpty == true ? (isVietnamese ? 'Bắt buộc' : 'Required') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: tagsCtrl,
                  decoration: InputDecoration(
                    labelText: isVietnamese ? 'Thẻ (tùy chọn)' : 'Tags (optional)',
                    hintText: isVietnamese ? 'Nhập các thẻ, phân cách bằng dấu phẩy' : 'Enter tags, separated by commas',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVietnamese ? 'Ví dụ: bài tập, câu hỏi, thảo luận' : 'Example: assignment, question, discussion',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
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

              final tags = tagsCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              try {
                await ref.read(forumTopicProvider.notifier).createTopic(
                      courseId: widget.courseId,
                      title: titleCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                      authorId: user.id,
                      authorName: user.fullName,
                      isInstructor: widget.isInstructor,
                      tags: tags,
                    );

                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isVietnamese ? 'Đã tạo chủ đề mới' : 'Topic created')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
                  );
                }
              }
            },
            child: Text(isVietnamese ? 'Tạo' : 'Create'),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends ConsumerWidget {
  final ForumTopic topic;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges + Title
              Row(
                children: [
                  if (topic.isPinned)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isVietnamese ? 'Đã ghim' : 'Pinned',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  if (topic.isClosed)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isVietnamese ? 'Đã đóng' : 'Closed',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Content preview
              Text(
                topic.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),

              const SizedBox(height: 12),

              // Tags
              if (topic.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: topic.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 12),

              // Footer: Author + Stats
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text(
                      topic.authorName[0],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          topic.authorName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (topic.isInstructor) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 12, color: Colors.blue),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.forum, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${topic.replyCount}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  if (topic.attachments.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${topic.attachments.length}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
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