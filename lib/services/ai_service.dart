// lib/services/ai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AIProvider { openai, gemini, groq }
enum QuizDifficulty { easy, medium, hard }
enum QuestionType { multipleChoice, trueFalse, shortAnswer, fillInBlank }

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static AIProvider _provider = AIProvider.gemini;
  
  // API Key
  static String get _apiKey {
    final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (envKey.isNotEmpty) return envKey;
    // Fallback - replace with your key
    return 'AIzaSyA8CEoWywNo52mbVR1o3z71hkVhqvL1yCg';
  }

  static String get _model {
    switch (_provider) {
      case AIProvider.openai:
        return 'gpt-3.5-turbo';
      case AIProvider.gemini:
        return 'gemini-2.0-flash';
      case AIProvider.groq:
        return 'llama-3.1-70b-versatile';
    }
  }

  static String get _baseUrl {
    switch (_provider) {
      case AIProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case AIProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
      case AIProvider.groq:
        return 'https://api.groq.com/openai/v1/chat/completions';
    }
  }

  /// Check if AI is configured
  static bool get isConfigured {
    final key = _apiKey;
    return key.isNotEmpty && key.length > 10;
  }

  /// Set provider
  static void setProvider(AIProvider provider) {
    _provider = provider;
  }

  /// Initialize AI service
  static Future<void> initialize() async {
    print('🤖 Initializing AI Service...');
    print('🤖 Using model: $_model');
    print('🤖 isConfigured: $isConfigured');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE CHAT COMPLETION
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> chat({
    required String message,
    String? systemPrompt,
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    if (!isConfigured) {
      throw Exception('AI service not configured. Please add API key.');
    }

    try {
      if (_provider == AIProvider.gemini) {
        return await _chatGemini(
          message: message,
          systemPrompt: systemPrompt,
          conversationHistory: conversationHistory,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      } else {
        return await _chatOpenAIFormat(
          message: message,
          systemPrompt: systemPrompt,
          conversationHistory: conversationHistory,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      }
    } catch (e) {
      print('❌ AI chat error: $e');
      rethrow;
    }
  }

  static Future<String> _chatOpenAIFormat({
    required String message,
    String? systemPrompt,
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    final messages = <Map<String, String>>[];
    
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    
    if (conversationHistory != null) {
      messages.addAll(conversationHistory);
    }
    
    messages.add({'role': 'user', 'content': message});

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  static Future<String> _chatGemini({
    required String message,
    String? systemPrompt,
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    final contents = <Map<String, dynamic>>[];
    
    // Build conversation history
    if (conversationHistory != null) {
      for (final msg in conversationHistory) {
        contents.add({
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [{'text': msg['content']}],
        });
      }
    }
    
    // Add current message with system prompt
    String fullMessage = message;
    if (systemPrompt != null && contents.isEmpty) {
      fullMessage = '$systemPrompt\n\nUser question: $message';
    }
    
    contents.add({
      'role': 'user',
      'parts': [{'text': fullMessage}],
    });

    final url = '$_baseUrl?key=$_apiKey';

    final requestBody = {
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      print('❌ Gemini error: ${response.body}');
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    
    if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
      if (data['promptFeedback']?['blockReason'] != null) {
        throw Exception('Content blocked: ${data['promptFeedback']['blockReason']}');
      }
      throw Exception('No response from AI');
    }
    
    final candidate = data['candidates'][0];
    
    if (candidate['finishReason'] == 'SAFETY') {
      throw Exception('Response blocked due to safety filters');
    }
    
    if (candidate['content'] == null || candidate['content']['parts'] == null) {
      throw Exception('Invalid response format from AI');
    }
    
    return candidate['content']['parts'][0]['text'] as String;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🤖 AI LEARNING CHATBOT (Basic - no app context)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> learningAssistant({
    required String question,
    required String courseName,
    String? courseDescription,
    String? materialContext,
    List<Map<String, String>>? conversationHistory,
    String language = 'vi',
  }) async {
    final systemPrompt = '''
Bạn là trợ lý học tập AI thông minh cho môn học "$courseName".
${courseDescription != null ? 'Mô tả môn học: $courseDescription' : ''}

Nhiệm vụ của bạn:
1. Trả lời câu hỏi của sinh viên một cách rõ ràng, dễ hiểu
2. Giải thích các khái niệm phức tạp bằng ví dụ thực tế
3. Khuyến khích sinh viên tư duy phản biện
4. Nếu không chắc chắn, hãy thừa nhận và gợi ý nguồn tham khảo
5. Sử dụng ngôn ngữ ${language == 'vi' ? 'tiếng Việt' : 'English'}

${materialContext != null ? 'Tài liệu tham khảo:\n$materialContext' : ''}

Hãy trả lời ngắn gọn, súc tích nhưng đầy đủ thông tin. Sử dụng markdown để format (**bold**, *italic*, - list).
''';

    return await chat(
      message: question,
      systemPrompt: systemPrompt,
      conversationHistory: conversationHistory,
      temperature: 0.7,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🤖 AI LEARNING CHATBOT WITH APP CONTEXT (NEW!)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> learningAssistantWithContext({
    required String question,
    required String courseName,
    String? courseDescription,
    String? appContext,
    String? materialContext,
    List<Map<String, String>>? conversationHistory,
    String language = 'vi',
  }) async {
    final isVi = language == 'vi';
    
    final systemPrompt = isVi ? '''
Bạn là trợ lý AI thông minh cho hệ thống quản lý học tập (LMS).
${courseDescription != null ? 'Đang xem môn: $courseDescription' : ''}

**VAI TRÒ CỦA BẠN:**
1. Trả lời câu hỏi về hệ thống LMS, môn học, bài tập, bài nộp của sinh viên
2. Cung cấp thống kê và phân tích dữ liệu khi được hỏi
3. Giải thích các khái niệm học tập một cách dễ hiểu
4. Hỗ trợ giảng viên quản lý lớp học hiệu quả
5. Trả lời bằng tiếng Việt

**DỮ LIỆU HỆ THỐNG HIỆN TẠI:**
${appContext ?? 'Không có dữ liệu'}

${materialContext != null ? '**TÀI LIỆU THAM KHẢO:**\n$materialContext' : ''}

**HƯỚNG DẪN TRẢ LỜI:**
- Sử dụng dữ liệu hệ thống ở trên để trả lời câu hỏi về bài nộp, sinh viên, môn học
- Khi được hỏi về thống kê, hãy tính toán chính xác từ dữ liệu được cung cấp
- Trả lời ngắn gọn, súc tích, sử dụng markdown để format (**bold**, *italic*, - list)
- Nếu không có đủ thông tin trong dữ liệu, hãy nói rõ
- KHÔNG bịa thông tin không có trong dữ liệu
- Khi liệt kê danh sách, sử dụng bullet points
''' : '''
You are an intelligent AI assistant for a Learning Management System (LMS).
${courseDescription != null ? 'Currently viewing: $courseDescription' : ''}

**YOUR ROLE:**
1. Answer questions about the LMS, courses, assignments, and student submissions
2. Provide statistics and data analysis when asked
3. Explain learning concepts clearly
4. Help instructors manage their classes effectively
5. Respond in English

**CURRENT SYSTEM DATA:**
${appContext ?? 'No data available'}

${materialContext != null ? '**REFERENCE MATERIALS:**\n$materialContext' : ''}

**RESPONSE GUIDELINES:**
- Use the system data above to answer questions about submissions, students, courses
- When asked about statistics, calculate accurately from the provided data
- Keep responses concise, use markdown formatting (**bold**, *italic*, - lists)
- If information is not available in the data, say so clearly
- DO NOT make up information not present in the data
- Use bullet points when listing items
''';

    return await chat(
      message: question,
      systemPrompt: systemPrompt,
      conversationHistory: conversationHistory,
      temperature: 0.7,
      maxTokens: 2048,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📝 AI QUIZ GENERATOR
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String material,
    required int numberOfQuestions,
    required QuizDifficulty difficulty,
    required List<QuestionType> questionTypes,
    String? topic,
    String language = 'vi',
  }) async {
    final difficultyDesc = {
      QuizDifficulty.easy: 'Dễ - câu hỏi cơ bản, kiểm tra kiến thức nền tảng',
      QuizDifficulty.medium: 'Trung bình - câu hỏi yêu cầu hiểu và áp dụng',
      QuizDifficulty.hard: 'Khó - câu hỏi phân tích, tổng hợp, sáng tạo',
    };

    final typeDesc = questionTypes.map((t) {
      switch (t) {
        case QuestionType.multipleChoice:
          return 'Trắc nghiệm (4 đáp án A, B, C, D)';
        case QuestionType.trueFalse:
          return 'Đúng/Sai';
        case QuestionType.shortAnswer:
          return 'Tự luận ngắn';
        case QuestionType.fillInBlank:
          return 'Điền vào chỗ trống';
      }
    }).join(', ');

    final prompt = '''
Dựa trên tài liệu sau, hãy tạo $numberOfQuestions câu hỏi kiểm tra.

TÀI LIỆU:
$material

YÊU CẦU:
- Độ khó: ${difficultyDesc[difficulty]}
- Loại câu hỏi: $typeDesc
${topic != null ? '- Chủ đề tập trung: $topic' : ''}
- Ngôn ngữ: ${language == 'vi' ? 'Tiếng Việt' : 'English'}

ĐỊNH DẠNG OUTPUT (chỉ JSON array, không có markdown hay text khác):
[{"question":"Nội dung câu hỏi","type":"multipleChoice","difficulty":"medium","options":["A. ...","B. ...","C. ...","D. ..."],"correctAnswer":"A","explanation":"Giải thích","points":1}]

CHỈ TRẢ VỀ JSON ARRAY, KHÔNG CÓ TEXT KHÁC.
''';

    final response = await chat(
      message: prompt,
      temperature: 0.8,
      maxTokens: 4096,
    );

    try {
      String jsonStr = response.trim();
      
      // Remove markdown code blocks
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }
      
      // Find JSON array
      final startIndex = jsonStr.indexOf('[');
      final endIndex = jsonStr.lastIndexOf(']');
      if (startIndex != -1 && endIndex != -1) {
        jsonStr = jsonStr.substring(startIndex, endIndex + 1);
      }
      
      final List<dynamic> questions = jsonDecode(jsonStr);
      return questions.map((q) => Map<String, dynamic>.from(q)).toList();
    } catch (e) {
      print('❌ Error parsing quiz questions: $e');
      print('Raw response: $response');
      throw Exception('Failed to parse AI response. Please try again.');
    }
  }

  /// Validate generated questions
  static List<Map<String, dynamic>> validateQuestions(List<Map<String, dynamic>> questions) {
    final validated = <Map<String, dynamic>>[];
    
    for (final q in questions) {
      if (q['question'] == null || (q['question'] as String).isEmpty) continue;
      if (q['correctAnswer'] == null) continue;
      
      if (q['type'] == 'multipleChoice') {
        if (q['options'] == null || (q['options'] as List).length < 2) continue;
      }
      
      validated.add(q);
    }
    
    return validated;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📚 AI MATERIAL SUMMARIZER
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> summarizeMaterial({
    required String content,
    String? title,
    bool includeKeyPoints = true,
    bool includeQuestions = true,
    String language = 'vi',
  }) async {
    final prompt = '''
Hãy tóm tắt tài liệu học tập sau:

${title != null ? 'TIÊU ĐỀ: $title\n' : ''}
NỘI DUNG:
$content

Trả về JSON với format (chỉ JSON, không markdown):
{"summary":"Tóm tắt ngắn gọn (2-3 đoạn)","keyPoints":["Điểm chính 1","Điểm chính 2"],"concepts":[{"term":"Thuật ngữ","definition":"Định nghĩa"}],"reviewQuestions":["Câu hỏi ôn tập 1","Câu hỏi ôn tập 2"],"studyTips":"Gợi ý cách học hiệu quả"}

CHỈ TRẢ VỀ JSON, KHÔNG CÓ TEXT KHÁC.
''';

    final response = await chat(
      message: prompt,
      temperature: 0.5,
      maxTokens: 2048,
    );

    try {
      String jsonStr = response.trim();
      
      // Remove markdown
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }
      
      // Find JSON object
      final startIndex = jsonStr.indexOf('{');
      final endIndex = jsonStr.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        jsonStr = jsonStr.substring(startIndex, endIndex + 1);
      }
      
      return Map<String, dynamic>.from(jsonDecode(jsonStr));
    } catch (e) {
      return {
        'summary': response,
        'error': 'Could not parse structured summary',
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 💬 SIMPLE CHAT (for general questions)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> simpleChat({
    required String message,
    String language = 'vi',
  }) async {
    final systemPrompt = language == 'vi' 
        ? 'Bạn là trợ lý AI thân thiện. Trả lời ngắn gọn, hữu ích bằng tiếng Việt.'
        : 'You are a friendly AI assistant. Respond concisely and helpfully in English.';
    
    return await chat(
      message: message,
      systemPrompt: systemPrompt,
      temperature: 0.7,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📊 AI DATA ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> analyzeData({
    required String data,
    required String analysisRequest,
    String language = 'vi',
  }) async {
    final systemPrompt = '''
Bạn là chuyên gia phân tích dữ liệu giáo dục.
Phân tích dữ liệu được cung cấp và đưa ra insights hữu ích.
Trả lời bằng ${language == 'vi' ? 'tiếng Việt' : 'English'}.
Sử dụng markdown để format câu trả lời.
''';

    final message = '''
DỮ LIỆU:
$data

YÊU CẦU PHÂN TÍCH:
$analysisRequest
''';

    return await chat(
      message: message,
      systemPrompt: systemPrompt,
      temperature: 0.5,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📝 FEEDBACK GENERATOR
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> generateFeedback({
    required String studentWork,
    required String assignmentTitle,
    String? rubric,
    String language = 'vi',
  }) async {
    final systemPrompt = '''
Bạn là giảng viên đang chấm bài và viết phản hồi cho sinh viên.
Viết phản hồi mang tính xây dựng, cụ thể và khuyến khích.
Chỉ ra điểm mạnh và điểm cần cải thiện.
Trả lời bằng ${language == 'vi' ? 'tiếng Việt' : 'English'}.
''';

    final message = '''
BÀI TẬP: $assignmentTitle
${rubric != null ? 'RUBRIC CHẤM ĐIỂM:\n$rubric\n' : ''}
BÀI LÀM CỦA SINH VIÊN:
$studentWork

Hãy viết phản hồi chi tiết cho bài làm này.
''';

    return await chat(
      message: message,
      systemPrompt: systemPrompt,
      temperature: 0.6,
    );
  }
}