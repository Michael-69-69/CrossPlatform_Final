// screens/shared/forum_thread_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/forum.dart';
import '../../models/user.dart';
import '../../providers/forum_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/file_download_helper.dart';

class ForumThreadScreen extends ConsumerStatefulWidget {
  final ForumTopic topic;
  final bool isInstructor;

  const ForumThreadScreen({
    super.key,
    required this.topic,
    required this.isInstructor,
  });

  @override
  ConsumerState<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends ConsumerState<ForumThreadScreen> {
  final _replyController = TextEditingController();
  String? _replyingToId;
  String? _replyingToAuthor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('🔵 ForumThreadScreen initialized for topic: ${widget.topic.id}');
    _loadReplies();
  }

  Future<void> _loadReplies() async {
    setState(() => _isLoading = true);
    try {
      print('📥 Loading replies for topic: ${widget.topic.id}');
      await ref.read(forumReplyProvider.notifier).loadReplies(widget.topic.id);
      final count = ref.read(forumReplyProvider).length;
      print('✅ Loaded $count replies');
    } catch (e) {
      print('❌ Error loading replies: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final replies = ref.watch(forumReplyProvider);
    final topics = ref.watch(forumTopicProvider);
    final topic = topics.firstWhere(
      (t) => t.id == widget.topic.id,
      orElse: () => widget.topic,
    );

    print('🔄 Building thread screen - replies count: ${replies.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thảo luận'),
        actions: [
          if (widget.isInstructor) ...[
            IconButton(
              icon: Icon(topic.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: topic.isPinned ? 'Bỏ ghim' : 'Ghim',
              onPressed: () {
                ref.read(forumTopicProvider.notifier).togglePin(topic.id);
              },
            ),
            IconButton(
              icon: Icon(topic.isClosed ? Icons.lock : Icons.lock_open),
              tooltip: topic.isClosed ? 'Mở lại' : 'Đóng',
              onPressed: () {
                ref.read(forumTopicProvider.notifier).toggleClose(topic.id);
              },
            ),
          ],
          if (user?.id == topic.authorId || widget.isInstructor)
            PopupMenuButton(
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xóa chủ đề'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteTopic();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Topic Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with badges
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
                        child: const Text(
                          'Đã ghim',
                          style: TextStyle(color: Colors.white, fontSize: 10),
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
                        child: const Text(
                          'Đã đóng',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Author info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      child: Text(topic.authorName[0]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                topic.authorName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (topic.isInstructor) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 14, color: Colors.blue),
                              ],
                            ],
                          ),
                          Text(
                            '${topic.createdAt.day}/${topic.createdAt.month}/${topic.createdAt.year} ${topic.createdAt.hour}:${topic.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${topic.replyCount} trả lời',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Content
                Text(topic.content),

                // Attachments
                if (topic.attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text(
                    'Tệp đính kèm:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...topic.attachments.map((attachment) {
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        attachment.isLink ? Icons.link : Icons.attach_file,
                        color: Colors.blue,
                      ),
                      title: Text(attachment.fileName),
                      subtitle: attachment.fileSize != null
                          ? Text('${(attachment.fileSize! / 1024).toStringAsFixed(1)} KB')
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _downloadFile(attachment),
                      ),
                    );
                  }),
                ],

                // Tags
                if (topic.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: topic.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Replies List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : replies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text('Chưa có trả lời nào'),
                            const SizedBox(height: 8),
                            if (!topic.isClosed)
                              const Text(
                                'Hãy là người đầu tiên trả lời!',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReplies,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: replies.length,
                          itemBuilder: (context, index) {
                            final reply = replies[index];
                            final isNested = reply.parentReplyId != null;

                            return Container(
                              margin: EdgeInsets.only(
                                bottom: 12,
                                left: isNested ? 32 : 0,
                              ),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Reply header
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            child: Text(reply.authorName[0]),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      reply.authorName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    if (reply.isInstructor) ...[
                                                      const SizedBox(width: 4),
                                                      const Icon(
                                                        Icons.verified,
                                                        size: 12,
                                                        color: Colors.blue,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                Text(
                                                  '${reply.createdAt.day}/${reply.createdAt.month} ${reply.createdAt.hour}:${reply.createdAt.minute.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (user?.id == reply.authorId || widget.isInstructor)
                                            PopupMenuButton(
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete, color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text('Xóa'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              onSelected: (value) {
                                                if (value == 'delete') {
                                                  _deleteReply(reply.id);
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Reply content
                                      Text(reply.content),

                                      // Attachments
                                      if (reply.attachments.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        ...reply.attachments.map((attachment) {
                                          return ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              attachment.isLink ? Icons.link : Icons.attach_file,
                                              size: 20,
                                              color: Colors.blue,
                                            ),
                                            title: Text(
                                              attachment.fileName,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.download, size: 20),
                                              onPressed: () => _downloadFile(attachment),
                                            ),
                                          );
                                        }),
                                      ],

                                      // Reply button
                                      if (!topic.isClosed)
                                        TextButton.icon(
                                          icon: const Icon(Icons.reply, size: 16),
                                          label: const Text('Trả lời'),
                                          onPressed: () {
                                            setState(() {
                                              _replyingToId = reply.id;
                                              _replyingToAuthor = reply.authorName;
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Reply Input
          if (!topic.isClosed)
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show who we're replying to
                  if (_replyingToId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.blue.withOpacity(0.1),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Đang trả lời $_replyingToAuthor',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setState(() {
                                _replyingToId = null;
                                _replyingToAuthor = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: const InputDecoration(
                            hintText: 'Viết trả lời...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => _sendReply(user),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: const Center(
                child: Text(
                  'Chủ đề này đã bị đóng',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendReply(AppUser? user) async {
    if (_replyController.text.trim().isEmpty || user == null) return;

    try {
      print('📤 Sending reply...');
      await ref.read(forumReplyProvider.notifier).addReply(
            topicId: widget.topic.id,
            content: _replyController.text.trim(),
            authorId: user.id,
            authorName: user.fullName,
            isInstructor: widget.isInstructor,
            parentReplyId: _replyingToId,
          );

      // Update topic reply count
      await ref.read(forumTopicProvider.notifier).incrementReplyCount(widget.topic.id);

      _replyController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToAuthor = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi trả lời')),
        );
      }
    } catch (e) {
      print('❌ Error sending reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteReply(String replyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa trả lời'),
        content: const Text('Bạn có chắc muốn xóa trả lời này?'),
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
        await ref.read(forumReplyProvider.notifier).deleteReply(replyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa trả lời')),
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

  Future<void> _deleteTopic() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa chủ đề'),
        content: const Text('Bạn có chắc muốn xóa chủ đề này? Tất cả các trả lời cũng sẽ bị xóa.'),
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
        await ref.read(forumTopicProvider.notifier).deleteTopic(widget.topic.id);
        if (mounted) {
          Navigator.of(context).pop(); // Go back to forum list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa chủ đề')),
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

  Future<void> _downloadFile(ForumAttachment attachment) async {
    try {
      if (attachment.isLink) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Link: ${attachment.fileUrl}')),
          );
        }
        return;
      }

      String result;
      if (attachment.fileData != null && attachment.fileData!.isNotEmpty) {
        final path = await FileDownloadHelper.downloadFromBase64(
          base64Data: attachment.fileData!,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } else if (attachment.fileUrl != null &&
          (attachment.fileUrl!.startsWith('http://') ||
              attachment.fileUrl!.startsWith('https://'))) {
        final path = await FileDownloadHelper.downloadFile(
          url: attachment.fileUrl!,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } else {
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
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}
