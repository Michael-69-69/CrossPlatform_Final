// lib/services/file_text_extractor.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';  // This comes from image package's dependency
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service to extract text from various file formats (PDF, DOCX, TXT, etc.)
class FileTextExtractor {
  
  /// Extract text from file bytes based on file extension
  static Future<String> extractText({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return await _extractFromPdf(bytes);
      case 'docx':
        return await _extractFromDocx(bytes);
      case 'doc':
        return _extractFromDoc(bytes);
      case 'txt':
      case 'md':
      case 'markdown':
        return _extractFromText(bytes);
      case 'rtf':
        return _extractFromRtf(bytes);
      case 'html':
      case 'htm':
        return _extractFromHtml(bytes);
      case 'json':
        return _extractFromJson(bytes);
      case 'csv':
        return _extractFromText(bytes);
      case 'xml':
        return _extractFromXml(bytes);
      default:
        // Try to read as plain text
        try {
          return utf8.decode(bytes);
        } catch (e) {
          throw UnsupportedFileException(
            'Không hỗ trợ định dạng .$extension / Unsupported format .$extension'
          );
        }
    }
  }

  /// Extract text from PDF using Syncfusion
  static Future<String> _extractFromPdf(Uint8List bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      
      final StringBuffer textBuffer = StringBuffer();
      
      for (int i = 0; i < document.pages.count; i++) {
        final String pageText = extractor.extractText(startPageIndex: i);
        if (pageText.isNotEmpty) {
          textBuffer.writeln('--- Page ${i + 1} ---');
          textBuffer.writeln(pageText);
          textBuffer.writeln();
        }
      }
      
      document.dispose();
      
      final result = textBuffer.toString().trim();
      if (result.isEmpty) {
        throw Exception('PDF không chứa text / PDF contains no extractable text');
      }
      
      return result;
    } catch (e) {
      if (e.toString().contains('không chứa text') || e.toString().contains('no extractable')) {
        rethrow;
      }
      throw Exception('Lỗi đọc PDF / Error reading PDF: $e');
    }
  }

  /// Extract text from DOCX (which is a ZIP containing XML)
  static Future<String> _extractFromDocx(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final documentFile = archive.files.firstWhere(
        (file) => file.name == 'word/document.xml',
        orElse: () => throw Exception('Invalid DOCX structure'),
      );
      
      if (documentFile.content == null) {
        throw Exception('Empty document content');
      }
      
      final xmlContent = utf8.decode(documentFile.content as List<int>);
      final text = _extractTextFromDocxXml(xmlContent);
      
      if (text.trim().isEmpty) {
        throw Exception('DOCX không chứa text / DOCX contains no text');
      }
      
      return text;
    } catch (e) {
      throw Exception('Lỗi đọc DOCX / Error reading DOCX: $e');
    }
  }

  static String _extractTextFromDocxXml(String xml) {
    final buffer = StringBuffer();
    
    final textPattern = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
    final paragraphEndPattern = RegExp(r'</w:p>');
    
    final parts = xml.split(paragraphEndPattern);
    
    for (final part in parts) {
      final matches = textPattern.allMatches(part);
      final paragraphText = matches.map((m) => m.group(1) ?? '').join('');
      if (paragraphText.isNotEmpty) {
        buffer.writeln(paragraphText);
      }
    }
    
    return buffer.toString();
  }

  static String _extractFromDoc(Uint8List bytes) {
    try {
      final text = _extractReadableText(bytes);
      if (text.isEmpty) {
        throw Exception('Không thể đọc file DOC cũ / Cannot read old DOC format');
      }
      return text;
    } catch (e) {
      throw Exception('File DOC cũ không được hỗ trợ. Vui lòng dùng DOCX / Old DOC not supported. Please use DOCX');
    }
  }

  static String _extractReadableText(Uint8List bytes) {
    final buffer = StringBuffer();
    final tempBuffer = StringBuffer();
    
    for (final byte in bytes) {
      if ((byte >= 32 && byte <= 126) || byte == 10 || byte == 13 || byte == 9) {
        tempBuffer.writeCharCode(byte);
      } else {
        final text = tempBuffer.toString().trim();
        if (text.length > 3) {
          buffer.write(text);
          buffer.write(' ');
        }
        tempBuffer.clear();
      }
    }
    
    final lastText = tempBuffer.toString().trim();
    if (lastText.length > 3) {
      buffer.write(lastText);
    }
    
    return buffer.toString().trim();
  }

  static String _extractFromText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      try {
        return latin1.decode(bytes);
      } catch (e2) {
        throw Exception('Lỗi đọc file text / Error reading text file');
      }
    }
  }

  static String _extractFromRtf(Uint8List bytes) {
    try {
      final rtfContent = utf8.decode(bytes);
      String text = rtfContent;
      
      text = text.replaceAll(RegExp(r'\\rtf\d+'), '');
      text = text.replaceAll(RegExp(r'\{\\fonttbl[^}]*\}'), '');
      text = text.replaceAll(RegExp(r'\{\\colortbl[^}]*\}'), '');
      text = text.replaceAll(RegExp(r'\{\\stylesheet[^}]*\}'), '');
      text = text.replaceAll(RegExp(r'\\[a-z]+\d*\s?'), ' ');
      text = text.replaceAll(RegExp(r'[{}\\]'), '');
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      return text;
    } catch (e) {
      throw Exception('Lỗi đọc RTF / Error reading RTF: $e');
    }
  }

  static String _extractFromHtml(Uint8List bytes) {
    try {
      final html = utf8.decode(bytes);
      
      String text = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
      text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
      text = text.replaceAll(RegExp(r'<(p|div|br|h\d|li|tr)[^>]*>', caseSensitive: false), '\n');
      text = text.replaceAll(RegExp(r'<[^>]+>'), '');
      text = _decodeHtmlEntities(text);
      text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
      text = text.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
      
      return text.trim();
    } catch (e) {
      throw Exception('Lỗi đọc HTML / Error reading HTML: $e');
    }
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static String _extractFromJson(Uint8List bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final parsed = jsonDecode(jsonString);
      return _jsonToText(parsed);
    } catch (e) {
      return utf8.decode(bytes);
    }
  }

  static String _jsonToText(dynamic json, [int indent = 0]) {
    final buffer = StringBuffer();
    final prefix = '  ' * indent;
    
    if (json is Map) {
      for (final entry in json.entries) {
        buffer.writeln('$prefix${entry.key}: ${_jsonToText(entry.value, indent + 1)}');
      }
    } else if (json is List) {
      for (int i = 0; i < json.length; i++) {
        buffer.writeln('$prefix- ${_jsonToText(json[i], indent + 1)}');
      }
    } else {
      return json.toString();
    }
    
    return buffer.toString().trim();
  }

  static String _extractFromXml(Uint8List bytes) {
    try {
      final xml = utf8.decode(bytes);
      
      String text = xml.replaceAll(RegExp(r'<\?[^>]+\?>'), '');
      text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
      text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      return text;
    } catch (e) {
      throw Exception('Lỗi đọc XML / Error reading XML: $e');
    }
  }

  static List<String> get supportedExtensions => [
    'pdf', 'docx', 'doc', 'txt', 'md', 'rtf', 'html', 'htm', 'json', 'csv', 'xml'
  ];

  static bool isSupported(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return supportedExtensions.contains(extension);
  }

  static String getFileTypeDescription(String fileName, {bool vietnamese = true}) {
    final extension = fileName.split('.').last.toLowerCase();
    
    final descriptions = {
      'pdf': vietnamese ? 'Tài liệu PDF' : 'PDF Document',
      'docx': vietnamese ? 'Tài liệu Word' : 'Word Document',
      'doc': vietnamese ? 'Tài liệu Word (cũ)' : 'Word Document (old)',
      'txt': vietnamese ? 'File văn bản' : 'Text File',
      'md': vietnamese ? 'Markdown' : 'Markdown',
      'rtf': vietnamese ? 'Rich Text' : 'Rich Text',
      'html': vietnamese ? 'Trang web' : 'Web Page',
      'htm': vietnamese ? 'Trang web' : 'Web Page',
      'json': vietnamese ? 'Dữ liệu JSON' : 'JSON Data',
      'csv': vietnamese ? 'Bảng tính CSV' : 'CSV Spreadsheet',
      'xml': vietnamese ? 'Dữ liệu XML' : 'XML Data',
    };
    
    return descriptions[extension] ?? (vietnamese ? 'File' : 'File');
  }
}

class UnsupportedFileException implements Exception {
  final String message;
  UnsupportedFileException(this.message);
  
  @override
  String toString() => message;
}