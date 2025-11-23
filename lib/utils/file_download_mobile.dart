// utils/file_download_mobile.dart (for mobile/desktop platforms)
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart'; // ✅ UPDATED

/// Download file on mobile - saves to downloads or documents folder
Future<String> downloadFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Request permission
      if (!await _requestPermission()) {
        throw Exception('Storage permission denied');
      }

      // ✅ For images, save to Gallery
      if (_isImage(fileName)) {
        final result = await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name: fileName.split('.').first,
        );
        
        if (result != null && result['isSuccess'] == true) {
          print('📷 Image saved to Gallery');
          return 'Saved to Gallery';
        }
      }

      // For other files, save to Downloads
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = Directory('/storage/emulated/0/Downloads');
      }
      
      if (!await directory.exists()) {
        // Fallback to app directory
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          final downloadsDir = Directory('${directory.path}/Downloads');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          directory = downloadsDir;
        }
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
      
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      directory = downloadsDir;
    } else {
      directory = await getDownloadsDirectory();
    }

    if (directory == null) {
      throw Exception('Could not find download directory');
    }

    // Save file
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    print('✅ File saved: $filePath');
    return filePath;
  } catch (e) {
    print('❌ Download error: $e');
    rethrow;
  }
}

Future<String?> downloadFromLocalPath({
  required String localPath,
  required String fileName,
}) async {
  try {
    final sourceFile = File(localPath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist');
    }

    final bytes = await sourceFile.readAsBytes();
    return await downloadFile(bytes: bytes, fileName: fileName);
  } catch (e) {
    print('❌ Copy error: $e');
    rethrow;
  }
}

// ============================================
// HELPER FUNCTIONS
// ============================================

bool _isImage(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
}

Future<bool> _requestPermission() async {
  if (!Platform.isAndroid) return true;

  try {
    // Try photos permission first (Android 13+)
    var status = await Permission.photos.status;
    if (status.isGranted) return true;
    
    status = await Permission.photos.request();
    if (status.isGranted) return true;

    // Fallback to storage permission
    status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    
    if (status.isGranted) return true;

    // Try manage external storage (Android 11+)
    var manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      manageStatus = await Permission.manageExternalStorage.request();
    }
    
    return manageStatus.isGranted;
  } catch (e) {
    print('Permission error: $e');
    return false;
  }
}