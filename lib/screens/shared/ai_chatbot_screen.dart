// lib/screens/shared/ai_chatbot_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../services/ai_service.dart';
import '../../services/file_text_extractor.dart';
import '../../models/course.dart';
import '../../models/semester.dart';
import '../../models/user.dart';
import '../../models/assignment.dart';
import '../../models/group.dart' as app;
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/semester_provider.dart';
import '../../main.dart';

class AIChatbotScreen extends ConsumerStatefulWidget {
  final Course? course;
  final String? materialContext;

  const AIChatbotScreen({
    super.key,
    this.course,
    this.materialContext,
  });

  @override
  ConsumerState<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends ConsumerState<AIChatbotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _welcomeAdded = false;
  bool _contextLoaded = false;
  bool _isLoadingContext = false;
  
  // ══════════════════════════════════════════════════════════════════════════
  // FILE ATTACHMENT STATE
  // ══════════════════════════════════════════════════════════════════════════
  String? _attachedFileName;
  String? _attachedFileContent;
  bool _isExtractingFile = false;
  bool _isDragging = false;
  
  // ══════════════════════════════════════════════════════════════════════════
  // COOLDOWN TIMER
  // ══════════════════════════════════════════════════════════════════════════
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  
  // ══════════════════════════════════════════════════════════════════════════
  // STRUCTURED CONTEXT DATA
  // ══════════════════════════════════════════════════════════════════════════
  AIContextData _contextData = AIContextData();

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeAdded) {
      _loadContextAndWelcome();
      _welcomeAdded = true;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final newCooldown = AIService.remainingCooldownSeconds;
        if (newCooldown != _cooldownSeconds) {
          setState(() {
            _cooldownSeconds = newCooldown;
          });
        }
      }
    });
  }

  bool _isVietnamese() {
    try {
      return ref.read(localeProvider).languageCode == 'vi';
    } catch (e) {
      return true;
    }
  }

  Future<void> _loadContextAndWelcome() async {
    await _refreshContextData(forceReload: true);
    _addWelcomeMessage();
    if (mounted) setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE HANDLING - PICK FILE
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
      _showFileError(e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE HANDLING - DRAG & DROP
  // ══════════════════════════════════════════════════════════════════════════
  
  Future<void> _handleDroppedFiles(List<DropDoneDetails> details) async {
    if (details.isEmpty) return;
    
    final files = details.first.files;
    if (files.isEmpty) return;
    
    final file = files.first;
    final fileName = file.name;
    
    // Check if file is supported
    if (!FileTextExtractor.isSupported(fileName)) {
      final isVi = _isVietnamese();
      _showFileError(isVi 
        ? 'Định dạng file không được hỗ trợ. Hỗ trợ: ${FileTextExtractor.supportedExtensions.join(", ")}'
        : 'File format not supported. Supported: ${FileTextExtractor.supportedExtensions.join(", ")}');
      return;
    }
    
    try {
      final bytes = await file.readAsBytes();
      await _extractFileContent(bytes, fileName);
    } catch (e) {
      _showFileError(e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE EXTRACTION
  // ══════════════════════════════════════════════════════════════════════════
  
  Future<void> _extractFileContent(Uint8List bytes, String fileName) async {
    final isVi = _isVietnamese();
    
    setState(() {
      _isExtractingFile = true;
      _attachedFileName = fileName;
      _attachedFileContent = null;
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
        _isExtractingFile = false;
      });
      
      // Show success
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
                    overflow: TextOverflow.ellipsis,
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
      _showFileError(e.toString());
    }
  }

  void _showFileError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(error, overflow: TextOverflow.ellipsis)),
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
  
  void _clearAttachedFile() {
    setState(() {
      _attachedFileName = null;
      _attachedFileContent = null;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REFRESH CONTEXT DATA FROM PROVIDERS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _refreshContextData({bool forceReload = false}) async {
    if (_isLoadingContext) return;
    
    try {
      _isLoadingContext = true;
      
      if (forceReload) {
        if (mounted) setState(() => _contextLoaded = false);
        
        print('🔄 Force reloading all data for AI context...');
        
        await ref.read(courseProvider.notifier).loadCourses();
        
        await Future.wait([
          ref.read(semesterProvider.notifier).loadSemesters(),
          ref.read(groupProvider.notifier).loadGroups(),
          ref.read(studentProvider.notifier).loadStudents(),
        ]);
        
        final courses = ref.read(courseProvider);
        for (final course in courses) {
          await ref.read(assignmentProvider.notifier).loadAssignments(course.id);
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final user = ref.read(authProvider);
      final courses = ref.read(courseProvider);
      final semesters = ref.read(semesterProvider);
      final students = ref.read(studentProvider);
      final groups = ref.read(groupProvider);
      final assignments = ref.read(assignmentProvider);

      _contextData = AIContextData(
        user: user,
        semesters: semesters,
        courses: courses,
        groups: groups,
        students: students,
        assignments: assignments,
        currentCourse: widget.course,
        lastRefreshed: DateTime.now(),
      );

      _contextLoaded = true;
      
      print('✅ AI Context refreshed: ${courses.length} courses, ${assignments.length} assignments');
      
    } catch (e) {
      print('❌ Error refreshing context: $e');
    } finally {
      _isLoadingContext = false;
    }
  }

  String _buildContextString() {
    return _contextData.toContextString();
  }

  void _addWelcomeMessage() {
    final isVi = _isVietnamese();
    final courseName = widget.course?.name ?? (isVi ? 'hệ thống LMS' : 'LMS system');
    final user = ref.read(authProvider);
    
    _messages.add(_ChatMessage(
      content: isVi
          ? '''Xin chào ${user?.fullName ?? 'bạn'}! 👋 

Tôi là trợ lý AI của **$courseName** với quyền truy cập toàn bộ dữ liệu LMS.

**📎 Tính năng mới:** Kéo thả file (PDF, DOCX, TXT...) vào đây để tôi giải thích!

**Ví dụ câu hỏi:**
- "Có bao nhiêu bài chưa chấm?"
- "Ai nộp bài trễ?"
- Kéo thả file → "Giải thích nội dung này"

Hãy hỏi tôi bất cứ điều gì!'''
          : '''Hello ${user?.fullName ?? 'there'}! 👋 

I'm the AI assistant for **$courseName** with access to all LMS data.

**📎 New feature:** Drag & drop files (PDF, DOCX, TXT...) here for explanations!

**Example questions:**
- "How many submissions are ungraded?"
- "Who submitted late?"
- Drop a file → "Explain this content"

Ask me anything!''',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEND MESSAGE (WITH FILE SUPPORT)
  // ══════════════════════════════════════════════════════════════════════════
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _attachedFileContent == null) return;
    if (_isLoading) return;

    // Check cooldown
    if (AIService.isInCooldown) {
      final remaining = AIService.remainingCooldownSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isVietnamese() 
            ? '⏳ Vui lòng đợi ${remaining}s trước khi gửi tin nhắn tiếp' 
            : '⏳ Please wait ${remaining}s before sending another message'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isVi = _isVietnamese();
    
    // Build display message and actual prompt
    String displayMessage = message;
    String actualPrompt = message;
    
    if (_attachedFileContent != null) {
      // Show what user is asking about the file
      displayMessage = message.isEmpty 
          ? '📎 **${_attachedFileName}**\n\n_${isVi ? "Hãy giải thích nội dung file này" : "Please explain this file content"}_'
          : '📎 **${_attachedFileName}**\n\n$message';
      
      // Build the full prompt with file content
      actualPrompt = isVi 
          ? '''
Người dùng đã đính kèm một file tài liệu. Hãy đọc và phân tích nội dung sau:

═══════════════════════════════════════════════════════════════
📄 TÊN FILE: $_attachedFileName
═══════════════════════════════════════════════════════════════
NỘI DUNG FILE:
$_attachedFileContent
═══════════════════════════════════════════════════════════════

${message.isEmpty ? 'Hãy giải thích và tóm tắt nội dung file này một cách rõ ràng, dễ hiểu. Nêu các điểm chính và khái niệm quan trọng.' : 'CÂU HỎI CỦA NGƯỜI DÙNG VỀ FILE NÀY: $message'}
'''
          : '''
The user has attached a document file. Please read and analyze the following content:

═══════════════════════════════════════════════════════════════
📄 FILE NAME: $_attachedFileName
═══════════════════════════════════════════════════════════════
FILE CONTENT:
$_attachedFileContent
═══════════════════════════════════════════════════════════════

${message.isEmpty ? 'Please explain and summarize this file content clearly. Highlight the key points and important concepts.' : 'USER QUESTION ABOUT THIS FILE: $message'}
''';
    }

    _messageController.clear();
    
    // Store file info before clearing
    final hadFile = _attachedFileContent != null;
    final fileName = _attachedFileName;
    _clearAttachedFile();

    setState(() {
      _messages.add(_ChatMessage(content: displayMessage, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Force refresh context to get LATEST data before sending
      if (!hadFile) {
        await _refreshContextData(forceReload: true);
      }
      
      final history = _messages
          .where((m) => m.content.isNotEmpty)
          .toList()
          .reversed
          .take(10)
          .toList()
          .reversed
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.content})
          .toList();

      final contextString = hadFile ? '' : _buildContextString(); // Skip context for file analysis

      final response = await AIService.learningAssistantWithContext(
        question: actualPrompt,
        courseName: widget.course?.name ?? 'LMS System',
        courseDescription: widget.course?.name,
        appContext: contextString,
        materialContext: widget.materialContext,
        conversationHistory: history.length > 1 ? history.sublist(0, history.length - 1) : null,
        language: isVi ? 'vi' : 'en',
      );

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(content: response, isUser: false, timestamp: DateTime.now()));
        });
      }
    } catch (e) {
      print('❌ AI Error: $e');
      
      if (mounted) {
        String errorMsg = e.toString();
        
        if (errorMsg.contains('429') || errorMsg.contains('rate') || errorMsg.contains('quota')) {
          errorMsg = isVi 
            ? '⚠️ Đã vượt giới hạn API. Vui lòng đợi 30 giây rồi thử lại.'
            : '⚠️ Rate limit exceeded. Please wait 30 seconds and try again.';
        } else if (errorMsg.contains('API key')) {
          errorMsg = isVi
            ? '⚠️ API key không hợp lệ hoặc đã hết hạn.'
            : '⚠️ Invalid or expired API key.';
        } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
          errorMsg = isVi
            ? '⚠️ Lỗi kết nối mạng. Vui lòng kiểm tra internet.'
            : '⚠️ Network error. Please check your connection.';
        }
        
        setState(() {
          _messages.add(_ChatMessage(
            content: '❌ ${isVi ? 'Lỗi' : 'Error'}: $errorMsg',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONTEXT EDITOR DIALOG
  // ══════════════════════════════════════════════════════════════════════════
  void _showContextEditorDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AIContextEditorSheet(
        contextData: _contextData,
        onRefresh: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 12),
                  Text(_isVietnamese() ? 'Đang tải dữ liệu mới...' : 'Loading fresh data...'),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
          
          await _refreshContextData(forceReload: true);
          
          if (mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isVietnamese() 
                  ? '✅ Đã cập nhật: ${_contextData.courses.length} môn, ${_contextData.assignments.length} bài tập'
                  : '✅ Refreshed: ${_contextData.courses.length} courses, ${_contextData.assignments.length} assignments'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {});
          }
        },
        isVietnamese: _isVietnamese(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD UI
  // ══════════════════════════════════════════════════════════════════════════
  
  @override
  Widget build(BuildContext context) {
    final isVi = ref.watch(localeProvider).languageCode == 'vi';
    final user = ref.watch(authProvider);
    final isConfigured = AIService.isConfigured;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInCooldown = _cooldownSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🤖', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.course?.name ?? (isVi ? 'Trợ lý AI' : 'AI Assistant'),
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (isInCooldown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${_cooldownSeconds}s', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: isVi ? 'Xem/Sửa Context' : 'View/Edit Context',
            onPressed: _showContextEditorDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: isVi ? 'Xóa chat' : 'Clear chat',
            onPressed: () => setState(() { _messages.clear(); _addWelcomeMessage(); }),
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (details) => setState(() => _isDragging = true),
        onDragExited: (details) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          _handleDroppedFiles([details]);
        },
        child: Stack(
          children: [
            Column(
              children: [
                // AI Not Configured Warning
                if (!isConfigured)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isVi ? '⚠️ AI chưa cấu hình. Thêm GEMINI_API_KEY vào file .env' : '⚠️ AI not configured. Add GEMINI_API_KEY to .env file',
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Context Status Bar
                InkWell(
                  onTap: _showContextEditorDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: _contextLoaded ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Row(
                      children: [
                        if (_isLoadingContext)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Icon(
                            _contextLoaded ? Icons.check_circle : Icons.warning,
                            color: _contextLoaded ? Colors.green.shade700 : Colors.orange.shade700,
                            size: 16,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _contextLoaded
                              ? (isVi 
                                  ? '${_contextData.courses.length} môn • ${_contextData.groups.length} nhóm • ${_contextData.assignments.length} bài tập'
                                  : '${_contextData.courses.length} courses • ${_contextData.groups.length} groups • ${_contextData.assignments.length} assignments')
                              : (isVi ? 'Đang tải dữ liệu...' : 'Loading data...'),
                            style: TextStyle(
                              color: _contextLoaded ? Colors.green.shade700 : Colors.orange.shade700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Icon(Icons.edit, color: Colors.green.shade700, size: 14),
                      ],
                    ),
                  ),
                ),

                // Chat Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index], user?.fullName ?? 'User', isDark);
                    },
                  ),
                ),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickAction('📊 ${isVi ? 'Tổng quan' : 'Overview'}', isVi ? 'Cho tôi thống kê tổng quan hệ thống' : 'Give me a system overview'),
                        const SizedBox(width: 8),
                        _buildQuickAction('📝 ${isVi ? 'Chưa chấm' : 'Ungraded'}', isVi ? 'Liệt kê tất cả bài chưa chấm' : 'List all ungraded submissions'),
                        const SizedBox(width: 8),
                        _buildQuickAction('⏰ ${isVi ? 'Nộp trễ' : 'Late'}', isVi ? 'Ai nộp bài trễ?' : 'Who submitted late?'),
                        const SizedBox(width: 8),
                        _buildQuickAction('👥 ${isVi ? 'Nhóm' : 'Groups'}', isVi ? 'Liệt kê các nhóm và thành viên' : 'List groups and members'),
                      ],
                    ),
                  ),
                ),

                // Input Area with File Attachment
                _buildInputArea(isVi, isConfigured, isInCooldown, isDark),
              ],
            ),
            
            // Drag & Drop Overlay
            if (_isDragging)
              _buildDragOverlay(isVi),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DRAG & DROP OVERLAY
  // ══════════════════════════════════════════════════════════════════════════
  
  Widget _buildDragOverlay(bool isVi) {
    return Positioned.fill(
      child: Container(
        color: Colors.deepPurple.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated drop zone
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Bouncing arrow
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: -10, end: 10),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, value),
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.description_outlined,
                        size: 40,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isVi ? 'Thả file vào đây!' : 'Drop file here!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVi 
                  ? 'Hỗ trợ: PDF, DOCX, TXT, MD, HTML, JSON, CSV'
                  : 'Supported: PDF, DOCX, TXT, MD, HTML, JSON, CSV',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
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
                    const Text('🤖', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      isVi ? 'AI sẽ giải thích nội dung' : 'AI will explain the content',
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

  // ══════════════════════════════════════════════════════════════════════════
  // INPUT AREA WITH FILE ATTACHMENT
  // ══════════════════════════════════════════════════════════════════════════
  
  Widget _buildInputArea(bool isVi, bool isConfigured, bool isInCooldown, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attached File Indicator
            if (_attachedFileName != null || _isExtractingFile)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Row(
                  children: [
                    if (_isExtractingFile)
                      SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepPurple.shade700,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getFileIcon(_attachedFileName ?? ''),
                          color: Colors.deepPurple.shade700,
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
                                ? (isVi ? 'Đang trích xuất nội dung...' : 'Extracting content...')
                                : _attachedFileName ?? '',
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!_isExtractingFile && _attachedFileContent != null)
                            Text(
                              _formatTextLength(_attachedFileContent!.length),
                              style: TextStyle(
                                color: Colors.deepPurple.shade400,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!_isExtractingFile && _attachedFileName != null)
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: Colors.deepPurple.shade700),
                        onPressed: _clearAttachedFile,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            
            // Input Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment Button
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: IconButton(
                    icon: const Icon(Icons.attach_file_rounded),
                    onPressed: (isConfigured && !_isLoading && !_isExtractingFile)
                        ? _pickAndExtractFile
                        : null,
                    tooltip: isVi ? 'Đính kèm file (PDF, DOCX, TXT...)' : 'Attach file (PDF, DOCX, TXT...)',
                    color: Colors.deepPurple,
                    disabledColor: Colors.grey,
                  ),
                ),
                
                // Text Input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _attachedFileName != null
                          ? (isVi ? 'Hỏi về file này... (hoặc Enter để giải thích)' : 'Ask about this file... (or Enter to explain)')
                          : (isInCooldown 
                              ? (isVi ? 'Đợi ${_cooldownSeconds}s...' : 'Wait ${_cooldownSeconds}s...')
                              : (isVi ? 'Nhập câu hỏi hoặc kéo thả file...' : 'Type a question or drag & drop a file...')),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isInCooldown ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: isConfigured && !isInCooldown && !_isLoading,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Send Button
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: (isConfigured && !isInCooldown && !_isLoading) ? Colors.deepPurple : Colors.grey,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    color: Colors.white,
                    onPressed: (_isLoading || !isConfigured || isInCooldown) ? null : _sendMessage,
                  ),
                ),
              ],
            ),
            
            // Supported formats hint
            if (_attachedFileName == null && !_isExtractingFile)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.drag_indicator, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      isVi 
                          ? 'Kéo thả file hoặc nhấn 📎 • PDF, DOCX, TXT, MD, HTML'
                          : 'Drag & drop or tap 📎 • PDF, DOCX, TXT, MD, HTML',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'html':
      case 'htm':
        return Icons.html;
      case 'json':
        return Icons.data_object;
      case 'csv':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildQuickAction(String label, String message) {
    final isDisabled = _cooldownSeconds > 0 || _isLoading || !AIService.isConfigured;
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isDisabled ? Colors.grey : null)),
      onPressed: isDisabled ? null : () { 
        _messageController.text = message; 
        _sendMessage(); 
      },
      backgroundColor: isDisabled ? Colors.grey.shade200 : Colors.deepPurple.withOpacity(0.1),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, String userName, bool isDark) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(backgroundColor: Colors.deepPurple.withOpacity(0.1), radius: 18, child: const Text('🤖', style: TextStyle(fontSize: 18))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? Colors.deepPurple : (message.isError ? Colors.red.withOpacity(0.1) : (isDark ? Colors.grey.shade800 : Colors.grey.withOpacity(0.1))),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isUser
                      ? MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white),
                            strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            em: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(color: message.isError ? Colors.red : (isDark ? Colors.white : Colors.black87), fontSize: 14),
                            strong: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                            listBullet: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          ),
                          selectable: true,
                        ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.deepPurple,
              radius: 18,
              child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.deepPurple.withOpacity(0.1), radius: 18, child: const Text('🤖', style: TextStyle(fontSize: 18))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple)),
                const SizedBox(width: 8),
                Text(_isVietnamese() ? 'Đang xử lý...' : 'Processing...', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHAT MESSAGE MODEL
// ══════════════════════════════════════════════════════════════════════════════

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  _ChatMessage({required this.content, required this.isUser, required this.timestamp, this.isError = false});
}

// ══════════════════════════════════════════════════════════════════════════════
// AI CONTEXT DATA MODEL
// ══════════════════════════════════════════════════════════════════════════════

class AIContextData {
  final AppUser? user;
  final List<Semester> semesters;
  final List<Course> courses;
  final List<app.Group> groups;
  final List<AppUser> students;
  final List<Assignment> assignments;
  final Course? currentCourse;
  final DateTime? lastRefreshed;

  AIContextData({
    this.user,
    this.semesters = const [],
    this.courses = const [],
    this.groups = const [],
    this.students = const [],
    this.assignments = const [],
    this.currentCourse,
    this.lastRefreshed,
  });

  int get totalSubmissions {
    int count = 0;
    for (final a in assignments) {
      count += a.submissions.length;
    }
    return count;
  }

  int get ungradedSubmissions {
    int count = 0;
    for (final a in assignments) {
      count += a.submissions.where((s) => s.grade == null).length;
    }
    return count;
  }

  int get lateSubmissions {
    int count = 0;
    for (final a in assignments) {
      count += a.submissions.where((s) => s.isLate).length;
    }
    return count;
  }

  String toContextString() {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('           DỮ LIỆU HỆ THỐNG LMS - REALTIME');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('');

    if (user != null) {
      buffer.writeln('👤 NGƯỜI DÙNG ĐANG ĐĂNG NHẬP:');
      buffer.writeln('   • ID: ${user!.id}');
      buffer.writeln('   • Họ tên: ${user!.fullName}');
      buffer.writeln('   • Email: ${user!.email}');
      buffer.writeln('   • Vai trò: ${user!.role == UserRole.instructor ? "GIẢNG VIÊN" : "SINH VIÊN"}');
      if (user!.code != null) buffer.writeln('   • Mã: ${user!.code}');
      buffer.writeln('');
    }

    if (semesters.isNotEmpty) {
      buffer.writeln('📅 HỌC KỲ (${semesters.length} học kỳ):');
      for (final sem in semesters) {
        final status = sem.isActive ? '🟢 ĐANG HOẠT ĐỘNG' : '⚪ Không hoạt động';
        buffer.writeln('   • ${sem.name} (Mã: ${sem.code}) - $status');
      }
      buffer.writeln('');
    }

    if (students.isNotEmpty) {
      buffer.writeln('👨‍🎓 DANH SÁCH SINH VIÊN (${students.length} sinh viên):');
      for (final student in students) {
        buffer.writeln('   • ${student.code ?? "N/A"}: ${student.fullName} (${student.email})');
      }
      buffer.writeln('');
    }

    if (courses.isNotEmpty) {
      buffer.writeln('📚 DANH SÁCH MÔN HỌC (${courses.length} môn):');
      buffer.writeln('');
      
      for (final course in courses) {
        final semester = semesters.where((s) => s.id == course.semesterId).firstOrNull;
        final courseGroups = groups.where((g) => g.courseId == course.id).toList();
        final courseAssignments = assignments.where((a) => a.courseId == course.id).toList();
        
        buffer.writeln('┌─────────────────────────────────────────────────────');
        buffer.writeln('│ 📖 ${course.code} - ${course.name}');
        buffer.writeln('│    Học kỳ: ${semester?.name ?? "N/A"}');
        buffer.writeln('│    Số nhóm: ${courseGroups.length} | Số bài tập: ${courseAssignments.length}');
        
        if (courseGroups.isNotEmpty) {
          buffer.writeln('│');
          buffer.writeln('│    👥 NHÓM:');
          for (final group in courseGroups) {
            buffer.writeln('│       • ${group.name} (${group.studentIds.length} SV)');
            for (final sid in group.studentIds) {
              final student = students.where((s) => s.id == sid).firstOrNull;
              buffer.writeln('│         - ${student?.fullName ?? sid}');
            }
          }
        }
        
        if (courseAssignments.isNotEmpty) {
          buffer.writeln('│');
          buffer.writeln('│    📝 BÀI TẬP:');
          for (final assignment in courseAssignments) {
            final subs = assignment.submissions;
            final gradedCount = subs.where((s) => s.grade != null).length;
            buffer.writeln('│       • ${assignment.title}: ${subs.length} nộp, $gradedCount chấm');
          }
        }
        
        buffer.writeln('└─────────────────────────────────────────────────────');
        buffer.writeln('');
      }
    }

    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('TỔNG QUAN: ${courses.length} môn | ${groups.length} nhóm | ${students.length} SV | ${assignments.length} BT | $totalSubmissions nộp ($ungradedSubmissions chờ chấm)');
    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AI CONTEXT EDITOR BOTTOM SHEET (Simplified)
// ══════════════════════════════════════════════════════════════════════════════

class _AIContextEditorSheet extends StatefulWidget {
  final AIContextData contextData;
  final VoidCallback onRefresh;
  final bool isVietnamese;

  const _AIContextEditorSheet({
    required this.contextData,
    required this.onRefresh,
    required this.isVietnamese,
  });

  @override
  State<_AIContextEditorSheet> createState() => _AIContextEditorSheetState();
}

class _AIContextEditorSheetState extends State<_AIContextEditorSheet> {
  
  @override
  Widget build(BuildContext context) {
    final isVi = widget.isVietnamese;
    final data = widget.contextData;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.data_object, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isVi ? 'Dữ liệu AI Context' : 'AI Context Data', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (data.lastRefreshed != null)
                            Text('${isVi ? 'Cập nhật' : 'Updated'}: ${_formatTime(data.lastRefreshed!)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(isVi ? 'Làm mới' : 'Refresh'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildStatChip('📚 ${data.courses.length}', isVi ? 'Môn' : 'Courses', Colors.blue),
                    const SizedBox(width: 6),
                    _buildStatChip('👥 ${data.groups.length}', isVi ? 'Nhóm' : 'Groups', Colors.amber),
                    const SizedBox(width: 6),
                    _buildStatChip('👨‍🎓 ${data.students.length}', isVi ? 'SV' : 'Students', Colors.green),
                    const SizedBox(width: 6),
                    _buildStatChip('📝 ${data.assignments.length}', isVi ? 'BT' : 'Assign', Colors.orange),
                    const SizedBox(width: 6),
                    _buildStatChip('❌ ${data.ungradedSubmissions}', isVi ? 'Chờ' : 'Pending', Colors.red),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.code, color: Colors.grey, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(isVi ? 'Raw Context (gửi cho AI)' : 'Raw Context (sent to AI)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                Text('${data.toContextString().length} chars', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                            const Divider(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
                              constraints: const BoxConstraints(maxHeight: 400),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  data.toContextString(),
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.greenAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
            Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}