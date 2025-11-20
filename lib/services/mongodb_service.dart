// services/mongodb_service.dart
import 'dart:async'; // ✅ ADD THIS for TimeoutException
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoDBService {
  static Db? _db;
  static bool _isConnected = false;
  static bool _isWeb = kIsWeb;
  static DateTime? _lastConnectionAttempt;
  static const _connectionTimeout = Duration(seconds: 30);

  static String get connectionString {
    final username = dotenv.env['MONGODB_USERNAME'] ?? 'starboy_user';
    final password = dotenv.env['MONGODB_PASSWORD'] ?? '55359279';
    final cluster = dotenv.env['MONGODB_CLUSTER'] ?? 'cluster0.qnn7pyq.mongodb.net';
    final database = dotenv.env['DATABASE_NAME'] ?? 'GoogleClarroom';
    
    // ✅ FIX: Add tls=true for SSL/TLS connection
    return 'mongodb+srv://$username:$password@$cluster/$database?retryWrites=true&w=majority&tls=true';
  }

  static Future<void> connect() async {
    // Skip MongoDB connection on web - mongo_dart doesn't support web
    if (_isWeb) {
      print('MongoDB: Skipping direct connection on web platform');
      _isConnected = false;
      return;
    }

    // ✅ FIX: Check if already connected and connection is alive
    if (_isConnected && _db != null) {
      try {
        // Test if connection is still alive
        await _db!.collection('test').findOne();
        print('✅ MongoDB: Using existing connection');
        return;
      } catch (e) {
        print('⚠️ MongoDB: Existing connection is dead, reconnecting...');
        _isConnected = false;
        await _db?.close();
        _db = null;
      }
    }

    // ✅ FIX: Prevent too frequent reconnection attempts
    if (_lastConnectionAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastConnectionAttempt!);
      if (timeSinceLastAttempt < const Duration(seconds: 5)) {
        print('⏳ MongoDB: Waiting before reconnection attempt...');
        await Future.delayed(const Duration(seconds: 5) - timeSinceLastAttempt);
      }
    }

    _lastConnectionAttempt = DateTime.now();

    try {
      print('🔄 MongoDB: Connecting to database...');
      
      // ✅ FIX: Close any existing connection first
      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      // Create new connection
      _db = await Db.create(connectionString);
      
      // ✅ FIX: Add connection timeout
      await _db!.open().timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException('MongoDB connection timeout after $_connectionTimeout');
        },
      );
      
      _isConnected = true;
      print('✅ MongoDB connected successfully');
    } catch (e) {
      print('❌ MongoDB connection error: $e');
      _isConnected = false;
      _db = null;
      rethrow;
    }
  }

  static Future<void> disconnect() async {
    try {
      if (_db != null) {
        await _db!.close();
      }
    } catch (e) {
      print('Error closing MongoDB connection: $e');
    } finally {
      _db = null;
      _isConnected = false;
      print('MongoDB disconnected');
    }
  }

  // ✅ FIX: Ensure connection before returning collection
  static Future<DbCollection> getCollection(String collectionName) async {
    if (_isWeb) {
      throw Exception('MongoDB direct connection not supported on web. Use HTTP API instead.');
    }
    
    // ✅ FIX: Auto-reconnect if not connected
    if (!_isConnected || _db == null || !_db!.isConnected) {
      print('⚠️ MongoDB not connected, reconnecting...');
      await connect();
    }
    
    print('📚 Using collection: $collectionName');
    return _db!.collection(collectionName);
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