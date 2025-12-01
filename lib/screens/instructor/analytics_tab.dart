// screens/instructor/analytics_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/course.dart';
import '../../models/user.dart';
import '../../models/assignment.dart';
import '../../models/quiz.dart';
import '../../models/material.dart' as app;
import '../../providers/assignment_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/material_provider.dart';
import '../../main.dart'; // for localeProvider

class AnalyticsTab extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  final List<AppUser> students;

  const AnalyticsTab({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.students,
  });

  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignmentProvider.notifier).loadAssignments(widget.courseId);
      ref.read(quizProvider.notifier).loadQuizzes(courseId: widget.courseId);
      ref.read(materialProvider.notifier).loadMaterials(courseId: widget.courseId);
      ref.read(materialViewProvider.notifier).loadViews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Column(
      children: [
        // Tab Selector
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  label: isVietnamese ? 'Bài tập' : 'Assignments',
                  icon: Icons.assignment,
                  isSelected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TabButton(
                  label: 'Quiz',
                  icon: Icons.quiz,
                  isSelected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TabButton(
                  label: isVietnamese ? 'Tài liệu' : 'Materials',
                  icon: Icons.folder,
                  isSelected: _selectedTab == 2,
                  onTap: () => setState(() => _selectedTab = 2),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildAssignmentAnalytics(),
              _buildQuizAnalytics(),
              _buildMaterialAnalytics(),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // ASSIGNMENT ANALYTICS
  // ═══════════════════════════════════════════════
  Widget _buildAssignmentAnalytics() {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
    final assignments = ref.watch(assignmentProvider)
        .where((a) => a.courseId == widget.courseId)
        .toList();

    if (assignments.isEmpty) {
      return Center(child: Text(isVietnamese ? 'Chưa có bài tập nào' : 'No assignments yet'));
    }

    // Calculate statistics
    final totalStudents = widget.students.length;
    int totalSubmitted = 0;
    int totalLate = 0;
    int totalOnTime = 0;

    for (var assignment in assignments) {
      for (var submission in assignment.submissions) {
        totalSubmitted++;
        if (submission.submittedAt.isAfter(assignment.deadline)) {
          totalLate++;
        } else {
          totalOnTime++;
        }
      }
    }

    final totalExpected = assignments.length * totalStudents;
    final submissionRate = totalExpected > 0 
        ? (totalSubmitted / totalExpected * 100).toStringAsFixed(1)
        : '0.0';

    // Grade distribution
    final Map<String, int> gradeDistribution = {
      'A (90-100)': 0,
      'B (80-89)': 0,
      'C (70-79)': 0,
      'D (60-69)': 0,
      'F (<60)': 0,
    };

    for (var assignment in assignments) {
      for (var submission in assignment.submissions) {
        if (submission.grade != null) {
          final grade = submission.grade!;
          if (grade >= 90) {
            gradeDistribution['A (90-100)'] = (gradeDistribution['A (90-100)'] ?? 0) + 1;
          } else if (grade >= 80) {
            gradeDistribution['B (80-89)'] = (gradeDistribution['B (80-89)'] ?? 0) + 1;
          } else if (grade >= 70) {
            gradeDistribution['C (70-79)'] = (gradeDistribution['C (70-79)'] ?? 0) + 1;
          } else if (grade >= 60) {
            gradeDistribution['D (60-69)'] = (gradeDistribution['D (60-69)'] ?? 0) + 1;
          } else {
            gradeDistribution['F (<60)'] = (gradeDistribution['F (<60)'] ?? 0) + 1;
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Tổng bài tập' : 'Total Assignments',
                  value: assignments.length.toString(),
                  icon: Icons.assignment,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Tỷ lệ nộp' : 'Submission Rate',
                  value: '$submissionRate%',
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
                  title: isVietnamese ? 'Đúng hạn' : 'On Time',
                  value: totalOnTime.toString(),
                  icon: Icons.schedule,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Trễ hạn' : 'Late',
                  value: totalLate.toString(),
                  icon: Icons.warning,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Submission Rate Pie Chart
          Text(
            isVietnamese ? 'Tỷ lệ nộp bài' : 'Submission Rate',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _buildSubmissionPieChart(
              submitted: totalSubmitted,
              notSubmitted: totalExpected - totalSubmitted,
              isVietnamese: isVietnamese,
            ),
          ),

          const SizedBox(height: 24),

          // Grade Distribution
          Text(
            isVietnamese ? 'Phân bố điểm' : 'Grade Distribution',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _buildGradeBarChart(gradeDistribution),
          ),

          const SizedBox(height: 24),

          // Student Participation
          Text(
            isVietnamese ? 'Tham gia của sinh viên' : 'Student Participation',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildStudentParticipation(assignments, isVietnamese),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // QUIZ ANALYTICS
  // ═══════════════════════════════════════════════
  Widget _buildQuizAnalytics() {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
    final quizzes = ref.watch(quizProvider)
        .where((q) => q.courseId == widget.courseId)
        .toList();
    final submissions = ref.watch(quizSubmissionProvider);

    if (quizzes.isEmpty) {
      return Center(child: Text(isVietnamese ? 'Chưa có quiz nào' : 'No quizzes yet'));
    }

    // Calculate statistics
    final totalStudents = widget.students.length;
    final totalExpected = quizzes.length * totalStudents;
    final totalCompleted = submissions.length;
    final completionRate = totalExpected > 0
        ? (totalCompleted / totalExpected * 100).toStringAsFixed(1)
        : '0.0';

    // Average scores
    final scores = submissions.map((s) => s.score / s.maxScore * 100).toList();
    final avgScore = scores.isNotEmpty
        ? (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1)
        : '0.0';

    // Pass rate (>= 50%)
    final passed = submissions.where((s) => (s.score / s.maxScore) >= 0.5).length;
    final passRate = totalCompleted > 0
        ? (passed / totalCompleted * 100).toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Tổng quiz' : 'Total Quizzes',
                  value: quizzes.length.toString(),
                  icon: Icons.quiz,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Hoàn thành' : 'Completed',
                  value: '$completionRate%',
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
                  title: isVietnamese ? 'Điểm TB' : 'Avg Score',
                  value: '$avgScore%',
                  icon: Icons.grade,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Tỷ lệ đậu' : 'Pass Rate',
                  value: '$passRate%',
                  icon: Icons.emoji_events,
                  color: Colors.amber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Score Distribution
          Text(
            isVietnamese ? 'Phân bố điểm số' : 'Score Distribution',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _buildQuizScoreDistribution(submissions),
          ),

          const SizedBox(height: 24),

          // Quiz List with Stats
          Text(
            isVietnamese ? 'Chi tiết từng quiz' : 'Quiz Details',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...quizzes.map((quiz) {
            final quizSubmissions = submissions.where((s) => s.quizId == quiz.id).toList();
            final completed = quizSubmissions.length;
            final avgQuizScore = quizSubmissions.isNotEmpty
                ? (quizSubmissions.map((s) => s.score / s.maxScore * 100).reduce((a, b) => a + b) / quizSubmissions.length).toStringAsFixed(1)
                : '0.0';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.quiz),
                ),
                title: Text(quiz.title),
                subtitle: Text(isVietnamese
                    ? '$completed/$totalStudents sinh viên hoàn thành'
                    : '$completed/$totalStudents students completed'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isVietnamese ? 'TB: $avgQuizScore%' : 'Avg: $avgQuizScore%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isVietnamese
                          ? '${(completed / totalStudents * 100).toStringAsFixed(0)}% hoàn thành'
                          : '${(completed / totalStudents * 100).toStringAsFixed(0)}% completed',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // MATERIAL ANALYTICS
  // ═══════════════════════════════════════════════
  Widget _buildMaterialAnalytics() {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
    final materials = ref.watch(materialProvider)
        .where((m) => m.courseId == widget.courseId)
        .toList();
    final allViews = ref.watch(materialViewProvider);

    if (materials.isEmpty) {
      return Center(child: Text(isVietnamese ? 'Chưa có tài liệu nào' : 'No materials yet'));
    }

    // Calculate statistics
    final totalStudents = widget.students.length;
    final totalViews = allViews.length;
    final totalDownloads = allViews.where((v) => v.downloaded).length;
    final uniqueViewers = allViews.map((v) => v.studentId).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Tổng tài liệu' : 'Total Materials',
                  value: materials.length.toString(),
                  icon: Icons.folder,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Lượt xem' : 'Views',
                  value: totalViews.toString(),
                  icon: Icons.visibility,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Lượt tải' : 'Downloads',
                  value: totalDownloads.toString(),
                  icon: Icons.download,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: isVietnamese ? 'Đã xem' : 'Viewed',
                  value: '$uniqueViewers/$totalStudents',
                  icon: Icons.people,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Material Engagement
          Text(
            isVietnamese ? 'Mức độ tương tác' : 'Engagement Level',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...materials.map((material) {
            final materialViews = allViews.where((v) => v.materialId == material.id).toList();
            final viewCount = materialViews.length;
            final downloadCount = materialViews.where((v) => v.downloaded).length;
            final viewRate = totalStudents > 0
                ? (viewCount / totalStudents * 100).toStringAsFixed(0)
                : '0';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.folder),
                ),
                title: Text(material.title),
                subtitle: Text(isVietnamese
                    ? '$viewCount xem • $downloadCount tải'
                    : '$viewCount views • $downloadCount downloads'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getEngagementColor(int.parse(viewRate)).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$viewRate%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getEngagementColor(int.parse(viewRate)),
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Viewed students
                        Row(
                          children: [
                            const Icon(Icons.visibility, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              isVietnamese ? 'Đã xem ($viewCount):' : 'Viewed ($viewCount):',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (materialViews.isEmpty)
                          Text(isVietnamese ? 'Chưa có ai xem' : 'No views yet')
                        else
                          ...materialViews.take(5).map((view) {
                            final student = widget.students.firstWhere(
                              (s) => s.id == view.studentId,
                              orElse: () => AppUser(
                                id: '',
                                fullName: 'Unknown',
                                email: '',
                                role: UserRole.student,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              ),
                            );
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text(student.fullName.isNotEmpty ? student.fullName[0] : '?'),
                              ),
                              title: Text(student.fullName),
                              subtitle: Text(student.code ?? ''),
                              trailing: view.downloaded
                                  ? const Icon(Icons.download, size: 16, color: Colors.green)
                                  : null,
                            );
                          }),
                        if (materialViews.length > 5)
                          Text(
                            isVietnamese
                                ? '... và ${materialViews.length - 5} người khác'
                                : '... and ${materialViews.length - 5} others',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Not viewed students
                        Row(
                          children: [
                            const Icon(Icons.close, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              isVietnamese
                                  ? 'Chưa xem (${totalStudents - viewCount}):'
                                  : 'Not viewed (${totalStudents - viewCount}):',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        () {
                          final viewedStudentIds = materialViews.map((v) => v.studentId).toSet();
                          final notViewed = widget.students
                              .where((s) => !viewedStudentIds.contains(s.id))
                              .toList();

                          if (notViewed.isEmpty) {
                            return Text(isVietnamese ? 'Tất cả đã xem' : 'All viewed');
                          }

return Column(
  children: [
    // Show first 5 students
    ...notViewed.take(5).map((student) {
      return ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          child: Text(student.fullName[0]),
        ),
        title: Text(student.fullName),
        subtitle: Text(student.code ?? ''),
      );
    }),

    // Show "... and X more" if needed
    if (notViewed.length > 5)
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          isVietnamese
              ? '... và ${notViewed.length - 5} người khác'
              : '... and ${notViewed.length - 5} others',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
  ],
);
                        }(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getEngagementColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  // ═══════════════════════════════════════════════
  // CHART WIDGETS
  // ═══════════════════════════════════════════════

  Widget _buildSubmissionPieChart({
    required int submitted,
    required int notSubmitted,
    required bool isVietnamese,
  }) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: submitted.toDouble(),
            title: isVietnamese ? 'Đã nộp\n$submitted' : 'Submitted\n$submitted',
            color: Colors.green,
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: notSubmitted.toDouble(),
            title: isVietnamese ? 'Chưa nộp\n$notSubmitted' : 'Not Submitted\n$notSubmitted',
            color: Colors.red,
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildGradeBarChart(Map<String, int> distribution) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: distribution.values.isEmpty ? 10 : distribution.values.reduce((a, b) => a > b ? a : b).toDouble() + 5,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final labels = distribution.keys.toList();
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[value.toInt()].split(' ')[0],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: distribution.entries.toList().asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: _getGradeColor(entry.value.key),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return Colors.blue;
    if (grade.startsWith('C')) return Colors.orange;
    if (grade.startsWith('D')) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildQuizScoreDistribution(List submissions) {
    // Group scores into ranges
    final Map<String, int> scoreRanges = {
      '0-20': 0,
      '20-40': 0,
      '40-60': 0,
      '60-80': 0,
      '80-100': 0,
    };

    for (var submission in submissions) {
      final percentage = (submission.score / submission.maxScore * 100);
      if (percentage < 20) {
        scoreRanges['0-20'] = (scoreRanges['0-20'] ?? 0) + 1;
      } else if (percentage < 40) {
        scoreRanges['20-40'] = (scoreRanges['20-40'] ?? 0) + 1;
      } else if (percentage < 60) {
        scoreRanges['40-60'] = (scoreRanges['40-60'] ?? 0) + 1;
      } else if (percentage < 80) {
        scoreRanges['60-80'] = (scoreRanges['60-80'] ?? 0) + 1;
      } else {
        scoreRanges['80-100'] = (scoreRanges['80-100'] ?? 0) + 1;
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: scoreRanges.values.isEmpty ? 10 : scoreRanges.values.reduce((a, b) => a > b ? a : b).toDouble() + 3,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final labels = scoreRanges.keys.toList();
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: scoreRanges.entries.toList().asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: Colors.purple,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentParticipation(List<Assignment> assignments, bool isVietnamese) {
    // Calculate per-student submission count
    final Map<String, int> studentSubmissions = {};
    for (var student in widget.students) {
      studentSubmissions[student.id] = 0;
    }

    for (var assignment in assignments) {
      for (var submission in assignment.submissions) {
        studentSubmissions[submission.studentId] =
            (studentSubmissions[submission.studentId] ?? 0) + 1;
      }
    }

    // Sort by submission count
    final sortedStudents = widget.students.toList()
      ..sort((a, b) =>
          (studentSubmissions[b.id] ?? 0).compareTo(studentSubmissions[a.id] ?? 0));

    return Column(
      children: sortedStudents.take(10).map((student) {
        final count = studentSubmissions[student.id] ?? 0;
        final rate = assignments.isEmpty ? 0.0 : count / assignments.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(student.fullName[0]),
            ),
            title: Text(student.fullName),
            subtitle: Text(isVietnamese
                ? '${student.code} • $count/${assignments.length} bài tập'
                : '${student.code} • $count/${assignments.length} assignments'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rate >= 0.8
                    ? Colors.green.withOpacity(0.2)
                    : rate >= 0.5
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rate >= 0.8
                      ? Colors.green
                      : rate >= 0.5
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════

class _TabButton extends ConsumerWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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