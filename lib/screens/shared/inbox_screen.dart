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

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final isInstructor = user.role == UserRole.instructor;
    await ref.read(conversationProvider.notifier).loadConversations(
          user.id,
          isInstructor,
        );
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
        title: const Text('Tin nhắn'),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
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
              ),
            ),
        ],
      ),
      // ✅ ADD: Floating action button to start new conversation
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageDialog(context, user, isInstructor),
        child: const Icon(Icons.message),
        tooltip: 'Tin nhắn mới',
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
                            _loadConversations();
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
            _loadConversations();
          }
        },
      ),
    );
  }
}

// ✅ NEW: Dialog to select who to message
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

    // For instructors: show all students
    // For students: show instructors of their enrolled courses
    final List<AppUser> availablePeople = isInstructor
        ? students // Show all students
        : _getInstructorsFromCourses(courses, user.id);

    return AlertDialog(
      title: Text(isInstructor ? 'Chọn học sinh' : 'Chọn giảng viên'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: availablePeople.isEmpty
            ? Center(
                child: Text(
                  isInstructor
                      ? 'Chưa có học sinh nào'
                      : 'Bạn chưa tham gia khóa học nào',
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: availablePeople.length,
                itemBuilder: (context, index) {
                  final person = availablePeople[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(person.fullName[0].toUpperCase()),
                    ),
                    title: Text(person.fullName),
                    subtitle: Text(
                      isInstructor
                          ? (person.code ?? person.email)
                          : _getInstructorCourses(courses, person.id),
                    ),
                    onTap: () => onSelected(person),
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

  // Get unique instructors from courses the student is enrolled in
  List<AppUser> _getInstructorsFromCourses(List<Course> courses, String studentId) {
    final instructorMap = <String, AppUser>{};
    
    // Find courses where student is enrolled (via groups)
    // For simplicity, get all instructors from available courses
    // In real app, filter by student's enrolled courses
    for (final course in courses) {
      instructorMap[course.instructorId] = AppUser(
        id: course.instructorId,
        fullName: course.instructorName,
        email: '',
        role: UserRole.instructor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    return instructorMap.values.toList();
  }

  String _getInstructorCourses(List<Course> courses, String instructorId) {
    final instructorCourses = courses
        .where((c) => c.instructorId == instructorId)
        .map((c) => c.name)
        .take(2)
        .join(', ');
    return instructorCourses.isEmpty ? 'Giảng viên' : instructorCourses;
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

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            child: Text(
              otherPersonName[0].toUpperCase(),
              style: const TextStyle(fontSize: 18),
            ),
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
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherPersonName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (conversation.lastMessageAt != null)
            Text(
              _formatTimestamp(conversation.lastMessageAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
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
      onTap: onTap,
      tileColor: hasUnread ? Colors.blue.withOpacity(0.05) : null,
    );
  }
}