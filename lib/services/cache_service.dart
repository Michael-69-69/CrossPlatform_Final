// lib/services/cache_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  static Box? _cacheBox;
  static SharedPreferences? _prefs;
  static bool _initialized = false;

  // Cache expiration times (in minutes)
  static const int CATEGORY_CACHE_DURATION = 60; // 1 hour
  static const int QUERY_CACHE_DURATION = 10;    // 10 minutes
  static const int SEMESTER_CACHE_DURATION = 30; // 30 minutes
  static const int PERMANENT_CACHE = -1;         // Never expires

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

  /// Ensure cache is initialized
  static Future<void> _ensureInitialized() async {
    if (!_initialized || _cacheBox == null) {
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
    if (_cacheBox == null) return;
    
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': durationMinutes == PERMANENT_CACHE 
            ? null 
            : DateTime.now().add(Duration(minutes: durationMinutes)).toIso8601String(),
      };
      
      await _cacheBox!.put(key, jsonEncode(cacheData));
      print('✅ Cached category data: $key (${data.length} items)');
    } catch (e) {
      print('❌ Error caching category data: $e');
    }
  }

  /// Get cached category data
  static Future<List<Map<String, dynamic>>?> getCachedCategoryData(String key, {bool ignoreExpiry = false}) async {
    await _ensureInitialized();
    if (_cacheBox == null) return null;
    
    try {
      final cached = _cacheBox!.get(key);
      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      
      // Check if expired (skip if ignoreExpiry or no expiration)
      if (!ignoreExpiry && cacheData['expiresAt'] != null) {
        final expiresAt = DateTime.parse(cacheData['expiresAt'] as String);
        if (DateTime.now().isAfter(expiresAt)) {
          print('⏰ Cache expired: $key');
          // Still return data, let caller decide to refresh
        }
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
    if (_cacheBox == null) return;
    
    try {
      final cacheData = {
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now()
            .add(Duration(minutes: durationMinutes))
            .toIso8601String(),
      };
      
      await _cacheBox!.put('query_$queryKey', jsonEncode(cacheData));
      print('✅ Cached query result: $queryKey');
    } catch (e) {
      print('❌ Error caching query result: $e');
    }
  }

  /// Get cached query result
  static Future<Map<String, dynamic>?> getCachedQueryResult(String queryKey) async {
    await _ensureInitialized();
    if (_cacheBox == null) return null;
    
    try {
      final cached = _cacheBox!.get('query_$queryKey');
      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(cacheData['expiresAt'] as String);
      
      if (DateTime.now().isAfter(expiresAt)) {
        await _cacheBox!.delete('query_$queryKey');
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
    if (_cacheBox == null) return;
    
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
      
      await _cacheBox!.put(cacheKey, jsonEncode(cacheData));
      print('✅ Cached semester data: $semesterId');
    } catch (e) {
      print('❌ Error caching semester data: $e');
    }
  }

  /// Get cached semester data
  static Future<Map<String, dynamic>?> getCachedSemesterData(String semesterId) async {
    await _ensureInitialized();
    if (_cacheBox == null) return null;
    
    try {
      final cacheKey = 'semester_$semesterId';
      final cached = _cacheBox!.get(cacheKey);
      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(cacheData['expiresAt'] as String);
      
      if (DateTime.now().isAfter(expiresAt)) {
        await _cacheBox!.delete(cacheKey);
        print('⏰ Semester cache expired: $semesterId');
        return null;
      }

      print('✅ Retrieved cached semester: $semesterId');
      return Map<String, dynamic>.from(cacheData['data'] as Map);
    } catch (e) {
      print('❌ Error retrieving cached semester: $e');
      return null;
    }
  }

  // ============================================
  // CACHE MANAGEMENT
  // ============================================

  /// Clear specific cache
  static Future<void> clearCache(String key) async {
    await _ensureInitialized();
    if (_cacheBox == null) return;
    
    await _cacheBox!.delete(key);
    print('🗑️ Cleared cache: $key');
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    await _ensureInitialized();
    if (_cacheBox == null) return;
    
    await _cacheBox!.clear();
    print('🗑️ Cleared all cache');
  }

  /// Get all cache items with metadata
  static Future<List<Map<String, dynamic>>> getAllCacheItems() async {
    await _ensureInitialized();
    if (_cacheBox == null) return [];
    
    final List<Map<String, dynamic>> items = [];
    
    try {
      for (var key in _cacheBox!.keys) {
        try {
          final cached = _cacheBox!.get(key);
          if (cached == null) continue;
          
          final cacheData = jsonDecode(cached) as Map<String, dynamic>;
          final data = cacheData['data'] ?? cacheData['result'];
          
          items.add({
            'key': key.toString(),
            'timestamp': cacheData['timestamp'],
            'expiresAt': cacheData['expiresAt'],
            'permanent': cacheData['permanent'] ?? false,
            'data': data,
            'dataCount': data is List ? data.length : 1,
          });
        } catch (e) {
          print('⚠️ Skipping malformed cache entry: $key');
        }
      }
      
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

  /// Get cache statistics
  static Future<Map<String, int>> getCacheStats() async {
    await _ensureInitialized();
    if (_cacheBox == null) {
      return {'total': 0, 'category': 0, 'query': 0, 'semester': 0};
    }
    
    final items = await getAllCacheItems();
    
    int categoryCount = 0;
    int queryCount = 0;
    int semesterCount = 0;
    
    for (var item in items) {
      final key = item['key'] as String;
      if (key.startsWith('query_')) {
        queryCount++;
      } else if (key.startsWith('semester_')) {
        semesterCount++;
      } else {
        categoryCount++;
      }
    }
    
    return {
      'total': items.length,
      'category': categoryCount,
      'query': queryCount,
      'semester': semesterCount,
    };
  }

  /// Check if cache is initialized
  static bool get isInitialized => _initialized && _cacheBox != null;
}