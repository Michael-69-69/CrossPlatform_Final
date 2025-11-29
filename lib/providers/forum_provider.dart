// providers/forum_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/forum.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';

final forumTopicProvider = StateNotifierProvider<ForumTopicNotifier, List<ForumTopic>>((ref) {
  return ForumTopicNotifier(ref);
});

final forumReplyProvider = StateNotifierProvider<ForumReplyNotifier, List<ForumReply>>((ref) {
  return ForumReplyNotifier();
});

class ForumTopicNotifier extends StateNotifier<List<ForumTopic>> {
  final Ref ref;
  
  ForumTopicNotifier(this.ref) : super([]);

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

  // ✅ Helper: Extract ObjectId string
  String _extractObjectIdString(dynamic value) {
    if (value == null) return '';
    
    if (value is ObjectId) {
      return value.toHexString();
    }
    
    final valueStr = value.toString();
    
    if (valueStr.startsWith('ObjectId(')) {
      final regex = RegExp(r'ObjectId\("?([a-fA-F0-9]{24})"?\)');
      final match = regex.firstMatch(valueStr);
      if (match != null) {
        return match.group(1)!;
      }
    }
    
    if (valueStr.contains('"')) {
      final parts = valueStr.split('"');
      if (parts.length >= 2) {
        return parts[1];
      }
    }
    
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(valueStr)) {
      return valueStr;
    }
    
