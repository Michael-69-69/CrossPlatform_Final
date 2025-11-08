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
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final user = ref.read(authProvider)!;
          return user.role == UserRole.instructor
              ? const HomeInstructor()
              : HomeStudent();
        },
      ),
      GoRoute(
        // keep absolute path
        path: '/assignment/:id',
        builder: (context, state) {
          final extra = state.extra;
          Map<String, dynamic> assignment;
          if (extra is Map<String, dynamic>) {
            assignment = extra;
          } else {
            // Try to extract id at runtime from whatever property the go_router version provides.
            // Use dynamic access inside try/catch so we don't get compile-time errors.
            String id = 'unknown';
            try {
              final dyn = state as dynamic;
              final loc = dyn.location ?? dyn.uri?.toString() ?? dyn.subloc;
              if (loc is String) {
                final segs = Uri.parse(loc).pathSegments;
                if (segs.isNotEmpty) id = segs.last;
              }
            } catch (_) {
              // ignore — leave id as 'unknown'
            }

            assignment = {
              'id': id,
              'title': 'Bài tập #$id',
              'due': '-',
              'score': '-',
              'desc': '',
              'comment': null,
              'link': null,
              'status': '',
              'rating': null,
              'courseTitle': ''
            };
          }
          return AssignmentDetailScreen(assignment: assignment);
        },
      ),
      GoRoute(
        path: '/classwork',
        builder: (context, state) {
          final courses = state.extra as List<Map<String, dynamic>>;
          return classwork.ClassworkScreen(courses: courses);
        },
      ),
    ],
    redirect: (context, state) {
      // Fix: get auth from provider using ProviderScope.containerOf
      final container = ProviderScope.containerOf(context, listen: false);
      final auth = container.read(authProvider);

      final loggedIn = auth != null;
      final loggingIn = state.uri.toString() == '/';

      if (!loggedIn && !loggingIn) return '/';
      if (loggedIn && loggingIn) return '/home';
      return null;
    },
  );
});