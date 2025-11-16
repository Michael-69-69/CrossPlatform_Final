// providers/class_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/class.dart';
import '../services/mongodb_service.dart';

final classProvider = StateNotifierProvider<ClassNotifier, List<ClassModel>>((ref) {
  return ClassNotifier();
});

class ClassNotifier extends StateNotifier<List<ClassModel>> {
  ClassNotifier() : super([]) {
    loadClasses();
  }

  // === LOAD CLASSES ===
  Future<void> loadClasses() async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('classes');
      final data = await collection.find().toList();
      state = data.map((e) => ClassModel.fromMap(e)).toList();
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  // === CREATE CLASS ===
  Future<void> createClass({
    required String name,
    required String instructorId,
    required String instructorName,
  }) async {
    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('classes');
      final doc = {
        'name': name,
        'instructorId': ObjectId.fromHexString(instructorId), // CONVERT
        'instructorName': instructorName,
        'studentIds': <ObjectId>[],
        'schedule': <Map<String, dynamic>>[],
        'content': <Map<String, dynamic>>[],
        'exams': <Map<String, dynamic>>[],
      };
      await collection.insertOne(doc);
      await loadClasses();
    } catch (e) {
      print('Error creating class: $e');
      rethrow;
    }
  }

  // === ADD TO ARRAY ===
  Future<void> addExam(String classId, Map<String, dynamic> exam) async {
    await _pushToArray(classId, 'exams', exam);
  }

  Future<void> addContent(String classId, Map<String, dynamic> content) async {
    await _pushToArray(classId, 'content', content);
  }

  Future<void> addSchedule(String classId, Map<String, dynamic> shift) async {
    await _pushToArray(classId, 'schedule', shift);
  }

  Future<void> enrollStudent(String classId, String studentId) async {
    await _pushToArray(classId, 'studentIds', ObjectId.fromHexString(studentId)); // CONVERT
  }

  Future<void> kickStudent(String classId, String studentId) async {
    await _removeFromArray(classId, 'studentIds', ObjectId.fromHexString(studentId)); // CONVERT
  }

  // === EDIT & DELETE ARRAY ITEMS ===
  Future<void> updateContent(String classId, int index, Map<String, dynamic> updatedContent) async {
    await _updateArrayItem(classId, 'content', index, updatedContent);
  }

  Future<void> deleteContent(String classId, int index) async {
    await _removeArrayItem(classId, 'content', index);
  }

  Future<void> updateSchedule(String classId, int index, Map<String, dynamic> updatedShift) async {
    await _updateArrayItem(classId, 'schedule', index, updatedShift);
  }

  Future<void> deleteSchedule(String classId, int index) async {
    await _removeArrayItem(classId, 'schedule', index);
  }

  Future<void> deleteExam(String classId, int index) async {
    await _removeArrayItem(classId, 'exams', index);
  }

  Future<void> updateExam(String classId, int examIndex, Map<String, dynamic> updatedExam) async {
    final objectId = _parseObjectId(classId);
    if (objectId == null) return;

    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('classes');
      final classDoc = await collection.findOne(where.id(objectId));
      if (classDoc == null) return;

      final exams = List<dynamic>.from(classDoc['exams'] ?? []);
      if (examIndex < 0 || examIndex >= exams.length) return;

      exams[examIndex] = updatedExam;

      await collection.updateOne(
        where.id(objectId),
        ModifierBuilder().set('exams', exams),
      );

      // Update local state
      final classes = [...state];
      final classIndex = classes.indexWhere((c) => c.id == classId);
      if (classIndex != -1) {
        classes[classIndex] = classes[classIndex].copyWith(
          exams: exams.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
        state = classes;
      }
    } catch (e) {
      print('Error updating exam: $e');
    }
  }

  // === HELPER: PUSH TO ARRAY ===
  Future<void> _pushToArray(String classId, String field, dynamic value) async {
    final objectId = _parseObjectId(classId);
    if (objectId == null) {
      print('Invalid classId: $classId');
      return;
    }

    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('classes');
      await collection.updateOne(
        where.id(objectId),
        ModifierBuilder().push(field, value),
      );
      await loadClasses();
    } catch (e) {
      print('Error adding to $field: $e');
    }
  }

  // === HELPER: REMOVE FROM ARRAY ===
  Future<void> _removeFromArray(String classId, String field, dynamic value) async {
    final objectId = _parseObjectId(classId);
    if (objectId == null) {
      print('Invalid classId: $classId');
      return;
    }

    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('classes');
      await collection.updateOne(
        where.id(objectId),
        ModifierBuilder().pull(field, value),
      );
      await loadClasses();
    } catch (e) {
      print('Error removing from $field: $e');
    }
  }

  // === HELPER: UPDATE ARRAY ITEM ===
  Future<void> _updateArrayItem(String classId, String field, int index, Map<String, dynamic> updatedItem) async {
    final objectId = _parseObjectId(classId);
    if (objectId == null) {
      print('Invalid classId: $classId');
      return;
    }

    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('classes');
      final classDoc = await collection.findOne(where.id(objectId));
      if (classDoc == null) return;

      final array = List<dynamic>.from(classDoc[field] ?? []);
      if (index < 0 || index >= array.length) return;

      array[index] = updatedItem;

      await collection.updateOne(
        where.id(objectId),
        ModifierBuilder().set(field, array),
      );
      await loadClasses();
    } catch (e) {
      print('Error updating $field at index $index: $e');
    }
  }

  // === HELPER: REMOVE ARRAY ITEM BY INDEX ===
  Future<void> _removeArrayItem(String classId, String field, int index) async {
    final objectId = _parseObjectId(classId);
    if (objectId == null) {
      print('Invalid classId: $classId');
      return;
    }

    try {
      await MongoDBService.connect();
      final collection = MongoDBService.getCollection('classes');
      final classDoc = await collection.findOne(where.id(objectId));
      if (classDoc == null) return;

      final array = List<dynamic>.from(classDoc[field] ?? []);
      if (index < 0 || index >= array.length) return;

      array.removeAt(index);

      await collection.updateOne(
        where.id(objectId),
        ModifierBuilder().set(field, array),
      );
      await loadClasses();
    } catch (e) {
      print('Error deleting from $field at index $index: $e');
    }
  }

  // === HELPER: SAFE ObjectId.parse() ===
  ObjectId? _parseObjectId(String id) {
    if (id.length != 24) return null;
    try {
      return ObjectId.fromHexString(id);
    } catch (e) {
      print('Invalid ObjectId format: $id');
      return null;
    }
  }
}