
// import 'package:flutter_test/flutter_test.dart';
// import 'package:ggclassroom/providers/semester_provider.dart';
// import 'package:ggclassroom/services/mongodb_service.dart';
// import 'package:mongo_dart/mongo_dart.dart';

// class FakeMongoDBService extends MongoDBService {
//   static bool deleteOneCalled = false;
//   static SelectorBuilder? capturedSelector;

//   @override
//   static DbCollection getCollection(String collectionName) {
//     return FakeDbCollection();
//   }

//   static void reset() {
//     deleteOneCalled = false;
//     capturedSelector = null;
//   }
// }

// class FakeDbCollection implements DbCollection {
//   @override
//   Future<Map<String, dynamic>> deleteOne(selector, {WriteConcern? writeConcern, bool? bypassDocumentValidation}) async {
//     FakeMongoDBService.deleteOneCalled = true;
//     if (selector is SelectorBuilder) {
//       FakeMongoDBService.capturedSelector = selector;
//     }
//     return {'ok': 1};
//   }

//   @override
//   dynamic noSuchMethod(Invocation invocation) {
//     return super.noSuchMethod(invocation);
//   }
// }

// void main() {
//   group('SemesterNotifier', () {
//     late SemesterNotifier semesterNotifier;

//     setUp(() {
//       semesterNotifier = SemesterNotifier();
//       FakeMongoDBService.reset();
//       MongoDBService.setTestingInstance(FakeMongoDBService());
//     });

//     test('deleteSemester calls deleteOne on the collection', () async {
//       final semesterId = '60c72b969b1d8a001f8e8b82';
//       final objectId = ObjectId.fromHexString(semesterId);

//       await semesterNotifier.deleteSemester(semesterId);

//       expect(FakeMongoDBService.deleteOneCalled, isTrue);
//       // This is a simplified check. A real implementation would require inspecting the selector more deeply.
//       expect(FakeMongoDBService.capturedSelector, isNotNull);
//     });
//   });
// }
