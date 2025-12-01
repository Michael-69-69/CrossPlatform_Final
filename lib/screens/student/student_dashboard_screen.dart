// screens/student/student_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/course.dart';
import '../../models/assignment.dart';
import '../../models/quiz.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../main.dart'; // for localeProvider

class StudentDashboardScreen extends ConsumerWidget {
  final String semesterId;
  final List<Course> courses;

  const StudentDashboardScreen({
    super.key,
    required this.semesterId,
    required this.courses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final allAssignments = ref.watch(assignmentProvider);
    final allQuizzes = ref.watch(quizProvider);
    final allSubmissions = ref.watch(quizSubmissionProvider);
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    // Filter assignments for student's courses
    final assignments = allAssignments.where((a) => 
      courses.any((c) => c.id == a.courseId)
    ).toList();

    // Filter quizzes for student's courses
    final quizzes = allQuizzes.where((q) => 
      courses.any((c) => c.id == q.courseId)
    ).toList();

    // Get student's submissions
    final mySubmissions = allSubmissions.where((s) => 
      s.studentId == user?.id
    ).toList();

    // Calculate statistics
    final pendingAssignments = assignments.where((a) {
      final hasSubmitted = a.submissions.any((s) => s.studentId == user?.id);
      return !hasSubmitted && DateTime.now().isBefore(a.deadline);
    }).toList();

    final completedAssignments = assignments.where((a) {
      return a.submissions.any((s) => s.studentId == user?.id);
    }).toList();

    final lateAssignments = assignments.where((a) {
      final hasSubmitted = a.submissions.any((s) => s.studentId == user?.id);
      return !hasSubmitted && DateTime.now().isAfter(a.deadline);
    }).toList();

    final completedQuizzes = mySubmissions.length;
    final pendingQuizzes = quizzes.where((q) {
      final hasCompleted = mySubmissions.any((s) => s.quizId == q.id);
      return !hasCompleted && DateTime.now().isBefore(q.closeTime);
    }).length;

    // Upcoming deadlines
    final upcomingDeadlines = [
      ...assignments.where((a) => DateTime.now().isBefore(a.deadline)),
      ...quizzes.where((q) => DateTime.now().isBefore(q.closeTime)),
    ]..sort((a, b) {
      final aDate = a is Assignment ? a.deadline : (a as Quiz).closeTime;
      final bDate = b is Assignment ? b.deadline : (b as Quiz).closeTime;
      return aDate.compareTo(bDate);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Text(
            isVietnamese ? 'Tổng quan' : 'Overview',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Bài tập chờ nộp' : 'Pending',
                  value: pendingAssignments.length.toString(),
                  icon: Icons.assignment,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Đã hoàn thành' : 'Completed',
                  value: completedAssignments.length.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Trễ hạn' : 'Late',
                  value: lateAssignments.length.toString(),
                  icon: Icons.warning,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Quiz chờ làm' : 'Pending Quiz',
                  value: pendingQuizzes.toString(),
                  icon: Icons.quiz,
                  color: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Upcoming Deadlines
          Text(
            isVietnamese ? 'Deadline sắp tới' : 'Upcoming Deadlines',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (upcomingDeadlines.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.celebration, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      isVietnamese ? 'Không có deadline nào!' : 'No deadlines!',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...upcomingDeadlines.take(5).map((item) {
              if (item is Assignment) {
                return _DeadlineItem(
                  title: item.title,
                  type: isVietnamese ? 'Bài tập' : 'Assignment',
                  deadline: item.deadline,
                  icon: Icons.assignment,
                  color: Colors.orange,
                  isVietnamese: isVietnamese,
                );
              } else {
                final quiz = item as Quiz;
                return _DeadlineItem(
                  title: quiz.title,
                  type: 'Quiz',
                  deadline: quiz.closeTime,
                  icon: Icons.quiz,
                  color: Colors.blue,
                  isVietnamese: isVietnamese,
                );
              }
            }),

          const SizedBox(height: 24),

          // Quiz Scores
          Text(
            isVietnamese ? 'Điểm Quiz gần đây' : 'Recent Quiz Scores',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (mySubmissions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  isVietnamese ? 'Chưa có điểm quiz nào' : 'No quiz scores yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...mySubmissions.take(5).map((submission) {
              final quiz = quizzes.firstWhere(
                (q) => q.id == submission.quizId,
                orElse: () => Quiz(
                  id: '',
                  courseId: '',
                  title: 'Unknown',
                  openTime: DateTime.now(),
                  closeTime: DateTime.now(),
                  maxAttempts: 1,
                  durationMinutes: 0,
                  questionIds: [],
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              
              return _QuizScoreItem(
                title: quiz.title,
                score: submission.score,
                maxScore: submission.maxScore,
                submittedAt: submission.submittedAt,
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineItem extends StatelessWidget {
  final String title;
  final String type;
  final DateTime deadline;
  final IconData icon;
  final Color color;
  final bool isVietnamese;

  const _DeadlineItem({
    required this.title,
    required this.type,
    required this.deadline,
    required this.icon,
    required this.color,
    required this.isVietnamese,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntil = deadline.difference(DateTime.now()).inDays;
    final hoursUntil = deadline.difference(DateTime.now()).inHours;

    String timeText;
    if (daysUntil > 0) {
      timeText = isVietnamese ? '$daysUntil ngày nữa' : 'in $daysUntil days';
    } else if (hoursUntil > 0) {
      timeText = isVietnamese ? '$hoursUntil giờ nữa' : 'in $hoursUntil hours';
    } else {
      timeText = isVietnamese ? 'Sắp hết hạn!' : 'Due soon!';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text('$type • ${deadline.day}/${deadline.month}/${deadline.year}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hoursUntil < 24 ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            timeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hoursUntil < 24 ? Colors.red : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizScoreItem extends StatelessWidget {
  final String title;
  final int score;
  final int maxScore;
  final DateTime submittedAt;

  const _QuizScoreItem({
    required this.title,
    required this.score,
    required this.maxScore,
    required this.submittedAt,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score / maxScore * 100).toStringAsFixed(1);
    final isPassing = score / maxScore >= 0.5;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPassing ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          child: Icon(
            isPassing ? Icons.check : Icons.close,
            color: isPassing ? Colors.green : Colors.red,
          ),
        ),
        title: Text(title),
        subtitle: Text('${submittedAt.day}/${submittedAt.month}/${submittedAt.year}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$score/$maxScore',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12,
                color: isPassing ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}