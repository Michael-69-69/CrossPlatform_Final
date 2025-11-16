// providers/student_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/user.dart';
import '../services/mongodb_service.dart';

final studentProvider = StateNotifierProvider<StudentNotifier, List<AppUser>>((ref) => StudentNotifier());

class StudentNotifier extends StateNotifier<List<AppUser>> {
  StudentNotifier() : super([]);

  // ────── LOAD ALL STUDENTS ──────
  Future<void> loadStudents() async {
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('users');
      final data = await col.find(where.eq('role', 'student')).toList();
      state = data.map(AppUser.fromMap).toList();
    } catch (e) {
      print('loadStudents error: $e');
      state = [];
    }
  }

  // ────── CREATE ONE STUDENT ──────
  Future<void> createStudent({
    required String code,
    required String name,
    required String email,
  }) async {
    try {
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('users');

      // Check duplicate code
      final exists = await col.findOne(where.eq('code', code));
      if (exists != null) {
        throw Exception('Mã sinh viên "$code" đã tồn tại');
      }

      final doc = {
        'code': code,
        'email': email,
        'name': name,
        'role': 'student',
      };

      final result = await col.insertOne(doc);
      final insertedId = result.id as ObjectId;

      final newUser = AppUser(
        id: insertedId.toHexString(),
        code: code,
        name: name,
        email: email,
        role: UserRole.student,
      );

      state = [...state, newUser];
    } catch (e) {
      print('createStudent error: $e');
      rethrow;
    }
  }

  // ────── IMPORT FROM CSV ──────
  Future<List<AppUser>> importStudentsFromCsv(String csvContent) async {
    if (csvContent.trim().isEmpty) return [];

    final rows = const CsvToListConverter().convert(csvContent);
    final List<AppUser> created = [];

    if (rows.isEmpty) return created;

    await MongoDBService.connect();
    final col = MongoDBService.getCollection('users');

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;

      final code = row[0].toString().trim();
      final name = row[1].toString().trim();
      final email = row[2].toString().trim().toLowerCase();

      if (code.isEmpty || name.isEmpty) continue;

      // FIXED: Use $or operator directly in map
      final existing = await col.findOne({
        r'$or': [
          {'email': email},
          {'code': code},
        ]
      });

      if (existing != null) continue;

      final doc = {
        'code': code,
        'email': email,
        'name': name,
        'role': 'student',
      };

      try {
        final result = await col.insertOne(doc);
        final insertedId = result.id as ObjectId;

        final user = AppUser(
          id: insertedId.toHexString(),
          code: code,
          email: email,
          name: name,
          role: UserRole.student,
        );

        created.add(user);
      } catch (e) {
        print('CSV insert error (row $i): $e');
      }
    }

    await loadStudents(); // Refresh full list
    return created;
  }
}