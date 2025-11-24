// services/cache_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  static late Box _cacheBox;
  static late SharedPreferences _prefs;
  static bool _initialized = false;

  // Cache expiration times (in minutes)
  static const int CATEGORY_CACHE_DURATION = 60; // 1 hour
  static const int QUERY_CACHE_DURATION = 10;    // 10 minutes
  static const int SEMESTER_CACHE_DURATION = 30; // 30 minutes

  /// Initialize cache service
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await Hive.initFlutter();
      _cacheBox = await Hive.openBox('app_cache');
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      print('✅ Cache service initialized');
    } catch (e) {
      print('❌ Cache initialization error: $e');
      rethrow;
    }
  }

// Add this method to cache_service.dart

  /// Get all cache items with metadata
  static Future<List<Map<String, dynamic>>> getAllCacheItems() async {
    await _ensureInitialized();
    
    final List<Map<String, dynamic>> items = [];
    
    try {
      for (var key in _cacheBox.keys) {
        try {
          final cached = _cacheBox.get(key);
          if (cached == null) continue;
          
          final cacheData = jsonDecode(cached) as Map<String, dynamic>;
          final data = cacheData['data'];
          
          items.add({
            'key': key.toString(),
            'timestamp': cacheData['timestamp'],
            'expiresAt': cacheData['expiresAt'],
            'data': data,
            'dataCount': data is List ? data.length : 1,
          });
        } catch (e) {
          // Skip malformed cache entries
          print('⚠️ Skipping malformed cache entry: $key');
        }
      }
      
      // Sort by timestamp (newest first)
      items.sort((a, b) {
        final aTime = a['timestamp'] as String? ?? '';
        final bTime = b['timestamp'] as String? ?? '';
        return bTime.compareTo(aTime);
      });
      
      return items;
    } catch (e) {
      print('❌ Error getting cache items: $e');
      return [];
    }
  }

  /// Ensure cache is initialized
  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ============================================
  // CATEGORY DATA CACHING
  // ============================================

  /// Cache category data (semesters, courses, groups)
  static Future<void> cacheCategoryData({
    required String key,
    required List<Map<String, dynamic>> data,
    int durationMinutes = CATEGORY_CACHE_DURATION,
  }) async {
    await _ensureInitialized();
    
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now()
            .add(Duration(minutes: durationMinutes))
            .toIso8601String(),
      };
      
      await _cacheBox.put(key, jsonEncode(cacheData));
      print('✅ Cached category data: $key (${data.length} items)');
    } catch (e) {
      print('❌ Error caching category data: $e');
    }
  }

  /// Get cached category data
  static Future<List<Map<String, dynamic>>?> getCachedCategoryData(String key) async {
    await _ensureInitialized();
    
    try {
      final cached = _cacheBox.get(key);
      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(cacheData['expiresAt'] as String);
      
      // Check if expired
      if (DateTime.now().isAfter(expiresAt)) {
        await _cacheBox.delete(key);
        print('⏰ Cache expired: $key');
        return null;
      }

      final data = (cacheData['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      
      print('✅ Retrieved cached data: $key (${data.length} items)');
      return data;
    } catch (e) {
      print('❌ Error retrieving cached data: $e');
      return null;
    }
  }

  // ============================================
  // QUERY RESULT CACHING
  // ============================================

  /// Cache query results
  static Future<void> cacheQueryResult({
    required String queryKey,
    required Map<String, dynamic> result,
    int durationMinutes = QUERY_CACHE_DURATION,
  }) async {
    await _ensureInitialized();
    
    try {
      final cacheData = {
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now()
            .add(Duration(minutes: durationMinutes))
            .toIso8601String(),
      };
      
      await _cacheBox.put('query_$queryKey', jsonEncode(cacheData));
      print('✅ Cached query result: $queryKey');
    } catch (e) {
      print('❌ Error caching query result: $e');
    }
  }

  /// Get cached query result
  static Future<Map<String, dynamic>?> getCachedQueryResult(String queryKey) async {
    await _ensureInitialized();
    
    try {
      final cached = _cacheBox.get('query_$queryKey');
      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(cacheData['expiresAt'] as String);
      
      if (DateTime.now().isAfter(expiresAt)) {
        await _cacheBox.delete('query_$queryKey');
        print('⏰ Query cache expired: $queryKey');
        return null;
      }

      print('✅ Retrieved cached query: $queryKey');
      return Map<String, dynamic>.from(cacheData['result'] as Map);
    } catch (e) {
      print('❌ Error retrieving cached query: $e');
      return null;
    }
  }

  // ============================================
  // SEMESTER SWITCHING CACHE
  // ============================================

  /// Cache semester-specific data
  static Future<void> cacheSemesterData({
    required String semesterId,
    required Map<String, dynamic> data,
    int durationMinutes = SEMESTER_CACHE_DURATION,
  }) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = 'semester_$semesterId';
      final cacheData = {
        'semesterId': semesterId,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now()
            .add(Duration(minutes: durationMinutes))
            .toIso8601String(),
      };
      
      await _cacheBox.put(cacheKey, jsonEncode(cacheData));
      print('✅ Cached semester data: $semesterId');
    } catch (e) {
      print('❌ Error caching semester data: $e');
    }
  }

  /// Get cached semester data
  static Future<Map<String, dynamic>?> getCachedSemesterData(String semesterId) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = 'semester_$semesterId';
      final cached = _cacheBox.get(cacheKey);
      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(cacheData['expiresAt'] as String);
      
      if (DateTime.now().isAfter(expiresAt)) {
        await _cacheBox.delete(cacheKey);
        print('⏰ Semester cache expired: $semesterId');
        return null;
      }

      print('✅ Retrieved cached semester data: $semesterId');
      return Map<String, dynamic>.from(cacheData['data'] as Map);
    } catch (e) {
      print('❌ Error retrieving cached semester data: $e');
      return null;
    }
  }

  // ============================================
  // CACHE MANAGEMENT
  // ============================================

  /// Clear specific cache by key
  static Future<void> clearCache(String key) async {
    await _ensureInitialized();
    await _cacheBox.delete(key);
    print('🗑️ Cleared cache: $key');
  }

  /// Clear all category caches
  static Future<void> clearCategoryCache() async {
    await _ensureInitialized();
    
    final keys = _cacheBox.keys.where((key) => 
      key.toString().startsWith('semesters') || 
      key.toString().startsWith('courses') || 
      key.toString().startsWith('groups') ||
      key.toString().startsWith('students')
    ).toList();
    
    for (var key in keys) {
      await _cacheBox.delete(key);
    }
    
    print('🗑️ Cleared all category caches');
  }

  /// Clear all query caches
  static Future<void> clearQueryCache() async {
    await _ensureInitialized();
    
    final keys = _cacheBox.keys.where((key) => 
      key.toString().startsWith('query_')
    ).toList();
    
    for (var key in keys) {
      await _cacheBox.delete(key);
    }
    
    print('🗑️ Cleared all query caches');
  }

  /// Clear semester cache
  static Future<void> clearSemesterCache([String? semesterId]) async {
    await _ensureInitialized();
    
    if (semesterId != null) {
      await _cacheBox.delete('semester_$semesterId');
      print('🗑️ Cleared semester cache: $semesterId');
    } else {
      final keys = _cacheBox.keys.where((key) => 
        key.toString().startsWith('semester_')
      ).toList();
      
      for (var key in keys) {
        await _cacheBox.delete(key);
      }
      
      print('🗑️ Cleared all semester caches');
    }
  }

  /// Clear all caches
  static Future<void> clearAllCache() async {
    await _ensureInitialized();
    await _cacheBox.clear();
    print('🗑️ Cleared all caches');
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();
    
    final allKeys = _cacheBox.keys.toList();
    final categoryKeys = allKeys.where((k) => 
      !k.toString().startsWith('query_') && 
      !k.toString().startsWith('semester_')
    ).length;
    final queryKeys = allKeys.where((k) => k.toString().startsWith('query_')).length;
    final semesterKeys = allKeys.where((k) => k.toString().startsWith('semester_')).length;
    
    return {
      'total': allKeys.length,
      'category': categoryKeys,
      'query': queryKeys,
      'semester': semesterKeys,
    };
  }
}