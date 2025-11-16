// File reader for native platforms using dart:io
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

Future<String?> readFileContent(String? filePath, Uint8List? bytes) async {
  // Always prefer bytes if available (works on all platforms)
  if (bytes != null) {
    return utf8.decode(bytes);
  }
  
  // Fallback to file path on native platforms
  if (filePath != null && filePath.isNotEmpty) {
    try {
      final file = File(filePath);
      return await file.readAsString();
    } catch (e) {
      print('Error reading file from path: $e');
      return null;
    }
  }
  
  return null;
}

