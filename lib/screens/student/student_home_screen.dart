// screens/student/student_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/semester.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/group_provider.dart';
import 'student_course_detail_screen.dart';
import 'student_dashboard_screen.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  String? _selectedSemesterId;
  bool _showDashboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(semesterProvider.notifier).loadSemesters();
      ref.read(courseProvider.notifier).loadCourses();
      ref.read(groupProvider.notifier).loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final semesters = ref.watch(semesterProvider);
    final allCourses = ref.watch(courseProvider);
    final allGroups = ref.watch(groupProvider);

    // Auto-select latest semester
    if (_selectedSemesterId == null && semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedSemesterId = semesters.first.id;
        });
      });
    }

    final selectedSemester = semesters.firstWhere(
      (s) => s.id == _selectedSemesterId,
      orElse: () => semesters.isNotEmpty ? semesters.first : Semester(id: '', code: '', name: ''),
    );

    // Get student's enrolled courses
    final studentGroups = allGroups.where((g) => 
      g.studentIds.contains(user?.id ?? '')
    ).toList();

    final enrolledCourses = allCourses.where((course) {
      return course.semesterId == _selectedSemesterId &&
             studentGroups.any((g) => g.courseId == course.id);
    }).toList();

    // Check if selected semester is past (read-only)
    final isPastSemester = semesters.isNotEmpty && 
                          selectedSemester.id != semesters.first.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khóa học của tôi'),
        actions: [
          // Dashboard toggle
          IconButton(
            icon: Icon(_showDashboard ? Icons.grid_view : Icons.dashboard),
            onPressed: () => setState(() => _showDashboard = !_showDashboard),
            tooltip: _showDashboard ? 'Xem khóa học' : 'Xem dashboard',
          ),
          // Profile
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/student/profile'),
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Semester Switcher
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSemesterId,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: semesters.map((s) {
                      final isCurrent = s.id == semesters.first.id;
                      return DropdownMenuItem(
                        value: s.id,
                        child: Row(
                          children: [
                            Text('${s.code}: ${s.name}'),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                label: Text('Hiện tại', style: TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedSemesterId = value),
                  ),
                ),
              ],
            ),
          ),
          
          // Warning for past semesters
          if (isPastSemester)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Học kỳ cũ - Chỉ xem, không thể nộp bài hoặc làm quiz',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),

          // Content: Dashboard or Course Cards
          Expanded(
            child: _showDashboard
                ? StudentDashboardScreen(
                    semesterId: _selectedSemesterId ?? '',
                    courses: enrolledCourses,
                  )
                : _buildCourseCards(enrolledCourses, selectedSemester, studentGroups, isPastSemester),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCards(
    List<Course> courses,
    Semester semester,
    List<Group> studentGroups, // ✅ FIX: Changed from List<dynamic> to List<Group>
    bool isPastSemester,
  ) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có khóa học nào',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        
        // ✅ FIX: Proper orElse with Group type
        final courseGroup = studentGroups.firstWhere(
          (g) => g.courseId == course.id,
          orElse: () => Group(
            id: '',
            name: 'N/A',
            courseId: '',
          ),
        );

        return _CourseCard(
          course: course,
          semester: semester,
          groupName: courseGroup.name,
          isPastSemester: isPastSemester,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentCourseDetailScreen(
                  course: course,
                  semester: semester,
                  isPastSemester: isPastSemester,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final Semester semester;
  final String groupName;
  final bool isPastSemester;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.semester,
    required this.groupName,
    required this.isPastSemester,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.primaries[course.code.hashCode % Colors.primaries.length],
                    Colors.primaries[course.code.hashCode % Colors.primaries.length].withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        course.code,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (isPastSemester)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cũ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Course Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course.instructorName,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.group, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          groupName,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}