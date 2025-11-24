// providers/semester_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester.dart';
import '../services/database_service.dart';
import '../services/cache_service.dart'; // ✅ ADD
import '../services/network_service.dart'; // ✅ ADD

final semesterProvider = StateNotifierProvider<SemesterNotifier, List<Semester>>((ref) => SemesterNotifier());

class SemesterNotifier extends StateNotifier<List<Semester>> {
  SemesterNotifier() : super([]);

  Future<void> loadSemesters() async {
    try {
      // ✅ 1. Try to load from cache first
      final cached = await CacheService.getCachedCategoryData('semesters');
      if (cached != null && cached.isNotEmpty) {
        final semesters = cached.map((e) => Semester.fromMap(e)).toList();
        
        // Sort in memory: Active first, then by newest
        semesters.sort((a, b) {
          if (a.isActive != b.isActive) {
            return a.isActive ? -1 : 1;
          }
          return b.id.compareTo(a.id);
        });
        
        state = semesters;
        print('📦 Loaded ${state.length} semesters from cache');
        
        // ✅ If online, refresh in background
        if (NetworkService().isOnline) {
          _refreshSemestersInBackground();
        }
        
        return;
      }

      // ✅ 2. If no cache and offline, show empty
      if (NetworkService().isOffline) {
        print('⚠️ Offline and no cache available for semesters');
        state = [];
        return;
      }

      // ✅ 3. Fetch from database if online or no cache
      final data = await DatabaseService.find(
        collection: 'semesters',
      );
      
      // Parse data first
      final semesters = data.map((e) => Semester.fromMap(e)).toList();
      
      // Sort in memory: Active first, then by newest (reverse ID order)
      semesters.sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return b.id.compareTo(a.id);
      });
      
      state = semesters;

      // ✅ 4. Save to cache
      await CacheService.cacheCategoryData(
        key: 'semesters',
        data: data,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );
      
      // SMART: If no semester is active, auto-activate the first one
      if (state.isNotEmpty && !state.any((s) => s.isActive)) {
        print('⚠️ No active semester found. Auto-activating the first semester...');
        await setActiveSemester(state.first.id);
      }
      
      print('✅ Loaded ${state.length} semesters from database');
    } catch (e, stack) {
      print('loadSemesters error: $e');
      print(stack);
      
      // ✅ 5. On error, try to fallback to cache
      final cached = await CacheService.getCachedCategoryData('semesters');
      if (cached != null && cached.isNotEmpty) {
        state = cached.map((e) => Semester.fromMap(e)).toList();
        print('📦 Loaded ${state.length} semesters from cache (fallback)');
      } else {
        state = [];
      }
    }
  }

  // ✅ Background refresh (silent update without blocking UI)
  Future<void> _refreshSemestersInBackground() async {
    try {
      final data = await DatabaseService.find(
        collection: 'semesters',
      );
      
      final semesters = data.map((e) => Semester.fromMap(e)).toList();
      
      semesters.sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return b.id.compareTo(a.id);
      });
      
      state = semesters;

      // Update cache
      await CacheService.cacheCategoryData(
        key: 'semesters',
        data: data,
        durationMinutes: CacheService.CATEGORY_CACHE_DURATION,
      );

      print('🔄 Background refresh: semesters updated');
    } catch (e) {
      print('Background refresh failed: $e');
      // Don't throw - this is a background operation
    }
  }

  Future<void> createSemester({
    required String code,
    required String name,
  }) async {
    try {
      // If this is the first semester, make it active by default
      final isFirstSemester = state.isEmpty;
      
      final doc = {
        'code': code,
        'name': name,
        'isActive': isFirstSemester,
      };

      print('Inserting: $doc');

      final insertedId = await DatabaseService.insertOne(
        collection: 'semesters',
        document: doc,
      );

      print('Inserted ID: $insertedId');

      // Insert at the beginning (newest first)
      state = [
        Semester(
          id: insertedId,
          code: code,
          name: name,
          isActive: isFirstSemester,
        ),
        ...state,
      ];
      
      // ✅ Clear cache after creating
      await CacheService.clearCache('semesters');
      
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
      
      // Re-sort after updating
      state.sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return b.id.compareTo(a.id);
      });

      // ✅ Clear cache after updating
      await CacheService.clearCache('semesters');

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
      
      // ✅ Clear cache after deleting
      await CacheService.clearCache('semesters');
      
      print('✅ Deleted semester: $id');
    } catch (e) {
      print('❌ Error deleting semester: $e');
    }
  }

  // ✅ Add method to force refresh from database
  Future<void> refresh() async {
    // Clear cache first to force fresh fetch
    await CacheService.clearCache('semesters');
    await loadSemesters();
  }
}