// providers/assignment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../services/database_service.dart';

final assignmentProvider = StateNotifierProvider<AssignmentNotifier, List<Assignment>>((ref) => AssignmentNotifier());

class AssignmentNotifier extends StateNotifier<List<Assignment>> {
  AssignmentNotifier() : super([]);

  Future<void> loadAssignments(String courseId) async {
    try {
      final data = await DatabaseService.find(
        collection: 'assignments',
        filter: {'courseId': courseId},
      );
      state = data.map(Assignment.fromMap).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('loadAssignments error: $e');
      state = [];
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
      
      final doc = {
        'courseId': courseId,
        'title': title,
        'description': description,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'startDate': startDate.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'allowLateSubmission': allowLateSubmission,
        if (lateDeadline != null) 'lateDeadline': lateDeadline.toIso8601String(),
        'maxAttempts': maxAttempts,
        'allowedFileFormats': allowedFileFormats,
        'maxFileSize': maxFileSize,
        'groupIds': groupIds,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'submissions': [],
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final insertedId = await DatabaseService.insertOne(
        collection: 'assignments',
        document: doc,
      );

      // Add to state
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
    } catch (e) {
      print('createAssignment error: $e');
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
      
      await DatabaseService.updateOne(
        collection: 'assignments',
        id: assignmentId,
        update: {
          'submissions': updatedSubmissions.map((s) => s.toMap()).toList(),
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
    } catch (e) {
      print('submitAssignment error: $e');
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
      
      await DatabaseService.updateOne(
        collection: 'assignments',
        id: assignmentId,
        update: {
          'submissions': updatedSubmissions.map((s) => s.toMap()).toList(),
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
    } catch (e) {
      print('gradeSubmission error: $e');
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
    } catch (e) {
      print('deleteAssignment error: $e');
    }
  }
}