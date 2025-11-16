// services/data_loader.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/semester_provider.dart';
import '../providers/course_provider.dart';
import '../providers/group_provider.dart';
import '../providers/student_provider.dart';

Future<void> loadAllData(ProviderContainer container) async {
  try {
    await Future.wait([
      container.read(semesterProvider.notifier).loadSemesters(),
      container.read(courseProvider.notifier).loadCourses(),
      container.read(groupProvider.notifier).loadGroups(),
      container.read(studentProvider.notifier).loadStudents(),
    ]);
  } catch (e) {
    print('loadAllData error: $e');
    rethrow;
  }
}