// File reader for web platform
import 'dart:convert';
import 'dart:typed_data';

Future<String?> readFileContent(String? filePath, Uint8List? bytes) async {
  // On web, only bytes are available
  if (bytes != null) {
    return utf8.decode(bytes);
  }
  
  // Web doesn't support file path reading
  return null;
}

