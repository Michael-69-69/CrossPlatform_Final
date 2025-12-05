// lib/screens/instructor/material_summarizer_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../services/ai_service.dart';
import '../../services/file_text_extractor.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';

class MaterialSummarizerScreen extends ConsumerStatefulWidget {
  const MaterialSummarizerScreen({super.key});

  @override
  ConsumerState<MaterialSummarizerScreen> createState() => _MaterialSummarizerScreenState();
}

class _MaterialSummarizerScreenState extends ConsumerState<MaterialSummarizerScreen> {
  final _materialController = TextEditingController();
  
  // File state
  String? _attachedFileName;
  String? _attachedFileContent;
  bool _isExtractingFile = false;
  bool _isDragging = false;
  
  // Summarization state
  bool _isSummarizing = false;
  Map<String, dynamic>? _summaryResult;
  String? _errorMessage;

  @override
  void dispose() {
    _materialController.dispose();
    super.dispose();
  }

  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE HANDLING
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickAndExtractFile() async {
    final isVi = _isVietnamese();
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: FileTextExtractor.supportedExtensions,
        allowMultiple: false,
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      
      if (file.bytes == null) {
        throw Exception(isVi ? 'Không thể đọc file' : 'Cannot read file');
      }
      
      await _extractFileContent(file.bytes!, file.name);
      
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    final files = details.files;
    if (files.isEmpty) return;
    
    final file = files.first;
    final fileName = file.name;
    
    if (!FileTextExtractor.isSupported(fileName)) {
      final isVi = _isVietnamese();
      _showError(isVi 
        ? 'Định dạng không hỗ trợ. Hỗ trợ: ${FileTextExtractor.supportedExtensions.join(", ")}'
        : 'Format not supported. Supported: ${FileTextExtractor.supportedExtensions.join(", ")}');
      return;
    }
    
    try {
      final bytes = await file.readAsBytes();
      await _extractFileContent(bytes, fileName);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _extractFileContent(Uint8List bytes, String fileName) async {
    final isVi = _isVietnamese();
    
    setState(() {
      _isExtractingFile = true;
      _attachedFileName = fileName;
      _attachedFileContent = null;
      _summaryResult = null;
      _errorMessage = null;
    });
    
    try {
      final extractedText = await FileTextExtractor.extractText(
        bytes: bytes,
        fileName: fileName,
      );
      
      if (extractedText.trim().isEmpty) {
        throw Exception(isVi ? 'File không chứa nội dung text' : 'File contains no text content');
      }
      
      setState(() {
        _attachedFileContent = extractedText;
        _materialController.text = extractedText;
        _isExtractingFile = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVi 
                      ? 'Đã tải "$fileName" (${_formatTextLength(extractedText.length)})'
                      : 'Loaded "$fileName" (${_formatTextLength(extractedText.length)})',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _isExtractingFile = false;
        _attachedFileName = null;
        _attachedFileContent = null;
      });
      _showError(e.toString());
    }
  }

  void _showError(String error) {
    setState(() => _errorMessage = error);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTextLength(int length) {
    if (length < 1000) return '$length chars';
    if (length < 1000000) return '${(length / 1000).toStringAsFixed(1)}K chars';
    return '${(length / 1000000).toStringAsFixed(1)}M chars';
  }

  void _clearFile() {
    setState(() {
      _attachedFileName = null;
      _attachedFileContent = null;
      _materialController.clear();
      _summaryResult = null;
      _errorMessage = null;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUMMARIZATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _summarize() async {
    final content = _materialController.text.trim();
    if (content.isEmpty) return;

    final isVi = _isVietnamese();

    setState(() {
      _isSummarizing = true;
      _summaryResult = null;
      _errorMessage = null;
    });

    try {
      final summary = await AIService.summarizeMaterial(
        content: content,
        title: _attachedFileName,
        language: isVi ? 'vi' : 'en',
      );

      setState(() {
        _summaryResult = summary;
        _isSummarizing = false;
      });

    } catch (e) {
      setState(() {
        _isSummarizing = false;
        _errorMessage = e.toString();
      });
      _showError(e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD UI
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isVi = ref.watch(localeProvider).languageCode == 'vi';
    final hasContent = _materialController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.summarize_rounded, size: 20),
            ),
            const SizedBox(width: 12),
            Text(isVi ? 'Tóm tắt tài liệu' : 'Material Summarizer'),
          ],
        ),
        backgroundColor: const Color(0xFF00BFA5),
        foregroundColor: Colors.white,
        actions: [
          if (hasContent)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: isVi ? 'Xóa tất cả' : 'Clear all',
              onPressed: _clearFile,
            ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (details) => setState(() => _isDragging = true),
        onDragExited: (details) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          _handleDroppedFiles(details);
        },
        child: Stack(
          children: [
            Row(
              children: [
                // Left Panel - Input
                Expanded(
                  child: _buildInputPanel(isVi),
                ),
                
                // Divider
                Container(
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                
                // Right Panel - Result
                Expanded(
                  child: _buildResultPanel(isVi),
                ),
              ],
            ),
            
            // Drag Overlay
            if (_isDragging)
              _buildDragOverlay(isVi),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPanel(bool isVi) {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.input, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  isVi ? 'Nội dung tài liệu' : 'Material Content',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                if (_materialController.text.isNotEmpty)
                  Text(
                    _formatTextLength(_materialController.text.length),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

          // File indicator
          if (_attachedFileName != null || _isExtractingFile)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  if (_isExtractingFile)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFA5)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getFileIcon(_attachedFileName ?? ''),
                        color: const Color(0xFF00BFA5),
                        size: 18,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isExtractingFile 
                              ? (isVi ? 'Đang trích xuất...' : 'Extracting...')
                              : _attachedFileName ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF00BFA5),
                          ),
                        ),
                        if (!_isExtractingFile && _attachedFileContent != null)
                          Text(
                            _formatTextLength(_attachedFileContent!.length),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  if (!_isExtractingFile)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _clearFile,
                      color: const Color(0xFF00BFA5),
                    ),
                ],
              ),
            ),

          // Drop zone / Text area
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _attachedFileContent == null && _materialController.text.isEmpty
                  ? _buildDropZone(isVi)
                  : _buildTextArea(isVi),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Pick file button
                OutlinedButton.icon(
                  onPressed: _isExtractingFile || _isSummarizing ? null : _pickAndExtractFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(isVi ? 'Chọn file' : 'Pick file'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00BFA5),
                    side: const BorderSide(color: Color(0xFF00BFA5)),
                  ),
                ),
                const SizedBox(width: 12),
                // Summarize button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_materialController.text.trim().isEmpty || _isSummarizing)
                        ? null
                        : _summarize,
                    icon: _isSummarizing
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isSummarizing
                        ? (isVi ? 'Đang tóm tắt...' : 'Summarizing...')
                        : (isVi ? 'Tóm tắt bằng AI' : 'Summarize with AI')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone(bool isVi) {
    return InkWell(
      onTap: _pickAndExtractFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 48,
                color: Color(0xFF00BFA5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isVi ? 'Kéo thả file vào đây' : 'Drag & drop file here',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00BFA5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVi ? 'hoặc nhấn để chọn file' : 'or click to select file',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'PDF, DOCX, TXT, MD, HTML, JSON, CSV',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    isVi ? 'hoặc dán text' : 'or paste text',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextArea(bool isVi) {
    return TextField(
      controller: _materialController,
      maxLines: null,
      expands: true,
      decoration: InputDecoration(
        hintText: isVi ? 'Nội dung tài liệu...' : 'Material content...',
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(16),
      ),
      style: const TextStyle(fontSize: 14, height: 1.5),
    );
  }

  Widget _buildResultPanel(bool isVi) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  isVi ? 'Kết quả tóm tắt' : 'Summary Result',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isSummarizing
                ? _buildLoadingState(isVi)
                : _summaryResult != null
                    ? _buildSummaryResult(isVi)
                    : _buildEmptyState(isVi),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isVi) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00BFA5)),
          const SizedBox(height: 16),
          Text(
            isVi ? 'AI đang phân tích tài liệu...' : 'AI is analyzing the document...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isVi) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isVi ? 'Kết quả sẽ hiển thị ở đây' : 'Results will appear here',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            isVi 
              ? 'Thêm nội dung và nhấn "Tóm tắt bằng AI"' 
              : 'Add content and click "Summarize with AI"',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryResult(bool isVi) {
    final summary = _summaryResult!;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        if (summary['summary'] != null) ...[
          _buildResultSection(
            icon: Icons.summarize,
            title: isVi ? 'Tóm tắt' : 'Summary',
            color: const Color(0xFF00BFA5),
            child: MarkdownBody(
              data: summary['summary'].toString(),
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Key Points
        if (summary['keyPoints'] != null && (summary['keyPoints'] as List).isNotEmpty) ...[
          _buildResultSection(
            icon: Icons.star,
            title: isVi ? 'Điểm chính' : 'Key Points',
            color: Colors.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (summary['keyPoints'] as List).map<Widget>((point) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(point.toString(), style: const TextStyle(height: 1.4))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Concepts
        if (summary['concepts'] != null && (summary['concepts'] as List).isNotEmpty) ...[
          _buildResultSection(
            icon: Icons.lightbulb,
            title: isVi ? 'Khái niệm' : 'Concepts',
            color: Colors.blue,
            child: Column(
              children: (summary['concepts'] as List).map<Widget>((concept) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        concept['term']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        concept['definition']?.toString() ?? '',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Review Questions
        if (summary['reviewQuestions'] != null && (summary['reviewQuestions'] as List).isNotEmpty) ...[
          _buildResultSection(
            icon: Icons.quiz,
            title: isVi ? 'Câu hỏi ôn tập' : 'Review Questions',
            color: Colors.purple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (summary['reviewQuestions'] as List).asMap().entries.map<Widget>((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.value.toString(), style: const TextStyle(height: 1.4))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Study Tips
        if (summary['studyTips'] != null && summary['studyTips'].toString().isNotEmpty) ...[
          _buildResultSection(
            icon: Icons.tips_and_updates,
            title: isVi ? 'Gợi ý học tập' : 'Study Tips',
            color: Colors.orange,
            child: Text(
              summary['studyTips'].toString(),
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultSection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDragOverlay(bool isVi) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF00BFA5).withOpacity(0.95),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.9, end: 1.1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: -15, end: 15),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, value),
                            child: child,
                          );
                        },
                        child: const Icon(Icons.arrow_downward_rounded, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.description_outlined, size: 36, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isVi ? 'Thả file vào đây!' : 'Drop file here!',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF, DOCX, TXT, MD, HTML, JSON, CSV',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isVi ? 'AI sẽ tóm tắt nội dung' : 'AI will summarize content',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'docx':
      case 'doc': return Icons.description;
      case 'txt':
      case 'md': return Icons.text_snippet;
      case 'html':
      case 'htm': return Icons.html;
      case 'json': return Icons.data_object;
      case 'csv': return Icons.table_chart;
      default: return Icons.insert_drive_file;
    }
  }
}