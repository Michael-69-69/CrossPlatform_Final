// services/database_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import 'api_service.dart';
import 'mongodb_service.dart';

/// Unified database service that works on both web and native platforms
class DatabaseService {
  static bool get isWeb => kIsWeb;

  /// Find multiple documents
  static Future<List<Map<String, dynamic>>> find({
    required String collection,
    Map<String, dynamic>? filter,
    Map<String, dynamic>? sort,
    int? limit,
    int? skip,
  }) async {
    if (isWeb) {
      // ✅ WEB: Use Render FastAPI backend
      return await ApiService.find(
        collection: collection,
        filter: filter,
        sort: sort,
        limit: limit,
        skip: skip,
      );
    } else {
      // ✅ MOBILE/DESKTOP: Use direct MongoDB connection
      await MongoDBService.connect();
      final col = await MongoDBService.getCollection(collection);
      
      // ✅ FIX: Convert filter to use ObjectId
      final convertedFilter = _convertFilterForMongo(filter);
      
      var results = await col.find(convertedFilter).toList();
      
      // ✅ FIX: Convert results to proper Map<String, dynamic>
      results = results.map((doc) => Map<String, dynamic>.from(doc)).toList();
      
      // Apply sorting
      if (sort != null && sort.isNotEmpty) {
        final sortKey = sort.keys.first;
        final sortOrder = sort[sortKey];
        results.sort((a, b) {
          final aVal = a[sortKey];
          final bVal = b[sortKey];
          if (aVal == null && bVal == null) return 0;
          if (aVal == null) return 1;
          if (bVal == null) return -1;
          final comparison = (aVal as Comparable).compareTo(bVal as Comparable);
          return sortOrder == 1 ? comparison : -comparison;
        });
      }
      
      // Apply skip
      if (skip != null && skip > 0) {
        results = results.skip(skip).toList();
      }
      
      // Apply limit
      if (limit != null && limit > 0) {
        results = results.take(limit).toList();
      }
      
      return results;
    }
  }

  /// Find one document
  static Future<Map<String, dynamic>?> findOne({
    required String collection,
    Map<String, dynamic>? filter,
  }) async {
    if (isWeb) {
      // ✅ WEB: Use Render FastAPI backend
      return await ApiService.findOne(
        collection: collection,
        filter: filter,
      );
    } else {
      // ✅ MOBILE/DESKTOP: Use direct MongoDB connection
      await MongoDBService.connect();
      final col = await MongoDBService.getCollection(collection);
      
      // ✅ FIX: Convert filter to use ObjectId
      final convertedFilter = _convertFilterForMongo(filter);
      
      final result = await col.findOne(convertedFilter);
      
      // ✅ FIX: Convert result to proper Map<String, dynamic>
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    }
  }

  /// Insert one document
  static Future<String> insertOne({
    required String collection,
    required Map<String, dynamic> document,
  }) async {
    if (isWeb) {
      // ✅ WEB: Use Render FastAPI backend
      return await ApiService.insertOne(
        collection: collection,
        document: document,
      );
    } else {
      // ✅ MOBILE/DESKTOP: Use direct MongoDB connection
      await MongoDBService.connect();
      final col = await MongoDBService.getCollection(collection);
      final doc = _prepareDocument(document);
      final result = await col.insertOne(doc);
      return result.id.toHexString();
    }
  }

  /// Insert many documents
  static Future<List<String>> insertMany({
    required String collection,
    required List<Map<String, dynamic>> documents,
  }) async {
    if (isWeb) {
      // ✅ WEB: Use Render FastAPI backend
      return await ApiService.insertMany(
        collection: collection,
        documents: documents,
      );
    } else {
      // ✅ MOBILE/DESKTOP: Use direct MongoDB connection
      await MongoDBService.connect();
      final col = await MongoDBService.getCollection(collection);
      final preparedDocs = documents.map(_prepareDocument).toList();
      
      // Insert documents one by one and collect IDs
      final insertedIds = <String>[];
      for (final doc in preparedDocs) {
        final result = await col.insertOne(doc);
        insertedIds.add(result.id.toHexString());
      }
      
      return insertedIds;
    }
  }

  /// Update one document
  static Future<void> updateOne({
    required String collection,
    required String id,
    required Map<String, dynamic> update,
  }) async {
    if (isWeb) {
      // ✅ WEB: Use Render FastAPI backend
      await ApiService.updateOne(
        collection: collection,
        id: id,
        update: update,
      );
    } else {
      // ✅ MOBILE/DESKTOP: Use direct MongoDB connection
      await MongoDBService.connect();
      final col = await MongoDBService.getCollection(collection);
      final updateDoc = _prepareUpdate(update);
      await col.updateOne(
        where.id(ObjectId.fromHexString(id)),
        updateDoc,
      );
    }
  }

