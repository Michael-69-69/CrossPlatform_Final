// lib/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/login_screen.dart';
import '../screens/instructor/home_instructor.dart';
import '../screens/instructor/ai_quiz_generator_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/student_profile_screen.dart';
import '../screens/instructor/group_detail_screen.dart'; 
import '../screens/instructor/course_detail_screen.dart'; 
import '../screens/instructor/semester_create_screen.dart'; 
import '../screens/instructor/csv_preview_screen.dart';
import '../screens/shared/ai_chatbot_screen.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../models/course.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState != null;
      final isLoginPage = state.uri.path == '/';

      if (!isLoggedIn && !isLoginPage) {
        return '/';
      }

      if (isLoggedIn && isLoginPage) {
        if (authState.role == UserRole.instructor) {
          return '/instructor/home';
        } else {
          return '/student/home';
        }
      }

      return null;
    },
    routes: [
      // ══════ LOGIN ══════
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),

      // ══════ INSTRUCTOR ROUTES ══════
      GoRoute(
        path: '/instructor/home',
        builder: (context, state) => const HomeInstructor(),
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
            initialTabIndex: extra['initialTabIndex'] ?? 0,
          );
        },
      ),

      GoRoute(
        path: '/instructor/course/:courseId/assignments',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CourseDetailScreen(
            course: extra['course'],
            semester: extra['semester'],
            groups: extra['groups'],
            students: extra['students'],
            initialTabIndex: 1,
          );
        },
      ),

      GoRoute(
        path: '/instructor/course/:courseId/quiz',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CourseDetailScreen(
            course: extra['course'],
            semester: extra['semester'],
            groups: extra['groups'],
            students: extra['students'],
            initialTabIndex: 2,
          );
        },
      ),

      GoRoute(
        path: '/instructor/course/:courseId/materials',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CourseDetailScreen(
            course: extra['course'],
            semester: extra['semester'],
            groups: extra['groups'],
            students: extra['students'],
            initialTabIndex: 3,
          );
        },
      ),

      GoRoute(
        path: '/instructor/course/:courseId/groups',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CourseDetailScreen(
            course: extra['course'],
            semester: extra['semester'],
            groups: extra['groups'],
            students: extra['students'],
            initialTabIndex: 4,
          );
        },
      ),

      GoRoute(
        path: '/instructor/course/:courseId/forum',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CourseDetailScreen(
            course: extra['course'],
            semester: extra['semester'],
            groups: extra['groups'],
            students: extra['students'],
            initialTabIndex: 5,
          );
        },
      ),

      GoRoute(
        path: '/instructor/course/:courseId/analytics',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CourseDetailScreen(
            course: extra['course'],
            semester: extra['semester'],
            groups: extra['groups'],
            students: extra['students'],
            initialTabIndex: 6,
          );
        },
      ),

      GoRoute(
        path: '/instructor/group/:groupId',
        builder: (context, state) {
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

      GoRoute(
        path: '/instructor/semester/create',
        builder: (context, state) => const SemesterCreateScreen(),
      ),

      GoRoute(
        path: '/instructor/csv-preview',
        builder: (context, state) => const CsvPreviewScreen(),
      ),

      // ══════ AI ROUTES ══════
      GoRoute(
        path: '/ai-chat',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Course) {
            return AIChatbotScreen(course: extra);
          } else if (extra is Map<String, dynamic>) {
            return AIChatbotScreen(
              course: extra['course'] as Course?,
              materialContext: extra['materialContext'] as String?,
            );
          }
          return const AIChatbotScreen();
        },
      ),

      GoRoute(
        path: '/instructor/ai-quiz-generator/:courseId',
        builder: (context, state) {
          final course = state.extra as Course;
          return AIQuizGeneratorScreen(course: course);
        },
      ),

      // ══════ STUDENT ROUTES ══════
      GoRoute(
        path: '/student/home',
        builder: (context, state) => const StudentHomeScreen(),
      ),

      GoRoute(
        path: '/student/profile',
        builder: (context, state) => const StudentProfileScreen(),
      ),
    ],
  );
});