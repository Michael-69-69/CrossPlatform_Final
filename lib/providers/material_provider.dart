// providers/material_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/material.dart' as app;
import '../services/mongodb_service.dart';

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
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('materials');
      var query = where;
      if (courseId != null) {
        query = where.eq('courseId', ObjectId.fromHexString(courseId));
      }
      final data = await collection.find(query).toList();
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
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('materials');
      final now = DateTime.now();
      final doc = {
        'courseId': ObjectId.fromHexString(courseId),
        'title': title,
        if (description != null) 'description': description,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await collection.insertOne(doc);
      await loadMaterials();
    } catch (e) {
      print('Error creating material: $e');
      rethrow;
    }
  }

  Future<void> updateMaterial(app.Material material) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('materials');
      final now = DateTime.now();
      await collection.updateOne(
        where.id(ObjectId.fromHexString(material.id)),
        ModifierBuilder()
          ..set('title', material.title)
          ..set('description', material.description)
          ..set('attachments', material.attachments.map((a) => a.toMap()).toList())
          ..set('updatedAt', now.toIso8601String()),
      );
      await loadMaterials();
    } catch (e) {
      print('Error updating material: $e');
      rethrow;
    }
  }

  Future<void> deleteMaterial(String materialId) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('materials');
      await collection.deleteOne(where.id(ObjectId.fromHexString(materialId)));
      await loadMaterials();
    } catch (e) {
      print('Error deleting material: $e');
      rethrow;
    }
  }
}

class MaterialViewNotifier extends StateNotifier<List<app.MaterialView>> {
  MaterialViewNotifier() : super([]) {
    loadViews();
  }

  Future<void> loadViews({String? materialId}) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('material_views');
      var query = where;
      if (materialId != null) {
        query = where.eq('materialId', ObjectId.fromHexString(materialId));
      }
      final data = await collection.find(query).toList();
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
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('material_views');
      
      // Check if view already exists
      final existing = await collection.findOne(where
          .eq('materialId', ObjectId.fromHexString(materialId))
          .eq('studentId', ObjectId.fromHexString(studentId)));
      
      if (existing != null) {
        // Update existing view
        await collection.updateOne(
          where.id(existing['_id'] as ObjectId),
          ModifierBuilder()
            ..set('viewedAt', DateTime.now().toIso8601String())
            ..set('downloaded', downloaded),
        );
      } else {
        // Create new view
        final now = DateTime.now();
        final doc = {
          'materialId': ObjectId.fromHexString(materialId),
          'studentId': ObjectId.fromHexString(studentId),
          'viewedAt': now.toIso8601String(),
          'downloaded': downloaded,
        };
        await collection.insertOne(doc);
      }
      await loadViews();
    } catch (e) {
      print('Error recording material view: $e');
      rethrow;
    }
  }
}

