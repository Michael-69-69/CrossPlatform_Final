// providers/student_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/csv_preview_item.dart';
import '../services/mongodb_service.dart';

final studentProvider = StateNotifierProvider<StudentNotifier, List<AppUser>>((ref) => StudentNotifier());

class StudentNotifier extends StateNotifier<List<AppUser>> {
  StudentNotifier() : super([]);

  // ────── LOAD ALL STUDENTS ──────
  Future<void> loadStudents() async {
    try {
      if (MongoDBService.isWebPlatform) {
        print('loadStudents: Skipping on web platform');
        state = [];
        return;
      }
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('users');
      final data = await col.find(where.eq('role', 'student')).toList();
      state = data.map(AppUser.fromMap).toList();
    } catch (e) {
      print('loadStudents error: $e');
      state = [];
    }
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ────── CREATE ONE STUDENT ──────
  Future<void> createStudent({
    required String code,
    required String fullName,
    required String email,
    String? password, // Optional, defaults to code if not provided
  }) async {
    try {
      if (MongoDBService.isWebPlatform) {
        throw Exception("MongoDB không hỗ trợ trên web. Vui lòng sử dụng ứng dụng mobile hoặc desktop.");
      }
      await MongoDBService.connect();
      final col = MongoDBService.getCollection('users');

      // Check duplicate code and email
      final exists = await col.findOne({
        r'$or': [
          {'code': code},
          {'email': email.isNotEmpty ? email : null},
        ]
      });
      if (exists != null) {
        if (exists['code'] == code) {
          throw Exception('Mã sinh viên "$code" đã tồn tại');
        }
        throw Exception('Email "$email" đã được sử dụng');
      }

      // Default password is the student code
      final studentPassword = password ?? code;
      final passwordHash = _hashPassword(studentPassword);

      final now = DateTime.now();
      final doc = {
        'code': code,
        'email': email.isNotEmpty ? email : '$code@school.com',
        'full_name': fullName,
        'password_hash': passwordHash,
        'role': 'student',
        'created_at': now,
        'updated_at': now,
      };

      final result = await col.insertOne(doc);
      final insertedId = result.id as ObjectId;

      final insertedUser = await col.findOne(where.id(insertedId));
      if (insertedUser != null) {
        final newUser = AppUser.fromMap(insertedUser);
        state = [...state, newUser];
      }
    } catch (e) {
      print('createStudent error: $e');
      rethrow;
    }
  }

  // ────── PREVIEW CSV DATA ──────
  Future<List<CsvPreviewItem>> previewCsvData(String csvContent, List<AppUser> existingStudents) async {
    if (csvContent.trim().isEmpty) return [];

    final rows = const CsvToListConverter().convert(csvContent);
    final List<CsvPreviewItem> previewItems = [];

    if (rows.isEmpty) return previewItems;

    // Create lookup maps for existing students
    final existingCodes = existingStudents.map((s) => s.code?.toLowerCase() ?? '').where((c) => c.isNotEmpty).toSet();
    final existingEmails = existingStudents.map((s) => s.email.toLowerCase()).where((e) => e.isNotEmpty).toSet();
    final seenCodes = <String>{};
    final seenEmails = <String>{};

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) {
        previewItems.add(CsvPreviewItem(
          rowIndex: i + 1,
          code: '',
          fullName: '',
          email: '',
          status: 'invalid',
          errorMessage: 'Thiếu cột dữ liệu (cần ít nhất 3 cột: Mã SV, Tên, Email)',
        ));
        continue;
      }

      final code = row[0].toString().trim();
      final fullName = row[1].toString().trim();
      final email = row[2].toString().trim().toLowerCase();

      // Validation
      if (code.isEmpty) {
        previewItems.add(CsvPreviewItem(
          rowIndex: i + 1,
          code: code,
          fullName: fullName,
          email: email,
          status: 'invalid',
          errorMessage: 'Mã SV không được để trống',
        ));
        continue;
      }

      if (fullName.isEmpty) {
        previewItems.add(CsvPreviewItem(
          rowIndex: i + 1,
          code: code,
          fullName: fullName,
          email: email,
          status: 'invalid',
          errorMessage: 'Tên không được để trống',
        ));
        continue;
      }

      // Check for duplicates within CSV
      if (seenCodes.contains(code.toLowerCase())) {
        previewItems.add(CsvPreviewItem(
          rowIndex: i + 1,
          code: code,
          fullName: fullName,
          email: email,
          status: 'duplicate',
          errorMessage: 'Mã SV trùng lặp trong file CSV',
        ));
        continue;
      }

      if (email.isNotEmpty && seenEmails.contains(email)) {
        previewItems.add(CsvPreviewItem(
          rowIndex: i + 1,
          code: code,
          fullName: fullName,
          email: email,
          status: 'duplicate',
          errorMessage: 'Email trùng lặp trong file CSV',
        ));
        continue;
      }

      seenCodes.add(code.toLowerCase());
      if (email.isNotEmpty) seenEmails.add(email);

      // Check if exists in database
      if (existingCodes.contains(code.toLowerCase()) || (email.isNotEmpty && existingEmails.contains(email))) {
        previewItems.add(CsvPreviewItem(
          rowIndex: i + 1,
          code: code,
          fullName: fullName,
          email: email,
          status: 'exists',
          errorMessage: 'Đã tồn tại trong hệ thống',
        ));
      } else {
        previewItems.add(CsvPreviewItem(
          rowIndex: i + 1,
          code: code,
          fullName: fullName,
          email: email,
          status: 'new',
        ));
      }
    }

