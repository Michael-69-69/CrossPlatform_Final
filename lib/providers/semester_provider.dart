// providers/semester_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/semester.dart';
import '../services/mongodb_service.dart';

final semesterProvider = StateNotifierProvider<SemesterNotifier, List<Semester>>((ref) => SemesterNotifier());

class SemesterNotifier extends StateNotifier<List<Semester>> {
  SemesterNotifier() : super([]);

  Future<void> loadSemesters() async {
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('semesters');
      final data = await col.find().toList();
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
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('semesters');

      // CRITICAL FIX: Use Map.from() to break internal reference
      final doc = Map<String, dynamic>.from({
        'code': code,
        'name': name,
      });

      print('Inserting: $doc'); // DEBUG

      final result = await col.insertOne(doc);
      final insertedId = result.id as ObjectId;

      print('Inserted ID: ${insertedId.toHexString()}'); // DEBUG

      state = [
        ...state,
        Semester(
          id: insertedId.toHexString(),
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
    final oid = _oid(id);
    if (oid == null) return;
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('semesters');
      await col.deleteOne(where.id(oid));
      state = state.where((s) => s.id != id).toList();
    } catch (e) {
      print('deleteSemester error: $e');
    }
  }

  ObjectId? _oid(String id) => id.length == 24 ? ObjectId.fromHexString(id) : null;
}