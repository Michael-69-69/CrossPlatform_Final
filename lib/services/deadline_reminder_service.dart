// services/deadline_reminder_service.dart
import '../services/database_service.dart';
import '../services/email_service.dart';

class DeadlineReminderService {
  // Check and send reminders for assignments and quizzes
  static Future<void> checkAndSendReminders() async {
    try {
      print('🔔 Checking for upcoming deadlines...');
      
      await _checkAssignmentDeadlines();
      await _checkQuizDeadlines();
      
      print('✅ Deadline check complete');
    } catch (e) {
      print('❌ Error checking deadlines: $e');
    }
  }

  static Future<void> _checkAssignmentDeadlines() async {
    try {
      // Find assignments with deadline in next 24 hours
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final now = DateTime.now();

      final assignments = await DatabaseService.find(
        collection: 'assignments',
        filter: {},
      );

      // Filter assignments with upcoming deadlines
      final upcomingAssignments = assignments.where((assignment) {
        final deadline = DateTime.parse(assignment['deadline']);
        return deadline.isAfter(now) && deadline.isBefore(tomorrow);
      }).toList();

      print('📋 Found ${upcomingAssignments.length} assignments with upcoming deadlines');

      for (var assignment in upcomingAssignments) {
        final assignmentId = assignment['_id'].toString();
        final title = assignment['title'];
        final deadline = DateTime.parse(assignment['deadline']);
        final groupIds = (assignment['groupIds'] as List).cast<String>();
        final courseId = assignment['courseId'];

        // Get course info
        final course = await DatabaseService.findOne(
          collection: 'courses',
          filter: {'_id': courseId},
        );
        final courseName = course?['name'] ?? 'Unknown Course';

        // Get students in these groups
        for (var groupId in groupIds) {
          final group = await DatabaseService.findOne(
            collection: 'groups',
            filter: {'_id': groupId},
          );
          
          if (group == null) continue;

          final studentIds = (group['studentIds'] as List).cast<String>();

          for (var studentId in studentIds) {
            // Check if student has submitted
            final submissions = (assignment['submissions'] as List?) ?? [];
            final hasSubmitted = submissions.any((s) => s['studentId'] == studentId);
            
            if (hasSubmitted) continue;

            // Check if reminder already sent
            final existingNotifications = await DatabaseService.find(
              collection: 'in_app_notifications',
              filter: {
                'userId': studentId,
                'relatedId': assignmentId,
                'type': 'deadlineReminder',
              },
            );

            if (existingNotifications.isNotEmpty) continue;

            // Get student info
            final student = await DatabaseService.findOne(
              collection: 'users',
              filter: {'_id': studentId},
            );
            
            if (student == null) continue;

            final studentEmail = student['email'] as String?;
            final studentName = student['fullName'] as String;

            // Send email
            if (studentEmail != null && studentEmail.isNotEmpty) {
              await EmailService.sendAssignmentDeadlineEmail(
                recipientEmail: studentEmail,
                recipientName: studentName,
                courseName: courseName,
                assignmentTitle: title,
                deadline: deadline,
              );
            }

            // Create in-app notification
            await DatabaseService.insertOne(
              collection: 'in_app_notifications',
              document: {
                'userId': studentId,
                'title': '⏰ Sắp hết hạn nộp bài',
                'body': 'Bài tập "$title" trong môn $courseName sẽ hết hạn vào ${_formatDeadline(deadline)}',
                'type': 'deadlineReminder',
                'isRead': false,
                'createdAt': DateTime.now().toIso8601String(),
                'relatedId': assignmentId,
                'courseId': courseId,
                'courseName': courseName,
              },
            );

            print('✅ Sent reminder to $studentName for assignment: $title');
          }
        }
      }
    } catch (e) {
      print('❌ Error checking assignment deadlines: $e');
    }
  }

  static Future<void> _checkQuizDeadlines() async {
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final now = DateTime.now();

      final quizzes = await DatabaseService.find(
        collection: 'quizzes',
        filter: {},
      );

      // Filter quizzes with upcoming deadlines
      final upcomingQuizzes = quizzes.where((quiz) {
        final endTime = DateTime.parse(quiz['endTime']);
        return endTime.isAfter(now) && endTime.isBefore(tomorrow);
      }).toList();

      print('📝 Found ${upcomingQuizzes.length} quizzes with upcoming deadlines');

      for (var quiz in upcomingQuizzes) {
        final quizId = quiz['_id'].toString();
        final title = quiz['title'];
        final endTime = DateTime.parse(quiz['endTime']);
        final groupIds = (quiz['groupIds'] as List).cast<String>();
        final courseId = quiz['courseId'];

        final course = await DatabaseService.findOne(
          collection: 'courses',
          filter: {'_id': courseId},
        );
        final courseName = course?['name'] ?? 'Unknown Course';

        for (var groupId in groupIds) {
          final group = await DatabaseService.findOne(
            collection: 'groups',
            filter: {'_id': groupId},
          );
          
          if (group == null) continue;

          final studentIds = (group['studentIds'] as List).cast<String>();

          for (var studentId in studentIds) {
            final attempts = (quiz['attempts'] as List?) ?? [];
            final hasCompleted = attempts.any((a) => a['studentId'] == studentId);
            
            if (hasCompleted) continue;

            final existingNotifications = await DatabaseService.find(
              collection: 'in_app_notifications',
              filter: {
                'userId': studentId,
                'relatedId': quizId,
                'type': 'deadlineReminder',
              },
            );

            if (existingNotifications.isNotEmpty) continue;

            final student = await DatabaseService.findOne(
              collection: 'users',
              filter: {'_id': studentId},
            );
            
            if (student == null) continue;

            final studentEmail = student['email'] as String?;
            final studentName = student['fullName'] as String;

            if (studentEmail != null && studentEmail.isNotEmpty) {
              await EmailService.sendQuizDeadlineEmail(
                recipientEmail: studentEmail,
                recipientName: studentName,
                courseName: courseName,
                quizTitle: title,
                deadline: endTime,
              );
            }

            await DatabaseService.insertOne(
              collection: 'in_app_notifications',
              document: {
                'userId': studentId,
                'title': '⏰ Sắp hết hạn làm bài quiz',
                'body': 'Quiz "$title" trong môn $courseName sẽ đóng vào ${_formatDeadline(endTime)}',
                'type': 'deadlineReminder',
                'isRead': false,
                'createdAt': DateTime.now().toIso8601String(),
                'relatedId': quizId,
                'courseId': courseId,
                'courseName': courseName,
              },
            );

            print('✅ Sent reminder to $studentName for quiz: $title');
          }
        }
      }
    } catch (e) {
      print('❌ Error checking quiz deadlines: $e');
    }
  }

  static String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.inHours < 24) {
      return '${difference.inHours} giờ nữa';
    } else {
      return '${deadline.day}/${deadline.month}/${deadline.year} lúc ${deadline.hour}:${deadline.minute.toString().padLeft(2, '0')}';
    }
  }
}