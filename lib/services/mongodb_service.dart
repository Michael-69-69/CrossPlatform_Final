// services/mongodb_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoDBService {
  static Db? _db;
  static bool _isConnected = false;
  static bool _isWeb = kIsWeb;

  static String get connectionString {
    final username = dotenv.env['MONGODB_USERNAME'] ?? 'starboy_user';
    final password = dotenv.env['MONGODB_PASSWORD'] ?? '55359279';
    final cluster = dotenv.env['MONGODB_CLUSTER'] ?? 'cluster0.qnn7pyq.mongodb.net';
    final database = dotenv.env['DATABASE_NAME'] ?? 'GoogleClarroom';
    
    return 'mongodb+srv://$username:$password@$cluster/$database?retryWrites=true&w=majority';
  }

  static Future<void> connect() async {
    // Skip MongoDB connection on web - mongo_dart doesn't support web
    if (_isWeb) {
      print('MongoDB: Skipping direct connection on web platform');
      _isConnected = false;
      return;
    }

    if (_isConnected && _db != null && _db!.isConnected) {
      return;
    }

    try {
      await _db?.close();
      _db = await Db.create(connectionString);
      await _db!.open();
      _isConnected = true;
      print('MongoDB connected successfully');
    } catch (e) {
      print('MongoDB connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  static Future<void> disconnect() async {
    await _db?.close();
    _db = null;
    _isConnected = false;
    print('MongoDB disconnected');
  }

  // CRITICAL FIX: Return FRESH collection every time
  static DbCollection getCollection(String collectionName) {
    if (_isWeb) {
      throw Exception('MongoDB direct connection not supported on web. Use HTTP API instead.');
    }
    if (_db == null || !_isConnected || !_db!.isConnected) {
      throw Exception('MongoDB not connected. Call connect() first.');
    }
    print('Using collection: $collectionName');
    return _db!.collection(collectionName); // ← Always fresh
  }

  static Future<void> ensureCollectionExists(String collectionName) async {
    if (_isWeb) {
      print('MongoDB: Skipping collection check on web platform');
      return;
    }
    await connect(); // Ensure connected
    print('Collection "$collectionName" is ready');
  }

  static bool get isConnected {
    if (_isWeb) return false; // Web doesn't support direct connection
    return _isConnected && _db?.isConnected == true;
  }

  static bool get isWebPlatform => _isWeb;
}