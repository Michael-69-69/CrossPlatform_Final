// routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/login_screen.dart';
import '../screens/instructor/home_instructor.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/student_profile_screen.dart';
import '../screens/instructor/group_detail_screen.dart'; 
import '../screens/instructor/course_detail_screen.dart'; 
import '../screens/instructor/semester_create_screen.dart'; 
import '../screens/instructor/csv_preview_screen.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState != null;
      final isLoginPage = state.uri.path == '/';

      // ✅ Not logged in and not on login page -> redirect to login
      if (!isLoggedIn && !isLoginPage) {
        return '/';
      }

      // ✅ Logged in and on login page -> redirect based on role
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