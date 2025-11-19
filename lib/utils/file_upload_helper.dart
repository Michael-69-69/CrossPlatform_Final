// utils/file_upload_helper.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class FileUploadHelper {
  /// Pick and encode file to Base64 - works on both web and mobile
  static Future<Map<String, dynamic>?> pickAndEncodeFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // Important for web!
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      
      if (kIsWeb) {
        // Web: Use bytes from file picker
        if (file.bytes == null) {
          throw Exception('No file data available');
        }
        
        return {
          'fileName': file.name,
          'fileData': base64Encode(file.bytes!),
          'fileSize': file.size,
          'mimeType': file.extension ?? 'application/octet-stream',
        };
      } else {
        // Mobile: Read file from path
        if (file.path == null) {
          throw Exception('No file path available');
        }
        
        final bytes = await File(file.path!).readAsBytes();
        
        return {
          'fileName': file.name,
          'fileData': base64Encode(bytes),
          'fileSize': file.size,
          'mimeType': file.extension ?? 'application/octet-stream',
        };
      }
    } catch (e) {
      print('File upload error: $e');
      rethrow;
    }
  }

  /// Pick multiple files and encode them
  static Future<List<Map<String, dynamic>>> pickAndEncodeMultipleFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> encodedFiles = [];

      for (final file in result.files) {
        if (kIsWeb) {
          if (file.bytes != null) {
            encodedFiles.add({
              'fileName': file.name,
              'fileData': base64Encode(file.bytes!),
              'fileSize': file.size,
              'mimeType': file.extension ?? 'application/octet-stream',
            });
          }
        } else {
          if (file.path != null) {
            final bytes = await File(file.path!).readAsBytes();
            encodedFiles.add({
              'fileName': file.name,
              'fileData': base64Encode(bytes),
              'fileSize': file.size,
              'mimeType': file.extension ?? 'application/octet-stream',
            });
          }
        }
      }

      return encodedFiles;
    } catch (e) {
      print('Multiple file upload error: $e');
      rethrow;
    }
  }

  /// Decode Base64 to bytes for download
  static Uint8List decodeBase64(String base64String) {
    return base64Decode(base64String);
  }
}