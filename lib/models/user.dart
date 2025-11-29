// models/user.dart
import 'package:mongo_dart/mongo_dart.dart';

enum UserRole { student, instructor }

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String? passwordHash;
  final UserRole role;
  final String? avatarUrl;
  final String? avatarBase64; // ✅ NEW: For uploaded avatar (stored as base64)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? code;
  
  // ✅ NEW: Additional editable fields for profile
  final String? phone;
  final DateTime? dateOfBirth;
  final String? address;
  final String? bio;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.passwordHash,
    required this.role,
    this.avatarUrl,
    this.avatarBase64,
    required this.createdAt,
    required this.updatedAt,
    this.code,
    this.phone,
    this.dateOfBirth,
    this.address,
    this.bio,
  });

  // DO NOT include 'id' or '_id' or 'password_hash'
  Map<String, dynamic> toMap() => {
        'full_name': fullName,
        'email': email,
        'role': role.name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (avatarBase64 != null) 'avatar_base64': avatarBase64,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (code != null) 'code': code,
        if (phone != null) 'phone': phone,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String(),
        if (address != null) 'address': address,
        if (bio != null) 'bio': bio,
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
    } else if (map['created_at'] is String) {
      createdAt = DateTime.tryParse(map['created_at']) ?? DateTime.now();
    } else if (map['createdAt'] is DateTime) {
      createdAt = map['createdAt'] as DateTime;
    } else if (map['createdAt'] is String) {
      createdAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    DateTime updatedAt;
    if (map['updated_at'] is DateTime) {
      updatedAt = map['updated_at'] as DateTime;
    } else if (map['updated_at'] is String) {
      updatedAt = DateTime.tryParse(map['updated_at']) ?? createdAt;
    } else if (map['updatedAt'] is DateTime) {
      updatedAt = map['updatedAt'] as DateTime;
    } else if (map['updatedAt'] is String) {
      updatedAt = DateTime.tryParse(map['updatedAt']) ?? createdAt;
    } else {
      updatedAt = createdAt;
    }

    // ✅ Handle date_of_birth - null-safe for existing users
    DateTime? dateOfBirth;
    if (map['date_of_birth'] != null) {
      if (map['date_of_birth'] is DateTime) {
        dateOfBirth = map['date_of_birth'] as DateTime;
      } else if (map['date_of_birth'] is String) {
        dateOfBirth = DateTime.tryParse(map['date_of_birth']);
      }
    }

    return AppUser(
      id: id,
      fullName: fullName,
      email: map['email'] ?? '',
      passwordHash: map['password_hash'] ?? map['password']?.toString(),
      role: role,
      avatarUrl: map['avatar_url'],
      avatarBase64: map['avatar_base64'], // ✅ Null-safe: returns null if not present
      createdAt: createdAt,
      updatedAt: updatedAt,
      code: map['code'],
      phone: map['phone'], // ✅ Null-safe: returns null if not present
      dateOfBirth: dateOfBirth, // ✅ Null-safe: returns null if not present
      address: map['address'], // ✅ Null-safe: returns null if not present
      bio: map['bio'], // ✅ Null-safe: returns null if not present
    );
  }

  // ✅ NEW: copyWith for easy updates
  AppUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? passwordHash,
    UserRole? role,
    String? avatarUrl,
    String? avatarBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? code,
    String? phone,
    DateTime? dateOfBirth,
    String? address,
    String? bio,
    // Special flags to explicitly set null
    bool clearAvatarBase64 = false,
    bool clearPhone = false,
    bool clearDateOfBirth = false,
    bool clearAddress = false,
    bool clearBio = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBase64: clearAvatarBase64 ? null : (avatarBase64 ?? this.avatarBase64),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      code: code ?? this.code,
      phone: clearPhone ? null : (phone ?? this.phone),
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      address: clearAddress ? null : (address ?? this.address),
      bio: clearBio ? null : (bio ?? this.bio),
    );
  }

  // ✅ Helper: Check if user has a custom avatar
  bool get hasAvatar => 
      (avatarBase64 != null && avatarBase64!.isNotEmpty) || 
      (avatarUrl != null && avatarUrl!.isNotEmpty);

  // ✅ Helper: Get display initial for avatar fallback
  String get avatarInitial => fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

  // ✅ Helper: Check if profile is complete
  bool get isProfileComplete => 
      phone != null && 
      dateOfBirth != null && 
      address != null;

  // ✅ Helper: Get profile completion percentage
  int get profileCompletionPercent {
    int filled = 0;
    int total = 4; // phone, dateOfBirth, address, bio
    
    if (phone != null && phone!.isNotEmpty) filled++;
    if (dateOfBirth != null) filled++;
    if (address != null && address!.isNotEmpty) filled++;
    if (bio != null && bio!.isNotEmpty) filled++;
    
    return ((filled / total) * 100).round();
  }
}