  /// Delete one document
  static Future<void> deleteOne({
    required String collection,
    required String id,
  }) async {
    if (isWeb) {
      // ✅ WEB: Use Render FastAPI backend
      await ApiService.deleteOne(
        collection: collection,
        id: id,
      );
    } else {
      // ✅ MOBILE/DESKTOP: Use direct MongoDB connection
      await MongoDBService.connect();
      final col = await MongoDBService.getCollection(collection);
      await col.deleteOne(where.id(ObjectId.fromHexString(id)));
    }
  }

  /// Count documents
  static Future<int> count({
    required String collection,
    Map<String, dynamic>? filter,
  }) async {
    if (isWeb) {
      // ✅ WEB: Use Render FastAPI backend
      return await ApiService.count(
        collection: collection,
        filter: filter,
      );
    } else {
      // ✅ MOBILE/DESKTOP: Use direct MongoDB connection
      await MongoDBService.connect();
      final col = await MongoDBService.getCollection(collection);
      
      // ✅ FIX: Convert filter to use ObjectId
      final convertedFilter = _convertFilterForMongo(filter);
      
      return await col.count(convertedFilter);
    }
  }

  /// ✅ UPDATED: Convert filter to use ObjectId for mobile MongoDB
  static Map<String, dynamic> _convertFilterForMongo(Map<String, dynamic>? filter) {
    if (filter == null) return {};
    
    final converted = <String, dynamic>{};
    
    // ✅ UPDATED: List of fields that should be ObjectId
    const idFields = [
      'courseId',
      'semesterId',
      'instructorId',
      'studentId',
      'userId',            // ✅ ADD THIS - for in_app_notifications
      'quizId',
      'assignmentId',
      'materialId',
      'announcementId',
      'groupId',
      'topicId',           // ✅ For forum topics
      'parentReplyId',     // ✅ For forum nested replies
      'conversationId',    // ✅ For messages
      '_id',
    ];
    
    for (final entry in filter.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Convert ID fields to ObjectId
      if (idFields.contains(key) && value is String) {
        try {
          converted[key] = ObjectId.fromHexString(value);
        } catch (e) {
          print('⚠️ Failed to convert $key to ObjectId: $e');
          converted[key] = value;
        }
      } 
      // Handle nested maps
      else if (value is Map<String, dynamic>) {
        converted[key] = _convertFilterForMongo(value);
      }
      // Keep other values as-is
      else {
        converted[key] = value;
      }
    }
    
    return converted;
  }

  /// Prepare document for MongoDB (convert ObjectId strings to ObjectId)
  static Map<String, dynamic> _prepareDocument(Map<String, dynamic> doc) {
    final result = <String, dynamic>{};
    
    for (final entry in doc.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Handle _id field
      if (key == '_id' && value is String) {
        try {
          result[key] = ObjectId.fromHexString(value);
        } catch (e) {
          result[key] = value;
        }
      } 
      // Handle nested maps
      else if (value is Map) {
        result[key] = _prepareDocument(value as Map<String, dynamic>);
      } 
      // Handle arrays
      else if (value is List) {
        result[key] = value.map((e) {
          if (e is Map) {
            return _prepareDocument(e as Map<String, dynamic>);
          } else if (e is String && key.endsWith('Ids')) {
            // Convert array of IDs (like groupIds, studentIds)
            try {
              return ObjectId.fromHexString(e);
            } catch (_) {
              return e;
            }
          }
          return e;
        }).toList();
      } 
      // Handle ID fields (courseId, studentId, etc.)
      else if (value is String && 
               (key.endsWith('Id') || key.endsWith('id')) &&
               key != 'id' &&
               key != '_id') {
        try {
          result[key] = ObjectId.fromHexString(value);
        } catch (e) {
          result[key] = value;
        }
      } 
      // Keep other values as-is
      else {
        result[key] = value;
      }
    }
    
    return result;
  }

  /// Prepare update document for MongoDB
  static ModifierBuilder _prepareUpdate(Map<String, dynamic> update) {
    final modifier = ModifierBuilder();
    for (final entry in update.entries) {
      if (entry.value is Map) {
        modifier.set(entry.key, _prepareDocument(entry.value as Map<String, dynamic>));
      } else if (entry.value is List) {
        // ✅ FIX: Handle arrays properly
        final list = entry.value as List;
        final processedList = list.map((item) {
          if (item is Map) {
            return _prepareDocument(item as Map<String, dynamic>);
          }
          return item;
        }).toList();
        modifier.set(entry.key, processedList);
      } else {
        modifier.set(entry.key, entry.value);
      }
    }
    return modifier;
  }

  /// Connect to database (no-op on web, connects MongoDB on native)
  static Future<void> connect() async {
    if (!isWeb) {
      await MongoDBService.connect();
    }
  }

  /// Ensure collection exists (no-op on web, checks on native)
  static Future<void> ensureCollectionExists(String collectionName) async {
    if (!isWeb) {
      await MongoDBService.ensureCollectionExists(collectionName);
    }
  }
}