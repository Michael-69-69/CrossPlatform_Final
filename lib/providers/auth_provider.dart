// providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../services/database_service.dart';
import 'semester_provider.dart';
import 'course_provider.dart';
import 'student_provider.dart';
import 'group_provider.dart';
import 'assignment_provider.dart';
import 'announcement_provider.dart';
import 'quiz_provider.dart';
import 'material_provider.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyPassword(String password, String hash) {
    return _hashPassword(password) == hash;
  }

  /// Load all data after successful login
  Future<void> loadAllData(ProviderContainer container) async {
    try {
      print('📊 Loading all data after login...');
      
      await Future.wait([
        container.read(semesterProvider.notifier).loadSemesters(),
        container.read(courseProvider.notifier).loadCourses(),
        container.read(studentProvider.notifier).loadStudents(),
        container.read(groupProvider.notifier).loadGroups(),
        container.read(assignmentProvider.notifier).loadAssignments(''),
        container.read(quizProvider.notifier).loadQuizzes(),
        container.read(questionProvider.notifier).loadQuestions(),
        container.read(materialProvider.notifier).loadMaterials(),
      ]);
      
      print('✅ All data loaded successfully');
    } catch (e) {
      print('⚠️ Error loading data: $e');
      // Don't throw - allow login to proceed even if some data fails to load
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final userMap = await DatabaseService.findOne(
        collection: 'users',
        filter: {'email': email},
      );

      if (userMap == null) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      // Check password
      final storedPassword = userMap['password_hash'] ?? userMap['password'];
      if (storedPassword == null) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      // Verify password (hash or plain text for backward compatibility)
      final bool passwordValid = storedPassword.toString().length == 64
          ? _verifyPassword(password, storedPassword.toString())
          : password == storedPassword.toString();

      if (!passwordValid) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      // Set auth state
      state = AppUser.fromMap(userMap);

      // Load all data
      final container = ProviderContainer();
      await loadAllData(container);
      container.dispose();

      print('✅ Login successful: ${state?.fullName} (${state?.role.name})');
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? code,
  }) async {
    try {
      await DatabaseService.connect();
      await DatabaseService.ensureCollectionExists('users');

      // Check if email already exists
      final existingUser = await DatabaseService.findOne(
        collection: 'users',
        filter: {'email': email},
      );

      if (existingUser != null) {
        throw Exception("Email đã được sử dụng");
      }

      final now = DateTime.now();
      final passwordHash = _hashPassword(password);

      final userDoc = <String, dynamic>{
        'full_name': fullName,
        'email': email,
        'password_hash': passwordHash,
        'role': role.name,
        if (code != null) 'code': code,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'users',
        document: userDoc,
      );

      final insertedUser = await DatabaseService.findOne(
        collection: 'users',
        filter: {'_id': insertedId},
      );

      if (insertedUser != null) {
        state = AppUser.fromMap(insertedUser);

        // Load all data
        final container = ProviderContainer();
        await loadAllData(container);
        container.dispose();

        print('✅ Registration successful: ${state?.fullName}');
      } else {
        throw Exception("Không thể tìm thấy người dùng sau khi tạo");
      }
    } catch (e) {
      print('❌ Register error: $e');
      rethrow;
    }
  }

  void logout() {
    state = null;
    print('👋 Logged out');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier();
});