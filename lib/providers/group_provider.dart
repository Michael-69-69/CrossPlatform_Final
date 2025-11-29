// providers/group_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/group.dart' as app;
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';

final groupProvider = StateNotifierProvider<GroupNotifier, List<app.Group>>((ref) => GroupNotifier());

// ✅ NEW: Separate provider for student details cache
final groupStudentDetailsProvider = StateProvider<Map<String, List<Map<String, dynamic>>>>((ref) => {});

class GroupNotifier extends StateNotifier<List<app.Group>> {
  GroupNotifier() : super([]);

  // ✅ Store student details for offline display (in-memory)
  static Map<String, List<Map<String, dynamic>>> studentDetailsCache = {};

  // ══════════════════════════════════════════════════════════════
  // HELPER: Convert ObjectIds to strings for caching
  // ══════════════════════════════════════════════════════════════
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
          if (item == null) return null;
          return item.toString();
        }).where((item) => item != null).toList();
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

  app.Group _parseGroupFromCache(Map<String, dynamic> map) {
    final id = map['_id']?.toString() ?? '';
    final name = map['name']?.toString() ?? '';
    final courseId = map['courseId']?.toString() ?? '';
    
    List<String> studentIds = [];
    final rawStudentIds = map['studentIds'];
    if (rawStudentIds != null && rawStudentIds is List) {
      studentIds = rawStudentIds
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty && e != 'null')
          .toList();
    }
    
    return app.Group(
      id: id,
      name: name,
      courseId: courseId,
      studentIds: studentIds,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LOAD GROUPS
  // ══════════════════════════════════════════════════════════════
  Future<void> loadGroups() async {
    try {
      // ✅ 1. Try to load from cache first
      final cached = await CacheService.getCachedCategoryData('groups_with_students');
      if (cached != null && cached.isNotEmpty) {
        print('📦 Found ${cached.length} groups in cache, parsing...');
        
        final groups = <app.Group>[];
        studentDetailsCache = {};
        
        for (final item in cached) {
          final map = Map<String, dynamic>.from(item);
          final group = _parseGroupFromCache(map);
          groups.add(group);
          
          // ✅ Extract embedded student details into STATIC cache
          final studentDetails = map['_studentDetails'];
          if (studentDetails is List && studentDetails.isNotEmpty) {
            studentDetailsCache[group.id] = studentDetails
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            print('  ✓ ${group.name}: ${group.studentIds.length} IDs, ${studentDetails.length} details');
          } else {
            studentDetailsCache[group.id] = [];
            print('  ✓ ${group.name}: ${group.studentIds.length} IDs, 0 details');
          }
        }
        
        state = groups;
        print('📦 Loaded ${state.length} groups, studentDetailsCache has ${studentDetailsCache.length} entries');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshGroupsInBackground();
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for groups');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database and cache with student details
      await _fetchAndCacheGroupsWithStudents();
      
    } catch (e, stack) {
      print('❌ loadGroups error: $e');
      print('Stack: $stack');
      
      // Fallback to cache
      await _loadFromCacheFallback();
    }
  }

  Future<void> _loadFromCacheFallback() async {
    final cached = await CacheService.getCachedCategoryData('groups_with_students');
    if (cached != null && cached.isNotEmpty) {
      final groups = <app.Group>[];
      studentDetailsCache = {};
      
      for (final item in cached) {
        final map = Map<String, dynamic>.from(item);
        final group = _parseGroupFromCache(map);
        groups.add(group);
        
        final studentDetails = map['_studentDetails'];
        if (studentDetails is List) {
          studentDetailsCache[group.id] = studentDetails
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          studentDetailsCache[group.id] = [];
        }
      }
      
      state = groups;
      print('📦 Loaded ${state.length} groups from cache (fallback)');
    } else {
      state = [];
    }
  }

  // ✅ Fetch groups and embed student details for offline use
  Future<void> _fetchAndCacheGroupsWithStudents() async {
    print('🌐 Fetching groups from database...');
    final data = await DatabaseService.find(collection: 'groups');
    print('🌐 Received ${data.length} groups from database');
    
    final cacheData = <Map<String, dynamic>>[];
    final groups = <app.Group>[];
    studentDetailsCache = {};
    
    for (final rawGroup in data) {
      final converted = _convertObjectIds(Map<String, dynamic>.from(rawGroup));
      
      // Parse studentIds
      List<String> studentIds = [];
      if (converted['studentIds'] is List) {
        studentIds = (converted['studentIds'] as List)
            .where((e) => e != null)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty && e != 'null')
            .toList();
      }
      converted['studentIds'] = studentIds;
      
      final groupId = converted['_id']?.toString() ?? '';
      final groupName = converted['name']?.toString() ?? '';
      
      // ✅ Fetch student details for this group
      List<Map<String, dynamic>> studentDetails = [];
      if (studentIds.isNotEmpty) {
        studentDetails = await _fetchStudentDetailsForGroup(studentIds);
        print('  ✓ $groupName: ${studentIds.length} IDs, ${studentDetails.length} details');
      }
      
      // ✅ Embed student details in cache data
      converted['_studentDetails'] = studentDetails;
      cacheData.add(converted);
      
      // Update groups list
      final group = _parseGroupFromCache(converted);
      groups.add(group);
      
      // Store in static cache
      studentDetailsCache[groupId] = studentDetails;
    }
    
    state = groups;
    
    // ✅ Save to cache with embedded student details
    await CacheService.cacheCategoryData(
      key: 'groups_with_students',
      data: cacheData,
      durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
    );
    
    // Also clear old cache key
    await CacheService.clearCache('groups');
    
    print('✅ Loaded ${state.length} groups, cached ${studentDetailsCache.length} student detail lists');
  }

  // ✅ Fetch student details for a list of student IDs
  Future<List<Map<String, dynamic>>> _fetchStudentDetailsForGroup(List<String> studentIds) async {
    final students = <Map<String, dynamic>>[];
    
    for (final studentId in studentIds) {
      try {
        final student = await DatabaseService.findOne(
          collection: 'users',
          filter: {'_id': studentId},
        );
        
        if (student != null) {
          students.add({
            '_id': _extractObjectIdString(student['_id']),
            'code': student['code']?.toString() ?? '',
            'email': student['email']?.toString() ?? '',
            'full_name': student['full_name']?.toString() ?? '',
          });
        }
      } catch (e) {
        print('    ⚠️ Failed to fetch student $studentId: $e');
      }
    }
    
    return students;
  }

  // ✅ Get student details for a group - reads from static cache
  List<Map<String, dynamic>> getStudentDetailsForGroup(String groupId) {
    final details = studentDetailsCache[groupId] ?? [];
    print('📋 getStudentDetailsForGroup($groupId): ${details.length} students');
    return details;
  }

  // ✅ STATIC METHOD: Get student details (can be called from anywhere)
  static List<Map<String, dynamic>> getStudentDetails(String groupId) {
    return studentDetailsCache[groupId] ?? [];
  }

  // ✅ Background refresh
  Future<void> _refreshGroupsInBackground() async {
    try {
      print('🔄 Background refresh: fetching groups with students...');
      await _fetchAndCacheGroupsWithStudents();
      print('🔄 Background refresh complete');
    } catch (e) {
      print('⚠️ Background refresh failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // CREATE GROUP
  // ══════════════════════════════════════════════════════════════
  Future<void> createGroup({
    required String name,
    required String courseId,
  }) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể tạo nhóm khi offline');
    }
    
    try {
      final doc = {
        'name': name,
        'courseId': courseId,
        'studentIds': <String>[],
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'groups',
        document: doc,
      );

      final newGroup = app.Group(
        id: insertedId,
        name: name,
        courseId: courseId,
        studentIds: [],
      );

      state = [...state, newGroup];
      studentDetailsCache[insertedId] = [];
      
      await _updateCacheWithStudentDetails();
      
      print('✅ Created group: $insertedId');
    } catch (e) {
      print('createGroup error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // UPDATE GROUP NAME
  // ══════════════════════════════════════════════════════════════
  Future<void> updateGroup(String groupId, String newName) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể cập nhật nhóm khi offline');
    }
    
    try {
      await DatabaseService.updateOne(
        collection: 'groups',
        id: groupId,
        update: {'name': newName},
      );

      state = state.map((g) {
        if (g.id == groupId) {
          return app.Group(
            id: g.id,
            name: newName,
            courseId: g.courseId,
            studentIds: g.studentIds,
          );
        }
        return g;
      }).toList();
      
      await _updateCacheWithStudentDetails();
      
      print('✅ Updated group: $groupId');
    } catch (e) {
      print('updateGroup error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ADD STUDENTS TO GROUP
  // ══════════════════════════════════════════════════════════════
  Future<void> addStudents(String groupId, List<String> studentIds) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể thêm học sinh khi offline');
    }
    
    try {
      final groupDoc = await DatabaseService.findOne(
        collection: 'groups',
        filter: {'_id': groupId},
      );
      if (groupDoc == null) {
        throw Exception('Không tìm thấy nhóm');
      }

      final courseId = _extractObjectIdString(groupDoc['courseId']);
      
      final existingGroups = await DatabaseService.find(
        collection: 'groups',
        filter: {'courseId': courseId},
      );

      final currentStudentIds = List<String>.from(
        (groupDoc['studentIds'] as List? ?? []).map((e) => _extractObjectIdString(e))
      );

      for (final studentId in studentIds) {
        for (final otherGroup in existingGroups) {
          final otherGroupId = _extractObjectIdString(otherGroup['_id']);
          if (otherGroupId == groupId) continue;

          final otherStudentIds = List<String>.from(
            (otherGroup['studentIds'] as List? ?? []).map((e) => _extractObjectIdString(e))
          );

          if (otherStudentIds.contains(studentId)) {
            otherStudentIds.remove(studentId);
            await DatabaseService.updateOne(
              collection: 'groups',
              id: otherGroupId,
              update: {'studentIds': otherStudentIds},
            );
            print('  ↳ Removed $studentId from group $otherGroupId');
          }
        }

        if (!currentStudentIds.contains(studentId)) {
          currentStudentIds.add(studentId);
        }
      }

      await DatabaseService.updateOne(
        collection: 'groups',
        id: groupId,
        update: {'studentIds': currentStudentIds},
      );

      // ✅ Refresh to update student details
      await refresh();
      
      print('✅ Added ${studentIds.length} students to group: $groupId');
    } catch (e) {
      print('addStudents error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // REMOVE STUDENT FROM GROUP
  // ══════════════════════════════════════════════════════════════
  Future<void> removeStudent(String groupId, String studentId) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể xóa học sinh khi offline');
    }
    
    try {
      final groupDoc = await DatabaseService.findOne(
        collection: 'groups',
        filter: {'_id': groupId},
      );
      if (groupDoc == null) return;

      final currentStudentIds = List<String>.from(
        (groupDoc['studentIds'] as List? ?? []).map((e) => _extractObjectIdString(e))
      );
      currentStudentIds.remove(studentId);

      await DatabaseService.updateOne(
        collection: 'groups',
        id: groupId,
        update: {'studentIds': currentStudentIds},
      );

      // Update local state
      state = state.map((g) {
        if (g.id == groupId) {
          return app.Group(
            id: g.id,
            name: g.name,
            courseId: g.courseId,
            studentIds: currentStudentIds,
          );
        }
        return g;
      }).toList();

      // Update student details cache
      studentDetailsCache[groupId] = (studentDetailsCache[groupId] ?? [])
          .where((s) => s['_id'] != studentId)
          .toList();

      await _updateCacheWithStudentDetails();
      
      print('✅ Removed student $studentId from group: $groupId');
    } catch (e) {
      print('removeStudent error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // DELETE GROUP
  // ══════════════════════════════════════════════════════════════
  Future<void> deleteGroup(String id) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể xóa nhóm khi offline');
    }
    
    try {
      await DatabaseService.deleteOne(
        collection: 'groups',
        id: id,
      );
      
      state = state.where((g) => g.id != id).toList();
      studentDetailsCache.remove(id);
      
      await _updateCacheWithStudentDetails();
      
      print('✅ Deleted group: $id');
    } catch (e) {
      print('deleteGroup error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // UPDATE CACHE WITH STUDENT DETAILS
  // ══════════════════════════════════════════════════════════════
  Future<void> _updateCacheWithStudentDetails() async {
    try {
      final cacheData = state.map((g) => <String, dynamic>{
        '_id': g.id,
        'name': g.name,
        'courseId': g.courseId,
        'studentIds': List<String>.from(g.studentIds),
        '_studentDetails': studentDetailsCache[g.id] ?? [],
      }).toList();
      
      await CacheService.cacheCategoryData(
        key: 'groups_with_students',
        data: cacheData,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );
      
      print('📦 Cache updated: ${state.length} groups');
    } catch (e) {
      print('⚠️ Failed to update cache: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════
  
  Future<void> refresh() async {
    print('🔄 Force refresh: clearing cache and reloading groups...');
    await CacheService.clearCache('groups_with_students');
    await CacheService.clearCache('groups');
    await loadGroups();
  }

  List<app.Group> getGroupsForCourse(String courseId) {
    return state.where((g) => g.courseId == courseId).toList();
  }

  app.Group? getGroupById(String groupId) {
    try {
      return state.firstWhere((g) => g.id == groupId);
    } catch (e) {
      return null;
    }
  }

  List<String> getAllStudentIdsInCourse(String courseId) {
    final courseGroups = getGroupsForCourse(courseId);
    final studentIds = <String>{};
    for (var group in courseGroups) {
      studentIds.addAll(group.studentIds);
    }
    return studentIds.toList();
  }

  app.Group? findStudentGroup(String courseId, String studentId) {
    final courseGroups = getGroupsForCourse(courseId);
    for (var group in courseGroups) {
      if (group.studentIds.contains(studentId)) {
        return group;
      }
    }
    return null;
  }

  bool isStudentInCourse(String courseId, String studentId) {
    return findStudentGroup(courseId, studentId) != null;
  }

  int getTotalStudentsInCourse(String courseId) {
    return getAllStudentIdsInCourse(courseId).length;
  }

  void clearState() {
    state = [];
    studentDetailsCache = {};
  }

  void debugPrintState() {
    print('═══════════════════════════════════════');
    print('GROUP PROVIDER STATE DEBUG');
    print('═══════════════════════════════════════');
    print('Total groups: ${state.length}');
    print('StudentDetailsCache entries: ${studentDetailsCache.length}');
    for (var group in state) {
      final details = studentDetailsCache[group.id] ?? [];
      print('  📁 ${group.name}');
      print('     IDs: ${group.studentIds.length}, Details: ${details.length}');
      if (details.isNotEmpty) {
        print('     First: ${details.first['full_name']}');
      }
    }
    print('═══════════════════════════════════════');
  }
}