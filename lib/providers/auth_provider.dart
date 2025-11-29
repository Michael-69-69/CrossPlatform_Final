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
import 'assignment_provider.dart';
import 'announcement_provider.dart';
import 'quiz_provider.dart';
import 'material_provider.dart';
import 'message_provider.dart';
import 'forum_provider.dart';
import 'in_app_notification_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AppUser?> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(null) {
    _loadSavedSession();
  }

  // ══════════════════════════════════════════════
  // SESSION MANAGEMENT
  // ══════════════════════════════════════════════

  Future<void> _loadSavedSession() async {
    try {
      final cached = await CacheService.getCachedCategoryData('auth_session');
      if (cached != null && cached.isNotEmpty) {
        final userMap = cached.first;
        state = AppUser.fromMap(userMap);
        print('✅ Restored user session: ${state?.fullName}');
        
        await _loadAllData(skipCacheClear: true);
      }
    } catch (e) {
      print('⚠️ Failed to restore session: $e');
      state = null;
    }
  }

  Future<void> _saveSession(AppUser user) async {
    try {
      final userMap = {
        '_id': user.id,
        'full_name': user.fullName,
        'email': user.email,
        'role': user.role.name,
        if (user.avatarUrl != null) 'avatar_url': user.avatarUrl,
        if (user.avatarBase64 != null) 'avatar_base64': user.avatarBase64,
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
        if (user.code != null) 'code': user.code,
        if (user.phone != null) 'phone': user.phone,
        if (user.dateOfBirth != null) 'date_of_birth': user.dateOfBirth!.toIso8601String(),
        if (user.address != null) 'address': user.address,
        if (user.bio != null) 'bio': user.bio,
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

  Future<void> _clearSession() async {
    try {
      await CacheService.clearCache('auth_session');
      print('✅ Session cleared');
    } catch (e) {
      print('⚠️ Failed to clear session: $e');
    }
  }

  // ══════════════════════════════════════════════
  // PASSWORD UTILITIES
  // ══════════════════════════════════════════════

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyPassword(String password, String hash) {
    return _hashPassword(password) == hash;
  }

  // ══════════════════════════════════════════════
  // DATA LOADING
  // ══════════════════════════════════════════════

  Future<void> _loadAllData({bool skipCacheClear = false}) async {
    if (state == null) return;
    
    try {
      print('📊 Loading all data after login...');
      
      final user = state!;
      final isInstructor = user.role == UserRole.instructor;

      if (!skipCacheClear && NetworkService().isOnline) {
        print('🗑️ Clearing all cache for fresh data...');
        await CacheService.clearAllCache();
        await _saveSession(user);
        print('✅ Cache cleared, fetching fresh data from server');
      }
      
      // 1. Load core shared data
      await Future.wait([
        ref.read(semesterProvider.notifier).loadSemesters(),
        ref.read(courseProvider.notifier).loadCourses(),
        ref.read(groupProvider.notifier).loadGroups(),
        if (isInstructor) ref.read(studentProvider.notifier).loadStudents(),
      ]);
      
      print('✅ Core data loaded (semesters, courses, groups)');
      
      // 2. Load user-specific data
      await Future.wait([
        ref.read(conversationProvider.notifier).loadConversations(user.id, isInstructor),
        ref.read(inAppNotificationProvider.notifier).loadNotifications(user.id),
      ]);
      
      print('✅ User-specific data loaded (conversations, notifications)');

      // 3. Load messages for all conversations
      final conversations = ref.read(conversationProvider);
      if (conversations.isNotEmpty) {
        print('💬 Loading messages for ${conversations.length} conversations...');
        
        for (final conversation in conversations) {
          try {
            await ref.read(messageProvider.notifier).loadMessages(conversation.id);
          } catch (e) {
            print('⚠️ Failed to load messages for conversation ${conversation.id}: $e');
          }
        }
        
        print('✅ Messages loaded for all conversations');
      }

      // 4. Load course-specific data
      final courses = ref.read(courseProvider);
      if (courses.isNotEmpty) {
        print('📚 Loading data for ${courses.length} courses...');
        
        for (final course in courses) {
          await Future.wait([
            ref.read(assignmentProvider.notifier).loadAssignments(course.id),
            ref.read(announcementProvider.notifier).loadAnnouncements(course.id),
            ref.read(quizProvider.notifier).loadQuizzes(courseId: course.id),
            ref.read(questionProvider.notifier).loadQuestions(courseId: course.id),
            ref.read(materialProvider.notifier).loadMaterials(courseId: course.id),
            ref.read(forumTopicProvider.notifier).loadTopics(course.id),
          ]);
        }
        
        print('✅ Course-specific data loaded for ${courses.length} courses');
      }

      // 5. Load quiz submissions
      await ref.read(quizSubmissionProvider.notifier).loadSubmissions(
        studentId: isInstructor ? null : user.id,
      );
      print('✅ Quiz submissions loaded');

      // 6. Load material views
      await ref.read(materialViewProvider.notifier).loadViews();
      print('✅ Material views loaded');
      
      print('✅ All data loaded successfully for ${user.fullName}');
    } catch (e) {
      print('⚠️ Error loading data: $e');
    }
  }

  // ══════════════════════════════════════════════
  // AUTHENTICATION
  // ══════════════════════════════════════════════

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

      final storedPassword = userMap['password_hash'] ?? userMap['password'];
      if (storedPassword == null) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      final bool passwordValid = storedPassword.toString().length == 64
          ? _verifyPassword(password, storedPassword.toString())
          : password == storedPassword.toString();

      if (!passwordValid) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      final user = AppUser.fromMap(userMap);
      state = user;

      await _saveSession(user);

      print('✅ Login successful: ${user.fullName} (${user.role.name})');

      await _loadAllData(skipCacheClear: false);
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

        await _saveSession(user);

        print('✅ Registration successful: ${user.fullName}');

        await _loadAllData(skipCacheClear: false);
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
      await _clearSession();
      state = null;
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      state = null;
    }
  }

  // ══════════════════════════════════════════════
  // ✅ NEW: PROFILE UPDATE METHODS
  // ══════════════════════════════════════════════

  /// Update user profile (editable fields only)
  /// This method handles null-safe updates for existing users
  Future<void> updateProfile({
    String? phone,
    DateTime? dateOfBirth,
    String? address,
    String? bio,
    String? avatarBase64,
    // Flags to explicitly clear fields
    bool clearPhone = false,
    bool clearDateOfBirth = false,
    bool clearAddress = false,
    bool clearBio = false,
    bool clearAvatar = false,
  }) async {
    if (state == null) {
      throw Exception('Chưa đăng nhập');
    }

    // ✅ Check network connectivity
    if (NetworkService().isOffline) {
      throw Exception('Không có kết nối mạng. Vui lòng thử lại sau.');
    }

    try {
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'updated_at': now.toIso8601String(),
      };

      // ✅ Handle each field - support both update and clear
      if (clearPhone) {
        updates['phone'] = null;
      } else if (phone != null) {
        updates['phone'] = phone;
      }

      if (clearDateOfBirth) {
        updates['date_of_birth'] = null;
      } else if (dateOfBirth != null) {
        updates['date_of_birth'] = dateOfBirth.toIso8601String();
      }

      if (clearAddress) {
        updates['address'] = null;
      } else if (address != null) {
        updates['address'] = address;
      }

      if (clearBio) {
        updates['bio'] = null;
      } else if (bio != null) {
        updates['bio'] = bio;
      }

      if (clearAvatar) {
        updates['avatar_base64'] = null;
      } else if (avatarBase64 != null) {
        updates['avatar_base64'] = avatarBase64;
      }

      // ✅ Update database
      await DatabaseService.updateOne(
        collection: 'users',
        id: state!.id,
        update: updates,
      );

      // ✅ Update local state with copyWith
      state = state!.copyWith(
        phone: clearPhone ? null : (phone ?? state!.phone),
        dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? state!.dateOfBirth),
        address: clearAddress ? null : (address ?? state!.address),
        bio: clearBio ? null : (bio ?? state!.bio),
        avatarBase64: clearAvatar ? null : (avatarBase64 ?? state!.avatarBase64),
        updatedAt: now,
        clearPhone: clearPhone,
        clearDateOfBirth: clearDateOfBirth,
        clearAddress: clearAddress,
        clearBio: clearBio,
        clearAvatarBase64: clearAvatar,
      );

      // ✅ Update cached session
      await _saveSession(state!);

      print('✅ Profile updated successfully');
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    }
  }

  /// Change user password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state == null) {
      throw Exception('Chưa đăng nhập');
    }

    if (NetworkService().isOffline) {
      throw Exception('Không có kết nối mạng. Vui lòng thử lại sau.');
    }

    try {
      // ✅ Fetch fresh user data to verify current password
      final userMap = await DatabaseService.findOne(
        collection: 'users',
        filter: {'_id': state!.id},
      );

      if (userMap == null) {
        throw Exception('Không tìm thấy người dùng');
      }

      final storedHash = userMap['password_hash'] ?? userMap['password'];
      
      // ✅ Verify current password
      bool passwordValid;
      if (storedHash.toString().length == 64) {
        // Hashed password
        passwordValid = _verifyPassword(currentPassword, storedHash.toString());
      } else {
        // Plain text (legacy)
        passwordValid = currentPassword == storedHash.toString();
      }

      if (!passwordValid) {
        print('❌ Current password incorrect');
        return false;
      }

      // ✅ Hash and update new password
      final newHash = _hashPassword(newPassword);
      await DatabaseService.updateOne(
        collection: 'users',
        id: state!.id,
        update: {
          'password_hash': newHash,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      print('✅ Password changed successfully');
      return true;
    } catch (e) {
      print('❌ Error changing password: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════

  Future<void> refreshAllData() async {
    await _loadAllData(skipCacheClear: false);
  }

  bool get isLoggedIn => state != null;
  AppUser? get currentUser => state;
  bool get isInstructor => state?.role == UserRole.instructor;
  bool get isStudent => state?.role == UserRole.student;
}