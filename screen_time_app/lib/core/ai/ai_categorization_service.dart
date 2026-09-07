import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A high-precision AI categorization service that:
/// - Runs only once, on first launch (results are permanently cached)
/// - Processes apps in batches of 40 to prevent LLM hallucination / token limits
/// - Uses both appName + packageName for maximum accuracy
/// - Enforces strict JSON-only output format
class AICategorizationService {
  static const String _cacheKey = 'cached_app_categories';
  static const int _batchSize = 40;

  static const List<String> _allowedCategories = [
    'Social',
    'Messaging',
    'Games',
    'Productivity',
    'Education',
    'Entertainment',
    'Utilities',
    'Browser',
    'Health & Fitness',
    'Finance',
    'Shopping',
    'Photography',
    'Music & Audio',
    'Maps & Navigation',
    'Food & Drink',
    'News',
    'System',
    'Others',
  ];

  late final GenerativeModel _model;

  AICategorizationService() {
    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not defined in .env');
    }
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns the full packageName → category map.
  /// On subsequent calls, instantly returns the persisted cache without
  /// making any network requests.
  Future<Map<String, String>> categorizeApps(List<AppInfo> installedApps) async {
    final entries = installedApps
        .map((a) => _AppEntry(packageName: a.packageName, name: a.name))
        .toList();
    return _categorizeEntries(entries);
  }

  /// Alternative entry point for callers that only have raw JSON maps
  /// (e.g., RemoteScheduleScreen working from cloud-fetched child app list).
  Future<Map<String, String>> categorizeFromMap(
      List<Map<String, String>> apps) async {
    final entries = apps
        .map((a) => _AppEntry(
              packageName: a['packageName'] ?? '',
              name: a['appName'] ?? a['packageName'] ?? '',
            ))
        .where((e) => e.packageName.isNotEmpty)
        .toList();
    return _categorizeEntries(entries);
  }

  Future<Map<String, String>> _categorizeEntries(List<_AppEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();

    // Fast path: return cached result if it exists
    final cached = prefs.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cached);
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (e) {
        print('=== 🤖 CATEGORIZER: Cache corrupt, re-running AI. ===');
        await prefs.remove(_cacheKey);
      }
    }

    // Slow path: run AI batched categorization
    print('=== 🤖 CATEGORIZER: First launch. Running AI categorization on ${entries.length} apps. ===');
    final Map<String, String> fullResult = {};

    // Split into batches of _batchSize
    for (int i = 0; i < entries.length; i += _batchSize) {
      final end = (i + _batchSize < entries.length) ? i + _batchSize : entries.length;
      final batch = entries.sublist(i, end);
      final batchNumber = (i ~/ _batchSize) + 1;
      final totalBatches = (entries.length / _batchSize).ceil();

      print('=== 🤖 CATEGORIZER: Processing batch $batchNumber / $totalBatches (${batch.length} apps) ===');

      try {
        final batchResult = await _categorizeBatch(batch);
        fullResult.addAll(batchResult);
      } catch (e) {
        print('=== 🤖 CATEGORIZER: Batch $batchNumber failed, skipping. Error: $e ===');
      }

      if (end < entries.length) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Persist the merged result permanently
    await prefs.setString(_cacheKey, jsonEncode(fullResult));
    print('=== 🤖 CATEGORIZER: Done. ${fullResult.length} apps categorized and cached permanently. ===');

    return fullResult;
  }

  /// Instantly reads the category for a single package from the local cache.
  /// Returns 'Others' if the package was never categorized.
  Future<String> getCategoryForApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null || cached.isEmpty) return 'Others';

    try {
      final Map<String, dynamic> decoded = jsonDecode(cached);
      return decoded[packageName]?.toString() ?? 'Others';
    } catch (_) {
      return 'Others';
    }
  }

  /// Clears the cache, forcing a full re-categorization on the next call.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    print('=== 🤖 CATEGORIZER: Cache cleared. Will re-run on next launch. ===');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _categorizeBatch(List<_AppEntry> batch) async {
    // Format: "App Name (com.package.name)" — gives the LLM maximum context
    final appList = batch
        .map((app) => '${app.name} (${app.packageName})')
        .join('\n');

    final categoriesStr = _allowedCategories.join(', ');

    final prompt = '''
You are a ruthlessly precise mobile app categorizer. Your only job is to output a single valid JSON object and NOTHING else.

STRICT RULES — violating any rule makes your output useless:
1. Output ONLY a raw JSON object. No markdown, no code fences (no ```), no explanation, no preamble.
2. Each key MUST be the exact packageName from the list below.
3. Each value MUST be exactly one category from this allowed list: [$categoriesStr].
4. Every app in the list MUST appear in your output. Do not skip any.
5. If you are genuinely unsure, use "Others". Never invent a new category.

Use the packageName (in parentheses) to resolve ambiguity. For example:
- com.facebook.* or com.instagram.* → Social
- com.whatsapp or org.telegram.* → Messaging
- com.google.android.gms or android.* → System
- com.*.game or com.*.puzzle → Games

Apps to categorize:
$appList

Respond with only the JSON object:
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final raw = response.text?.trim() ?? '{}';

    return _parseJsonSafely(raw, batch);
  }

  Map<String, String> _parseJsonSafely(String raw, List<_AppEntry> batch) {
    // Strip accidental markdown fences the model may add despite instructions
    String cleaned = raw;
    if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
    else if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
    if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
    cleaned = cleaned.trim();

    try {
      final Map<String, dynamic> decoded = jsonDecode(cleaned);
      final result = <String, String>{};

      for (final app in batch) {
        final value = decoded[app.packageName];
        if (value != null && _allowedCategories.contains(value.toString())) {
          result[app.packageName] = value.toString();
        } else {
          result[app.packageName] = 'Others';
        }
      }

      return result;
    } catch (e) {
      print('=== 🤖 CATEGORIZER: JSON parse failed for batch. Raw: "$cleaned". Error: $e ===');
      return {for (final app in batch) app.packageName: 'Others'};
    }
  }
}

/// Internal lightweight app entry used by both public methods.
class _AppEntry {
  final String packageName;
  final String name;
  _AppEntry({required this.packageName, required this.name});
}
