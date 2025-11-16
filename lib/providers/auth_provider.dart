// providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/data_loader.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Verify password against hash
  bool _verifyPassword(String password, String hash) {
    return _hashPassword(password) == hash;
  }

  Future<void> login(String email, String password) async {
    try {
      await DatabaseService.connect();
      await DatabaseService.ensureCollectionExists('users');

      final userMap = await DatabaseService.findOne(
        collection: 'users',
        filter: {'email': email},
      );

      if (userMap == null) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      // Check password - support both old plain password and new hashed password
      final storedPassword = userMap['password_hash'] ?? userMap['password'];
      if (storedPassword == null) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      // If it's a hash (64 chars for SHA-256), verify it. Otherwise, compare directly (backward compatibility)
      final bool passwordValid = storedPassword.toString().length == 64
          ? _verifyPassword(password, storedPassword.toString())
          : password == storedPassword.toString();

      if (!passwordValid) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      state = AppUser.fromMap(userMap);

      // LOAD ALL DATA AFTER LOGIN
      final container = ProviderContainer();
      await loadAllData(container);
      container.dispose();
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
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

      final userDoc = {
        'full_name': fullName,
        'email': email,
        'password_hash': passwordHash,
        'role': role.name,
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

        // LOAD ALL DATA AFTER REGISTER
        final container = ProviderContainer();
        await loadAllData(container);
        container.dispose();
      } else {
        throw Exception("Không thể tìm thấy người dùng sau khi tạo");
      }
    } catch (e) {
      print('Register error: $e');
      rethrow;
    }
  }

  void logout() => state = null;
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) => AuthNotifier());