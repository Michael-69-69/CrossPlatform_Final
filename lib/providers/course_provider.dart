// providers/course_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../services/database_service.dart';

final courseProvider = StateNotifierProvider<CourseNotifier, List<Course>>((ref) => CourseNotifier());

class CourseNotifier extends StateNotifier<List<Course>> {
  CourseNotifier() : super([]);

  Future<void> loadCourses() async {
    try {
      final data = await DatabaseService.find(collection: 'courses');
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
      final doc = {
        'code': code,
        'name': name,
        'sessions': sessions,
        'semesterId': semesterId,
        'instructorId': instructorId,
        'instructorName': instructorName,
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'courses',
        document: doc,
      );

      state = [
        ...state,
        Course(
          id: insertedId,
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
    try {
      await DatabaseService.deleteOne(
        collection: 'courses',
        id: id,
      );
      state = state.where((c) => c.id != id).toList();
    } catch (e) {
      print('deleteCourse error: $e');
    }
  }
}