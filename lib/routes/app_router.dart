import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/login_screen.dart';
import '../screens/home_instructor.dart';
import '../screens/home_student.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../screens/assignment_detail_screen.dart';
import '../screens/classwork_screen.dart' as classwork;

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
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final user = ref.read(authProvider)!;
          return user.role == UserRole.instructor ? const HomeInstructor() : HomeStudent();
        },
      ),
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
      GoRoute(
        path: '/classwork',
        builder: (context, state) {
          final courses = state.extra as List<Map<String, dynamic>>?;
          return classwork.ClassworkScreen(courses: courses ?? []);
        },
      ),
    ],
  );
});