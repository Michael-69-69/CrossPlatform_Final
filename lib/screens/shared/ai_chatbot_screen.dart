// lib/screens/shared/ai_chatbot_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_service.dart';
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
  // COOLDOWN TIMER (FIX: Timer to update UI)
  // ══════════════════════════════════════════════════════════════════════════
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  
  // ══════════════════════════════════════════════════════════════════════════
  // STRUCTURED CONTEXT DATA (for editing)
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

  // ══════════════════════════════════════════════════════════════════════════
  // COOLDOWN TIMER (Updates UI every second)
  // ══════════════════════════════════════════════════════════════════════════
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
  // REFRESH CONTEXT DATA FROM PROVIDERS (FIXED!)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _refreshContextData({bool forceReload = false}) async {
    if (_isLoadingContext) return;
    
    try {
      _isLoadingContext = true;
      
      if (forceReload) {
        if (mounted) setState(() => _contextLoaded = false);
        
        print('🔄 Force reloading all data for AI context...');
        
        // Step 1: Load courses first (we need course IDs for assignments)
        await ref.read(courseProvider.notifier).loadCourses();
        
        // Step 2: Load other data in parallel
        await Future.wait([
          ref.read(semesterProvider.notifier).loadSemesters(),
          ref.read(groupProvider.notifier).loadGroups(),
          ref.read(studentProvider.notifier).loadStudents(),
        ]);
        
        // Step 3: Load assignments for each course
        final courses = ref.read(courseProvider);
        for (final course in courses) {
          await ref.read(assignmentProvider.notifier).loadAssignments(course.id);
        }
        
        // Small delay to ensure state is updated
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Now read the fresh data
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
      
      print('════════════════════════════════════════════════════════');
      print('✅ AI Context refreshed successfully!');
      print('   📚 Courses: ${courses.length}');
      print('   📝 Assignments: ${assignments.length}');
      print('   👥 Groups: ${groups.length}');
      print('   👨‍🎓 Students: ${students.length}');
      print('   📅 Semesters: ${semesters.length}');
      print('════════════════════════════════════════════════════════');
      
      // Debug: Print group details
      for (final g in groups) {
        final course = courses.where((c) => c.id == g.courseId).firstOrNull;
        print('   📁 Group: ${g.name} (${course?.code ?? "?"})');
        print('      Student IDs: ${g.studentIds}');
        for (final sid in g.studentIds) {
          final student = students.where((s) => s.id == sid).firstOrNull;
          print('      - ${student?.fullName ?? sid}');
        }
      }
      
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

**Ví dụ câu hỏi:**
- "Có bao nhiêu bài chưa chấm?"
- "Ai nộp bài trễ?"
- "Thống kê môn WebDev"
- "Nhóm 1 môn WEB102 có ai?"

Hãy hỏi tôi bất cứ điều gì!'''
          : '''Hello ${user?.fullName ?? 'there'}! 👋 

I'm the AI assistant for **$courseName** with access to all LMS data.

**Example questions:**
- "How many submissions are ungraded?"
- "Who submitted late?"
- "Statistics for WebDev"
- "Who is in Group 1 of WEB102?"

Ask me anything!''',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

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

    _messageController.clear();

    setState(() {
      _messages.add(_ChatMessage(content: message, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Force refresh context to get LATEST data before sending!
      await _refreshContextData(forceReload: true);
      
      // Debug: Print what we're sending
      print('════════════════════════════════════════════════════════');
      print('📤 SENDING TO AI:');
      print('   Question: $message');
      print('   Context Stats:');
      print('   - Courses: ${_contextData.courses.length}');
      print('   - Groups: ${_contextData.groups.length}');
      print('   - Students: ${_contextData.students.length}');
      print('   - Assignments: ${_contextData.assignments.length}');
      print('════════════════════════════════════════════════════════');
      
      final history = _messages
          .where((m) => m.content.isNotEmpty)
          .toList()
          .reversed
          .take(10)
          .toList()
          .reversed
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.content})
          .toList();

      final contextString = _buildContextString();
      
      // Debug: Print a portion of the context
      print('📋 Context Preview (first 500 chars):');
      print(contextString.length > 500 ? '${contextString.substring(0, 500)}...' : contextString);

      final response = await AIService.learningAssistantWithContext(
        question: message,
        courseName: widget.course?.name ?? 'LMS System',
        courseDescription: widget.course?.name,
        appContext: contextString,
        materialContext: widget.materialContext,
        conversationHistory: history.length > 1 ? history.sublist(0, history.length - 1) : null,
        language: _isVietnamese() ? 'vi' : 'en',
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
        
        // Friendly error messages
        if (errorMsg.contains('429') || errorMsg.contains('rate') || errorMsg.contains('quota')) {
          errorMsg = _isVietnamese() 
            ? '⚠️ Đã vượt giới hạn API. Vui lòng đợi 30 giây rồi thử lại.'
            : '⚠️ Rate limit exceeded. Please wait 30 seconds and try again.';
        } else if (errorMsg.contains('API key')) {
          errorMsg = _isVietnamese()
            ? '⚠️ API key không hợp lệ hoặc đã hết hạn.'
            : '⚠️ Invalid or expired API key.';
        } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
          errorMsg = _isVietnamese()
            ? '⚠️ Lỗi kết nối mạng. Vui lòng kiểm tra internet.'
            : '⚠️ Network error. Please check your connection.';
        }
        
        setState(() {
          _messages.add(_ChatMessage(
            content: '❌ ${_isVietnamese() ? 'Lỗi' : 'Error'}: $errorMsg',
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
  // SHOW CONTEXT EDITOR DIALOG
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
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
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
                  ? '✅ Đã cập nhật: ${_contextData.courses.length} môn, ${_contextData.assignments.length} bài tập, ${_contextData.groups.length} nhóm, ${_contextData.students.length} sinh viên'
                  : '✅ Refreshed: ${_contextData.courses.length} courses, ${_contextData.assignments.length} assignments, ${_contextData.groups.length} groups, ${_contextData.students.length} students'),
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
          // Cooldown indicator
          if (isInCooldown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${_cooldownSeconds}s',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Context Editor Button
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: isVi ? 'Xem/Sửa Context' : 'View/Edit Context',
            onPressed: _showContextEditorDialog,
          ),
          
          // Clear Chat Button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: isVi ? 'Xóa chat' : 'Clear chat',
            onPressed: () => setState(() { _messages.clear(); _addWelcomeMessage(); }),
          ),
        ],
      ),
      body: Column(
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
          
          // Context Status Bar (Clickable)
          InkWell(
            onTap: _showContextEditorDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _contextLoaded ? Colors.green.shade50 : Colors.orange.shade50,
              child: Row(
                children: [
                  if (_isLoadingContext)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
                            ? '${_contextData.courses.length} môn • ${_contextData.groups.length} nhóm • ${_contextData.assignments.length} bài tập • ${_contextData.students.length} SV'
                            : '${_contextData.courses.length} courses • ${_contextData.groups.length} groups • ${_contextData.assignments.length} assignments • ${_contextData.students.length} students')
                        : (isVi ? 'Đang tải dữ liệu...' : 'Loading data...'),
                      style: TextStyle(
                        color: _contextLoaded ? Colors.green.shade700 : Colors.orange.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.green.shade700, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    isVi ? 'Xem/Sửa' : 'View/Edit',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 11),
                  ),
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

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: isInCooldown 
                          ? (isVi ? 'Đợi ${_cooldownSeconds}s...' : 'Wait ${_cooldownSeconds}s...')
                          : (isVi ? 'Hỏi về LMS...' : 'Ask about LMS...'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isInCooldown ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: isConfigured && !isInCooldown && !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: (isConfigured && !isInCooldown && !_isLoading) ? Colors.deepPurple : Colors.grey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: (_isLoading || !isConfigured || isInCooldown) ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
                      ? Text(message.content, style: const TextStyle(color: Colors.white))
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
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
                ),
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

    // User Info
    if (user != null) {
      buffer.writeln('👤 NGƯỜI DÙNG ĐANG ĐĂNG NHẬP:');
      buffer.writeln('   • ID: ${user!.id}');
      buffer.writeln('   • Họ tên: ${user!.fullName}');
      buffer.writeln('   • Email: ${user!.email}');
      buffer.writeln('   • Vai trò: ${user!.role == UserRole.instructor ? "GIẢNG VIÊN" : "SINH VIÊN"}');
      if (user!.code != null) buffer.writeln('   • Mã: ${user!.code}');
      buffer.writeln('');
    }

    // Semesters
    if (semesters.isNotEmpty) {
      buffer.writeln('📅 HỌC KỲ (${semesters.length} học kỳ):');
      for (final sem in semesters) {
        final status = sem.isActive ? '🟢 ĐANG HOẠT ĐỘNG' : '⚪ Không hoạt động';
        buffer.writeln('   • ${sem.name} (Mã: ${sem.code}) - $status');
      }
      buffer.writeln('');
    }

    // Students
    if (students.isNotEmpty) {
      buffer.writeln('👨‍🎓 DANH SÁCH TẤT CẢ SINH VIÊN (${students.length} sinh viên):');
      for (final student in students) {
        buffer.writeln('   • ID: ${student.id}');
        buffer.writeln('     Mã SV: ${student.code ?? "N/A"} | Tên: ${student.fullName} | Email: ${student.email}');
      }
      buffer.writeln('');
    }

    // Courses with details
    if (courses.isNotEmpty) {
      buffer.writeln('📚 DANH SÁCH MÔN HỌC (${courses.length} môn):');
      buffer.writeln('');
      
      for (final course in courses) {
        final semester = semesters.where((s) => s.id == course.semesterId).firstOrNull;
        final semesterName = semester?.name ?? 'N/A';
        final courseGroups = groups.where((g) => g.courseId == course.id).toList();
        final courseAssignments = assignments.where((a) => a.courseId == course.id).toList();
        
        buffer.writeln('┌─────────────────────────────────────────────────────');
        buffer.writeln('│ 📖 MÔN: ${course.code} - ${course.name}');
        buffer.writeln('│    ID môn: ${course.id}');
        buffer.writeln('│    Học kỳ: $semesterName');
        buffer.writeln('│    Giảng viên: ${course.instructorName}');
        buffer.writeln('│    Số buổi học: ${course.sessions}');
        buffer.writeln('│    Số nhóm: ${courseGroups.length}');
        buffer.writeln('│    Số bài tập: ${courseAssignments.length}');
        
        // Groups in course
        if (courseGroups.isNotEmpty) {
          buffer.writeln('│');
          buffer.writeln('│    👥 CÁC NHÓM TRONG MÔN ${course.code}:');
          for (final group in courseGroups) {
            buffer.writeln('│');
            buffer.writeln('│       📁 NHÓM: "${group.name}"');
            buffer.writeln('│          ID nhóm: ${group.id}');
            buffer.writeln('│          Số sinh viên: ${group.studentIds.length}');
            
            if (group.studentIds.isNotEmpty) {
              buffer.writeln('│          👨‍🎓 DANH SÁCH THÀNH VIÊN:');
              for (final studentId in group.studentIds) {
                final student = students.where((s) => s.id == studentId).firstOrNull;
                if (student != null) {
                  buffer.writeln('│             • ${student.code ?? "N/A"}: ${student.fullName} (${student.email})');
                } else {
                  buffer.writeln('│             • [Không tìm thấy] ID: $studentId');
                }
              }
            } else {
              buffer.writeln('│          ⚠️ Nhóm chưa có sinh viên');
            }
          }
        }
        
        // Assignments in course
        if (courseAssignments.isNotEmpty) {
          buffer.writeln('│');
          buffer.writeln('│    📝 BÀI TẬP TRONG MÔN ${course.code}:');
          
          for (final assignment in courseAssignments) {
            final deadlineStr = '${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year} ${assignment.deadline.hour}:${assignment.deadline.minute.toString().padLeft(2, '0')}';
            final isOverdue = DateTime.now().isAfter(assignment.deadline);
            final overdueLabel = isOverdue ? ' ⚠️ ĐÃ QUÁ HẠN' : '';
            
            buffer.writeln('│');
            buffer.writeln('│       📋 BÀI TẬP: "${assignment.title}"');
            buffer.writeln('│          ID: ${assignment.id}');
            buffer.writeln('│          Hạn nộp: $deadlineStr$overdueLabel');
            buffer.writeln('│          Số lần nộp tối đa: ${assignment.maxAttempts}');
            
            final subs = assignment.submissions;
            final gradedCount = subs.where((s) => s.grade != null).length;
            final pendingCount = subs.length - gradedCount;
            final lateCount = subs.where((s) => s.isLate).length;
            
            buffer.writeln('│          📊 Thống kê: ${subs.length} nộp | $gradedCount đã chấm | $pendingCount chờ chấm | $lateCount trễ');
            
            if (subs.isNotEmpty) {
              buffer.writeln('│          📄 CHI TIẾT BÀI NỘP:');
              for (final sub in subs) {
                final gradeText = sub.grade != null ? 'Điểm: ${sub.grade}' : '❌ CHƯA CHẤM';
                final lateText = sub.isLate ? ' [TRỄ HẠN]' : '';
                final submitDate = '${sub.submittedAt.day}/${sub.submittedAt.month}/${sub.submittedAt.year} ${sub.submittedAt.hour}:${sub.submittedAt.minute.toString().padLeft(2, '0')}';
                buffer.writeln('│             • ${sub.studentName} (Nhóm: ${sub.groupName})');
                buffer.writeln('│               Nộp lúc: $submitDate$lateText');
                buffer.writeln('│               $gradeText');
              }
            }
          }
        }
        
        buffer.writeln('└─────────────────────────────────────────────────────');
        buffer.writeln('');
      }
    }

    // Current course focus
    if (currentCourse != null) {
      buffer.writeln('🎯 ĐANG XEM MÔN: ${currentCourse!.code} - ${currentCourse!.name}');
      buffer.writeln('');
    }

    // Summary
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('                    TỔNG QUAN HỆ THỐNG');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('   • Học kỳ: ${semesters.length}');
    buffer.writeln('   • Môn học: ${courses.length}');
    buffer.writeln('   • Nhóm: ${groups.length}');
    buffer.writeln('   • Sinh viên: ${students.length}');
    buffer.writeln('   • Bài tập: ${assignments.length}');
    buffer.writeln('   • Bài nộp: $totalSubmissions (Chấm: ${totalSubmissions - ungradedSubmissions} | Chờ: $ungradedSubmissions | Trễ: $lateSubmissions)');
    buffer.writeln('═══════════════════════════════════════════════════════');

    return buffer.toString();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AI CONTEXT EDITOR BOTTOM SHEET
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
  int _selectedTab = 0;
  
  @override
  Widget build(BuildContext context) {
    final isVi = widget.isVietnamese;
    final data = widget.contextData;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
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
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
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
                          Text(
                            isVi ? 'Dữ liệu AI Context' : 'AI Context Data',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (data.lastRefreshed != null)
                            Text(
                              '${isVi ? 'Cập nhật' : 'Updated'}: ${_formatTime(data.lastRefreshed!)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(isVi ? 'Làm mới' : 'Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
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
              
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildTab(0, '👤 User'),
                    _buildTab(1, '📅 ${isVi ? 'Học kỳ' : 'Semesters'}'),
                    _buildTab(2, '📚 ${isVi ? 'Môn' : 'Courses'}'),
                    _buildTab(3, '👥 ${isVi ? 'Nhóm' : 'Groups'}'),
                    _buildTab(4, '👨‍🎓 ${isVi ? 'SV' : 'Students'}'),
                    _buildTab(5, '📝 ${isVi ? 'BT' : 'Assignments'}'),
                    _buildTab(6, '📄 Raw'),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              Expanded(
                child: _buildTabContent(isVi, scrollController),
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

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedTab = index),
        selectedColor: Colors.deepPurple.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildTabContent(bool isVi, ScrollController scrollController) {
    final data = widget.contextData;
    
    List<Widget> children;
    
    switch (_selectedTab) {
      case 0:
        children = [_buildUserCard(data.user, isVi)];
        break;
      case 1:
        children = data.semesters.isEmpty 
          ? [_buildEmptyCard(isVi ? 'Không có học kỳ' : 'No semesters')]
          : data.semesters.map((s) => _buildSemesterCard(s, isVi)).toList();
        break;
      case 2:
        children = data.courses.isEmpty
          ? [_buildEmptyCard(isVi ? 'Không có môn học' : 'No courses')]
          : data.courses.map((c) => _buildCourseCard(c, data, isVi)).toList();
        break;
      case 3:
        children = data.groups.isEmpty
          ? [_buildEmptyCard(isVi ? 'Không có nhóm' : 'No groups')]
          : data.groups.map((g) => _buildGroupCard(g, data, isVi)).toList();
        break;
      case 4:
        children = data.students.isEmpty
          ? [_buildEmptyCard(isVi ? 'Không có sinh viên' : 'No students')]
          : data.students.map((s) => _buildStudentCard(s, isVi)).toList();
        break;
      case 5:
        children = data.assignments.isEmpty
          ? [_buildEmptyCard(isVi ? 'Không có bài tập' : 'No assignments')]
          : data.assignments.map((a) => _buildAssignmentCard(a, data, isVi)).toList();
        break;
      case 6:
        children = [_buildRawDataCard(data, isVi)];
        break;
      default:
        children = [];
    }
    
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(AppUser? user, bool isVi) {
    if (user == null) {
      return _buildEmptyCard(isVi ? 'Chưa đăng nhập' : 'Not logged in');
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    user.role == UserRole.instructor ? (isVi ? 'GV' : 'Instructor') : (isVi ? 'SV' : 'Student'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: user.role == UserRole.instructor ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDataRow('ID', user.id),
            if (user.code != null) _buildDataRow(isVi ? 'Mã' : 'Code', user.code!),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterCard(Semester semester, bool isVi) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: semester.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          child: Icon(
            semester.isActive ? Icons.check_circle : Icons.circle_outlined,
            color: semester.isActive ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(semester.name),
        subtitle: Text('${isVi ? 'Mã' : 'Code'}: ${semester.code}'),
        trailing: semester.isActive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isVi ? 'Hoạt động' : 'Active', style: const TextStyle(fontSize: 10, color: Colors.green)),
              )
            : null,
      ),
    );
  }

  Widget _buildCourseCard(Course course, AIContextData data, bool isVi) {
    final semester = data.semesters.where((s) => s.id == course.semesterId).firstOrNull;
    final groupCount = data.groups.where((g) => g.courseId == course.id).length;
    final assignmentCount = data.assignments.where((a) => a.courseId == course.id).length;
    
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withOpacity(0.1),
          child: const Icon(Icons.school, color: Colors.indigo, size: 20),
        ),
        title: Text('${course.code} - ${course.name}', style: const TextStyle(fontSize: 14)),
        subtitle: Text('${semester?.name ?? 'N/A'} • $groupCount ${isVi ? 'nhóm' : 'groups'} • $assignmentCount ${isVi ? 'BT' : 'assign'}', style: const TextStyle(fontSize: 11)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDataRow('ID', course.id),
                _buildDataRow(isVi ? 'Giảng viên' : 'Instructor', course.instructorName),
                _buildDataRow(isVi ? 'Số buổi' : 'Sessions', '${course.sessions}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(app.Group group, AIContextData data, bool isVi) {
    final course = data.courses.where((c) => c.id == group.courseId).firstOrNull;
    
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.withOpacity(0.1),
          child: const Icon(Icons.group, color: Colors.amber, size: 20),
        ),
        title: Text(group.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text('${course?.code ?? 'N/A'} • ${group.studentIds.length} ${isVi ? 'SV' : 'students'}', style: const TextStyle(fontSize: 11)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDataRow('ID', group.id),
                _buildDataRow(isVi ? 'Môn học' : 'Course', '${course?.code ?? 'N/A'} - ${course?.name ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('${isVi ? 'Thành viên' : 'Members'} (${group.studentIds.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                if (group.studentIds.isEmpty)
                  Text(isVi ? '  ⚠️ Chưa có sinh viên' : '  ⚠️ No students', style: TextStyle(color: Colors.orange.shade700, fontSize: 12))
                else
                  ...group.studentIds.map((id) {
                    final student = data.students.where((s) => s.id == id).firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              student != null 
                                ? '${student.code ?? 'N/A'}: ${student.fullName}'
                                : '❓ ID: $id (không tìm thấy)',
                              style: TextStyle(fontSize: 12, color: student != null ? null : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(AppUser student, bool isVi) {
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          radius: 18,
          child: Text(student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12)),
        ),
        title: Text(student.fullName, style: const TextStyle(fontSize: 13)),
        subtitle: Text('${student.code ?? 'N/A'} • ${student.email}', style: const TextStyle(fontSize: 10)),
      ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment, AIContextData data, bool isVi) {
    final course = data.courses.where((c) => c.id == assignment.courseId).firstOrNull;
    final subs = assignment.submissions;
    final gradedCount = subs.where((s) => s.grade != null).length;
    final lateCount = subs.where((s) => s.isLate).length;
    final isOverdue = DateTime.now().isAfter(assignment.deadline);
    
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
          child: Icon(Icons.assignment, color: isOverdue ? Colors.red : Colors.orange, size: 20),
        ),
        title: Text(assignment.title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${course?.code ?? 'N/A'} • ${subs.length} ${isVi ? 'nộp' : 'sub'} • $gradedCount ${isVi ? 'chấm' : 'graded'}',
          style: const TextStyle(fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDataRow('ID', assignment.id),
                _buildDataRow(isVi ? 'Hạn nộp' : 'Deadline', _formatDateTime(assignment.deadline)),
                _buildDataRow(isVi ? 'Trạng thái' : 'Status', isOverdue ? '⚠️ Quá hạn' : '✅ Còn hạn'),
                _buildDataRow(isVi ? 'Tổng nộp' : 'Submissions', '${subs.length}'),
                _buildDataRow(isVi ? 'Đã chấm' : 'Graded', '$gradedCount'),
                _buildDataRow(isVi ? 'Chờ chấm' : 'Pending', '${subs.length - gradedCount}'),
                _buildDataRow(isVi ? 'Trễ hạn' : 'Late', '$lateCount'),
                if (subs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${isVi ? 'Bài nộp' : 'Submissions'}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ...subs.take(5).map((sub) {
                    final gradeText = sub.grade != null ? '${sub.grade}đ' : '❌';
                    final lateText = sub.isLate ? ' [TRỄ]' : '';
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text('• ${sub.studentName}$lateText - $gradeText', style: const TextStyle(fontSize: 11)),
                    );
                  }),
                  if (subs.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text('... ${isVi ? 'và' : 'and'} ${subs.length - 5} ${isVi ? 'bài khác' : 'more'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawDataCard(AIContextData data, bool isVi) {
    final contextString = data.toContextString();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVi ? 'Raw Context (gửi cho AI)' : 'Raw Context (sent to AI)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  '${contextString.length} chars',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: SelectableText(
                  contextString,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}