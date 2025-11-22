// providers/semester_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester.dart';
import '../services/database_service.dart';

final semesterProvider = StateNotifierProvider<SemesterNotifier, List<Semester>>((ref) => SemesterNotifier());

class SemesterNotifier extends StateNotifier<List<Semester>> {
  SemesterNotifier() : super([]);

  Future<void> loadSemesters() async {
    try {
      // ✅ FIX: Load without sorting, then sort in memory
      final data = await DatabaseService.find(
        collection: 'semesters',
        // ❌ REMOVE: Don't sort booleans in database
        // sort: {'isActive': -1, '_id': -1},
      );
      
      // ✅ Parse data first
      final semesters = data.map(Semester.fromMap).toList();
      
      // ✅ Sort in memory: Active first, then by newest (reverse ID order)
      semesters.sort((a, b) {
        // First priority: isActive (true before false)
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1; // Active semesters first
        }
        // Second priority: Newest first (by ID)
        return b.id.compareTo(a.id);
      });
      
      state = semesters;
      
      // ✅ SMART: If no semester is active, auto-activate the first one
      if (state.isNotEmpty && !state.any((s) => s.isActive)) {
        print('⚠️ No active semester found. Auto-activating the first semester...');
        await setActiveSemester(state.first.id);
      }
      
      print('✅ Loaded ${state.length} semesters');
    } catch (e, stack) {
      print('loadSemesters error: $e');
      print(stack);
      state = [];
    }
  }

  Future<void> createSemester({
    required String code,
    required String name,
  }) async {
    try {
      // ✅ If this is the first semester, make it active by default
      final isFirstSemester = state.isEmpty;
      
      final doc = {
        'code': code,
        'name': name,
        'isActive': isFirstSemester, // ✅ First semester is auto-active
      };

      print('Inserting: $doc');

      final insertedId = await DatabaseService.insertOne(
        collection: 'semesters',
        document: doc,
      );

      print('Inserted ID: $insertedId');

      // ✅ Insert at the beginning (newest first)
      state = [
        Semester(
          id: insertedId,
          code: code,
          name: name,
          isActive: isFirstSemester,
        ),
        ...state,
      ];
      
      print('✅ Created semester: $insertedId (active: $isFirstSemester)');
    } catch (e, stack) {
      print('createSemester error: $e');
      print(stack);
      rethrow;
    }
  }

  // Set active semester (only one can be active at a time)
  Future<void> setActiveSemester(String semesterId) async {
    try {
      print('🔄 Setting active semester to: $semesterId');
      
      // Step 1: Deactivate ALL semesters
      for (var semester in state) {
        if (semester.isActive) {
          await DatabaseService.updateOne(
            collection: 'semesters',
            id: semester.id,
            update: {'isActive': false},
          );
        }
      }

      // Step 2: Activate the selected semester
      await DatabaseService.updateOne(
        collection: 'semesters',
        id: semesterId,
        update: {'isActive': true},
      );

      // Step 3: Update local state and re-sort
      state = state.map((s) {
        if (s.id == semesterId) {
          return s.copyWith(isActive: true);
        } else {
          return s.copyWith(isActive: false);
        }
      }).toList();
      
      // ✅ Re-sort after updating
      state.sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return b.id.compareTo(a.id);
      });

      print('✅ Active semester set to: $semesterId');
    } catch (e) {
      print('❌ Error setting active semester: $e');
      rethrow;
    }
  }

  // Get the active semester
  Semester? getActiveSemester() {
    try {
      return state.firstWhere((s) => s.isActive);
    } catch (e) {
      // If no active semester, return the first one as fallback
      return state.isNotEmpty ? state.first : null;
    }
  }

  Future<void> deleteSemester(String id) async {
    try {
      // Check if deleting the active semester
      final semesterToDelete = state.firstWhere((s) => s.id == id);
      final wasActive = semesterToDelete.isActive;
      
      await DatabaseService.deleteOne(
        collection: 'semesters',
        id: id,
      );
      
      state = state.where((s) => s.id != id).toList();
      
      // If we deleted the active semester, activate the first remaining one
      if (wasActive && state.isNotEmpty) {
        await setActiveSemester(state.first.id);
      }
      
      print('✅ Deleted semester: $id');
    } catch (e) {
      print('❌ Error deleting semester: $e');
    }
  }
}