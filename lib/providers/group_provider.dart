// providers/group_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart' as app;
import '../services/database_service.dart';

final groupProvider = StateNotifierProvider<GroupNotifier, List<app.Group>>((ref) => GroupNotifier());

class GroupNotifier extends StateNotifier<List<app.Group>> {
  GroupNotifier() : super([]);

  Future<void> loadGroups() async {
    try {
      final data = await DatabaseService.find(collection: 'groups');
      state = data.map(app.Group.fromMap).toList();
    } catch (e) {
      print('loadGroups error: $e');
      state = [];
    }
  }

  Future<void> createGroup({
    required String name,
    required String courseId,
  }) async {
    try {
      // ✅ FIXED: Send data in the format that works for BOTH web API and mobile
      final doc = {
        'name': name,
        'courseId': courseId,  // Keep as string - backend will handle it
        'studentIds': <String>[],  // Keep as array of strings
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'groups',
        document: doc,
      );

      state = [
        ...state,
        app.Group(
          id: insertedId,
          name: name,
          courseId: courseId,
          studentIds: [],
        ),
      ];
    } catch (e) {
      print('createGroup error: $e');
      rethrow;
    }
  }

  Future<void> updateGroup(String groupId, String newName) async {
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
    } catch (e) {
      print('updateGroup error: $e');
      rethrow;
    }
  }

  Future<void> addStudents(String groupId, List<String> studentIds) async {
    try {
      final groupDoc = await DatabaseService.findOne(
        collection: 'groups',
        filter: {'_id': groupId},
      );
      if (groupDoc == null) return;

      final courseId = groupDoc['courseId'].toString();
      final existingGroups = await DatabaseService.find(
        collection: 'groups',
        filter: {'courseId': courseId},
      );

      // Get current student IDs as strings
      final currentStudentIds = List<String>.from(
        (groupDoc['studentIds'] as List? ?? []).map((e) => e.toString())
      );

      for (final studentId in studentIds) {
        // Remove from other groups in same course
        for (final otherGroup in existingGroups) {
          final otherGroupId = otherGroup['_id'].toString();
          if (otherGroupId == groupId) continue;

          final otherStudentIds = List<String>.from(
            (otherGroup['studentIds'] as List? ?? []).map((e) => e.toString())
          );

          if (otherStudentIds.contains(studentId)) {
            otherStudentIds.remove(studentId);
            await DatabaseService.updateOne(
              collection: 'groups',
              id: otherGroupId,
              update: {'studentIds': otherStudentIds},
            );
          }
        }

        // Add to current group if not there
        if (!currentStudentIds.contains(studentId)) {
          currentStudentIds.add(studentId);
        }
      }

      await DatabaseService.updateOne(
        collection: 'groups',
        id: groupId,
        update: {'studentIds': currentStudentIds},
      );

      await loadGroups();
    } catch (e) {
      print('addStudents error: $e');
      rethrow;
    }
  }

  Future<void> removeStudent(String groupId, String studentId) async {
    try {
      final groupDoc = await DatabaseService.findOne(
        collection: 'groups',
        filter: {'_id': groupId},
      );
      if (groupDoc == null) return;

      final currentStudentIds = List<String>.from(
        (groupDoc['studentIds'] as List? ?? []).map((e) => e.toString())
      );
      currentStudentIds.remove(studentId);

      await DatabaseService.updateOne(
        collection: 'groups',
        id: groupId,
        update: {'studentIds': currentStudentIds},
      );

      await loadGroups();
    } catch (e) {
      print('removeStudent error: $e');
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'groups',
        id: id,
      );
      state = state.where((g) => g.id != id).toList();
    } catch (e) {
      print('deleteGroup error: $e');
    }
  }
}