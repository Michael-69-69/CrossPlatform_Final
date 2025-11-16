// providers/group_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/group.dart' as app;
import '../services/mongodb_service.dart';

final groupProvider = StateNotifierProvider<GroupNotifier, List<app.Group>>((ref) => GroupNotifier());

class GroupNotifier extends StateNotifier<List<app.Group>> {
  GroupNotifier() : super([]);

  Future<void> loadGroups() async {
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('groups');
      final data = await col.find().toList();
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
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('groups');
      final doc = {
        'name': name,
        'courseId': ObjectId.fromHexString(courseId),
        'studentIds': <ObjectId>[],
      };

      final result = await col.insertOne(doc);
      final insertedId = result.id as ObjectId;

      state = [
        ...state,
        app.Group(
          id: insertedId.toHexString(),
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

  Future<void> addStudents(String groupId, List<String> studentIds) async {
    final groupOid = _oid(groupId);
    if (groupOid == null) return;

    try {
      await MongoDBService.connect();
      final groupCol = MongoDBService.getCollection('groups');
      final groupDoc = await groupCol.findOne(where.id(groupOid));
      if (groupDoc == null) return;

      final courseId = groupDoc['courseId'] is ObjectId
          ? groupDoc['courseId'].toHexString()
          : groupDoc['courseId'].toString();

      final existingGroups = await groupCol
          .find(where.eq('courseId', ObjectId.fromHexString(courseId)))
          .toList();

      for (final studentId in studentIds) {
        final sid = ObjectId.fromHexString(studentId);
        final alreadyInGroup = existingGroups.any((g) {
          final ids = (g['studentIds'] as List).cast<ObjectId>();
          return ids.contains(sid);
        });
        if (alreadyInGroup) continue;

        await groupCol.updateOne(
          where.id(groupOid),
          ModifierBuilder().push('studentIds', sid),
        );
      }
      await loadGroups();
    } catch (e) {
      print('addStudents error: $e');
    }
  }

  Future<void> removeStudent(String groupId, String studentId) async {
    final oid = _oid(groupId);
    if (oid == null) return;
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('groups');
      await col.updateOne(
        where.id(oid),
        ModifierBuilder().pull('studentIds', ObjectId.fromHexString(studentId)),
      );
      await loadGroups();
    } catch (e) {
      print('removeStudent error: $e');
    }
  }

  ObjectId? _oid(String id) => id.length == 24 ? ObjectId.fromHexString(id) : null;
}