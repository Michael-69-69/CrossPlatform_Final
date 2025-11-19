// utils/file_download_mobile.dart (for mobile/desktop platforms)
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Download file on mobile - saves to downloads or documents folder
Future<String> downloadFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  // Get the appropriate directory
  Directory? directory;
  
  if (Platform.isAndroid) {
    // Try to get Downloads directory first
    directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      directory = await getExternalStorageDirectory();
    }
  } else if (Platform.isIOS) {
    // iOS: use application documents directory
    directory = await getApplicationDocumentsDirectory();
  } else {
    // Desktop: use downloads directory
    directory = await getDownloadsDirectory();
  }

  if (directory == null) {
    throw Exception('Could not find download directory');
  }

  // Create file and write bytes
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  return filePath;
}

/// Copy file from local path to downloads
Future<String?> downloadFromLocalPath({
  required String localPath,
  required String fileName,
}) async {
  final sourceFile = File(localPath);
  
  if (!await sourceFile.exists()) {
    throw Exception('Source file does not exist');
  }

  // Get destination directory
  Directory? directory;
  
  if (Platform.isAndroid) {
    directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      directory = await getExternalStorageDirectory();
    }
  } else if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else {
    directory = await getDownloadsDirectory();
  }

  if (directory == null) {
    throw Exception('Could not find download directory');
  }

  // Copy file
  final destinationPath = '${directory.path}/$fileName';
  await sourceFile.copy(destinationPath);

  return destinationPath;
}