import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIAgentService {
  late final GenerativeModel _model;

  AIAgentService() {
    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not defined in .env');
    }
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  Future<Map<String, String>> categorizeApps(List<String> appNames) async {
    if (appNames.isEmpty) return {};

    final prompt =
        '''
You are an expert app categorizer. I will provide a list of app names. You must deeply analyze the names, including company prefixes (like 'Meta', 'Google', 'Microsoft') or app suffixes (like 'Lite', 'Pro', 'Go').
For example: 'Meta Facebook Lite' or 'Instagram' MUST be 'Social'. 'WhatsApp' or 'Telegram' MUST be 'Messaging'. 'Chrome' is 'Browser'.
Categories allowed ONLY: [Social, Messaging, Browser, Productivity, Gaming, Media, System, Others].
Return ONLY a valid JSON object where the key is the app name and the value is the category. No markdown, no extra text.

App names:
${appNames.join(', ')}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '{}';

      // Clean up markdown block if model accidentally adds it
      String jsonStr = text;
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }

      final Map<String, dynamic> decoded = jsonDecode(jsonStr.trim());
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print('Error parsing AI response: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> parseScheduleCommand(
    String userInput,
    List<String> activeCategories,
  ) async {
    final prompt =
        '''
You are a smart app blocker config parser. The user might want to set a schedule, OR just instantly block/unblock an app or category.
Days are 1 (Monday) to 7 (Sunday). If time is not specified, assume 00:00 to 23:59. 
Return ONLY raw JSON, no markdown blocks.

JSON Schema must now include 'action_type' which can ONLY be: 'schedule', 'manual_block', or 'unblock'.
If the user says 'block [app]' without time, use 'manual_block'.
If the user sets a daily time limit (e.g., '2 hours', '30 mins'), convert it to TOTAL MINUTES and put it in 'max_daily_minutes'.

CRITICAL INSTRUCTION: If target_type is "category", you MUST use the EXACT category names provided in the Active Categories list below. Do NOT invent new categories.

Schema: [{"target": "name", "target_type": "category" or "app", "action_type": "schedule"|"manual_block"|"unblock", "allowed_days": [int], "start_time": "HH:MM", "end_time": "HH:MM", "max_daily_minutes": int}]

Active Categories:
${activeCategories.join(', ')}

User Request:
$userInput
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '[]';

      String jsonStr = text;
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }

      final List<dynamic> decoded = jsonDecode(jsonStr.trim());
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error parsing NLP schedule command: $e');
      return [];
    }
  }

  Future<List<String>> generateRoastAmunition(
    int count,
    String roastLevel,
  ) async {
    String promptPrefix =
        "You are a passive-aggressive Butler. Give a snarky, sarcastic remark to discourage the user from opening blocked apps.";
    if (roastLevel == 'Polite') {
      promptPrefix =
          "You are a polite British Butler. Give a gentle, elegant reminder to the user to not open blocked apps.";
    } else if (roastLevel == 'Savage') {
      promptPrefix =
          "You are a ruthless, savage AI. Roast the user absolutely ruthlessly for lacking discipline and opening blocked apps.";
    }

    final prompt =
        '''
$promptPrefix Generate exactly $count distinct, short sentences in a single JSON array format. Return ONLY the raw JSON array of strings, e.g. ["Sentence 1", "Sentence 2"]. No markdown formatting.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '[]';

      String jsonStr = text;
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }

      final List<dynamic> decoded = jsonDecode(jsonStr.trim());
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print('Error generating roast ammunition: $e');
      return [];
    }
  }

  Future<String> getSarcasticRoast(String appName, String category) async {
    final prompt =
        '''
You are an extremely sarcastic, passive-aggressive, and highly critical AI Butler. Your user just tried to open the blocked app '$appName' (Category: $category) instead of being productive. Write a short, punchy, 1-2 sentence sarcastic roast mocking their lack of discipline and telling them to get back to work/real life. Be witty and savage, but not overly offensive. Respond ONLY with the text, no markdown, no quotes.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          "Really? We both know you have better things to do.";
    } catch (e) {
      print('Error generating roast: $e');
      return "Really? We both know you have better things to do.";
    }
  }

  Future<String> getAnalyticsVerdict(
    int totalMinutes,
    String topCategory,
    String timeframe,
  ) async {
    final prompt =
        '''
You are a judgmental British Butler. The user spent $totalMinutes minutes on their phone $timeframe, mostly on $topCategory. Give a short, brutal, sarcastic 1-sentence verdict/grade on their performance $timeframe. No markdown.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          "A shockingly average display of wasted time.";
    } catch (e) {
      print('Error generating analytics verdict: $e');
      return "A shockingly average display of wasted time.";
    }
  }
}
