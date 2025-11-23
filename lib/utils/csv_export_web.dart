// utils/csv_export_web.dart
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Export CSV on web - triggers browser download with UTF-8 encoding
Future<String> exportCsv({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    // ✅ Create blob with explicit UTF-8 charset for proper Vietnamese character display
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // ✅ Create download link and trigger download
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none'  // Hide the link
      ..click();
    
    // ✅ Cleanup - revoke object URL to free memory
    html.Url.revokeObjectUrl(url);
    
    print('✅ CSV downloaded: $fileName');
    return 'Downloaded: $fileName';
  } catch (e) {
    print('❌ Web CSV export error: $e');
    rethrow;
  }
}