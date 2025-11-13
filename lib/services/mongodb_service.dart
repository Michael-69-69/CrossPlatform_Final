import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoDBService {
  static Db? _db;
  static bool _isConnected = false;

  static String get connectionString {
    final username = dotenv.env['MONGODB_USERNAME'] ?? 'starboy_user';
    final password = dotenv.env['MONGODB_PASSWORD'] ?? '55359279';
    final cluster = dotenv.env['MONGODB_CLUSTER'] ?? 'cluster0.qnn7pyq.mongodb.net';
    final database = dotenv.env['DATABASE_NAME'] ?? 'GoogleClarroom';
    
    return 'mongodb+srv://$username:$password@$cluster/$database?retryWrites=true&w=majority';
  }

  static Future<void> connect() async {
    if (_isConnected && _db != null) {
      return;
    }

    try {
      _db = await Db.create(connectionString);
      await _db!.open();
      _isConnected = true;
      print('MongoDB connected successfully');
    } catch (e) {
      print('MongoDB connection error: $e');
      rethrow;
    }
  }

  static Future<void> disconnect() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _isConnected = false;
      print('MongoDB disconnected');
    }
  }

  static DbCollection getCollection(String collectionName) {
    if (_db == null || !_isConnected) {
      throw Exception('MongoDB not connected. Call connect() first.');
    }
    // MongoDB automatically creates collections on first insert,
    // but we can ensure it exists by getting the collection reference
    final collection = _db!.collection(collectionName);
    print('Using collection: $collectionName');
    return collection;
  }

  /// Ensures a collection exists in the database
  /// MongoDB creates collections automatically on first insert,
  /// so we just verify the connection is ready
  static Future<void> ensureCollectionExists(String collectionName) async {
    if (_db == null || !_isConnected) {
      throw Exception('MongoDB not connected. Call connect() first.');
    }
    
    // MongoDB automatically creates collections on first insert
    // The collection will be created automatically when we insert the first document
    print('Collection "$collectionName" is ready (will be created on first insert if needed)');
  }

  static bool get isConnected => _isConnected;
}


