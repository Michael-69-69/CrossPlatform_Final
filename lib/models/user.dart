// models/user.dart
import 'package:mongo_dart/mongo_dart.dart';

enum UserRole { student, instructor }

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String? passwordHash; // Not included in toMap for security
  final UserRole role;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? code; // Optional: kept for backward compatibility with student codes

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.passwordHash,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.code,
  });

  // DO NOT include 'id' or '_id' or 'password_hash'
  Map<String, dynamic> toMap() => {
        'full_name': fullName,
        'email': email,
        'role': role.name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'created_at': createdAt,
        'updated_at': updatedAt,
        if (code != null) 'code': code,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final role = map['role'] == 'student'
        ? UserRole.student
        : UserRole.instructor;

    // Handle both old 'name' and new 'full_name' for migration
    final fullName = map['full_name'] ?? map['name'] ?? '';

    // Handle timestamps - support both old and new formats
    DateTime createdAt;
    if (map['created_at'] is DateTime) {
      createdAt = map['created_at'] as DateTime;
    } else if (map['createdAt'] is DateTime) {
      createdAt = map['createdAt'] as DateTime;
    } else {
      createdAt = DateTime.now();
    }

    DateTime updatedAt;
    if (map['updated_at'] is DateTime) {
      updatedAt = map['updated_at'] as DateTime;
    } else if (map['updatedAt'] is DateTime) {
      updatedAt = map['updatedAt'] as DateTime;
    } else {
      updatedAt = createdAt;
    }

    return AppUser(
      id: id,
      fullName: fullName,
      email: map['email'] ?? '',
      passwordHash: map['password_hash'] ?? map['password']?.toString(),
      role: role,
      avatarUrl: map['avatar_url'],
      createdAt: createdAt,
      updatedAt: updatedAt,
      code: map['code'],
    );
  }
}