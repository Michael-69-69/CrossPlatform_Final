// providers/course_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/course.dart';
import '../services/mongodb_service.dart';

final courseProvider = StateNotifierProvider<CourseNotifier, List<Course>>((ref) => CourseNotifier());

class CourseNotifier extends StateNotifier<List<Course>> {
  CourseNotifier() : super([]);

  Future<void> loadCourses() async {
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('courses');
      final data = await col.find().toList();
      state = data.map(Course.fromMap).toList();
    } catch (e) {
      print('loadCourses error: $e');
      state = [];
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
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('courses');
      final doc = {
        'code': code,
        'name': name,
        'sessions': sessions,
        'semesterId': ObjectId.fromHexString(semesterId),
        'instructorId': ObjectId.fromHexString(instructorId),
        'instructorName': instructorName,
      };

      final result = await col.insertOne(doc);
      final insertedId = result.id as ObjectId;

      state = [
        ...state,
        Course(
          id: insertedId.toHexString(),
          code: code,
          name: name,
          sessions: sessions,
          semesterId: semesterId,
          instructorId: instructorId,
          instructorName: instructorName,
        ),
      ];
    } catch (e) {
      print('createCourse error: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(String id) async {
    final oid = _oid(id);
    if (oid == null) return;
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('courses');
      await col.deleteOne(where.id(oid));
      state = state.where((c) => c.id != id).toList();
    } catch (e) {
      print('deleteCourse error: $e');
    }
  }

  ObjectId? _oid(String id) => id.length == 24 ? ObjectId.fromHexString(id) : null;
}