// providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../models/user.dart';
import '../services/mongodb_service.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  String _getId(dynamic id) {
    try {
      print('DEBUG _getId: id = $id, type = ${id.runtimeType}');
      
      if (id == null) {
        print('DEBUG _getId: id is null');
        return '';
      }
      
      if (id is ObjectId) {
        // ObjectId.toString() returns the hex string representation
        final result = id.toString();
        print('DEBUG _getId: ObjectId converted to string: $result');
        return result;
      } else if (id is String) {
        print('DEBUG _getId: id is already a string: $id');
        return id;
      } else if (id is Map) {
        print('DEBUG _getId: id is a Map: $id');
        // Sometimes _id comes as a map with $oid key
        if (id.containsKey('\$oid')) {
          return id['\$oid'].toString();
        } else if (id.containsKey('oid')) {
          return id['oid'].toString();
        }
        return id.toString();
      } else {
        print('DEBUG _getId: id is other type, using toString(): ${id.toString()}');
        return id.toString();
      }
    } catch (e, stackTrace) {
      print('ERROR _getId: Exception = $e');
      print('ERROR _getId: StackTrace = $stackTrace');
      print('ERROR _getId: id value = $id, type = ${id.runtimeType}');
      return id.toString();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await MongoDBService.connect();
      await MongoDBService.ensureCollectionExists('users');
      final collection = MongoDBService.getCollection('users');
      
      final user = await collection.findOne({
        'email': email,
        'password': password,
      });

      if (user == null) {
        throw Exception("Sai email hoặc mật khẩu");
      }

      print('DEBUG login: User found: $user');
      print('DEBUG login: User _id: ${user['_id']}, type: ${user['_id'].runtimeType}');
      final userId = _getId(user['_id']);
      print('DEBUG login: Converted _id: $userId');
      
      // Ensure all fields are strings
      final userName = (user['name'] ?? 'User').toString();
      final userEmail = user['email'].toString();
      final userRole = user['role'].toString();
      print('DEBUG login: userName: $userName, userEmail: $userEmail, userRole: $userRole');

      state = AppUser(
        id: userId,
        name: userName,
        email: userEmail,
        role: userRole == 'instructor' ? UserRole.instructor : UserRole.student,
      );
      print('DEBUG login: User state set successfully');
    } catch (e, stackTrace) {
      print('ERROR login: Exception = $e');
      print('ERROR login: StackTrace = $stackTrace');
      print('ERROR login: Exception type = ${e.runtimeType}');
      throw Exception("Lỗi đăng nhập: ${e.toString()}");
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

      // Check if email exists
      final existingUser = await collection.findOne({
        'email': email,
      });

      if (existingUser != null) {
        throw Exception("Email đã được sử dụng");
      }

      // Create user - ensure all values are explicitly strings/primitives
      // Use Map<String, Object> to avoid any type issues
      final userDoc = Map<String, Object>.from({
        'email': email.toString(),
        'password': password.toString(), // plain text — OK for demo
        'name': name.toString(),
        'role': role == UserRole.instructor ? 'instructor' : 'student',
        'createdAt': DateTime.now().toIso8601String(),
      });

      print('DEBUG register: Inserting user document: $userDoc');
      print('DEBUG register: Document types - email: ${userDoc['email'].runtimeType}, password: ${userDoc['password'].runtimeType}, name: ${userDoc['name'].runtimeType}, role: ${userDoc['role'].runtimeType}');
      
      // Use insert() method which might handle the document better
      try {
        final insertResult = await collection.insert(userDoc);
        print('DEBUG register: Insert result: $insertResult');
        
        // After insert, fetch the document back to get the proper _id
        print('DEBUG register: Fetching inserted user from database...');
        final insertedUser = await collection.findOne({
          'email': email.toString(),
        });
        print('DEBUG register: Inserted user fetched: $insertedUser');
        print('DEBUG register: Inserted user _id: ${insertedUser?['_id']}, type: ${insertedUser?['_id']?.runtimeType}');
        
        if (insertedUser != null) {
          final userId = insertedUser['_id'];
          print('DEBUG register: About to convert _id: $userId, type: ${userId.runtimeType}');
          final userIdString = _getId(userId);
          print('DEBUG register: Converted _id to string: $userIdString');
          
          // Ensure all fields are properly converted to strings
          final userName = name.toString();
          final userEmail = email.toString();
          print('DEBUG register: userName: $userName, userEmail: $userEmail, role: $role');
          
          state = AppUser(
            id: userIdString,
            name: userName,
            email: userEmail,
            role: role,
          );
          print('DEBUG register: User state set successfully');
        } else {
          throw Exception("Không thể tìm thấy người dùng sau khi tạo");
        }
      } catch (insertError) {
        print('ERROR register: Insert failed: $insertError');
        rethrow;
      }
    } catch (e, stackTrace) {
      print('ERROR register: Exception = $e');
      print('ERROR register: StackTrace = $stackTrace');
      print('ERROR register: Exception type = ${e.runtimeType}');
      throw Exception("Lỗi đăng ký: ${e.toString()}");
    }
  }

  void logout() => state = null;
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier();
});