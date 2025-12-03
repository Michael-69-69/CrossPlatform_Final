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
  
  // ══════════════════════════════════════════════════════════════════════════
  // COOLDOWN MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════
  static DateTime? _lastRequestTime;
  static const int _cooldownSeconds = 10;
  
  static bool get isInCooldown {
    if (_lastRequestTime == null) return false;
    return DateTime.now().difference(_lastRequestTime!).inSeconds < _cooldownSeconds;
  }
  
  static int get remainingCooldownSeconds {
    if (_lastRequestTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastRequestTime!).inSeconds;
    return (_cooldownSeconds - elapsed).clamp(0, _cooldownSeconds);
  }
  
  static void _recordRequest() {
    _lastRequestTime = DateTime.now();
  }
  
  // API Key
  static String get _apiKey {
    final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (envKey.isNotEmpty) return envKey;
    return '';
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

  static bool get isConfigured {
    final key = _apiKey;
    return key.isNotEmpty && key.length > 10;
  }

  static void setProvider(AIProvider provider) {
    _provider = provider;
  }

  static Future<void> initialize() async {
    print('🤖 Initializing AI Service...');
    print('🤖 Using model: $_model');
    print('🤖 isConfigured: $isConfigured');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE CHAT COMPLETION (FIXED!)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String> chat({
    required String message,
    String? systemPrompt,
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    if (!isConfigured) {
      throw Exception('AI service not configured. Please add GEMINI_API_KEY to .env');
    }
    
    // Record request for cooldown
    _recordRequest();

    final url = '$_baseUrl?key=$_apiKey';
    
    // ═══════════════════════════════════════════════════════════════════════
    // FIX: Use Gemini's systemInstruction for proper context injection
    // ═══════════════════════════════════════════════════════════════════════
    
    final contents = <Map<String, dynamic>>[];
    
    // Add conversation history
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (final msg in conversationHistory) {
        contents.add({
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [{'text': msg['content']}],
        });
      }
    }
    
    // Add current message
    contents.add({
      'role': 'user',
      'parts': [{'text': message}],
    });

    // Build request body with systemInstruction (THE FIX!)
    final requestBody = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };
    
    // Add system instruction if provided (THIS IS THE KEY FIX!)
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      requestBody['systemInstruction'] = {
        'parts': [{'text': systemPrompt}]
      };
    }

    print('════════════════════════════════════════════════════════');
    print('🤖 SENDING TO GEMINI API:');
    print('   Model: $_model');
    print('   System prompt length: ${systemPrompt?.length ?? 0} chars');
    print('   Message: $message');
    print('   History: ${conversationHistory?.length ?? 0} messages');
    print('════════════════════════════════════════════════════════');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      print('❌ Gemini error: ${response.body}');
      
      // Parse error for better message
      try {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Gemini API error: $errorMessage');
      } catch (e) {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
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
    
    final responseText = candidate['content']['parts'][0]['text'] as String;
    
    print('✅ AI Response received: ${responseText.length} chars');
    
    return responseText;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🤖 AI LEARNING CHATBOT WITH APP CONTEXT (FIXED!)
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
    
    // Build a comprehensive system prompt with ALL context
    final systemPrompt = isVi ? '''
BẠN LÀ TRỢ LÝ AI CHO HỆ THỐNG QUẢN LÝ HỌC TẬP (LMS).
${courseDescription != null ? 'Đang xem môn: $courseDescription' : ''}

══════════════════════════════════════════════════════════════════
QUAN TRỌNG: DỮ LIỆU HỆ THỐNG BÊN DƯỚI LÀ NGUỒN THÔNG TIN CHÍNH XÁC.
BẠN PHẢI SỬ DỤNG DỮ LIỆU NÀY ĐỂ TRẢ LỜI CÂU HỎI CỦA NGƯỜI DÙNG.
══════════════════════════════════════════════════════════════════

$appContext

══════════════════════════════════════════════════════════════════
HƯỚNG DẪN TRẢ LỜI:
══════════════════════════════════════════════════════════════════
1. LUÔN sử dụng dữ liệu hệ thống ở trên để trả lời
2. Khi được hỏi về số liệu, đếm CHÍNH XÁC từ dữ liệu
3. Khi được hỏi về sinh viên/nhóm, tìm trong phần DANH SÁCH
4. Nếu không tìm thấy thông tin, nói rõ "Không có dữ liệu về..."
5. KHÔNG bịa thông tin không có trong dữ liệu
6. Trả lời ngắn gọn, dùng markdown: **bold**, *italic*, - list
7. Khi liệt kê, dùng bullet points

${materialContext != null ? 'TÀI LIỆU THAM KHẢO:\n$materialContext' : ''}
''' : '''
YOU ARE AN AI ASSISTANT FOR A LEARNING MANAGEMENT SYSTEM (LMS).
${courseDescription != null ? 'Currently viewing: $courseDescription' : ''}

══════════════════════════════════════════════════════════════════
IMPORTANT: THE SYSTEM DATA BELOW IS YOUR ACCURATE SOURCE OF TRUTH.
YOU MUST USE THIS DATA TO ANSWER USER QUESTIONS.
══════════════════════════════════════════════════════════════════

$appContext

══════════════════════════════════════════════════════════════════
RESPONSE GUIDELINES:
══════════════════════════════════════════════════════════════════
1. ALWAYS use the system data above to answer questions
2. When asked about numbers, count ACCURATELY from the data
3. When asked about students/groups, look in the LIST sections
4. If information is not found, say "No data available for..."
5. DO NOT make up information not in the data
6. Keep responses concise, use markdown: **bold**, *italic*, - lists
7. Use bullet points when listing items

${materialContext != null ? 'REFERENCE MATERIALS:\n$materialContext' : ''}
''';

    print('════════════════════════════════════════════════════════');
    print('📤 learningAssistantWithContext called');
    print('   Question: $question');
    print('   System prompt length: ${systemPrompt.length} chars');
    print('   App context length: ${appContext?.length ?? 0} chars');
    print('════════════════════════════════════════════════════════');

    return await chat(
      message: question,
      systemPrompt: systemPrompt,
      conversationHistory: conversationHistory,
      temperature: 0.3, // Lower temperature for more accurate answers
      maxTokens: 4096,
    );
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
  // 📝 AI QUIZ GENERATOR
  // ══════════════════════════════════════════════════════════════════════════
// Add this after generateQuizQuestions method:

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

    final response = await chat(message: prompt, temperature: 0.5, maxTokens: 4096);

    try {
      String jsonStr = response.trim();
      
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }
      
      final startIndex = jsonStr.indexOf('[');
      final endIndex = jsonStr.lastIndexOf(']');
      if (startIndex != -1 && endIndex != -1) {
        jsonStr = jsonStr.substring(startIndex, endIndex + 1);
      }
      
      final List<dynamic> questions = jsonDecode(jsonStr);
      return questions.map((q) => Map<String, dynamic>.from(q)).toList();
    } catch (e) {
      print('Error parsing quiz: $e');
      return [];
    }
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

    final response = await chat(message: prompt, temperature: 0.5, maxTokens: 2048);

    try {
      String jsonStr = response.trim();
      
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }
      
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
  // 💬 SIMPLE CHAT
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

    return await chat(
      message: 'DỮ LIỆU:\n$data\n\nYÊU CẦU PHÂN TÍCH:\n$analysisRequest',
      systemPrompt: systemPrompt,
      temperature: 0.5,
      maxTokens: 2048,
    );
  }
}