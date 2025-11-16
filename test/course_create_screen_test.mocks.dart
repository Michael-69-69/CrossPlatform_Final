
import 'package:ggclassroom/providers/course_provider.dart';
import 'package:mockito/mockito.dart';

class MockCourseNotifier extends Mock implements CourseNotifier {
  @override
  Future<void> createCourse({
    required String name,
    required String semesterId,
    required String instructorId,
    required String instructorName,
  }) {
    return super.noSuchMethod(
      Invocation.method(
        #createCourse,
        [],
        {
          #name: name,
          #semesterId: semesterId,
          #instructorId: instructorId,
          #instructorName: instructorName,
        },
      ),
      returnValue: Future.value(),
    );
  }
}
