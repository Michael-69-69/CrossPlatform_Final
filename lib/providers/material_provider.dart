// providers/material_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/material.dart' as app;
import '../services/database_service.dart';

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

  Future<void> loadMaterials({String? courseId}) async {
    // ✅ FIX: Don't reload if same course and not empty (unless forced)
    if (_isLoading || (_lastLoadedCourseId == courseId && state.isNotEmpty)) {
      print('⏭️ Skipping duplicate load for courseId: $courseId');
      return;
    }
    
    try {
      _isLoading = true;
      _lastLoadedCourseId = courseId;
      
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'materials',
        filter: filter,
      );
      
      // ✅ FIX: Explicit type casting for mobile
      state = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return app.Material.fromMap(map);
      }).toList();
      
      print('✅ Loaded ${state.length} materials for course: $courseId');
    } catch (e) {
      print('Error loading materials: $e');
      state = [];
    } finally {
      _isLoading = false;
    }
  }

  Future<void> createMaterial({
    required String courseId,
    required String title,
    String? description,
    required List<app.MaterialAttachment> attachments,
  }) async {
    try {
      final now = DateTime.now();
      
      // ✅ FIX: Explicit type casting for nested objects
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
      
      print('✅ Created material: $insertedId');
    } catch (e, stackTrace) {
      print('Error creating material: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateMaterial(app.Material material) async {
    try {
      final now = DateTime.now();
      
      // ✅ FIX: Explicit type casting
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
      
      print('✅ Updated material: ${material.id}');
    } catch (e) {
      print('Error updating material: $e');
      rethrow;
    }
  }

  Future<void> deleteMaterial(String materialId) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'materials',
        id: materialId,
      );
      
      // Remove from state immediately
      state = state.where((m) => m.id != materialId).toList();
      
      print('✅ Deleted material: $materialId');
    } catch (e) {
      print('Error deleting material: $e');
      rethrow;
    }
  }
  
  // ✅ FIX: Force reload
  Future<void> forceReload({String? courseId}) async {
    _lastLoadedCourseId = null;
    _isLoading = false;
    await loadMaterials(courseId: courseId);
  }
}

class MaterialViewNotifier extends StateNotifier<List<app.MaterialView>> {
  MaterialViewNotifier() : super([]);

  Future<void> loadViews({String? materialId}) async {
    try {
      final filter = materialId != null ? {'materialId': materialId} : null;
      final data = await DatabaseService.find(
        collection: 'material_views',
        filter: filter,
      );
      
      // ✅ FIX: Explicit type casting
      state = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return app.MaterialView.fromMap(map);
      }).toList();
    } catch (e) {
      print('Error loading material views: $e');
    }
  }

  Future<void> recordView({
    required String materialId,
    required String studentId,
    bool downloaded = false,
  }) async {
    try {
      final existing = await DatabaseService.findOne(
        collection: 'material_views',
        filter: {
          'materialId': materialId,
          'studentId': studentId,
        },
      );
      
      if (existing != null) {
        await DatabaseService.updateOne(
          collection: 'material_views',
          id: existing['_id'].toString(),
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