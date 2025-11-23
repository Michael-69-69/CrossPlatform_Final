// utils/csv_export_mobile.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Export CSV on mobile - saves to downloads or documents folder with UTF-8 encoding
Future<String> exportCsv({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // ✅ Request permission based on Android version
      if (!await _requestPermission()) {
        throw Exception('Quyền truy cập bị từ chối. Vui lòng cấp quyền trong Cài đặt.');
      }

      // ✅ Try to save to public Downloads folder (preferred location)
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = Directory('/storage/emulated/0/Downloads');
      }
      
      if (!await directory.exists()) {
        // ✅ Fallback: Use app's external storage directory
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsDir = Directory('${externalDir.path}/Downloads');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          directory = downloadsDir;
        } else {
          // ✅ Last fallback: Use app documents directory
          directory = await getApplicationDocumentsDirectory();
        }
      }
    } else if (Platform.isIOS) {
      // ✅ iOS: Save to Documents directory (accessible via Files app)
      directory = await getApplicationDocumentsDirectory();
      
      final downloadsDir = Directory('${directory.path}/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      directory = downloadsDir;
    } else {
      // ✅ Desktop (Windows/macOS/Linux): Use system downloads directory
      directory = await getDownloadsDirectory();
    }

    if (directory == null) {
      throw Exception('Không thể tìm thấy thư mục để lưu file');
    }

    // ✅ Save file with UTF-8 encoding (BOM is already in bytes)
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    print('✅ CSV saved: $filePath');
    return filePath;
  } catch (e) {
    print('❌ Mobile CSV export error: $e');
    rethrow;
  }
}

/// ✅ Request storage permission based on Android version
Future<bool> _requestPermission() async {
  if (!Platform.isAndroid) {
    return true; // iOS doesn't need permission for app documents
  }

  try {
    // ✅ Get Android version
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    print('📱 Android SDK: $sdkInt');

    if (sdkInt >= 33) {
      // ✅ Android 13+ (API 33+): No storage permission needed for Downloads
      // Scoped storage handles this automatically
      print('✅ Android 13+: No permission needed (scoped storage)');
      return true;
    } else if (sdkInt >= 30) {
      // ✅ Android 11-12 (API 30-32): Request MANAGE_EXTERNAL_STORAGE
      print('📋 Requesting MANAGE_EXTERNAL_STORAGE for Android 11-12');
      var status = await Permission.manageExternalStorage.status;
      
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        
        if (status.isPermanentlyDenied) {
          print('⚠️ Permission permanently denied, opening app settings');
          await openAppSettings();
          return false;
        }
      }
      
      print('${status.isGranted ? "✅" : "❌"} MANAGE_EXTERNAL_STORAGE: ${status.isGranted}');
      return status.isGranted;
    } else {
      // ✅ Android 10 and below (API 29-): Request WRITE_EXTERNAL_STORAGE
      print('📋 Requesting WRITE_EXTERNAL_STORAGE for Android 10 and below');
      var status = await Permission.storage.status;
      
      if (!status.isGranted) {
        status = await Permission.storage.request();
        
        if (status.isPermanentlyDenied) {
          print('⚠️ Permission permanently denied, opening app settings');
          await openAppSettings();
          return false;
        }
      }
      
      print('${status.isGranted ? "✅" : "❌"} WRITE_EXTERNAL_STORAGE: ${status.isGranted}');
      return status.isGranted;
    }
  } catch (e) {
    print('❌ Permission request error: $e');
    // ✅ Fallback: Allow and use app directory instead
    return true;
  }
}