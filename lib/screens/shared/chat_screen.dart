// screens/shared/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../providers/message_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/file_download_helper.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  final String otherPersonName;
  final String otherPersonId;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.otherPersonName,
    required this.otherPersonId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(messageProvider.notifier).loadMessages(widget.conversation.id);

      // Mark conversation as read
      final user = ref.read(authProvider);
      if (user != null) {
        final isInstructor = user.role == UserRole.instructor;
        await ref.read(conversationProvider.notifier).markAsRead(
              widget.conversation.id,
              isInstructor,
            );

        // Mark messages as read
        await ref.read(messageProvider.notifier).markMessagesAsRead(
              widget.conversation.id,
              user.id,
            );
      }

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      print('Error loading messages: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final allMessages = ref.watch(messageProvider);
    
    // ✅ FIX: Filter messages for THIS conversation only
    final messages = allMessages
        .where((m) => m.conversationId == widget.conversation.id)
        .toList();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    final isInstructor = user.role == UserRole.instructor;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(widget.otherPersonName[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherPersonName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    isInstructor ? 'Học sinh' : 'Giảng viên',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text('Chưa có tin nhắn nào'),
                            const SizedBox(height: 8),
                            const Text(
                              'Gửi tin nhắn đầu tiên!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == user.id;
                          final showSender = index == 0 ||
                              messages[index - 1].senderId != message.senderId;

                          return _MessageBubble(
                            message: message,
                            isMe: isMe,
                            showSender: showSender,
                            onDownload: _downloadFile,
                          );
                        },
                      ),
          ),

          // Message input
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
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(user, isInstructor),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(user, isInstructor),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(AppUser user, bool isInstructor) async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    try {
      // Send message
      await ref.read(messageProvider.notifier).sendMessage(
            conversationId: widget.conversation.id,
            senderId: user.id,
            senderName: user.fullName,
            isInstructor: isInstructor,
            content: content,
          );

      // Update conversation
      await ref.read(conversationProvider.notifier).updateConversation(
            conversationId: widget.conversation.id,
            lastMessageContent: content,
            incrementInstructorUnread: !isInstructor, // If student sends, instructor has unread
            incrementStudentUnread: isInstructor, // If instructor sends, student has unread
          );

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(MessageAttachment attachment) async {
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

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showSender;
  final Function(MessageAttachment) onDownload;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && showSender)
            CircleAvatar(
              radius: 16,
              child: Text(message.senderName[0].toUpperCase()),
            ),
          if (!isMe && showSender) const SizedBox(width: 8),
          if (!isMe && !showSender) const SizedBox(width: 40),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name (if not me and showSender)
                  if (!isMe && showSender) ...[
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Message content
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),

                  // Attachments
                  if (message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...message.attachments.map((attachment) {
                      return InkWell(
                        onTap: () => onDownload(attachment),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                attachment.isLink ? Icons.link : Icons.attach_file,
                                size: 16,
                                color: isMe ? Colors.white : Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  attachment.fileName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe ? Colors.white : Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  // Timestamp
                  const SizedBox(height: 4),
                  Text(
                    '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}