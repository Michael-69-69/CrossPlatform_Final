// providers/forum_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum.dart';
import '../services/database_service.dart';

final forumTopicProvider = StateNotifierProvider<ForumTopicNotifier, List<ForumTopic>>((ref) {
  return ForumTopicNotifier();
});

final forumReplyProvider = StateNotifierProvider<ForumReplyNotifier, List<ForumReply>>((ref) {
  return ForumReplyNotifier();
});

class ForumTopicNotifier extends StateNotifier<List<ForumTopic>> {
  ForumTopicNotifier() : super([]);

  // Load all topics for a course
  Future<void> loadTopics(String courseId) async {
    try {
      // ✅ FIX: Load without sorting from DB, sort in memory instead
      final data = await DatabaseService.find(
        collection: 'forum_topics',
        filter: {'courseId': courseId},
        sort: {'createdAt': -1}, // ✅ Only sort by createdAt (always exists)
      );
      
      final topics = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return ForumTopic.fromMap(map);
      }).toList();

      // ✅ Sort in memory: pinned first, then by lastReplyAt or createdAt
      topics.sort((a, b) {
        // Pinned topics always come first
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;

        // If both pinned or both not pinned, sort by lastReplyAt or createdAt
        final aTime = a.lastReplyAt ?? a.createdAt;
        final bTime = b.lastReplyAt ?? b.createdAt;
        return bTime.compareTo(aTime); // Most recent first
      });
      
      state = topics;
      
