// screens/shared/inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../models/course.dart';
import '../../providers/message_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/student_provider.dart';
import 'chat_screen.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ✅ CHANGED: Don't automatically load on init, data should already be loaded from login
    // Just check if we need to load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conversations = ref.read(conversationProvider);
      if (conversations.isEmpty) {
        _loadConversations();
      }
    });
  }

  Future<void> _loadConversations() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(authProvider);
      if (user == null) return;

      final isInstructor = user.role == UserRole.instructor;
      await ref.read(conversationProvider.notifier).loadConversations(
            user.id,
            isInstructor,
          );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final conversations = ref.watch(conversationProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    final isInstructor = user.role == UserRole.instructor;

    // Filter conversations by search query
    final filteredConversations = _searchQuery.isEmpty
        ? conversations
        : conversations.where((conv) {
            final searchLower = _searchQuery.toLowerCase();
            final otherPersonName = isInstructor
                ? conv.studentName.toLowerCase()
                : conv.instructorName.toLowerCase();
            return otherPersonName.contains(searchLower) ||
                (conv.lastMessageContent?.toLowerCase().contains(searchLower) ?? false);
          }).toList();

    // Calculate unread count
    final unreadCount = conversations.fold<int>(
      0,
      (sum, c) => sum + (isInstructor ? c.unreadCountInstructor : c.unreadCountStudent),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Tin nhắn'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tin nhắn mới',
            onPressed: () => _showNewMessageDialog(context, user, isInstructor),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
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
          ),

          // ✅ NEW: Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // Conversations list
          Expanded(
            child: filteredConversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.message, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Chưa có tin nhắn nào'
                              : 'Không tìm thấy kết quả',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Bắt đầu trò chuyện'),
                            onPressed: () => _showNewMessageDialog(context, user, isInstructor),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadConversations,
                    child: ListView.builder(
                      itemCount: filteredConversations.length,
                      itemBuilder: (context, index) {
                        final conversation = filteredConversations[index];
                        final unreadCount = isInstructor
                            ? conversation.unreadCountInstructor
                            : conversation.unreadCountStudent;
                        final otherPersonName = isInstructor
                            ? conversation.studentName
                            : conversation.instructorName;
                        final otherPersonId = isInstructor
                            ? conversation.studentId
                            : conversation.instructorId;

                        return _ConversationTile(
                          conversation: conversation,
                          otherPersonName: otherPersonName,
                          otherPersonId: otherPersonId,
                          unreadCount: unreadCount,
                          isInstructor: isInstructor,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => ChatScreen(
                                  conversation: conversation,
                                  otherPersonName: otherPersonName,
                                  otherPersonId: otherPersonId,
                                ),
                              ),
                            );
                            // ✅ CHANGED: Don't reload after returning from chat
                            // The chat screen already handles marking as read
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Show dialog to select who to message
  void _showNewMessageDialog(BuildContext context, AppUser user, bool isInstructor) {
    showDialog(
      context: context,
      builder: (ctx) => _NewMessageDialog(
        user: user,
        isInstructor: isInstructor,
        onSelected: (otherPerson) async {
          Navigator.pop(ctx);
          
          // Create or get conversation
          try {
            final conversation = await ref.read(conversationProvider.notifier).getOrCreateConversation(
                  instructorId: isInstructor ? user.id : otherPerson.id,
                  instructorName: isInstructor ? user.fullName : otherPerson.fullName,
                  studentId: isInstructor ? otherPerson.id : user.id,
                  studentName: isInstructor ? otherPerson.fullName : user.fullName,
                );

            // Navigate to chat
            if (mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => ChatScreen(
                    conversation: conversation,
                    otherPersonName: otherPerson.fullName,
                    otherPersonId: otherPerson.id,
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e')),
              );
            }
          }
        },
      ),
    );
  }
}

class _NewMessageDialog extends ConsumerWidget {
  final AppUser user;
  final bool isInstructor;
  final Function(AppUser) onSelected;

  const _NewMessageDialog({
    required this.user,
    required this.isInstructor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseProvider);
    final students = ref.watch(studentProvider);

    if (isInstructor) {
      // Instructor: show list of students
      return AlertDialog(
        title: const Text('Chọn học sinh'),
        content: SizedBox(
          width: double.maxFinite,
          child: students.isEmpty
              ? const Center(child: Text('Chưa có học sinh nào'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: students.length,
                  itemBuilder: (ctx, index) {
                    final student = students[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(student.fullName[0].toUpperCase()),
                      ),
                      title: Text(student.fullName),
                      subtitle: Text(student.email),
                      onTap: () => onSelected(student),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      );
    } else {
      // Student: show list of instructors from their courses
      final instructorIds = courses
          .where((c) => c.instructorId != null)
          .map((c) => c.instructorId!)
          .toSet();

      if (instructorIds.isEmpty) {
        return AlertDialog(
          title: const Text('Tin nhắn mới'),
          content: const Text('Bạn chưa có giảng viên nào'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      }

      // Get instructor info from courses
      final instructors = courses
          .where((c) => c.instructorId != null && c.instructorName != null)
          .map((c) => {
                'id': c.instructorId!,
                'name': c.instructorName!,
              })
          .toList();

      // Remove duplicates
      final uniqueInstructors = <String, String>{};
      for (final instructor in instructors) {
        uniqueInstructors[instructor['id']!] = instructor['name']!;
      }

      return AlertDialog(
        title: const Text('Chọn giảng viên'),
        content: SizedBox(
          width: double.maxFinite,
          child: uniqueInstructors.isEmpty
              ? const Center(child: Text('Chưa có giảng viên nào'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: uniqueInstructors.length,
                  itemBuilder: (ctx, index) {
                    final entry = uniqueInstructors.entries.elementAt(index);
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(entry.value[0].toUpperCase()),
                      ),
                      title: Text(entry.value),
                      onTap: () {
                        // Create a temporary AppUser object
                        final instructor = AppUser(
                          id: entry.key,
                          fullName: entry.value,
                          email: '',
                          role: UserRole.instructor,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        onSelected(instructor);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      );
    }
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String otherPersonName;
  final String otherPersonId;
  final int unreadCount;
  final bool isInstructor;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.otherPersonName,
    required this.otherPersonId,
    required this.unreadCount,
    required this.isInstructor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            child: Text(otherPersonName[0].toUpperCase()),
          ),
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        otherPersonName,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: conversation.lastMessageContent != null
          ? Text(
              conversation.lastMessageContent!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                color: hasUnread ? Colors.black87 : Colors.grey[600],
              ),
            )
          : null,
      trailing: conversation.lastMessageAt != null
          ? Text(
              _formatTime(conversation.lastMessageAt!),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread ? Colors.blue : Colors.grey[600],
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            )
          : null,
      onTap: onTap,
      tileColor: hasUnread ? Colors.blue.withOpacity(0.05) : null,
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Hôm qua';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}