// providers/material_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/material.dart' as app;
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';

final materialProvider = StateNotifierProvider<MaterialNotifier, List<app.Material>>((ref) {
  return MaterialNotifier();
});

final materialViewProvider = StateNotifierProvider<MaterialViewNotifier, List<app.MaterialView>>((ref) {
  return MaterialViewNotifier();
});

class MaterialNotifier extends StateNotifier<List<app.Material>> {
  MaterialNotifier() : super([]);
  
  bool _isLoading = false;
  String? _lastLoadedCourseId;

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

  Future<void> loadMaterials({String? courseId}) async {
    // ✅ FIX: Don't reload if same course and not empty (unless forced)
    if (_isLoading || (_lastLoadedCourseId == courseId && state.isNotEmpty)) {
      print('⏭️ Skipping duplicate load for courseId: $courseId');
      return;
    }
    
    try {
      _isLoading = true;
      _lastLoadedCourseId = courseId;
      
      // ✅ 1. Try to load from cache first
      final cacheKey = courseId != null ? 'materials_$courseId' : 'materials_all';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return app.Material.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} materials from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshMaterialsInBackground(courseId, cacheKey);
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for materials');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'materials',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return app.Material.fromMap(map);
      }).toList();
      
      // ✅ 4. Save to cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60, // 1 hour for materials
      );
      
      print('✅ Loaded ${state.length} materials for course: $courseId');
    } catch (e, stackTrace) {
      print('Error loading materials: $e');
      print('StackTrace: $stackTrace');
      
      // ✅ 5. Fallback to cache on error
      final cacheKey = courseId != null ? 'materials_$courseId' : 'materials_all';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return app.Material.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} materials from cache (fallback)');
      } else {
        state = [];
      }
    } finally {
      _isLoading = false;
    }
  }

  // ✅ Background refresh
  Future<void> _refreshMaterialsInBackground(String? courseId, String cacheKey) async {
    try {
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'materials',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return app.Material.fromMap(map);
      }).toList();
      
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 60,
      );
      
      print('🔄 Background refresh: materials updated');
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  Future<void> createMaterial({
    required String courseId,
    required String title,
    String? description,
    required List<app.MaterialAttachment> attachments,
  }) async {
    // ✅ Check if online before creating
    if (NetworkService().isOffline) {
      throw Exception('Không thể tạo tài liệu khi offline');
    }
    
    try {
      final now = DateTime.now();
      
      final doc = <String, dynamic>{
        'courseId': courseId,
        'title': title,
        if (description != null) 'description': description,
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
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      
      final insertedId = await DatabaseService.insertOne(
        collection: 'materials',
        document: doc,
      );
      
      // Add to state immediately
      state = [
        app.Material(
          id: insertedId,
          courseId: courseId,
          title: title,
          description: description,
          attachments: attachments,
          createdAt: now,
          updatedAt: now,
        ),
        ...state,
      ];
      
      // ✅ Clear cache after creating
      await CacheService.clearCache('materials_$courseId');
      await CacheService.clearCache('materials_all');
      
      print('✅ Created material: $insertedId');
    } catch (e, stackTrace) {
      print('Error creating material: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateMaterial(app.Material material) async {
    // ✅ Check if online before updating
    if (NetworkService().isOffline) {
      throw Exception('Không thể cập nhật tài liệu khi offline');
    }
    
    try {
      final now = DateTime.now();
      
      await DatabaseService.updateOne(
        collection: 'materials',
        id: material.id,
        update: {
          'title': material.title,
          if (material.description != null) 'description': material.description,
          'attachments': material.attachments.map((a) {
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
          'updatedAt': now.toIso8601String(),
        },
      );
      
      // Update state
      state = state.map((m) {
        if (m.id == material.id) {
          return material.copyWith(updatedAt: now);
        }
        return m;
      }).toList();
      
      // ✅ Clear cache after updating
      await CacheService.clearCache('materials_${material.courseId}');
      await CacheService.clearCache('materials_all');
      
      print('✅ Updated material: ${material.id}');
    } catch (e) {
      print('Error updating material: $e');
      rethrow;
    }
  }

  Future<void> deleteMaterial(String materialId) async {
    // ✅ Check if online before deleting
    if (NetworkService().isOffline) {
      throw Exception('Không thể xóa tài liệu khi offline');
    }
    
    try {
      // Get courseId before deleting for cache clear
      final material = state.firstWhere((m) => m.id == materialId);
      final courseId = material.courseId;
      
      await DatabaseService.deleteOne(
        collection: 'materials',
        id: materialId,
      );
      
      // Remove from state immediately
      state = state.where((m) => m.id != materialId).toList();
      
      // ✅ Clear cache after deleting
      await CacheService.clearCache('materials_$courseId');
      await CacheService.clearCache('materials_all');
      
      print('✅ Deleted material: $materialId');
    } catch (e) {
      print('Error deleting material: $e');
      rethrow;
    }
  }
  
  // ✅ Force reload from database
  Future<void> forceReload({String? courseId}) async {
    final cacheKey = courseId != null ? 'materials_$courseId' : 'materials_all';
    await CacheService.clearCache(cacheKey);
    _lastLoadedCourseId = null;
    _isLoading = false;
    await loadMaterials(courseId: courseId);
  }
}

class MaterialViewNotifier extends StateNotifier<List<app.MaterialView>> {
  MaterialViewNotifier() : super([]);

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

  Future<void> loadViews({String? materialId}) async {
    try {
      // ✅ 1. Try cache first
      final cacheKey = materialId != null ? 'material_views_$materialId' : 'material_views_all';
      final cached = await CacheService.getCachedCategoryData(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return app.MaterialView.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} material views from cache');
        
        if (NetworkService().isOnline) {
          _refreshViewsInBackground(materialId, cacheKey);
        }
        return;
      }

      // ✅ 2. If offline and no cache
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for material views');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database
      final filter = materialId != null ? {'materialId': materialId} : null;
      final data = await DatabaseService.find(
        collection: 'material_views',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return app.MaterialView.fromMap(map);
      }).toList();

      // ✅ 4. Save to cache
      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('✅ Loaded ${state.length} material views');
    } catch (e) {
      print('Error loading material views: $e');
      state = [];
    }
  }

  // ✅ Background refresh
  Future<void> _refreshViewsInBackground(String? materialId, String cacheKey) async {
    try {
      final filter = materialId != null ? {'materialId': materialId} : null;
      final data = await DatabaseService.find(
        collection: 'material_views',
        filter: filter,
      );
      
      state = data.map((e) {
        final map = _convertObjectIds(Map<String, dynamic>.from(e));
        return app.MaterialView.fromMap(map);
      }).toList();

      final cacheData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      await CacheService.cacheCategoryData(
        key: cacheKey,
        data: cacheData,
        durationMinutes: 30,
      );
      
      print('🔄 Background refresh: material views updated');
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  Future<void> recordView({
    required String materialId,
    required String studentId,
    bool downloaded = false,
  }) async {
    // ✅ Only record if online
    if (NetworkService().isOffline) {
      print('⚠️ Offline - view not recorded');
      return;
    }
    
    try {
      final existing = await DatabaseService.findOne(
        collection: 'material_views',
        filter: {
          'materialId': materialId,
          'studentId': studentId,
        },
      );
      
      if (existing != null) {
        final existingId = existing['_id'] is ObjectId 
            ? (existing['_id'] as ObjectId).toHexString() 
            : existing['_id'].toString();
            
        await DatabaseService.updateOne(
          collection: 'material_views',
          id: existingId,
          update: {
            'viewedAt': DateTime.now().toIso8601String(),
            'downloaded': downloaded,
          },
        );
      } else {
        final now = DateTime.now();
        final doc = <String, dynamic>{
          'materialId': materialId,
          'studentId': studentId,
          'viewedAt': now.toIso8601String(),
          'downloaded': downloaded,
        };
        
        await DatabaseService.insertOne(
          collection: 'material_views',
          document: doc,
        );
      }
      
      // ✅ Clear cache after recording
      await CacheService.clearCache('material_views_$materialId');
      await CacheService.clearCache('material_views_all');
      
      await loadViews(materialId: materialId);
    } catch (e) {
      print('Error recording material view: $e');
      rethrow;
    }
  }

  Future<void> trackDownload({
    required String materialId,
    required String studentId,
  }) async {
    try {
      await recordView(
        materialId: materialId,
        studentId: studentId,
        downloaded: true,
      );
    } catch (e) {
      print('Error tracking download: $e');
      rethrow;
    }
  }
}