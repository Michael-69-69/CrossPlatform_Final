// utils/csv_export_helper.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';

// Platform-specific imports
import 'csv_export_web.dart' if (dart.library.io) 'csv_export_mobile.dart' as platform;

class CsvExportHelper {
  /// Export CSV data with UTF-8 BOM for proper Vietnamese character display
  static Future<String> exportCsv({
    required List<List<dynamic>> rows,
    required String fileName,
  }) async {
    try {
      // Convert to CSV format
      final csv = const ListToCsvConverter().convert(rows);
      
      // ✅ ADD UTF-8 BOM (Byte Order Mark) for Excel to recognize Vietnamese characters
      // BOM: EF BB BF in hexadecimal = 239 187 191 in decimal
      final bom = [0xEF, 0xBB, 0xBF];
      final csvBytes = utf8.encode(csv);
      final bytes = Uint8List.fromList([...bom, ...csvBytes]);

      // Use platform-specific export
      return await platform.exportCsv(
        bytes: bytes,
        fileName: fileName,
      );
    } catch (e) {
      throw Exception('CSV export error: $e');
    }
  }

  /// Generate CSV string (no file writing, no BOM)
  static String generateCsvString(List<List<dynamic>> rows) {
    return const ListToCsvConverter().convert(rows);
  }
}