// models/semester.dart
import 'package:mongo_dart/mongo_dart.dart';

class Semester {
  final String id;
  final String code;
  final String name;

  Semester({
    required this.id,
    required this.code,
    required this.name,
  });

  // DO NOT include 'id' or '_id'
  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
      };

  factory Semester.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    return Semester(
      id: id,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
    );
  }
}