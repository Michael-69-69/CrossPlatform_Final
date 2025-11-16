// models/user.dart
import 'package:mongo_dart/mongo_dart.dart';

enum UserRole { student, instructor, admin }

class AppUser {
  final String id;
  final String code;
  final String email;
  final String name;
  final UserRole role;

  AppUser({
    required this.id,
    required this.code,
    required this.email,
    required this.name,
    required this.role,
  });

  // DO NOT include 'id' or '_id'
  Map<String, dynamic> toMap() => {
        'code': code,
        'email': email,
        'name': name,
        'role': role.name,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final role = map['role'] == 'student'
        ? UserRole.student
        : map['role'] == 'instructor'
            ? UserRole.instructor
            : UserRole.admin;

    return AppUser(
      id: id,
      code: map['code'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: role,
    );
  }
}