    return previewItems;
  }

  // ────── IMPORT FROM CSV WITH PREVIEW ──────
  Future<Map<String, dynamic>> importStudentsFromCsvPreview(
    List<CsvPreviewItem> previewItems,
  ) async {
    if (MongoDBService.isWebPlatform) {
      throw Exception("MongoDB không hỗ trợ trên web. Vui lòng sử dụng ứng dụng mobile hoặc desktop.");
    }

    final List<AppUser> created = [];
    final List<String> errors = [];
    final List<String> skipped = [];

    // Filter only selected new items
    final itemsToImport = previewItems.where((item) => item.selected && item.status == 'new').toList();

    if (itemsToImport.isEmpty) {
      return {
        'created': created,
        'errors': errors,
        'skipped': skipped,
        'total': previewItems.length,
      };
    }

    await MongoDBService.connect();
    final col = MongoDBService.getCollection('users');

    for (var item in itemsToImport) {
      try {
        // Double-check existence before insert
        final existing = await col.findOne({
          r'$or': [
            {'code': item.code},
            if (item.email.isNotEmpty) {'email': item.email},
          ]
        });

        if (existing != null) {
          skipped.add('Dòng ${item.rowIndex}: ${item.code} - ${item.fullName} (đã tồn tại)');
          continue;
        }

        // Default password is the student code
        final passwordHash = _hashPassword(item.code);

        final now = DateTime.now();
        final doc = {
          'code': item.code,
          'email': item.email.isNotEmpty ? item.email : '${item.code}@school.com',
          'full_name': item.fullName,
          'password_hash': passwordHash,
          'role': 'student',
          'created_at': now,
          'updated_at': now,
        };

        final result = await col.insertOne(doc);
        final insertedId = result.id as ObjectId;

        final insertedUser = await col.findOne(where.id(insertedId));
        if (insertedUser != null) {
          final user = AppUser.fromMap(insertedUser);
          created.add(user);
        }
      } catch (e) {
        errors.add('Dòng ${item.rowIndex}: ${item.code} - ${item.fullName} (lỗi: $e)');
      }
    }

    await loadStudents(); // Refresh full list
    return {
      'created': created,
      'errors': errors,
      'skipped': skipped,
      'total': previewItems.length,
    };
  }

  // ────── LEGACY: IMPORT FROM CSV (for backward compatibility) ──────
  Future<List<AppUser>> importStudentsFromCsv(String csvContent) async {
    if (csvContent.trim().isEmpty) return [];

    if (MongoDBService.isWebPlatform) {
      throw Exception("MongoDB không hỗ trợ trên web. Vui lòng sử dụng ứng dụng mobile hoặc desktop.");
    }

    final rows = const CsvToListConverter().convert(csvContent);
    final List<AppUser> created = [];

    if (rows.isEmpty) return created;

    await MongoDBService.connect();
    final col = MongoDBService.getCollection('users');

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;

      final code = row[0].toString().trim();
      final fullName = row[1].toString().trim();
      final email = row[2].toString().trim().toLowerCase();

      if (code.isEmpty || fullName.isEmpty) continue;

      // FIXED: Use $or operator directly in map
      final existing = await col.findOne({
        r'$or': [
          {'email': email},
          {'code': code},
        ]
      });

      if (existing != null) continue;

      // Default password is the student code
      final studentPassword = code;
      final passwordHash = _hashPassword(studentPassword);

      final now = DateTime.now();
      final doc = {
        'code': code,
        'email': email.isNotEmpty ? email : '$code@school.com',
        'full_name': fullName,
        'password_hash': passwordHash,
        'role': 'student',
        'created_at': now,
        'updated_at': now,
      };

      try {
        final result = await col.insertOne(doc);
        final insertedId = result.id as ObjectId;

        final insertedUser = await col.findOne(where.id(insertedId));
        if (insertedUser != null) {
          final user = AppUser.fromMap(insertedUser);
          created.add(user);
        }
      } catch (e) {
        print('CSV insert error (row $i): $e');
      }
    }

    await loadStudents(); // Refresh full list
    return created;
  }
}