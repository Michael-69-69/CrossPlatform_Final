// providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/user.dart';
import '../services/mongodb_service.dart';
import '../services/data_loader.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  Future<void> login(String email, String password) async {
    try {
      await MongoDBService.connect();
      await MongoDBService.ensureCollectionExists('users');
      final collection = MongoDBService.getCollection('users');

      final userMap = await collection.findOne({
        'email': email,
        'password': password,
      });

      if (userMap == null) {
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
    required String name,
    required UserRole role,
  }) async {
    try {
      await MongoDBService.connect();
      await MongoDBService.ensureCollectionExists('users');
      final collection = MongoDBService.getCollection('users');

      final existingUser = await collection.findOne({'email': email});
      if (existingUser != null) {
        throw Exception("Email đã được sử dụng");
      }

      final userDoc = {
        'email': email,
        'password': password,
        'name': name,
        'role': role.name,
        'createdAt': DateTime.now(),
      };

      final result = await collection.insertOne(userDoc);
      final insertedId = result.id as ObjectId;

      final insertedUser = await collection.findOne(where.id(insertedId));
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