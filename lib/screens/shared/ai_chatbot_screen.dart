// lib/screens/shared/ai_chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_service.dart';
import '../../models/course.dart';
import '../../models/user.dart';
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
  String _appContext = '';
  bool _contextLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeAdded) {
      _loadContextAndWelcome();
      _welcomeAdded = true;
    }
  }

  bool _isVietnamese() {
    try {
      return ref.read(localeProvider).languageCode == 'vi';
    } catch (e) {
      return true;
    }
  }

  Future<void> _loadContextAndWelcome() async {
    await _buildAppContext();
    _addWelcomeMessage();
    if (mounted) setState(() {});
  }

  Future<void> _buildAppContext() async {
    final buffer = StringBuffer();
    
    try {
      final user = ref.read(authProvider);
      final courses = ref.read(courseProvider);
      final semesters = ref.read(semesterProvider);
      final students = ref.read(studentProvider);
      final groups = ref.read(groupProvider);
      final assignments = ref.read(assignmentProvider);

      buffer.writeln('═══════════════════════════════════════════════════════');
      buffer.writeln('           DỮ LIỆU HỆ THỐNG LMS - REALTIME');
      buffer.writeln('═══════════════════════════════════════════════════════');
      buffer.writeln('');

      if (user != null) {
        buffer.writeln('👤 NGƯỜI DÙNG ĐANG ĐĂNG NHẬP:');
        buffer.writeln('   • ID: ${user.id}');
        buffer.writeln('   • Họ tên: ${user.fullName}');
        buffer.writeln('   • Email: ${user.email}');
        buffer.writeln('   • Vai trò: ${user.role == UserRole.instructor ? "GIẢNG VIÊN" : "SINH VIÊN"}');
        if (user.code != null) buffer.writeln('   • Mã: ${user.code}');
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
          buffer.writeln('   • Mã SV: ${student.code ?? "N/A"} | Tên: ${student.fullName} | Email: ${student.email}');
        }
        buffer.writeln('');
      }

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
          buffer.writeln('│    Học kỳ: $semesterName');
          buffer.writeln('│    Giảng viên: ${course.instructorName}');
          buffer.writeln('│    Số buổi học: ${course.sessions}');
          buffer.writeln('│    Số nhóm: ${courseGroups.length}');
          buffer.writeln('│    Số bài tập: ${courseAssignments.length}');
          
          if (courseGroups.isNotEmpty) {
            buffer.writeln('│');
            buffer.writeln('│    👥 NHÓM TRONG MÔN NÀY:');
            for (final group in courseGroups) {
              buffer.writeln('│       • ${group.name}: ${group.studentIds.length} sinh viên');
              for (final studentId in group.studentIds) {
                final student = students.where((s) => s.id == studentId).firstOrNull;
                if (student != null) {
                  buffer.writeln('│         - ${student.code ?? "N/A"}: ${student.fullName}');
                }
              }
            }
          }
          
          if (courseAssignments.isNotEmpty) {
            buffer.writeln('│');
            buffer.writeln('│    📝 BÀI TẬP TRONG MÔN NÀY:');
            
            int totalSubmissions = 0;
            int totalGraded = 0;
            int totalLate = 0;
            
            for (final assignment in courseAssignments) {
              final deadlineStr = '${assignment.deadline.day}/${assignment.deadline.month}/${assignment.deadline.year} ${assignment.deadline.hour}:${assignment.deadline.minute.toString().padLeft(2, '0')}';
              final isOverdue = DateTime.now().isAfter(assignment.deadline);
              final overdueLabel = isOverdue ? ' ⚠️ ĐÃ QUÁ HẠN' : '';
              
              buffer.writeln('│');
              buffer.writeln('│       📋 "${assignment.title}"');
              buffer.writeln('│          Hạn nộp: $deadlineStr$overdueLabel');
              buffer.writeln('│          Số lần nộp tối đa: ${assignment.maxAttempts}');
              
              final subs = assignment.submissions;
              totalSubmissions += subs.length;
              
              final gradedCount = subs.where((s) => s.grade != null).length;
              final pendingCount = subs.length - gradedCount;
              final lateCount = subs.where((s) => s.isLate).length;
              
              totalGraded += gradedCount;
              totalLate += lateCount;
              
              buffer.writeln('│          📊 Thống kê: ${subs.length} nộp | $gradedCount đã chấm | $pendingCount chờ chấm | $lateCount trễ');
              
              if (subs.isNotEmpty) {
                buffer.writeln('│          📄 Chi tiết bài nộp:');
                for (final sub in subs) {
                  final gradeText = sub.grade != null ? 'Điểm: ${sub.grade}' : '❌ CHƯA CHẤM';
                  final lateText = sub.isLate ? ' [TRỄ]' : '';
                  final submitDate = '${sub.submittedAt.day}/${sub.submittedAt.month}/${sub.submittedAt.year} ${sub.submittedAt.hour}:${sub.submittedAt.minute.toString().padLeft(2, '0')}';
                  buffer.writeln('│             • ${sub.studentName} (${sub.groupName}) - $submitDate$lateText - $gradeText');
                }
              }
            }
            
            buffer.writeln('│');
            buffer.writeln('│    📊 TỔNG KẾT: $totalSubmissions nộp | $totalGraded chấm | ${totalSubmissions - totalGraded} chờ | $totalLate trễ');
          }
          
          buffer.writeln('└─────────────────────────────────────────────────────');
          buffer.writeln('');
        }
      }

      if (widget.course != null) {
        buffer.writeln('🎯 ĐANG XEM MÔN: ${widget.course!.code} - ${widget.course!.name}');
        buffer.writeln('');
      }

      buffer.writeln('═══════════════════════════════════════════════════════');
      buffer.writeln('                    TỔNG QUAN HỆ THỐNG');
      buffer.writeln('═══════════════════════════════════════════════════════');
      buffer.writeln('   • Học kỳ: ${semesters.length} | Môn học: ${courses.length}');
      buffer.writeln('   • Sinh viên: ${students.length} | Nhóm: ${groups.length}');
      buffer.writeln('   • Bài tập: ${assignments.length}');
      
      int allSubmissions = 0;
      int allGraded = 0;
      int allLate = 0;
      
      for (final a in assignments) {
        allSubmissions += a.submissions.length;
        allGraded += a.submissions.where((s) => s.grade != null).length;
        allLate += a.submissions.where((s) => s.isLate).length;
      }
      
      buffer.writeln('   • Bài nộp: $allSubmissions | Đã chấm: $allGraded | Chờ: ${allSubmissions - allGraded} | Trễ: $allLate');
      buffer.writeln('═══════════════════════════════════════════════════════');

      _appContext = buffer.toString();
      _contextLoaded = true;
      
    } catch (e) {
      print('❌ Error building context: $e');
      _appContext = 'Lỗi khi tải dữ liệu: $e';
    }
  }

  Future<void> _refreshContext() async {
    setState(() => _contextLoaded = false);
    await _buildAppContext();
    if (mounted) setState(() {});
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

Hãy hỏi tôi bất cứ điều gì!'''
          : '''Hello ${user?.fullName ?? 'there'}! 👋 

I'm the AI assistant for **$courseName** with access to all LMS data.

**Example questions:**
- "How many submissions are ungraded?"
- "Who submitted late?"
- "Statistics for WebDev"

Ask me anything!''',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();

    setState(() {
      _messages.add(_ChatMessage(content: message, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      await _buildAppContext();
      
      final history = _messages
          .where((m) => m.content.isNotEmpty)
          .toList()
          .reversed
          .take(10)
          .toList()
          .reversed
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.content})
          .toList();

      final response = await AIService.learningAssistantWithContext(
        question: message,
        courseName: widget.course?.name ?? 'LMS System',
        courseDescription: widget.course?.name,
        appContext: _appContext,
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
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            content: '❌ Lỗi: $e',
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

  void _showContextDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🤖 AI Context'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              _appContext.isEmpty ? 'No context' : _appContext,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = ref.watch(localeProvider).languageCode == 'vi';
    final user = ref.watch(authProvider);
    final isConfigured = AIService.isConfigured;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          IconButton(icon: const Icon(Icons.data_object), onPressed: _showContextDialog),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _refreshContext();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isVi ? '✅ Đã cập nhật' : '✅ Refreshed'), duration: const Duration(seconds: 1)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() { _messages.clear(); _addWelcomeMessage(); }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Text('⚠️ AI chưa cấu hình', style: TextStyle(color: Colors.orange.shade800)),
            ),
          
          if (_contextLoaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text('✅ Đã tải dữ liệu', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                ],
              ),
            ),

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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickAction('📊 Tổng quan', 'Thống kê tổng quan'),
                  const SizedBox(width: 8),
                  _buildQuickAction('📝 Chưa chấm', 'Liệt kê bài chưa chấm'),
                  const SizedBox(width: 8),
                  _buildQuickAction('⏰ Nộp trễ', 'Ai nộp trễ?'),
                ],
              ),
            ),
          ),

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
                        hintText: isVi ? 'Hỏi về LMS...' : 'Ask about LMS...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: isConfigured,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isConfigured ? Colors.deepPurple : Colors.grey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: _isLoading || !isConfigured ? null : _sendMessage,
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
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () { _messageController.text = message; _sendMessage(); },
      backgroundColor: Colors.deepPurple.withOpacity(0.1),
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
            child: const Text('...', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  _ChatMessage({required this.content, required this.isUser, required this.timestamp, this.isError = false});
}