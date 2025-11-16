// models/group.dart
import 'package:mongo_dart/mongo_dart.dart';

class Group {
  final String id;
  final String name;
  final String courseId;
  final List<String> studentIds;

  Group({
    required this.id,
    required this.name,
    required this.courseId,
    this.studentIds = const [],
  });

  // DO NOT include 'id' or '_id'
  Map<String, dynamic> toMap() => {
        'name': name,
        'courseId': ObjectId.fromHexString(courseId),
        'studentIds': studentIds.map(ObjectId.fromHexString).toList(),
      };

  factory Group.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId
        ? map['_id'].toHexString()
        : map['_id']?.toString() ?? '';

    final courseId = map['courseId'] is ObjectId
        ? map['courseId'].toHexString()
        : map['courseId']?.toString() ?? '';

    final raw = map['studentIds'] as List? ?? [];
    final studentIds = raw
        .map((e) => e is ObjectId ? e.toHexString() : e.toString())
        .toList();

    return Group(
      id: id,
      name: map['name'] ?? '',
      courseId: courseId,
      studentIds: studentIds,
    );
  }
}