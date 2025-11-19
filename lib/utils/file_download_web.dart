// utils/file_download_web.dart (for web platform)
import 'dart:html' as html;
import 'dart:typed_data';

/// Download file on web - triggers browser download
Future<String> downloadFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  // Create a blob from bytes
  final blob = html.Blob([bytes]);
  
  // Create download link
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  
  // Trigger download
  html.document.body?.children.add(anchor);
  anchor.click();
  
  // Cleanup
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
  
  return 'Downloaded to browser downloads folder';
}

/// Not supported on web
Future<String?> downloadFromLocalPath({
  required String localPath,
  required String fileName,
}) async {
  return null; // Web doesn't support local file system
}