// providers/student_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/csv_preview_item.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';

final studentProvider = StateNotifierProvider<StudentNotifier, List<AppUser>>((ref) => StudentNotifier());

class StudentNotifier extends StateNotifier<List<AppUser>> {
  StudentNotifier() : super([]);

  // ══════════════════════════════════════════════════════════════
  // ✅ NEW: Helper to convert ObjectIds to strings for caching
  // ══════════════════════════════════════════════════════════════
  Map<String, dynamic> _convertObjectIds(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is ObjectId) {
        result[key] = value.toHexString();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is ObjectId) {
            return item.toHexString();
          } else if (item is Map<String, dynamic>) {
            return _convertObjectIds(item);
          } else if (item is Map) {
            return _convertObjectIds(Map<String, dynamic>.from(item));
          }
          if (item == null) return null;
          return item;
        }).where((item) => item != null).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertObjectIds(value);
      } else if (value is Map) {
        result[key] = _convertObjectIds(Map<String, dynamic>.from(value));
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  // ────── LOAD ALL STUDENTS ──────
  Future<void> loadStudents() async {
    try {
      // ✅ 1. Try to load from cache first
      final cached = await CacheService.getCachedCategoryData('students');
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return AppUser.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} students from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshStudentsInBackground();
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for students');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database if online or no cache
      await DatabaseService.connect();
      final data = await DatabaseService.find(
        collection: 'users',
        filter: {'role': 'student'},
      );
      
      // ✅ Convert ObjectIds BEFORE caching
      final convertedData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      
      state = convertedData.map((e) => AppUser.fromMap(e)).toList();
      
      // ✅ 4. Save CONVERTED data to cache
      await CacheService.cacheCategoryData(
        key: 'students',
        data: convertedData,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );
      
      print('✅ Loaded ${state.length} students from database');
    } catch (e, stack) {
      print('loadStudents error: $e');
      print('Stack: $stack');
      
      // ✅ 5. On error, try to fallback to cache
      final cached = await CacheService.getCachedCategoryData('students');
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) {
          final map = Map<String, dynamic>.from(e);
          return AppUser.fromMap(map);
        }).toList();
        print('📦 Loaded ${state.length} students from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh (silent update without blocking UI)
  Future<void> _refreshStudentsInBackground() async {
    try {
      await DatabaseService.connect();
      final data = await DatabaseService.find(
        collection: 'users',
        filter: {'role': 'student'},
      );
      
      // ✅ Convert ObjectIds before caching
      final convertedData = data.map((e) => _convertObjectIds(Map<String, dynamic>.from(e))).toList();
      
      state = convertedData.map((e) => AppUser.fromMap(e)).toList();
      
      // Update cache with converted data
      await CacheService.cacheCategoryData(
        key: 'students',
        data: convertedData,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );
      
      print('🔄 Background refresh: ${state.length} students updated');
    } catch (e) {
      print('Background refresh failed: $e');
      // Don't throw - this is a background operation
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
    String? password,
  }) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể tạo sinh viên khi offline');
    }
    
    try {
      await DatabaseService.connect();

      // Check duplicate code and email
      final exists = await DatabaseService.findOne(
        collection: 'users',
        filter: {
          r'$or': [
            {'code': code},
            if (email.isNotEmpty) {'email': email},
          ]
        },
      );
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
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'users',
        document: doc,
      );

      final insertedUser = await DatabaseService.findOne(
        collection: 'users',
        filter: {'_id': insertedId},
      );
      if (insertedUser != null) {
        final convertedUser = _convertObjectIds(Map<String, dynamic>.from(insertedUser));
        final newUser = AppUser.fromMap(convertedUser);
        state = [...state, newUser];
      }
      
      // ✅ Update cache
      await _updateCache();
      
      print('✅ Created student: $insertedId');
    } catch (e) {
      print('createStudent error: $e');
      rethrow;
    }
  }

  // ✅ NEW: Update cache from current state
  Future<void> _updateCache() async {
    try {
      final cacheData = state.map((s) => <String, dynamic>{
        '_id': s.id,
        'code': s.code,
        'email': s.email,
        'full_name': s.fullName,
        'role': s.role.name,
        'created_at': s.createdAt?.toIso8601String(),
        'updated_at': s.updatedAt?.toIso8601String(),
      }).toList();
      
      await CacheService.cacheCategoryData(
        key: 'students',
        data: cacheData,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );
      
      print('📦 Student cache updated: ${state.length} students');
    } catch (e) {
      print('⚠️ Failed to update student cache: $e');
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
    if (NetworkService().isOffline) {
      throw Exception('Không thể import khi offline');
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

    await DatabaseService.connect();

    for (var item in itemsToImport) {
      try {
        // Double-check existence before insert
        final existing = await DatabaseService.findOne(
          collection: 'users',
          filter: {
            r'$or': [
              {'code': item.code},
              if (item.email.isNotEmpty) {'email': item.email},
            ]
          },
        );

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
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final insertedId = await DatabaseService.insertOne(
          collection: 'users',
          document: doc,
        );

        final insertedUser = await DatabaseService.findOne(
          collection: 'users',
          filter: {'_id': insertedId},
        );
        if (insertedUser != null) {
          final convertedUser = _convertObjectIds(Map<String, dynamic>.from(insertedUser));
          final user = AppUser.fromMap(convertedUser);
          created.add(user);
        }
      } catch (e) {
        errors.add('Dòng ${item.rowIndex}: ${item.code} - ${item.fullName} (lỗi: $e)');
      }
    }

    // ✅ Clear cache and reload
    await CacheService.clearCache('students');
    await loadStudents();
    
    print('✅ Imported ${created.length} students from CSV');
    
    return {
      'created': created,
      'errors': errors,
      'skipped': skipped,
      'total': previewItems.length,
    };
  }

  // ────── LEGACY: IMPORT FROM CSV (for backward compatibility) ──────
  Future<List<AppUser>> importStudentsFromCsv(String csvContent) async {
    if (NetworkService().isOffline) {
      throw Exception('Không thể import khi offline');
    }
    
    if (csvContent.trim().isEmpty) return [];

    final rows = const CsvToListConverter().convert(csvContent);
    final List<AppUser> created = [];

    if (rows.isEmpty) return created;

    await DatabaseService.connect();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;

      final code = row[0].toString().trim();
      final fullName = row[1].toString().trim();
      final email = row[2].toString().trim().toLowerCase();

      if (code.isEmpty || fullName.isEmpty) continue;

      // Check if exists
      final existing = await DatabaseService.findOne(
        collection: 'users',
        filter: {
          r'$or': [
            {'email': email},
            {'code': code},
          ]
        },
      );

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
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      try {
        final insertedId = await DatabaseService.insertOne(
          collection: 'users',
          document: doc,
        );

        final insertedUser = await DatabaseService.findOne(
          collection: 'users',
          filter: {'_id': insertedId},
        );
        if (insertedUser != null) {
          final convertedUser = _convertObjectIds(Map<String, dynamic>.from(insertedUser));
          final user = AppUser.fromMap(convertedUser);
          created.add(user);
        }
      } catch (e) {
        print('CSV insert error (row $i): $e');
      }
    }

    // ✅ Clear cache and reload
    await CacheService.clearCache('students');
    await loadStudents();
    
    print('✅ Legacy CSV import: ${created.length} students');
    
    return created;
  }

  // ✅ Force refresh from database
  Future<void> refresh() async {
    await CacheService.clearCache('students');
    await loadStudents();
  }

  // ✅ Get student by ID
  AppUser? getStudentById(String id) {
    try {
      return state.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // ✅ Get students by IDs
  List<AppUser> getStudentsByIds(List<String> ids) {
    return state.where((s) => ids.contains(s.id)).toList();
  }

  // ✅ Clear state
  void clearState() {
    state = [];
  }
}