    return valueStr;
  }

  // ✅ Sort topics helper
  void _sortTopics() {
    state.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final aTime = a.lastReplyAt ?? a.createdAt;
      final bTime = b.lastReplyAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
  }

  // ══════════════════════════════════════════════════════════════
  // ✅ NEW: Pre-cache replies for all topics when loading topics
  // This ensures replies are available in offline mode
  // ══════════════════════════════════════════════════════════════
  Future<void> _preCacheRepliesForTopics(List<ForumTopic> topics) async {
    if (NetworkService().isOffline) return;
    
    try {
      print('📦 Pre-caching replies for ${topics.length} topics...');
      
      // Fetch ALL replies at once (more efficient than per-topic)
      final allReplies = await DatabaseService.find(
        collection: 'forum_replies',
        filter: {},
        sort: {'createdAt': 1},
      );
      
      print('📦 Total replies fetched: ${allReplies.length}');
      
      // Group replies by topicId
      final Map<String, List<Map<String, dynamic>>> repliesByTopic = {};
      
      for (final reply in allReplies) {
        final topicId = _extractObjectIdString(reply['topicId']);
        if (topicId.isNotEmpty) {
          repliesByTopic.putIfAbsent(topicId, () => []);
          repliesByTopic[topicId]!.add(_convertObjectIds(Map<String, dynamic>.from(reply)));
        }
      }
      
      // Cache replies for each topic
      for (final topic in topics) {
        final topicReplies = repliesByTopic[topic.id] ?? [];
        final cacheKey = 'forum_replies_${topic.id}';
        
        await CacheService.cacheCategoryData(
          key: cacheKey,
          data: topicReplies,
          durationMinutes: 60, // Cache for 1 hour
        );
        
        if (topicReplies.isNotEmpty) {
          print('  ✅ Cached ${topicReplies.length} replies for topic: ${topic.title.substring(0, topic.title.length > 20 ? 20 : topic.title.length)}...');
        }
      }
      
      print('✅ Pre-cached replies for all topics');
    } catch (e) {
      print('⚠️ Error pre-caching replies: $e');
      // Don't throw - this is a background operation
    }
  }

  // Load all topics for a course
  Future<void> loadTopics(String courseId) async {
    try {
      // ✅ 1. Try to load from cache first
      final cacheKey = 'forum_topics_$courseId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return ForumTopic.fromMap(map);
        }).toList();
        _sortTopics();
        print('📦 Loaded ${state.length} forum topics from cache');
        
        // ✅ If online, refresh topics AND pre-cache replies in background
        if (NetworkService().isOnline) {
          _refreshTopicsInBackground(courseId, cacheKey);
        }
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for forum topics');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database
      final data = await DatabaseService.find(
        collection: 'forum_topics',
        filter: {'courseId': courseId},
        sort: {'createdAt': -1},
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return ForumTopic.fromMap(map);
      }).toList();
      _sortTopics();
      
      // ✅ 4. Save topics to cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('✅ Loaded ${state.length} forum topics');
      
      // ✅ 5. NEW: Pre-cache replies for all topics (background)
      _preCacheRepliesForTopics(state);
      
    } catch (e, stack) {
      print('❌ Error loading forum topics: $e');
      print('Stack: $stack');
      
      // ✅ 6. Fallback to cache on error
      final cacheKey = 'forum_topics_$courseId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return ForumTopic.fromMap(map);
        }).toList();
        _sortTopics();
        print('📦 Loaded ${state.length} forum topics from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh - now also pre-caches replies
  Future<void> _refreshTopicsInBackground(String courseId, String cacheKey) async {
    try {
      final data = await DatabaseService.find(
        collection: 'forum_topics',
        filter: {'courseId': courseId},
        sort: {'createdAt': -1},
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return ForumTopic.fromMap(map);
      }).toList();
      _sortTopics();
      
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('🔄 Background refresh: forum topics updated');
      
      // ✅ NEW: Also pre-cache replies during background refresh
      await _preCacheRepliesForTopics(state);
      
    } catch (e) {
      print('Background refresh failed: $e');
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

  // Create new topic
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
    if (NetworkService().isOffline) {
      throw Exception('Không thể tạo bài viết khi offline');
    }
    
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
      
      // ✅ Clear cache
      await CacheService.clearCache('forum_topics_$courseId');
      
      // ✅ NEW: Initialize empty replies cache for new topic
      await CacheService.cacheCategoryData(
        key: 'forum_replies_$insertedId',
        data: [],
        durationMinutes: 60,
      );

      print('✅ Created forum topic: $insertedId');
    } catch (e, stack) {
      print('❌ Error creating forum topic: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  // Edit topic
  Future<void> editTopic({
    required String topicId,
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể sửa bài viết khi offline');
    }
    
    try {
      final now = DateTime.now();
      final topic = state.firstWhere((t) => t.id == topicId);
      
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

      // ✅ Clear cache
      await CacheService.clearCache('forum_topics_${topic.courseId}');

      print('✅ Edited topic: $topicId');
    } catch (e) {
      print('❌ Error editing topic: $e');
      rethrow;
    }
  }

  // Pin/Unpin topic
  Future<void> togglePin(String topicId) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể ghim bài viết khi offline');
    }
    
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
      _sortTopics();

      // ✅ Clear cache
      await CacheService.clearCache('forum_topics_${topic.courseId}');

      print('✅ Toggled pin for topic: $topicId');
    } catch (e) {
      print('❌ Error toggling pin: $e');
      rethrow;
    }
  }

  // Close/Open topic
  Future<void> toggleClose(String topicId) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể đóng/mở bài viết khi offline');
    }
    
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

      // ✅ Clear cache
      await CacheService.clearCache('forum_topics_${topic.courseId}');

      print('✅ Toggled close for topic: $topicId');
    } catch (e) {
      print('❌ Error toggling close: $e');
      rethrow;
    }
  }

  // Delete topic
  Future<void> deleteTopic(String topicId) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể xóa bài viết khi offline');
    }
    
    try {
      final topic = state.firstWhere((t) => t.id == topicId);
      final courseId = topic.courseId;
      
      await DatabaseService.deleteOne(
        collection: 'forum_topics',
        id: topicId,
      );

      state = state.where((t) => t.id != topicId).toList();
      
      // ✅ Clear both topic and replies cache
      await CacheService.clearCache('forum_topics_$courseId');
      await CacheService.clearCache('forum_replies_$topicId');
      
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
      
      if (NetworkService().isOnline) {
        await DatabaseService.updateOne(
          collection: 'forum_topics',
          id: topicId,
          update: {
            'replyCount': topic.replyCount + 1,
            'lastReplyAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

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
      _sortTopics();

      // ✅ Clear cache
      await CacheService.clearCache('forum_topics_${topic.courseId}');

      print('✅ Incremented reply count for topic: $topicId');
    } catch (e) {
      print('❌ Error incrementing reply count: $e');
    }
  }
  
  // ✅ Force refresh
  Future<void> forceRefresh(String courseId) async {
    await CacheService.clearCache('forum_topics_$courseId');
    await loadTopics(courseId);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FORUM REPLY NOTIFIER
// ══════════════════════════════════════════════════════════════════════════════

class ForumReplyNotifier extends StateNotifier<List<ForumReply>> {
  ForumReplyNotifier() : super([]);

  // ✅ Helper: Convert ObjectIds to strings
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

  // ✅ Helper: Extract ObjectId string
  String _extractObjectIdString(dynamic value) {
    if (value == null) return '';
    
    if (value is ObjectId) {
      return value.toHexString();
    }
    
    final valueStr = value.toString();
    
    if (valueStr.startsWith('ObjectId(')) {
      final regex = RegExp(r'ObjectId\("?([a-fA-F0-9]{24})"?\)');
      final match = regex.firstMatch(valueStr);
      if (match != null) {
        return match.group(1)!;
      }
    }
    
    if (valueStr.contains('"')) {
      final parts = valueStr.split('"');
      if (parts.length >= 2) {
        return parts[1];
      }
    }
    
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(valueStr)) {
      return valueStr;
    }
    
    return valueStr;
  }

  // ✅ Check if replies are cached for a topic
  Future<bool> hasRepliesCached(String topicId) async {
    final cacheKey = 'forum_replies_$topicId';
    final cached = await CacheService.getCachedCategoryData(cacheKey);
    return cached != null;
  }

  // Load replies for a topic
  Future<void> loadReplies(String topicId) async {
    try {
      print('🔍 Loading replies for topicId: $topicId');
      
      // ✅ 1. Try to load from cache first
      final cacheKey = 'forum_replies_$topicId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      
      if (cached != null) {
        // ✅ Cache exists (even if empty - this is valid for topics with no replies)
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return ForumReply.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} forum replies from cache');
        
        // If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshRepliesInBackground(topicId, cacheKey);
        }
        return;
      }

      // ✅ 2. If no cache and offline, show empty with warning
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for forum replies');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database - WORKAROUND: Get ALL replies and filter in memory
      final data = await DatabaseService.find(
        collection: 'forum_replies',
        filter: {},
        sort: {'createdAt': 1},
      );
      
      print('📦 Total replies fetched: ${data.length}');
      
      // ✅ Filter in memory with improved ObjectId handling
      final filteredData = data.where((reply) {
        final replyTopicId = _extractObjectIdString(reply['topicId']);
        return replyTopicId == topicId;
      }).toList();
      
      print('📦 Filtered replies for topic $topicId: ${filteredData.length}');
      
      state = filteredData.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return ForumReply.fromMap(map);
      }).toList();

      // ✅ 4. Save to cache (even if empty - so we know this topic has no replies)
      final cacheData = filteredData.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60, // Cache for 1 hour
      );
      
      print('✅ Loaded and cached ${state.length} forum replies');
    } catch (e, stack) {
      print('❌ Error loading forum replies: $e');
      print('Stack: $stack');
      
      // ✅ 5. Fallback to cache on error
      final cacheKey = 'forum_replies_$topicId';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return ForumReply.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} forum replies from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh
  Future<void> _refreshRepliesInBackground(String topicId, String cacheKey) async {
    try {
      final data = await DatabaseService.find(
        collection: 'forum_replies',
        filter: {},
        sort: {'createdAt': 1},
      );
      
      final filteredData = data.where((reply) {
        final replyTopicId = _extractObjectIdString(reply['topicId']);
        return replyTopicId == topicId;
      }).toList();
      
      state = filteredData.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return ForumReply.fromMap(map);
      }).toList();

      final cacheData = filteredData.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60,
      );
      
      print('🔄 Background refresh: forum replies updated (${state.length} replies)');
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  // Add reply
  Future<void> addReply({
    required String topicId,
    required String content,
    required String authorId,
    required String authorName,
    required bool isInstructor,
    List<ForumAttachment> attachments = const [],
    String? parentReplyId,
  }) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể trả lời khi offline');
    }
    
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

      final newReply = ForumReply(
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
      );

      state = [...state, newReply];

      // ✅ Update cache with new reply
      final cacheKey = 'forum_replies_$topicId';
      final cacheData = state.map((r) => {
        '_id': r.id,
        'topicId': r.topicId,
        'content': r.content,
        'authorId': r.authorId,
        'authorName': r.authorName,
        'isInstructor': r.isInstructor,
        'attachments': r.attachments.map((a) => a.toMap()).toList(),
        if (r.parentReplyId != null) 'parentReplyId': r.parentReplyId,
        'createdAt': r.createdAt.toIso8601String(),
        'updatedAt': r.updatedAt.toIso8601String(),
      }).toList();
      
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60,
      );

      print('✅ Added forum reply to state and cache: $insertedId');
    } catch (e, stack) {
      print('❌ Error adding forum reply: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  // Edit reply
  Future<void> editReply({
    required String replyId,
    required String content,
  }) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể sửa trả lời khi offline');
    }
    
    try {
      final now = DateTime.now();
      final reply = state.firstWhere((r) => r.id == replyId);
      final topicId = reply.topicId;
      
      await DatabaseService.updateOne(
        collection: 'forum_replies',
        id: replyId,
        update: {
          'content': content,
          'updatedAt': now.toIso8601String(),
        },
      );

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

      // ✅ Update cache
      await _updateRepliesCache(topicId);

      print('✅ Edited reply: $replyId');
    } catch (e) {
      print('❌ Error editing reply: $e');
      rethrow;
    }
  }

  // Delete reply
  Future<void> deleteReply(String replyId) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể xóa trả lời khi offline');
    }
    
    try {
      final reply = state.firstWhere((r) => r.id == replyId);
      final topicId = reply.topicId;
      
      await DatabaseService.deleteOne(
        collection: 'forum_replies',
        id: replyId,
      );

      state = state.where((r) => r.id != replyId).toList();
      
      // ✅ Update cache
      await _updateRepliesCache(topicId);
      
      print('✅ Deleted reply: $replyId');
    } catch (e) {
      print('❌ Error deleting reply: $e');
      rethrow;
    }
  }

  // ✅ Helper: Update replies cache after modification
  Future<void> _updateRepliesCache(String topicId) async {
    final cacheKey = 'forum_replies_$topicId';
    final topicReplies = state.where((r) => r.topicId == topicId).toList();
    
    final cacheData = topicReplies.map((r) => {
      '_id': r.id,
      'topicId': r.topicId,
      'content': r.content,
      'authorId': r.authorId,
      'authorName': r.authorName,
      'isInstructor': r.isInstructor,
      'attachments': r.attachments.map((a) => a.toMap()).toList(),
      if (r.parentReplyId != null) 'parentReplyId': r.parentReplyId,
      'createdAt': r.createdAt.toIso8601String(),
      'updatedAt': r.updatedAt.toIso8601String(),
    }).toList();
    
    await CacheService.cacheCategoryData(
      key: cacheKey,
      data: cacheData,
      durationMinutes: 60,
    );
  }
  
  // ✅ Force refresh
  Future<void> forceRefresh(String topicId) async {
    await CacheService.clearCache('forum_replies_$topicId');
    await loadReplies(topicId);
  }

  // ✅ Clear state (useful when navigating away)
  void clearState() {
    state = [];
  }
}