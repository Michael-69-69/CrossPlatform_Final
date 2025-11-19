// utils/file_download_helper.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Platform-specific imports
import 'file_download_web.dart' if (dart.library.io) 'file_download_mobile.dart' as platform;

class FileDownloadHelper {
  /// Download from Base64 data - works on both web and mobile
  static Future<String> downloadFromBase64({
    required String base64Data,
    required String fileName,
  }) async {
    try {
      // Decode Base64 to bytes
      final bytes = base64Decode(base64Data);

      // Use platform-specific download
      return await platform.downloadFile(
        bytes: bytes,
        fileName: fileName,
      );
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }

  /// Download a file from URL - works on both web and mobile
  static Future<String> downloadFile({
    required String url,
    required String fileName,
  }) async {
    try {
      // Fetch the file
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      // Use platform-specific download
      return await platform.downloadFile(
        bytes: response.bodyBytes,
        fileName: fileName,
      );
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }

  /// Download from local path (mobile only) or copy file
  static Future<String?> downloadFromLocalPath({
    required String localPath,
    required String fileName,
  }) async {
    if (kIsWeb) {
      // Web doesn't have local file system access
      return null;
    }

    try {
      return await platform.downloadFromLocalPath(
        localPath: localPath,
        fileName: fileName,
      );
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }
}