// providers/message_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';

final conversationProvider = StateNotifierProvider<ConversationNotifier, List<Conversation>>((ref) {
  return ConversationNotifier();
});

final messageProvider = StateNotifierProvider<MessageNotifier, List<Message>>((ref) {
  return MessageNotifier();
});

class ConversationNotifier extends StateNotifier<List<Conversation>> {
  ConversationNotifier() : super([]);

  // ✅ Helper: Convert ObjectIds to strings recursively
  Map<String, dynamic> _convertObjectIds(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIds(item);
          } else if (item is Map) {
            return _convertObjectIds(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIds(value);
      } else if (value is Map) {
        result[key] = _convertObjectIds(Map<String, dynamic>.from(value));
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  // Load conversations for a user (instructor or student)
  Future<void> loadConversations(String userId, bool isInstructor) async {
    try {
      print('📥 Loading conversations for userId: $userId (instructor: $isInstructor)');
      
      // ✅ 1. Try to load from cache first
      final cacheKey = 'conversations_$userId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Conversation.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} conversations from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshConversationsInBackground(userId, isInstructor, cacheKey);
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for conversations');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database
      final filter = isInstructor
          ? {'instructorId': userId}
          : {'studentId': userId};

      final data = await DatabaseService.find(
        collection: 'conversations',
        filter: filter,
        sort: {'updatedAt': -1},
      );

      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Conversation.fromMap(map);
      }).toList();

      // ✅ 4. Save to cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );

      print('✅ Loaded ${state.length} conversations');
    } catch (e, stack) {
      print('❌ Error loading conversations: $e');
      print('Stack: $stack');
      
      // ✅ 5. Fallback to cache on error
      final cacheKey = 'conversations_$userId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Conversation.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} conversations from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh
  Future<void> _refreshConversationsInBackground(String userId, bool isInstructor, String cacheKey) async {
    try {
      final filter = isInstructor
          ? {'instructorId': userId}
          : {'studentId': userId};

      final data = await DatabaseService.find(
        collection: 'conversations',
        filter: filter,
        sort: {'updatedAt': -1},
      );

      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Conversation.fromMap(map);
      }).toList();

      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );

      print('🔄 Background refresh: conversations updated');
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  // Get or create conversation between instructor and student
  Future<Conversation> getOrCreateConversation({
    required String instructorId,
    required String instructorName,
    required String studentId,
    required String studentName,
  }) async {
    // ✅ Check if online before creating
    if (NetworkService().isOffline) {
      // Try to find in current state first
      final existing = state.where((c) => 
        c.instructorId == instructorId && c.studentId == studentId
      ).toList();
      
      if (existing.isNotEmpty) {
        return existing.first;
      }
      
      throw Exception('Không thể tạo cuộc hội thoại khi offline');
    }
    
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
        return Conversation.fromMap(_convertObjectIds(Map<String, dynamic>.from(existing.first)));
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

      // ✅ Clear cache after creating
      await CacheService.clearCache('conversations_$instructorId');
      await CacheService.clearCache('conversations_$studentId');

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

      // ✅ Clear cache after updating
      await CacheService.clearCache('conversations_${conversation.instructorId}');
      await CacheService.clearCache('conversations_${conversation.studentId}');

      print('✅ Updated conversation: $conversationId');
    } catch (e, stack) {
      print('❌ Error updating conversation: $e');
      print('Stack: $stack');
    }
  }

  // Mark conversation as read
  Future<void> markAsRead(String conversationId, bool isInstructor) async {
    try {
      final conversation = state.firstWhere((c) => c.id == conversationId);
      
      // ✅ Only update server if online
      if (NetworkService().isOnline) {
        final update = isInstructor
            ? {'unreadCountInstructor': 0}
            : {'unreadCountStudent': 0};

        await DatabaseService.updateOne(
          collection: 'conversations',
          id: conversationId,
          update: update,
        );
      }

      // Update state (always update local state)
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

      // ✅ Clear cache after updating
      await CacheService.clearCache('conversations_${conversation.instructorId}');
      await CacheService.clearCache('conversations_${conversation.studentId}');

      print('✅ Marked conversation as read: $conversationId');
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }
  
  // ✅ Force refresh from database
  Future<void> forceRefresh(String userId, bool isInstructor) async {
    await CacheService.clearCache('conversations_$userId');
    await loadConversations(userId, isInstructor);
  }
}

class MessageNotifier extends StateNotifier<List<Message>> {
  MessageNotifier() : super([]);

