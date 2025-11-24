// providers/course_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart'; // ✅ ADD
import '../services/network_service.dart'; // ✅ ADD

final courseProvider = StateNotifierProvider<CourseNotifier, List<Course>>((ref) => CourseNotifier());

class CourseNotifier extends StateNotifier<List<Course>> {
  CourseNotifier() : super([]);

  Future<void> loadCourses() async {
    try {
      // ✅ 1. Try to load from cache first
      final cached = await CacheService.getCachedCategoryData('courses');
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) => Course.fromMap(e)).toList();
        print('📦 Loaded ${state.length} courses from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshCoursesInBackground();
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for courses');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database if online or no cache
      final data = await DatabaseService.find(collection: 'courses');
      state = data.map(Course.fromMap).toList();
      
      // ✅ 4. Save to cache
      await CacheService.cacheCategoryData(
        key: 'courses',
        data: data,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );
      
      print('✅ Loaded ${state.length} courses from database');
    } catch (e) {
      print('loadCourses error: $e');
      
      // ✅ 5. On error, try to fallback to cache
      final cached = await CacheService.getCachedCategoryData('courses');
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) => Course.fromMap(e)).toList();
        print('📦 Loaded ${state.length} courses from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh (silent update without blocking UI)
  Future<void> _refreshCoursesInBackground() async {
    try {
      final data = await DatabaseService.find(collection: 'courses');
      state = data.map(Course.fromMap).toList();
      
      // Update cache
      await CacheService.cacheCategoryData(
        key: 'courses',
        data: data,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );
      
      print('🔄 Background refresh: courses updated');
    } catch (e) {
      print('Background refresh failed: $e');
      // Don't throw - this is a background operation
    }
  }

  Future<void> createCourse({
    required String code,
    required String name,
    required int sessions,
    required String semesterId,
    required String instructorId,
    required String instructorName,
  }) async {
    try {
      final doc = {
        'code': code,
        'name': name,
        'sessions': sessions,
        'semesterId': semesterId,
        'instructorId': instructorId,
        'instructorName': instructorName,
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'courses',
        document: doc,
      );

      state = [
        ...state,
        Course(
          id: insertedId,
          code: code,
          name: name,
          sessions: sessions,
          semesterId: semesterId,
          instructorId: instructorId,
          instructorName: instructorName,
        ),
      ];
      
      // ✅ Clear cache after creating
      await CacheService.clearCache('courses');
      
      print('✅ Created course: $insertedId');
    } catch (e) {
      print('createCourse error: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'courses',
        id: id,
      );
      state = state.where((c) => c.id != id).toList();
      
      // ✅ Clear cache after deleting
      await CacheService.clearCache('courses');
      
      print('✅ Deleted course: $id');
    } catch (e) {
      print('deleteCourse error: $e');
    }
  }

  // ✅ Add method to force refresh from database
  Future<void> refresh() async {
    // Clear cache first to force fresh fetch
    await CacheService.clearCache('courses');
    await loadCourses();
  }
}