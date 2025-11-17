// providers/semester_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester.dart';
import '../services/database_service.dart';

final semesterProvider = StateNotifierProvider<SemesterNotifier, List<Semester>>((ref) => SemesterNotifier());

class SemesterNotifier extends StateNotifier<List<Semester>> {
  SemesterNotifier() : super([]);

  Future<void> loadSemesters() async {
    try {
      final data = await DatabaseService.find(collection: 'semesters');
      state = data.map(Semester.fromMap).toList();
    } catch (e, stack) {
      print('loadSemesters error: $e');
      print(stack);
      state = [];
    }
  }

  Future<void> createSemester({
    required String code,
    required String name,
  }) async {
    try {
      final doc = {
        'code': code,
        'name': name,
      };

      print('Inserting: $doc'); // DEBUG

      final insertedId = await DatabaseService.insertOne(
        collection: 'semesters',
        document: doc,
      );

      print('Inserted ID: $insertedId'); // DEBUG

      state = [
        ...state,
        Semester(
          id: insertedId,
          code: code,
          name: name,
        ),
      ];
    } catch (e, stack) {
      print('createSemester error: $e');
      print(stack);
      rethrow;
    }
  }

  Future<void> deleteSemester(String id) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'semesters',
        id: id,
      );
      state = state.where((s) => s.id != id).toList();
    } catch (e) {
      print('deleteSemester error: $e');
    }
  }
}