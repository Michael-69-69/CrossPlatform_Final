// providers/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/email_service.dart';
import '../models/user.dart';

class NotificationNotifier extends StateNotifier<bool> {
  NotificationNotifier() : super(false);

  // Send announcement notification
  Future<void> notifyAnnouncement({
    required List<AppUser> recipients,
    required String courseName,
    required String announcementTitle,
    required String announcementContent,
  }) async {
    state = true;
    
    try {
      int sent = 0;
      for (var student in recipients) {
        if (student.email.isNotEmpty) {
          final success = await EmailService.sendAnnouncementEmail(
            recipientEmail: student.email,
            recipientName: student.fullName,
            courseName: courseName,
            announcementTitle: announcementTitle,
            announcementContent: announcementContent,
          );
          if (success) sent++;
        }
      }
      print('✅ Sent announcement emails to $sent/${recipients.length} students');
    } catch (e) {
      print('❌ Error sending announcement notifications: $e');
    } finally {
      state = false;
    }
  }

  // Send assignment deadline reminder
  Future<void> notifyAssignmentDeadline({
    required List<AppUser> recipients,
    required String courseName,
    required String assignmentTitle,
    required DateTime deadline,
  }) async {
    state = true;
    
    try {
      int sent = 0;
      for (var student in recipients) {
        if (student.email.isNotEmpty) {
          final success = await EmailService.sendAssignmentDeadlineEmail(
            recipientEmail: student.email,
            recipientName: student.fullName,
            courseName: courseName,
            assignmentTitle: assignmentTitle,
            deadline: deadline,
          );
          if (success) sent++;
        }
      }
      print('✅ Sent deadline reminders to $sent/${recipients.length} students');
    } catch (e) {
      print('❌ Error sending deadline notifications: $e');
    } finally {
      state = false;
    }
  }

  // Send quiz deadline reminder
  Future<void> notifyQuizDeadline({
    required List<AppUser> recipients,
    required String courseName,
    required String quizTitle,
    required DateTime deadline,
  }) async {
    state = true;
    
    try {
      int sent = 0;
      for (var student in recipients) {
        if (student.email.isNotEmpty) {
          final success = await EmailService.sendQuizDeadlineEmail(
            recipientEmail: student.email,
            recipientName: student.fullName,
            courseName: courseName,
            quizTitle: quizTitle,
            deadline: deadline,
          );
          if (success) sent++;
        }
      }
      print('✅ Sent quiz reminders to $sent/${recipients.length} students');
    } catch (e) {
      print('❌ Error sending quiz notifications: $e');
    } finally {
      state = false;
    }
  }

  // Send submission confirmation
  Future<void> notifySubmissionConfirmation({
    required String recipientEmail,
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    required DateTime submittedAt,
  }) async {
    if (recipientEmail.isEmpty) return;
    
    state = true;
    
    try {
      await EmailService.sendSubmissionConfirmationEmail(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        courseName: courseName,
        assignmentTitle: assignmentTitle,
        submittedAt: submittedAt,
      );
      print('✅ Sent submission confirmation to $recipientEmail');
    } catch (e) {
      print('❌ Error sending submission confirmation: $e');
    } finally {
      state = false;
    }
  }

  // Send instructor feedback
  Future<void> notifyInstructorFeedback({
    required String recipientEmail,
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    double? grade,
    required String feedback,
  }) async {
    if (recipientEmail.isEmpty) return;
    
    state = true;
    
    try {
      await EmailService.sendInstructorFeedbackEmail(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        courseName: courseName,
        assignmentTitle: assignmentTitle,
        grade: grade,
        feedback: feedback,
      );
      print('✅ Sent feedback notification to $recipientEmail');
    } catch (e) {
      print('❌ Error sending feedback notification: $e');
    } finally {
      state = false;
    }
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, bool>(
  (ref) => NotificationNotifier(),
);