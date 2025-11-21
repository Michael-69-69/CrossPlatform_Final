// providers/message_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/database_service.dart';

final conversationProvider = StateNotifierProvider<ConversationNotifier, List<Conversation>>((ref) {
  return ConversationNotifier();
});

final messageProvider = StateNotifierProvider<MessageNotifier, List<Message>>((ref) {
  return MessageNotifier();
});

class ConversationNotifier extends StateNotifier<List<Conversation>> {
  ConversationNotifier() : super([]);

  // Load conversations for a user (instructor or student)
  Future<void> loadConversations(String userId, bool isInstructor) async {
    try {
      print('📥 Loading conversations for userId: $userId (instructor: $isInstructor)');
      
      final filter = isInstructor
          ? {'instructorId': userId}
          : {'studentId': userId};

      final data = await DatabaseService.find(
        collection: 'conversations',
        filter: filter,
        sort: {'updatedAt': -1}, // Most recent first
      );

      state = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return Conversation.fromMap(map);
      }).toList();

      print('✅ Loaded ${state.length} conversations');
    } catch (e, stack) {
      print('❌ Error loading conversations: $e');
      print('Stack: $stack');
      state = [];
    }
  }

  // Get or create conversation between instructor and student
  Future<Conversation> getOrCreateConversation({
    required String instructorId,
    required String instructorName,
    required String studentId,
    required String studentName,
  }) async {
    try {
      // Check if conversation exists
      final existing = await DatabaseService.find(
        collection: 'conversations',
        filter: {
          'instructorId': instructorId,
          'studentId': studentId,
        },
      );

      if (existing.isNotEmpty) {
        return Conversation.fromMap(existing.first);
      }

      // Create new conversation
      final now = DateTime.now();
      final doc = <String, dynamic>{
        'instructorId': instructorId,
        'instructorName': instructorName,
        'studentId': studentId,
        'studentName': studentName,
        'unreadCountInstructor': 0,
        'unreadCountStudent': 0,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'conversations',
        document: doc,
      );

      final newConversation = Conversation(
        id: insertedId,
        instructorId: instructorId,
        instructorName: instructorName,
        studentId: studentId,
        studentName: studentName,
        createdAt: now,
        updatedAt: now,
      );

      state = [newConversation, ...state];

      print('✅ Created new conversation: $insertedId');
      return newConversation;
    } catch (e, stack) {
      print('❌ Error getting/creating conversation: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  // Update conversation after new message
  Future<void> updateConversation({
    required String conversationId,
    required String lastMessageContent,
    required bool incrementInstructorUnread,
    required bool incrementStudentUnread,
  }) async {
    try {
      final conversation = state.firstWhere((c) => c.id == conversationId);
      final now = DateTime.now();

      final update = <String, dynamic>{
        'lastMessageContent': lastMessageContent,
        'lastMessageAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      if (incrementInstructorUnread) {
        update['unreadCountInstructor'] = conversation.unreadCountInstructor + 1;
      }

      if (incrementStudentUnread) {
        update['unreadCountStudent'] = conversation.unreadCountStudent + 1;
      }

      await DatabaseService.updateOne(
        collection: 'conversations',
        id: conversationId,
        update: update,
      );

      // Update state
      state = state.map((c) {
        if (c.id == conversationId) {
          return Conversation(
            id: c.id,
            instructorId: c.instructorId,
            instructorName: c.instructorName,
            studentId: c.studentId,
            studentName: c.studentName,
            lastMessageContent: lastMessageContent,
            lastMessageAt: now,
            unreadCountInstructor: incrementInstructorUnread
                ? c.unreadCountInstructor + 1
                : c.unreadCountInstructor,
            unreadCountStudent: incrementStudentUnread
                ? c.unreadCountStudent + 1
                : c.unreadCountStudent,
            createdAt: c.createdAt,
            updatedAt: now,
          );
        }
        return c;
      }).toList();

      // Re-sort by updatedAt
      state.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      print('✅ Updated conversation: $conversationId');
    } catch (e, stack) {
      print('❌ Error updating conversation: $e');
      print('Stack: $stack');
    }
  }

  // Mark conversation as read
  Future<void> markAsRead(String conversationId, bool isInstructor) async {
    try {
      final update = isInstructor
          ? {'unreadCountInstructor': 0}
          : {'unreadCountStudent': 0};

      await DatabaseService.updateOne(
        collection: 'conversations',
        id: conversationId,
        update: update,
      );

      // Update state
      state = state.map((c) {
        if (c.id == conversationId) {
          return Conversation(
            id: c.id,
            instructorId: c.instructorId,
            instructorName: c.instructorName,
            studentId: c.studentId,
            studentName: c.studentName,
            lastMessageContent: c.lastMessageContent,
            lastMessageAt: c.lastMessageAt,
            unreadCountInstructor: isInstructor ? 0 : c.unreadCountInstructor,
            unreadCountStudent: isInstructor ? c.unreadCountStudent : 0,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          );
        }
        return c;
      }).toList();

      print('✅ Marked conversation as read: $conversationId');
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }
}

class MessageNotifier extends StateNotifier<List<Message>> {
  MessageNotifier() : super([]);

  // Load messages for a conversation
// Load messages for a conversation
Future<void> loadMessages(String conversationId) async {
  try {
    print('📥 Loading messages for conversation: $conversationId');

    // ✅ WORKAROUND: Get ALL messages and filter in memory
    final data = await DatabaseService.find(
      collection: 'messages',
      filter: {}, // Get all
      sort: {'createdAt': 1},
    );

    print('📦 Total messages fetched: ${data.length}');

    // ✅ FIX: Filter in memory with type checking
    final filteredData = data.where((msg) {
      final msgConvId = msg['conversationId'];
      
      // ✅ Handle both ObjectId and String by converting to string
      String convIdStr;
      if (msgConvId.runtimeType.toString().contains('ObjectId')) {
        // It's an ObjectId, extract the hex string
        // ObjectId has a toHexString() method or we can parse from toString()
        final objIdStr = msgConvId.toString();
        // Extract hex from format: ObjectId("hexstring")
        if (objIdStr.contains('"')) {
          convIdStr = objIdStr.split('"')[1];
        } else {
          convIdStr = msgConvId.toString();
        }
      } else {
        convIdStr = msgConvId.toString();
      }
      
      final match = convIdStr == conversationId;
      if (match) {
        print('  ✅ Match: $convIdStr == $conversationId');
      }
      return match;
    }).toList();

    print('📦 Filtered messages: ${filteredData.length}');

    state = filteredData.map((e) {
      final map = Map<String, dynamic>.from(e);
      return Message.fromMap(map);
    }).toList();

    print('✅ Loaded ${state.length} messages into state');
  } catch (e, stack) {
    print('❌ Error loading messages: $e');
    print('Stack: $stack');
    state = [];
  }
}

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required bool isInstructor,
    required String content,
    List<MessageAttachment> attachments = const [],
  }) async {
    try {
      final now = DateTime.now();

      final doc = <String, dynamic>{
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'isInstructor': isInstructor,
        'content': content,
        'attachments': attachments.map((a) {
          final map = a.toMap();
          return <String, dynamic>{
            'fileName': map['fileName'],
            if (map['fileUrl'] != null) 'fileUrl': map['fileUrl'],
            if (map['fileData'] != null) 'fileData': map['fileData'],
            if (map['fileSize'] != null) 'fileSize': map['fileSize'],
            if (map['mimeType'] != null) 'mimeType': map['mimeType'],
            'isLink': map['isLink'] ?? false,
          };
        }).toList(),
        'isRead': false,
        'createdAt': now.toIso8601String(),
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'messages',
        document: doc,
      );

      // Add to state
      state = [
        ...state,
        Message(
          id: insertedId,
          conversationId: conversationId,
          senderId: senderId,
          senderName: senderName,
          isInstructor: isInstructor,
          content: content,
          attachments: attachments,
          isRead: false,
          createdAt: now,
        ),
      ];

      print('✅ Sent message: $insertedId');
    } catch (e, stack) {
      print('❌ Error sending message: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      // Mark all unread messages from the other person as read
      for (var message in state) {
        if (message.conversationId == conversationId &&
            message.senderId != userId &&
            !message.isRead) {
          await DatabaseService.updateOne(
            collection: 'messages',
            id: message.id,
            update: {'isRead': true},
          );
        }
      }

      // Update local state
      state = state.map((m) {
        if (m.conversationId == conversationId &&
            m.senderId != userId &&
            !m.isRead) {
          return Message(
            id: m.id,
            conversationId: m.conversationId,
            senderId: m.senderId,
            senderName: m.senderName,
            isInstructor: m.isInstructor,
            content: m.content,
            attachments: m.attachments,
            isRead: true,
            createdAt: m.createdAt,
          );
        }
        return m;
      }).toList();

      print('✅ Marked messages as read in conversation: $conversationId');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }
}