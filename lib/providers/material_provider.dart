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
  MaterialNotifier() : super([]) {
    loadMaterials();
  }

  Future<void> loadMaterials({String? courseId}) async {
    try {
      final filter = courseId != null ? {'courseId': courseId} : null;
      final data = await DatabaseService.find(
        collection: 'materials',
        filter: filter,
      );
      state = data.map((e) => app.Material.fromMap(e)).toList();
    } catch (e) {
      print('Error loading materials: $e');
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
      final doc = {
        'courseId': courseId,
        'title': title,
        if (description != null) 'description': description,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      
      await DatabaseService.insertOne(
        collection: 'materials',
        document: doc,
      );
      
      await loadMaterials();
    } catch (e) {
      print('Error creating material: $e');
      rethrow;
    }
  }

  Future<void> updateMaterial(app.Material material) async {
    try {
      final now = DateTime.now();
      
      await DatabaseService.updateOne(
        collection: 'materials',
        id: material.id,
        update: {
          'title': material.title,
          if (material.description != null) 'description': material.description,
          'attachments': material.attachments.map((a) => a.toMap()).toList(),
          'updatedAt': now.toIso8601String(),
        },
      );
      
      await loadMaterials();
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
      await loadMaterials();
    } catch (e) {
      print('Error deleting material: $e');
      rethrow;
    }
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
      state = data.map((e) => app.MaterialView.fromMap(e)).toList();
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
      // Check if view already exists
      final existing = await DatabaseService.findOne(
        collection: 'material_views',
        filter: {
          'materialId': materialId,
          'studentId': studentId,
        },
      );
      
      if (existing != null) {
        // Update existing view
        await DatabaseService.updateOne(
          collection: 'material_views',
          id: existing['_id'].toString(),
          update: {
            'viewedAt': DateTime.now().toIso8601String(),
            'downloaded': downloaded,
          },
        );
      } else {
        // Create new view
        final now = DateTime.now();
        final doc = {
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
      
      await loadViews();
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