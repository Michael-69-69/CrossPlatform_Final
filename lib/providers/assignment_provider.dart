// providers/assignment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../services/database_service.dart';

final assignmentProvider = StateNotifierProvider<AssignmentNotifier, List<Assignment>>((ref) => AssignmentNotifier());

class AssignmentNotifier extends StateNotifier<List<Assignment>> {
  AssignmentNotifier() : super([]);
  
  bool _isLoading = false;

  Future<void> loadAssignments(String courseId) async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      final data = await DatabaseService.find(
        collection: 'assignments',
        filter: {'courseId': courseId},
      );
      
      // ✅ FIX: Explicit type casting for mobile
      state = data.map((e) {
        final map = Map<String, dynamic>.from(e);
        return Assignment.fromMap(map);
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      print('✅ Loaded ${state.length} assignments');
    } catch (e, stackTrace) {
      print('loadAssignments error: $e');
      print('StackTrace: $stackTrace');
      state = [];
    } finally {
      _isLoading = false;
    }
  }

  Future<void> createAssignment({
    required String courseId,
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime deadline,
    required String instructorId,
    required String instructorName,
    bool allowLateSubmission = false,
    DateTime? lateDeadline,
    int maxAttempts = 1,
    List<String> allowedFileFormats = const [],
    int maxFileSize = 10485760,
    List<String> groupIds = const [],
    List<AssignmentAttachment> attachments = const [],
  }) async {
    try {
      final now = DateTime.now();
      
      // ✅ FIX: Explicit type casting for nested objects
      final doc = <String, dynamic>{
        'courseId': courseId,
        'title': title,
        'description': description,
        'attachments': attachments.map((a) {
          final map = a.toMap();
          return <String, dynamic>{
            'fileName': map['fileName'],
            'fileUrl': map['fileUrl'],
            'fileSize': map['fileSize'],
            'mimeType': map['mimeType'],
          };
        }).toList(),
        'startDate': startDate.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'allowLateSubmission': allowLateSubmission,
        if (lateDeadline != null) 'lateDeadline': lateDeadline.toIso8601String(),
        'maxAttempts': maxAttempts,
        'allowedFileFormats': List<String>.from(allowedFileFormats),
        'maxFileSize': maxFileSize,
        'groupIds': List<String>.from(groupIds),
        'instructorId': instructorId,
        'instructorName': instructorName,
        'submissions': <Map<String, dynamic>>[],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'assignments',
        document: doc,
      );

      // Add to state immediately
      state = [
        Assignment(
          id: insertedId,
          courseId: courseId,
          title: title,
          description: description,
          attachments: attachments,
          startDate: startDate,
          deadline: deadline,
          allowLateSubmission: allowLateSubmission,
          lateDeadline: lateDeadline,
          maxAttempts: maxAttempts,
          allowedFileFormats: allowedFileFormats,
          maxFileSize: maxFileSize,
          groupIds: groupIds,
          instructorId: instructorId,
          instructorName: instructorName,
          createdAt: now,
          updatedAt: now,
        ),
        ...state,
      ];
      
      print('✅ Created assignment: $insertedId');
    } catch (e, stackTrace) {
      print('createAssignment error: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> submitAssignment({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String groupId,
    required String groupName,
    required List<AssignmentAttachment> files,
  }) async {
    try {
      final assignment = state.firstWhere((a) => a.id == assignmentId);
      final attemptCount = assignment.getAttemptCountForStudent(studentId) + 1;
      
      if (attemptCount > assignment.maxAttempts) {
        throw Exception('Maximum attempts reached');
      }

      final now = DateTime.now();
      final isLate = now.isAfter(assignment.deadline) && 
          (!assignment.allowLateSubmission || 
           (assignment.lateDeadline != null && now.isAfter(assignment.lateDeadline!)));

      final submission = AssignmentSubmission(
        id: now.millisecondsSinceEpoch.toString(),
        studentId: studentId,
        studentName: studentName,
        groupId: groupId,
        groupName: groupName,
        files: files,
        submittedAt: now,
        attemptNumber: attemptCount,
        isLate: isLate,
      );

      final updatedSubmissions = [...assignment.submissions, submission];
      
      // ✅ FIX: Explicit type casting for submissions
      await DatabaseService.updateOne(
        collection: 'assignments',
        id: assignmentId,
        update: {
          'submissions': updatedSubmissions.map((s) {
            final map = s.toMap();
            return <String, dynamic>{
              'id': map['id'],
              'studentId': map['studentId'],
              'studentName': map['studentName'],
              'groupId': map['groupId'],
              'groupName': map['groupName'],
              'files': (map['files'] as List).map((f) {
                return <String, dynamic>{
                  'fileName': f['fileName'],
                  'fileUrl': f['fileUrl'],
                  'fileSize': f['fileSize'],
                  'mimeType': f['mimeType'],
                };
              }).toList(),
              'submittedAt': map['submittedAt'],
              'attemptNumber': map['attemptNumber'],
              if (map['grade'] != null) 'grade': map['grade'],
              if (map['feedback'] != null) 'feedback': map['feedback'],
              'isLate': map['isLate'],
            };
          }).toList(),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Update local state
      state = state.map((a) {
        if (a.id == assignmentId) {
          return Assignment(
            id: a.id,
            courseId: a.courseId,
            title: a.title,
            description: a.description,
            attachments: a.attachments,
            startDate: a.startDate,
            deadline: a.deadline,
            allowLateSubmission: a.allowLateSubmission,
            lateDeadline: a.lateDeadline,
            maxAttempts: a.maxAttempts,
            allowedFileFormats: a.allowedFileFormats,
            maxFileSize: a.maxFileSize,
            groupIds: a.groupIds,
            instructorId: a.instructorId,
            instructorName: a.instructorName,
            submissions: updatedSubmissions,
            createdAt: a.createdAt,
            updatedAt: now,
          );
        }
        return a;
      }).toList();
    } catch (e, stackTrace) {
      print('submitAssignment error: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> gradeSubmission({
    required String assignmentId,
    required String submissionId,
    required double grade,
    String? feedback,
  }) async {
    try {
      final assignment = state.firstWhere((a) => a.id == assignmentId);
      final updatedSubmissions = assignment.submissions.map((s) {
        if (s.id == submissionId) {
          return AssignmentSubmission(
            id: s.id,
            studentId: s.studentId,
            studentName: s.studentName,
            groupId: s.groupId,
            groupName: s.groupName,
            files: s.files,
            submittedAt: s.submittedAt,
            attemptNumber: s.attemptNumber,
            grade: grade,
            feedback: feedback ?? s.feedback,
            isLate: s.isLate,
          );
        }
        return s;
      }).toList();

      final now = DateTime.now();
      
      // ✅ FIX: Explicit type casting
      await DatabaseService.updateOne(
        collection: 'assignments',
        id: assignmentId,
        update: {
          'submissions': updatedSubmissions.map((s) {
            final map = s.toMap();
            return <String, dynamic>{
              'id': map['id'],
              'studentId': map['studentId'],
              'studentName': map['studentName'],
              'groupId': map['groupId'],
              'groupName': map['groupName'],
              'files': (map['files'] as List).map((f) {
                return <String, dynamic>{
                  'fileName': f['fileName'],
                  'fileUrl': f['fileUrl'],
                  'fileSize': f['fileSize'],
                  'mimeType': f['mimeType'],
                };
              }).toList(),
              'submittedAt': map['submittedAt'],
              'attemptNumber': map['attemptNumber'],
              if (map['grade'] != null) 'grade': map['grade'],
              if (map['feedback'] != null) 'feedback': map['feedback'],
              'isLate': map['isLate'],
            };
          }).toList(),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Update local state
      state = state.map((a) {
        if (a.id == assignmentId) {
          return Assignment(
            id: a.id,
            courseId: a.courseId,
            title: a.title,
            description: a.description,
            attachments: a.attachments,
            startDate: a.startDate,
            deadline: a.deadline,
            allowLateSubmission: a.allowLateSubmission,
            lateDeadline: a.lateDeadline,
            maxAttempts: a.maxAttempts,
            allowedFileFormats: a.allowedFileFormats,
            maxFileSize: a.maxFileSize,
            groupIds: a.groupIds,
            instructorId: a.instructorId,
            instructorName: a.instructorName,
            submissions: updatedSubmissions,
            createdAt: a.createdAt,
            updatedAt: now,
          );
        }
        return a;
      }).toList();
    } catch (e, stackTrace) {
      print('gradeSubmission error: $e');
      print('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<void> deleteAssignment(String id) async {
    try {
      await DatabaseService.deleteOne(
        collection: 'assignments',
        id: id,
      );
      state = state.where((a) => a.id != id).toList();
      print('✅ Deleted assignment: $id');
    } catch (e) {
      print('deleteAssignment error: $e');
    }
  }
}