      print('✅ Loaded ${state.length} forum topics');
    } catch (e, stack) {
      print('❌ Error loading forum topics: $e');
      print('Stack: $stack');
      state = [];
    }
  }

  // Search topics
  List<ForumTopic> searchTopics(String query) {
    if (query.isEmpty) return state;
    
    final lowerQuery = query.toLowerCase();
    return state.where((topic) {
      return topic.title.toLowerCase().contains(lowerQuery) ||
             topic.content.toLowerCase().contains(lowerQuery) ||
             topic.authorName.toLowerCase().contains(lowerQuery) ||
             topic.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Create new topic (anyone can create)
  Future<void> createTopic({
    required String courseId,
    required String title,
    required String content,
    required String authorId,
    required String authorName,
    required bool isInstructor,
    List<ForumAttachment> attachments = const [],
    List<String> tags = const [],
  }) async {
    try {
      final now = DateTime.now();

      final doc = <String, dynamic>{
        'courseId': courseId,
        'title': title,
        'content': content,
        'authorId': authorId,
        'authorName': authorName,
        'isInstructor': isInstructor,
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
        'tags': tags,
        'isPinned': false,
        'isClosed': false,
        'replyCount': 0,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'forum_topics',
        document: doc,
      );

      // Add to state
      final newTopic = ForumTopic(
        id: insertedId,
        courseId: courseId,
        title: title,
        content: content,
        authorId: authorId,
        authorName: authorName,
        isInstructor: isInstructor,
        attachments: attachments,
        tags: tags,
        createdAt: now,
        updatedAt: now,
      );

      state = [newTopic, ...state];

      print('✅ Created forum topic: $insertedId');
    } catch (e, stack) {
      print('❌ Error creating forum topic: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  // ✅ NEW: Edit topic
  Future<void> editTopic({
    required String topicId,
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    try {
      final now = DateTime.now();
      
      await DatabaseService.updateOne(
        collection: 'forum_topics',
        id: topicId,
        update: {
          'title': title,
          'content': content,
          'tags': tags,
          'updatedAt': now.toIso8601String(),
        },
      );

      // Update state
      state = state.map((t) {
        if (t.id == topicId) {
          return ForumTopic(
            id: t.id,
            courseId: t.courseId,
            title: title,
            content: content,
            authorId: t.authorId,
            authorName: t.authorName,
            isInstructor: t.isInstructor,
            attachments: t.attachments,
            tags: tags,
            isPinned: t.isPinned,
            isClosed: t.isClosed,
            replyCount: t.replyCount,
            createdAt: t.createdAt,
            updatedAt: now,
            lastReplyAt: t.lastReplyAt,
          );
        }
        return t;
      }).toList();

      print('✅ Edited topic: $topicId');
    } catch (e) {
      print('❌ Error editing topic: $e');
      rethrow;
    }
  }

  // Pin/Unpin topic (instructor only)
  Future<void> togglePin(String topicId) async {
    try {
      final topic = state.firstWhere((t) => t.id == topicId);
      
      await DatabaseService.updateOne(
        collection: 'forum_topics',
        id: topicId,
        update: {
          'isPinned': !topic.isPinned,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      // Update state and re-sort
      state = state.map((t) {
        if (t.id == topicId) {
          return ForumTopic(
            id: t.id,
            courseId: t.courseId,
            title: t.title,
            content: t.content,
            authorId: t.authorId,
            authorName: t.authorName,
            isInstructor: t.isInstructor,
            attachments: t.attachments,
            tags: t.tags,
            isPinned: !t.isPinned,
            isClosed: t.isClosed,
            replyCount: t.replyCount,
            createdAt: t.createdAt,
            updatedAt: DateTime.now(),
            lastReplyAt: t.lastReplyAt,
          );
        }
        return t;
      }).toList();

      // Re-sort after pinning
      state.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final aTime = a.lastReplyAt ?? a.createdAt;
        final bTime = b.lastReplyAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      print('✅ Toggled pin for topic: $topicId');
    } catch (e) {
      print('❌ Error toggling pin: $e');
      rethrow;
    }
  }

  // Close/Open topic (instructor only)
  Future<void> toggleClose(String topicId) async {
    try {
      final topic = state.firstWhere((t) => t.id == topicId);
      
      await DatabaseService.updateOne(
        collection: 'forum_topics',
        id: topicId,
        update: {
          'isClosed': !topic.isClosed,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      // Update state
      state = state.map((t) {
        if (t.id == topicId) {
          return ForumTopic(
            id: t.id,
            courseId: t.courseId,
            title: t.title,
            content: t.content,
            authorId: t.authorId,
            authorName: t.authorName,
            isInstructor: t.isInstructor,
            attachments: t.attachments,
            tags: t.tags,
            isPinned: t.isPinned,
            isClosed: !t.isClosed,
            replyCount: t.replyCount,
            createdAt: t.createdAt,
            updatedAt: DateTime.now(),
            lastReplyAt: t.lastReplyAt,
          );
        }
        return t;
      }).toList();

      print('✅ Toggled close for topic: $topicId');
    } catch (e) {
      print('❌ Error toggling close: $e');
      rethrow;
    }
  }

  // Delete topic (instructor or author only)
  Future<void> deleteTopic(String topicId) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'forum_topics',
        id: topicId,
      );

      state = state.where((t) => t.id != topicId).toList();
      
      print('✅ Deleted topic: $topicId');
    } catch (e) {
      print('❌ Error deleting topic: $e');
      rethrow;
    }
  }

  // Update reply count and last reply time
  Future<void> incrementReplyCount(String topicId) async {
    try {
      final topic = state.firstWhere((t) => t.id == topicId);
      final now = DateTime.now();
      
      await DatabaseService.updateOne(
        collection: 'forum_topics',
        id: topicId,
        update: {
          'replyCount': topic.replyCount + 1,
          'lastReplyAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Update state and re-sort
      state = state.map((t) {
        if (t.id == topicId) {
          return ForumTopic(
            id: t.id,
            courseId: t.courseId,
            title: t.title,
            content: t.content,
            authorId: t.authorId,
            authorName: t.authorName,
            isInstructor: t.isInstructor,
            attachments: t.attachments,
            tags: t.tags,
            isPinned: t.isPinned,
            isClosed: t.isClosed,
            replyCount: t.replyCount + 1,
            createdAt: t.createdAt,
            updatedAt: now,
            lastReplyAt: now,
          );
        }
        return t;
      }).toList();

      // Re-sort after new reply
      state.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final aTime = a.lastReplyAt ?? a.createdAt;
        final bTime = b.lastReplyAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      print('✅ Incremented reply count for topic: $topicId');
    } catch (e) {
      print('❌ Error incrementing reply count: $e');
    }
  }
}

class ForumReplyNotifier extends StateNotifier<List<ForumReply>> {
  ForumReplyNotifier() : super([]);

// Load replies for a topic
Future<void> loadReplies(String topicId) async {
  try {
    print('🔍 Searching replies with topicId: $topicId');
    
    // ✅ WORKAROUND: Get ALL replies and filter in memory
    final data = await DatabaseService.find(
      collection: 'forum_replies',
      filter: {}, // Get all
      sort: {'createdAt': 1},
    );
    
    print('📦 Total replies fetched: ${data.length}');
    
    // Filter in memory
    final filteredData = data.where((reply) {
      final replyTopicId = reply['topicId'].toString();
      print('  Comparing: $replyTopicId == $topicId? ${replyTopicId == topicId}');
      return replyTopicId == topicId;
    }).toList();
    
    print('📦 Filtered replies: ${filteredData.length}');
    
    state = filteredData.map((e) {
      final map = Map<String, dynamic>.from(e);
      return ForumReply.fromMap(map);
    }).toList();
    
    print('✅ Loaded ${state.length} forum replies');
  } catch (e, stack) {
    print('❌ Error loading forum replies: $e');
    print('Stack: $stack');
    state = [];
  }
}


  // Add reply (anyone can reply)
  Future<void> addReply({
    required String topicId,
    required String content,
    required String authorId,
    required String authorName,
    required bool isInstructor,
    List<ForumAttachment> attachments = const [],
    String? parentReplyId,
  }) async {
    try {
      final now = DateTime.now();

      final doc = <String, dynamic>{
        'topicId': topicId,
        'content': content,
        'authorId': authorId,
        'authorName': authorName,
        'isInstructor': isInstructor,
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
        if (parentReplyId != null) 'parentReplyId': parentReplyId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      print('📤 Inserting reply with topicId: $topicId');

      final insertedId = await DatabaseService.insertOne(
        collection: 'forum_replies',
        document: doc,
      );

      print('✅ Reply inserted with ID: $insertedId');

      // Add to state
      state = [
        ...state,
        ForumReply(
          id: insertedId,
          topicId: topicId,
          content: content,
          authorId: authorId,
          authorName: authorName,
          isInstructor: isInstructor,
          attachments: attachments,
          parentReplyId: parentReplyId,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      print('✅ Added forum reply to state: $insertedId');
    } catch (e, stack) {
      print('❌ Error adding forum reply: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  // ✅ NEW: Edit reply
  Future<void> editReply({
    required String replyId,
    required String content,
  }) async {
    try {
      final now = DateTime.now();
      
      await DatabaseService.updateOne(
        collection: 'forum_replies',
        id: replyId,
        update: {
          'content': content,
          'updatedAt': now.toIso8601String(),
        },
      );

      // Update state
      state = state.map((r) {
        if (r.id == replyId) {
          return ForumReply(
            id: r.id,
            topicId: r.topicId,
            content: content,
            authorId: r.authorId,
            authorName: r.authorName,
            isInstructor: r.isInstructor,
            attachments: r.attachments,
            parentReplyId: r.parentReplyId,
            createdAt: r.createdAt,
            updatedAt: now,
          );
        }
        return r;
      }).toList();

      print('✅ Edited reply: $replyId');
    } catch (e) {
      print('❌ Error editing reply: $e');
      rethrow;
    }
  }

  // Delete reply (author or instructor only)
  Future<void> deleteReply(String replyId) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'forum_replies',
        id: replyId,
      );

      state = state.where((r) => r.id != replyId).toList();
      
      print('✅ Deleted reply: $replyId');
    } catch (e) {
      print('❌ Error deleting reply: $e');
      rethrow;
    }
  }
}