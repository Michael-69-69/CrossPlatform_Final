// providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart';
import '../services/network_service.dart';
import 'semester_provider.dart';
import 'course_provider.dart';
import 'student_provider.dart';
import 'group_provider.dart';
import 'message_provider.dart';
import 'in_app_notification_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AppUser?> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(null) {
    // ✅ Load saved session when provider is created
    _loadSavedSession();
  }

  // ✅ Load saved session from cache
  Future<void> _loadSavedSession() async {
    try {
      final cached = await CacheService.getCachedCategoryData('auth_session');
      if (cached != null && cached.isNotEmpty) {
        final userMap = cached.first;
        state = AppUser.fromMap(userMap);
        print('✅ Restored user session: ${state?.fullName}');
        
        // Load all data after restoring session
        await _loadAllData();
      }
    } catch (e) {
      print('⚠️ Failed to restore session: $e');
      state = null;
    }
  }

  // ✅ Save session to cache
  Future<void> _saveSession(AppUser user) async {
    try {
      final userMap = {
        '_id': user.id,
        'full_name': user.fullName,
        'email': user.email,
        'role': user.role.name,
        if (user.avatarUrl != null) 'avatar_url': user.avatarUrl,
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
        if (user.code != null) 'code': user.code,
      };
      
      await CacheService.cacheCategoryData(
        key: 'auth_session',
        data: [userMap],
        durationMinutes: 10080, // 7 days
      );
      
      print('✅ Session saved');
    } catch (e) {
      print('⚠️ Failed to save session: $e');
    }
  }

  // ✅ Clear session from cache
  Future<void> _clearSession() async {
    try {
      await CacheService.clearCache('auth_session');
      print('✅ Session cleared');
    } catch (e) {
      print('⚠️ Failed to clear session: $e');
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyPassword(String password, String hash) {
    return _hashPassword(password) == hash;
  }

  /// ✅ ENHANCED: Load ALL data after successful login
  Future<void> _loadAllData() async {
    if (state == null) return;
    
    try {
      print('📊 Loading all data after login...');
      
      final user = state!;
      final isInstructor = user.role == UserRole.instructor;
      
      // ✅ 1. Load core shared data first (parallel)
      await Future.wait([
        ref.read(semesterProvider.notifier).loadSemesters(),
        ref.read(courseProvider.notifier).loadCourses(),
        ref.read(groupProvider.notifier).loadGroups(),
        // Only instructors need full student list
        if (isInstructor) ref.read(studentProvider.notifier).loadStudents(),
      ]);
      
      print('✅ Core data loaded (semesters, courses, groups)');
      
      // ✅ 2. Load user-specific data (conversations, notifications)
      await Future.wait([
        ref.read(conversationProvider.notifier).loadConversations(user.id, isInstructor),
        ref.read(inAppNotificationProvider.notifier).loadNotifications(user.id),
      ]);
      
      print('✅ User-specific data loaded (conversations, notifications)');
      
      print('✅ All data loaded successfully for ${user.fullName}');
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

      // Create user object
      final user = AppUser.fromMap(userMap);
      state = user;

      // ✅ Save session to cache
      await _saveSession(user);

      print('✅ Login successful: ${user.fullName} (${user.role.name})');

      // ✅ Load all data
      await _loadAllData();
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
        final user = AppUser.fromMap(insertedUser);
        state = user;

        // ✅ Save session to cache
        await _saveSession(user);

        print('✅ Registration successful: ${user.fullName}');

        // ✅ Load all data
        await _loadAllData();
      } else {
        throw Exception("Không thể tìm thấy người dùng sau khi tạo");
      }
    } catch (e) {
      print('❌ Register error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      // ✅ Clear session from cache
      await _clearSession();
      
      state = null;
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      state = null;
    }
  }

  // ✅ Manual refresh all data (pull to refresh)
  Future<void> refreshAllData() async {
    await _loadAllData();
  }

  // ✅ Check if user is logged in
  bool get isLoggedIn => state != null;

  // ✅ Get current user
  AppUser? get currentUser => state;

  // ✅ Check if user is instructor
  bool get isInstructor => state?.role == UserRole.instructor;

  // ✅ Check if user is student
  bool get isStudent => state?.role == UserRole.student;
}