// services/email_service.dart
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // Get credentials from .env file
  static String get _username => dotenv.env['EMAIL_USER'] ?? '';
  static String get _password => dotenv.env['EMAIL_PASS'] ?? '';
  static String get _senderName => dotenv.env['EMAIL_SENDER_NAME'] ?? 'LMS';
  static String get _apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  
  // Get SMTP server configuration
  static SmtpServer get _smtpServer {
    if (_username.isEmpty || _password.isEmpty) {
      throw Exception('Email credentials not configured in .env file');
    }
    return gmail(_username, _password);
  }

  // ============================================
  // SEND EMAIL (Platform-aware)
  // ============================================
  static Future<bool> sendEmail({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlBody,
    String? plainTextBody,
  }) async {
    // ✅ WEB: Use backend API (Resend)
    if (kIsWeb) {
      return await _sendEmailViaAPI(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        subject: subject,
        htmlBody: htmlBody,
        plainTextBody: plainTextBody,
      );
    }
    
    // ✅ MOBILE/DESKTOP: Use direct SMTP (NO CHANGES)
    return await _sendEmailViaSMTP(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      htmlBody: htmlBody,
      plainTextBody: plainTextBody,
    );
  }

  // ✅ MOBILE: Send via SMTP (UNCHANGED - WORKING FINE)
  static Future<bool> _sendEmailViaSMTP({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlBody,
    String? plainTextBody,
  }) async {
    if (_username.isEmpty || _password.isEmpty) {
      print('⚠️ Email service not configured - skipping email');
      return false;
    }

    try {
      // Create message
      final message = Message()
        ..from = Address(_username, _senderName)
        ..recipients.add(Address(recipientEmail, recipientName))
        ..subject = subject
        ..text = plainTextBody ?? _stripHtml(htmlBody)
        ..html = htmlBody;

      // Send email
      final sendReport = await send(message, _smtpServer);
      
      print('✅ Email sent to $recipientEmail (SMTP)');
      print('   Subject: $subject');
      
      return true;
    } catch (e) {
      print('❌ Error sending email via SMTP to $recipientEmail: $e');
      return false;
    }
  }

  // ✅ WEB: Send via API (UPDATED FOR RESEND - BETTER ERROR HANDLING)
  static Future<bool> _sendEmailViaAPI({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlBody,
    String? plainTextBody,
  }) async {
    if (_apiBaseUrl.isEmpty) {
      print('⚠️ API_BASE_URL not configured - skipping email on web');
      print('   Would send to: $recipientEmail');
      print('   Subject: $subject');
      return false;
    }

    try {
      // ✅ Build API URL
      String baseUrl = _apiBaseUrl.endsWith('/') 
          ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1) 
          : _apiBaseUrl;
      
      String endpoint = baseUrl.endsWith('/api') 
          ? '$baseUrl/send-email'
          : '$baseUrl/api/send-email';

      print('🌐 Sending email via Resend API to: $recipientEmail');
      print('📍 API URL: $endpoint');
      
      // ✅ Send request with timeout
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'to': recipientEmail,
          'name': recipientName,
          'subject': subject,
          'html': htmlBody,
          'text': plainTextBody ?? _stripHtml(htmlBody),
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Email request timeout after 30 seconds');
        },
      );

      if (response.statusCode == 200) {
        // ✅ Parse response to get email ID
        try {
          final data = jsonDecode(response.body);
          print('✅ Email sent to $recipientEmail (Resend)');
          print('   Subject: $subject');
          if (data['id'] != null) {
            print('   Email ID: ${data['id']}');
          }
        } catch (e) {
          // Response might not be JSON, that's ok
          print('✅ Email sent to $recipientEmail (Resend)');
          print('   Subject: $subject');
        }
        return true;
      } else {
        print('❌ API error: ${response.statusCode}');
        print('   Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending email via API to $recipientEmail: $e');
      return false;
    }
  }

  // ============================================
  // BULK SEND EMAIL
  // ============================================
  static Future<Map<String, dynamic>> sendBulkEmail({
    required List<Map<String, String>> recipients, // [{email, name}]
    required String subject,
    required String htmlBody,
    String? plainTextBody,
  }) async {
    int successCount = 0;
    int failCount = 0;
    List<String> failedEmails = [];

    for (var recipient in recipients) {
      final success = await sendEmail(
        recipientEmail: recipient['email']!,
        recipientName: recipient['name']!,
        subject: subject,
        htmlBody: htmlBody,
        plainTextBody: plainTextBody,
      );

      if (success) {
        successCount++;
      } else {
        failCount++;
        failedEmails.add(recipient['email']!);
      }
      
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return {
      'total': recipients.length,
      'success': successCount,
      'failed': failCount,
      'failedEmails': failedEmails,
    };
  }

  // ============================================
  // EMAIL TEMPLATES
  // ============================================

  // 1. NEW ANNOUNCEMENT
  static Future<bool> sendAnnouncementEmail({
    required String recipientEmail,
    required String recipientName,
    required String courseName,
    required String announcementTitle,
    required String announcementContent,
    String announcementUrl = '#',
  }) async {
    final subject = '📢 Thông báo mới: $announcementTitle - $courseName';
    
    final htmlBody = _buildAnnouncementHtml(
      recipientName: recipientName,
      courseName: courseName,
      announcementTitle: announcementTitle,
      announcementContent: announcementContent,
      announcementUrl: announcementUrl,
    );

    return await sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      htmlBody: htmlBody,
    );
  }

  // 2. ASSIGNMENT DEADLINE APPROACHING
  static Future<bool> sendAssignmentDeadlineEmail({
    required String recipientEmail,
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    required DateTime deadline,
    String assignmentUrl = '#',
  }) async {
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    final hoursLeft = deadline.difference(DateTime.now()).inHours;
    
    String timeLeftText;
    if (daysLeft > 0) {
      timeLeftText = '$daysLeft ngày';
    } else if (hoursLeft > 0) {
      timeLeftText = '$hoursLeft giờ';
    } else {
      timeLeftText = 'Sắp hết hạn!';
    }
    
    final subject = '⏰ Nhắc nhở: "$assignmentTitle" còn $timeLeftText';
    
    final htmlBody = _buildAssignmentDeadlineHtml(
      recipientName: recipientName,
      courseName: courseName,
      assignmentTitle: assignmentTitle,
      deadline: deadline,
      timeLeftText: timeLeftText,
      assignmentUrl: assignmentUrl,
    );

    return await sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      htmlBody: htmlBody,
    );
  }

  // 3. QUIZ DEADLINE APPROACHING
  static Future<bool> sendQuizDeadlineEmail({
    required String recipientEmail,
    required String recipientName,
    required String courseName,
    required String quizTitle,
    required DateTime deadline,
    String quizUrl = '#',
  }) async {
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    final hoursLeft = deadline.difference(DateTime.now()).inHours;
    
    String timeLeftText;
    if (daysLeft > 0) {
      timeLeftText = '$daysLeft ngày';
    } else if (hoursLeft > 0) {
      timeLeftText = '$hoursLeft giờ';
    } else {
      timeLeftText = 'Sắp đóng!';
    }
    
    final subject = '📝 Nhắc nhở Quiz: "$quizTitle" còn $timeLeftText';
    
    final htmlBody = _buildQuizDeadlineHtml(
      recipientName: recipientName,
      courseName: courseName,
      quizTitle: quizTitle,
      deadline: deadline,
      timeLeftText: timeLeftText,
      quizUrl: quizUrl,
    );

    return await sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      htmlBody: htmlBody,
    );
  }

  // 4. SUBMISSION CONFIRMATION
  static Future<bool> sendSubmissionConfirmationEmail({
    required String recipientEmail,
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    required DateTime submittedAt,
  }) async {
    final subject = '✅ Xác nhận nộp bài: $assignmentTitle';
    
    final htmlBody = _buildSubmissionConfirmationHtml(
      recipientName: recipientName,
      courseName: courseName,
      assignmentTitle: assignmentTitle,
      submittedAt: submittedAt,
    );

    return await sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      htmlBody: htmlBody,
    );
  }

  // 5. INSTRUCTOR FEEDBACK
  static Future<bool> sendInstructorFeedbackEmail({
    required String recipientEmail,
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    double? grade,
    required String feedback,
    String assignmentUrl = '#',
  }) async {
    final subject = '📊 Giảng viên đã chấm bài: $assignmentTitle';
    
    final htmlBody = _buildInstructorFeedbackHtml(
      recipientName: recipientName,
      courseName: courseName,
      assignmentTitle: assignmentTitle,
      grade: grade,
      feedback: feedback,
      assignmentUrl: assignmentUrl,
    );

    return await sendEmail(
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      subject: subject,
      htmlBody: htmlBody,
    );
  }

  // ============================================
  // HTML TEMPLATES
  // ============================================
  
  static String _buildAnnouncementHtml({
    required String recipientName,
    required String courseName,
    required String announcementTitle,
    required String announcementContent,
    required String announcementUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
    .content { background: #f9f9f9; padding: 30px; }
    .announcement-box { background: white; padding: 20px; border-left: 4px solid #667eea; margin: 20px 0; }
    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>📢 Thông báo mới</h1>
    </div>
    <div class="content">
      <p>Xin chào <strong>$recipientName</strong>,</p>
      <p>Bạn có thông báo mới từ khóa học <strong>$courseName</strong>:</p>
      
      <h2 style="color: #667eea;">$announcementTitle</h2>
      <div class="announcement-box">
        ${_sanitizeHtml(announcementContent)}
      </div>
      
      <a href="$announcementUrl" class="button">Xem chi tiết</a>
      
      <p style="margin-top: 30px; color: #666;">Trân trọng,<br>Hệ thống LMS</p>
    </div>
    <div class="footer">
      <p>Email này được gửi tự động. Vui lòng không trả lời.</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _buildAssignmentDeadlineHtml({
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    required DateTime deadline,
    required String timeLeftText,
    required String assignmentUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 30px; text-align: center; }
    .content { background: #f9f9f9; padding: 30px; }
    .deadline-box { background: #fff3cd; border: 2px solid #ffc107; padding: 20px; border-radius: 5px; text-align: center; margin: 20px 0; }
    .button { display: inline-block; padding: 12px 30px; background: #f5576c; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⏰ Nhắc nhở hạn nộp bài</h1>
    </div>
    <div class="content">
      <p>Xin chào <strong>$recipientName</strong>,</p>
      <p>Bài tập <strong>"$assignmentTitle"</strong> trong khóa học <strong>$courseName</strong> sắp đến hạn nộp.</p>
      
      <div class="deadline-box">
        <h2 style="margin: 0; color: #856404;">⏱️ Còn $timeLeftText</h2>
        <p style="margin: 10px 0 0 0;">Hạn nộp: ${_formatDateTime(deadline)}</p>
      </div>
      
      <p>Hãy nhanh tay hoàn thành và nộp bài!</p>
      
      <a href="$assignmentUrl" class="button">Nộp bài ngay</a>
      
      <p style="margin-top: 30px; color: #666;">Chúc bạn học tập tốt!<br>Hệ thống LMS</p>
    </div>
    <div class="footer">
      <p>Email này được gửi tự động. Vui lòng không trả lời.</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _buildQuizDeadlineHtml({
    required String recipientName,
    required String courseName,
    required String quizTitle,
    required DateTime deadline,
    required String timeLeftText,
    required String quizUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); color: white; padding: 30px; text-align: center; }
    .content { background: #f9f9f9; padding: 30px; }
    .deadline-box { background: #d1ecf1; border: 2px solid #0c5460; padding: 20px; border-radius: 5px; text-align: center; margin: 20px 0; }
    .button { display: inline-block; padding: 12px 30px; background: #00f2fe; color: #333; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>📝 Nhắc nhở làm Quiz</h1>
    </div>
    <div class="content">
      <p>Xin chào <strong>$recipientName</strong>,</p>
      <p>Quiz <strong>"$quizTitle"</strong> trong khóa học <strong>$courseName</strong> sắp đóng.</p>
      
      <div class="deadline-box">
        <h2 style="margin: 0; color: #0c5460;">⏱️ Còn $timeLeftText</h2>
        <p style="margin: 10px 0 0 0;">Đóng lúc: ${_formatDateTime(deadline)}</p>
      </div>
      
      <p>Đừng bỏ lỡ cơ hội làm quiz này!</p>
      
      <a href="$quizUrl" class="button">Làm quiz ngay</a>
      
      <p style="margin-top: 30px; color: #666;">Chúc bạn làm bài tốt!<br>Hệ thống LMS</p>
    </div>
    <div class="footer">
      <p>Email này được gửi tự động. Vui lòng không trả lời.</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _buildSubmissionConfirmationHtml({
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    required DateTime submittedAt,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 30px; text-align: center; }
    .content { background: #f9f9f9; padding: 30px; }
    .success-box { background: #d4edda; border: 2px solid #28a745; padding: 20px; border-radius: 5px; text-align: center; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>✅ Nộp bài thành công</h1>
    </div>
    <div class="content">
      <p>Xin chào <strong>$recipientName</strong>,</p>
      
      <div class="success-box">
        <h2 style="margin: 0; color: #155724;">🎉 Đã nhận bài nộp!</h2>
        <p style="margin: 10px 0 0 0;">Khóa học: <strong>$courseName</strong></p>
        <p style="margin: 5px 0 0 0;">Bài tập: <strong>$assignmentTitle</strong></p>
        <p style="margin: 5px 0 0 0;">Nộp lúc: ${_formatDateTime(submittedAt)}</p>
      </div>
      
      <p>Bài làm của bạn đã được ghi nhận. Giảng viên sẽ chấm điểm sớm nhất.</p>
      
      <p style="margin-top: 30px; color: #666;">Chúc mừng!<br>Hệ thống LMS</p>
    </div>
    <div class="footer">
      <p>Email này được gửi tự động. Vui lòng không trả lời.</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _buildInstructorFeedbackHtml({
    required String recipientName,
    required String courseName,
    required String assignmentTitle,
    double? grade,
    required String feedback,
    required String assignmentUrl,
  }) {
    final gradeHtml = grade != null 
        ? '<p style="font-size: 24px; color: #667eea; font-weight: bold; margin: 10px 0;">Điểm: $grade/10</p>' 
        : '';
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
    .content { background: #f9f9f9; padding: 30px; }
    .feedback-box { background: white; border-left: 4px solid #667eea; padding: 20px; margin: 20px 0; }
    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>📊 Kết quả chấm bài</h1>
    </div>
    <div class="content">
      <p>Xin chào <strong>$recipientName</strong>,</p>
      <p>Giảng viên đã chấm bài tập <strong>"$assignmentTitle"</strong> trong khóa học <strong>$courseName</strong>.</p>
      
      $gradeHtml
      
      <div class="feedback-box">
        <h3 style="margin-top: 0; color: #667eea;">Nhận xét:</h3>
        <p>${_sanitizeHtml(feedback)}</p>
      </div>
      
      <a href="$assignmentUrl" class="button">Xem chi tiết</a>
      
      <p style="margin-top: 30px; color: #666;">Tiếp tục cố gắng!<br>Hệ thống LMS</p>
    </div>
    <div class="footer">
      <p>Email này được gửi tự động. Vui lòng không trả lời.</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  // ============================================
  // HELPER FUNCTIONS
  // ============================================
  
  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  static String _sanitizeHtml(String text) {
    // Basic sanitization - you can enhance this
    return text
        .replaceAll('<script', '&lt;script')
        .replaceAll('javascript:', '')
        .trim();
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} lúc ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}