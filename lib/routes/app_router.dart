// routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/login_screen.dart';
import '../screens/instructor/home_instructor.dart';
import '../screens/student/home_student.dart';
import '../screens/instructor/instructor_class_detail.dart';
import '../screens/instructor/exam_create.dart';
import '../screens/student/student_exam.dart';
import '../screens/student/assignment_detail_screen.dart';
import '../screens/student/classwork_screen.dart' as classwork;
import '../screens/instructor/group_detail_screen.dart'; 
import '../screens/instructor/course_detail_screen.dart'; 
import '../screens/instructor/semester_create_screen.dart'; 
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../models/class.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isLoggedIn = auth != null;
      final isLoginPage = state.uri.path == '/';

      if (!isLoggedIn && !isLoginPage) return '/';
      if (isLoggedIn && isLoginPage) return '/home';
      return null;
    },
    routes: [
      // ────── LOGIN ──────
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),

      // ────── HOME (INSTRUCTOR / STUDENT) ──────
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final user = ref.read(authProvider)!;
          return user.role == UserRole.instructor ? const HomeInstructor() : HomeStudent();
        },
      ),

      // ────── INSTRUCTOR: GROUP DETAIL ──────
      GoRoute(
        path: '/instructor/group/:groupId',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          final extra = state.extra as Map<String, dynamic>?;

          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('Không tìm thấy nhóm')),
            );
          }

          return GroupDetailScreen(
            group: extra['group'],
            course: extra['course'],
            semester: extra['semester'],
            students: extra['students'] ?? [],
          );
        },
      ),

      // ────── ASSIGNMENT DETAIL ──────
      GoRoute(
        path: '/assignment/:id',
        builder: (context, state) {
          final extra = state.extra;
          Map<String, dynamic> assignment = {
            'id': state.pathParameters['id'] ?? 'unknown',
            'title': 'Bài tập không xác định',
            'due': '-',
            'score': '-',
            'desc': '',
            'comment': null,
            'link': null,
            'status': '',
            'courseTitle': ''
          };
          if (extra is Map<String, dynamic>) assignment = extra;
          return AssignmentDetailScreen(assignment: assignment);
        },
      ),

      // ────── CLASSWORK ──────
      GoRoute(
        path: '/classwork',
        builder: (context, state) {
          final courses = state.extra as List<Map<String, dynamic>>?;
          return classwork.ClassworkScreen(courses: courses ?? []);
        },
      ),

      // ────── INSTRUCTOR: CLASS DETAIL ──────
      GoRoute(
        path: '/instructor/class/:id',
        builder: (context, state) {
          final cls = state.extra as ClassModel;
          return InstructorClassDetail(cls: cls);
        },
      ),

      // ────── INSTRUCTOR: CREATE EXAM ──────
      GoRoute(
        path: '/instructor/exam/create',
        builder: (context, state) {
          final classId = state.extra as String;
          return ExamCreateScreen(classId: classId);
        },
      ),

      // ────── INSTRUCTOR: EDIT EXAM ──────
      GoRoute(
        path: '/instructor/exam/edit',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic>) {
            return const Scaffold(body: Center(child: Text('Dữ liệu không hợp lệ')));
          }
          return ExamCreateScreen(
            classId: extra['classId'] as String,
            initialExam: extra['examData'] as Map<String, dynamic>,
            examIndex: extra['examIndex'] as int,
          );
        },
      ),

      // ────── STUDENT: TAKE EXAM ──────
      GoRoute(
        path: '/student/exam/:classId/:examId',
        builder: (context, state) {
          final classId = state.pathParameters['classId']!;
          final examId = state.pathParameters['examId']!;
          final extra = state.extra as Map<String, dynamic>?;

          if (extra == null) {
            return const Scaffold(body: Center(child: Text('Không tìm thấy bài kiểm tra')));
          }
          return StudentExamScreen(exam: extra, classId: classId);
        },
      ),

GoRoute(
  path: '/instructor/course/:courseId',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return CourseDetailScreen(
      course: extra['course'],
      semester: extra['semester'],
      groups: extra['groups'],
      students: extra['students'],
    );
  },
),
GoRoute(
  path: '/instructor/semester/create',
  builder: (context, state) => const SemesterCreateScreen(),
),
      
    ],
  );
});