// models/semester.dart
import 'package:mongo_dart/mongo_dart.dart';

class Semester {
  final String id;
  final String code;
  final String name;
  final bool isActive;

  Semester({
    required this.id,
    required this.code,
    required this.name,
    this.isActive = false, // ✅ Default to false for old semesters
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'isActive': isActive,
      };

  factory Semester.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    // ✅ SMART: If isActive field doesn't exist in DB, default to false
    // This handles backward compatibility with existing semesters
    final isActive = map['isActive'] ?? false;

    return Semester(
      id: id,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      isActive: isActive,
    );
  }

  // ✅ ADD: copyWith for easy updates
  Semester copyWith({
    String? id,
    String? code,
    String? name,
    bool? isActive,
  }) {
    return Semester(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}