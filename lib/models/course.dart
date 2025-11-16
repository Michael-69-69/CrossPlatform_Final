// models/course.dart
import 'package:mongo_dart/mongo_dart.dart';

class Course {
  final String id;
  final String code;
  final String name;
  final int sessions;
  final String semesterId;
  final String instructorId;
  final String instructorName;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.sessions,
    required this.semesterId,
    required this.instructorId,
    required this.instructorName,
  });

  // DO NOT include 'id' or '_id'
  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'sessions': sessions,
        'semesterId': ObjectId.fromHexString(semesterId),
        'instructorId': ObjectId.fromHexString(instructorId),
        'instructorName': instructorName,
      };

  factory Course.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final semesterId = map['semesterId'] is ObjectId
        ? map['semesterId'].toHexString()
        : map['semesterId']?.toString() ?? '';

    final instructorId = map['instructorId'] is ObjectId
        ? map['instructorId'].toHexString()
        : map['instructorId']?.toString() ?? '';

    return Course(
      id: id,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      sessions: map['sessions'] ?? 10,
      semesterId: semesterId,
      instructorId: instructorId,
      instructorName: map['instructorName'] ?? '',
    );
  }
}