  // ✅ Helper: Convert ObjectIds to strings recursively
  Map<String, dynamic> _convertObjectIds(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIds(item);
          } else if (item is Map) {
            return _convertObjectIds(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIds(value);
      } else if (value is Map) {
        result[key] = _convertObjectIds(Map<String, dynamic>.from(value));
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  // ✅ Helper: Extract ObjectId string properly
  String _extractObjectIdString(dynamic value) {
    if (value == null) return '';
    
    if (value is ObjectId) {
      return value.toHexString();
    }
    
    final valueStr = value.toString();
    
    // Check if it's in ObjectId("...") format
    if (valueStr.startsWith('ObjectId(')) {
      final regex = RegExp(r'ObjectId\("?([a-fA-F0-9]{24})"?\)');
      final match = regex.firstMatch(valueStr);
      if (match != null) {
        return match.group(1)!;
      }
    }
    
    // Check if it contains quotes (older format)
    if (valueStr.contains('"')) {
      final parts = valueStr.split('"');
      if (parts.length >= 2) {
        return parts[1];
      }
    }
    
    // Return as-is if it looks like a valid hex string
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(valueStr)) {
      return valueStr;
    }
    
    return valueStr;
  }

  // Load messages for a conversation
  Future<void> loadMessages(String conversationId) async {
    try {
      print('📥 Loading messages for conversation: $conversationId');

      // ✅ 1. Try to load from cache first
      final cacheKey = 'messages_$conversationId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Message.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} messages from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshMessagesInBackground(conversationId, cacheKey);
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for messages');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database - WORKAROUND: Get ALL messages and filter in memory
      final data = await DatabaseService.find(
        collection: 'messages',
        filter: {},
        sort: {'createdAt': 1},
      );

      print('📦 Total messages fetched: ${data.length}');

      // ✅ Filter in memory with improved type checking
      final filteredData = data.where((msg) {
        final msgConvId = msg['conversationId'];
        final convIdStr = _extractObjectIdString(msgConvId);
        final match = convIdStr == conversationId;
        return match;
      }).toList();

      print('📦 Filtered messages: ${filteredData.length}');

      state = filteredData.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Message.fromMap(map);
      }).toList();

      // ✅ 4. Save to cache
      final cacheData = filteredData.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60,
      );

      print('✅ Loaded ${state.length} messages into state');
    } catch (e, stack) {
      print('❌ Error loading messages: $e');
      print('Stack: $stack');
      
      // ✅ 5. Fallback to cache on error
      final cacheKey = 'messages_$conversationId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return Message.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} messages from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh
  Future<void> _refreshMessagesInBackground(String conversationId, String cacheKey) async {
    try {
      final data = await DatabaseService.find(
        collection: 'messages',
        filter: {},
        sort: {'createdAt': 1},
      );

      final filteredData = data.where((msg) {
        final msgConvId = msg['conversationId'];
        final convIdStr = _extractObjectIdString(msgConvId);
        return convIdStr == conversationId;
      }).toList();

      state = filteredData.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return Message.fromMap(map);
      }).toList();

      final cacheData = filteredData.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60,
      );

      print('🔄 Background refresh: messages updated');
    } catch (e) {
      print('Background refresh failed: $e');
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
    // ✅ Check if online before sending
    if (NetworkService().isOffline) {
      throw Exception('Không thể gửi tin nhắn khi offline');
    }
    
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

      // ✅ Clear cache after sending
      await CacheService.clearCache('messages_$conversationId');

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
      // ✅ Only update server if online
      if (NetworkService().isOnline) {
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
      }

      // Update local state (always)
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

      // ✅ Clear cache after updating
      await CacheService.clearCache('messages_$conversationId');

      print('✅ Marked messages as read in conversation: $conversationId');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }
  
  // ✅ Force refresh from database
  Future<void> forceRefresh(String conversationId) async {
    await CacheService.clearCache('messages_$conversationId');
    await loadMessages(conversationId);
  }
}