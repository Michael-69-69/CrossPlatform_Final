// services/api_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl {
    // Get API URL from environment or use default
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api';
    return apiUrl;
  }

  static bool get isWeb => kIsWeb;

  // Generic method to make HTTP requests
  static Future<Map<String, dynamic>> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
      );

      http.Response response;
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {'success': true};
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : {};
        throw Exception(
          errorBody['message'] ?? 
          'API request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('API request error: $e');
      rethrow;
    }
  }

  // Collection operations
  static Future<List<Map<String, dynamic>>> find({
    required String collection,
    Map<String, dynamic>? filter,
    Map<String, dynamic>? sort,
    int? limit,
    int? skip,
  }) async {
    final response = await _request(
      method: 'POST',
      endpoint: '/find',
      body: {
        'collection': collection,
        if (filter != null) 'filter': filter,
        if (sort != null) 'sort': sort,
        if (limit != null) 'limit': limit,
        if (skip != null) 'skip': skip,
      },
    );
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  static Future<Map<String, dynamic>?> findOne({
    required String collection,
    Map<String, dynamic>? filter,
  }) async {
    final response = await _request(
      method: 'POST',
      endpoint: '/findOne',
      body: {
        'collection': collection,
        if (filter != null) 'filter': filter,
      },
    );
    return response['data'] as Map<String, dynamic>?;
  }

  static Future<String> insertOne({
    required String collection,
    required Map<String, dynamic> document,
  }) async {
    final response = await _request(
      method: 'POST',
      endpoint: '/insertOne',
      body: {
        'collection': collection,
        'document': document,
      },
    );
    // ✅ FIXED: Changed from 'id' to 'insertedId' to match FastAPI response
    return response['insertedId'] as String;
  }

  static Future<List<String>> insertMany({
    required String collection,
    required List<Map<String, dynamic>> documents,
  }) async {
    final response = await _request(
      method: 'POST',
      endpoint: '/insertMany',
      body: {
        'collection': collection,
        'documents': documents,
      },
    );
    return List<String>.from(response['insertedIds'] ?? []);
  }

  static Future<void> updateOne({
    required String collection,
    required String id,
    required Map<String, dynamic> update,
  }) async {
    await _request(
      method: 'POST',
      endpoint: '/updateOne',
      body: {
        'collection': collection,
        'id': id,
        'update': update,
      },
    );
  }

  static Future<void> deleteOne({
    required String collection,
    required String id,
  }) async {
    await _request(
      method: 'POST',
      endpoint: '/deleteOne',
      body: {
        'collection': collection,
        'id': id,
      },
    );
  }

  static Future<int> count({
    required String collection,
    Map<String, dynamic>? filter,
  }) async {
    final response = await _request(
      method: 'POST',
      endpoint: '/count',
      body: {
        'collection': collection,
        if (filter != null) 'filter': filter,
      },
    );
    return response['count'] as int;
  }
}