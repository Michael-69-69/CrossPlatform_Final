
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:ggclassroom/models/semester.dart';
// import 'package:ggclassroom/models/user.dart';
// import 'package:ggclassroom/providers/auth_provider.dart';
// import 'package:ggclassroom/providers/course_provider.dart';
// import 'package:ggclassroom/providers/semester_provider.dart';
// import 'package:ggclassroom/screens/instructor/course_create_screen.dart';
// import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';

// import 'course_create_screen_test.mocks.dart';

// @GenerateMocks([CourseNotifier])
// void main() {
//   group('CourseCreateScreen', () {
//     late MockCourseNotifier mockCourseNotifier;

//     setUp(() {
//       mockCourseNotifier = MockCourseNotifier();
//     });

//     testWidgets('should create a course when the form is valid',
//         (WidgetTester tester) async {
//       await tester.pumpWidget(
//         ProviderScope(
//           overrides: [
//             courseProvider.overrideWith((ref) => mockCourseNotifier),
//             semesterProvider.overrideWith(
//               (ref) => StateNotifierProvider<SemesterNotifier, List<Semester>>(
//                   (ref) => SemesterNotifier()
//                     ..state = [
//                       Semester(id: 'semester1', name: 'Semester 1'),
//                       Semester(id: 'semester2', name: 'Semester 2'),
//                     ]),
//             ),
//             authProvider.overrideWith(
//               (ref) => StateProvider<User?>(
//                 (ref) => User(
//                   id: 'instructor1',
//                   name: 'Test Instructor',
//                   email: 'test@example.com',
//                   role: UserRole.instructor,
//                 ),
//               ),
//             ),
//           ],
//           child: const MaterialApp(
//             home: CourseCreateScreen(),
//           ),
//         ),
//       );

//       await tester.enterText(find.byType(TextFormField), 'Test Course');
//       await tester.pump();

//       await tester.tap(find.byType(DropdownButtonFormField<String>));
//       await tester.pumpAndSettle();

//       await tester.tap(find.text('Semester 1').last);
//       await tester.pumpAndSettle();

//       await tester.tap(find.byType(ElevatedButton));
//       await tester.pump();

//       verify(
//         mockCourseNotifier.createCourse(
//           name: 'Test Course',
//           semesterId: 'semester1',
//           instructorId: 'instructor1',
//           instructorName: 'Test Instructor',
//         ),
//       ).called(1);
//     });
//   });
// }
