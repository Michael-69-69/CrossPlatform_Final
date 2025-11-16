// models/class.dart
import 'package:mongo_dart/mongo_dart.dart';

class ClassModel {
  final String id;
  final String name;
  final String instructorId;
  final String instructorName;
  final List<String> studentIds;
  final List<Map<String, dynamic>> schedule;
  final List<Map<String, dynamic>> content;
  final List<Map<String, dynamic>> exams;

  ClassModel({
    required this.id,
    required this.name,
    required this.instructorId,
    required this.instructorName,
    this.studentIds = const [],
    this.schedule = const [],
    this.content = const [],
    this.exams = const [],
  });

  // === FROM MAP: ObjectId to String (safe) ===
  factory ClassModel.fromMap(Map<String, dynamic> map) {
    final id = map['_id'] is ObjectId ? map['_id'].toHexString() : map['_id'].toString();
    final instructorId = map['instructorId'] is ObjectId
        ? map['instructorId'].toHexString()
        : map['instructorId'].toString();

    final rawStudentIds = map['studentIds'] as List? ?? [];
    final studentIds = rawStudentIds
        .map((e) => e is ObjectId ? e.toHexString() : e.toString())
        .toList();

    return ClassModel(
      id: id,
      name: map['name'] ?? '',
      instructorId: instructorId,
      instructorName: map['instructorName'] ?? '',
      studentIds: studentIds,
      schedule: (map['schedule'] as List? ?? []).cast<Map<String, dynamic>>(),
      content: (map['content'] as List? ?? []).cast<Map<String, dynamic>>(),
      exams: (map['exams'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
  }

  // === TO MAP: String to ObjectId (for insert/update) ===
  Map<String, dynamic> toMap() => {
        '_id': ObjectId.fromHexString(id),
        'name': name,
        'instructorId': ObjectId.fromHexString(instructorId),
        'instructorName': instructorName,
        'studentIds': studentIds.map(ObjectId.fromHexString).toList(),
        'schedule': schedule,
        'content': content,
        'exams': exams,
      };

  // === COPY WITH: Required for updateExam() ===
  ClassModel copyWith({
    String? id,
    String? name,
    String? instructorId,
    String? instructorName,
    List<String>? studentIds,
    List<Map<String, dynamic>>? schedule,
    List<Map<String, dynamic>>? content,
    List<Map<String, dynamic>>? exams,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      studentIds: studentIds ?? this.studentIds,
      schedule: schedule ?? this.schedule,
      content: content ?? this.content,
      exams: exams ?? this.exams,
    );
  }
}