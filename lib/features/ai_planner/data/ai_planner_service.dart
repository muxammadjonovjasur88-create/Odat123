import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/planned_task.dart';

/// Thrown when a plan can't be produced; [message] is safe to show the user.
class AiPlannerException implements Exception {
  const AiPlannerException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Calls the Gemini API **directly from the app** (free Spark plan — no Cloud
/// Functions), then maps + strictly validates the JSON into [PlannedTask]s.
///
/// The API key is injected at build/run time from a git-ignored file via
/// `--dart-define-from-file=dart_defines.json` (key `GEMINI_API_KEY`); it is
/// never hardcoded in committed source.
// TODO: Bu vaqtinchalik yechim. Blaze tarifiga o'tgandan keyin,
// bu qismni qaytadan Cloud Functions orqali xavfsiz backend'ga
// ko'chirish kerak.
class AiPlannerService {
  AiPlannerService(this._client);

  final http.Client _client;

  static const _model = 'gemini-2.5-flash';
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _allowedCategories = [
    'study',
    'sport',
    'work',
    'personal',
    'wellness',
  ];
  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<PlannedTask>> generatePlan({
    required String goalText,
    required String focusType,
    required DateTime startDate,
    required int days,
    required Map<String, List<Map<String, String>>> busyTimesByDay,
    Map<String, String> userContext = const {},
    String locale = 'en',
  }) async {
    if (!isConfigured) {
      throw const AiPlannerException(
        'AI planning isn\'t configured. Add your Gemini key to '
        'dart_defines.json and run with '
        '--dart-define-from-file=dart_defines.json.',
      );
    }

    final totalSpan = days.clamp(1, 30);
    final start = _dateOnly(startDate);

    // Split plan into chunks of up to 7 days to guarantee complete JSON responses
    // from Gemini without token truncation limits for 14-30 day plans.
    const chunkSize = 7;
    final allPlannedTasks = <PlannedTask>[];

    for (var chunkStartOffset = 0; chunkStartOffset < totalSpan; chunkStartOffset += chunkSize) {
      final currentChunkDays = (totalSpan - chunkStartOffset).clamp(1, chunkSize);
      final currentChunkStart = start.add(Duration(days: chunkStartOffset));

      final chunkTasks = await _fetchChunkPlan(
        goalText: goalText,
        focusType: focusType,
        startDate: currentChunkStart,
        days: currentChunkDays,
        busyTimesByDay: busyTimesByDay,
        userContext: userContext,
        locale: locale,
      );

      allPlannedTasks.addAll(chunkTasks);
    }

    if (allPlannedTasks.isEmpty) {
      throw const AiPlannerException(
        'Could not craft a plan from that. Try rephrasing your goal.',
      );
    }

    // Sort by date & time
    allPlannedTasks.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.startMinute.compareTo(b.startMinute);
    });

    return allPlannedTasks;
  }

  Future<List<PlannedTask>> _fetchChunkPlan({
    required String goalText,
    required String focusType,
    required DateTime startDate,
    required int days,
    required Map<String, List<Map<String, String>>> busyTimesByDay,
    required Map<String, String> userContext,
    required String locale,
  }) async {
    final langInstruction = _langInstruction(locale);
    final prompt = _buildPrompt(
      goalText: goalText,
      focusType: focusType,
      startDate: startDate,
      days: days,
      busyTimesByDay: busyTimesByDay,
      userContext: userContext,
      langInstruction: langInstruction,
    );

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey',
    );
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': langInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.7,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING'},
              'category': {'type': 'STRING', 'enum': _allowedCategories},
              'date': {'type': 'STRING'},
              'startTime': {'type': 'STRING'},
              'durationMinutes': {'type': 'INTEGER'},
              'reasoning': {'type': 'STRING'},
            },
            'required': [
              'title',
              'category',
              'date',
              'startTime',
              'durationMinutes',
              'reasoning',
            ],
          },
        },
      },
    });

    debugPrint('🤖 [AiPlannerService] Sending Gemini request for $days days starting $startDate...');
    http.Response res;
    try {
      res = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      debugPrint('❌ [AiPlannerService] Network error: $e');
      throw const AiPlannerException(
        'Could not reach the planning service. Check your connection and '
        'try again.',
      );
    }

    debugPrint('🤖 [AiPlannerService] Response status: ${res.statusCode}');
    if (res.statusCode == 400 ||
        res.statusCode == 401 ||
        res.statusCode == 403) {
      debugPrint('❌ [AiPlannerService] Auth/Permission error body: ${res.body}');
      throw const AiPlannerException(
        'The AI request was rejected — check that your Gemini API key is '
        'valid and enabled.',
      );
    }
    if (res.statusCode != 200) {
      debugPrint('❌ [AiPlannerService] Error response body: ${res.body}');
      throw const AiPlannerException(
        'The planning service is busy right now. Please try again.',
      );
    }

    final text = _extractText(res.body);
    if (text == null) {
      debugPrint('❌ [AiPlannerService] Could not extract text from response: ${res.body}');
      throw const AiPlannerException(
        'The planner returned an unexpected response. Please try again.',
      );
    }

    debugPrint('🤖 [AiPlannerService] Extracted text length: ${text.length}');
    final tasks = _validatePlan(text, startDate, days);
    debugPrint('🤖 [AiPlannerService] Parsed ${tasks.length} valid tasks for this chunk.');
    return tasks;
  }

  /// Pulls `candidates[0].content.parts[0].text` out of the Gemini response.
  String? _extractText(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = (candidates.first as Map)['content'] as Map?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      final text = (parts.first as Map)['text'];
      return text is String ? text : null;
    } catch (_) {
      return null;
    }
  }

  /// Parses the model's JSON and keeps only well-formed tasks, validating that
  /// each task's date falls within `[start, start + days)`. Single-day plans
  /// behave as before; multi-day plans keep each task on its own date.
  List<PlannedTask> _validatePlan(String rawText, DateTime start, int days) {
    dynamic parsed;
    try {
      parsed = jsonDecode(rawText);
    } catch (_) {
      return const [];
    }
    if (parsed is! List) return const [];

    final last = start.add(Duration(days: days - 1));

    final clean = <PlannedTask>[];
    for (final item in parsed) {
      if (item is! Map) continue;
      final title = (item['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      final startTime = (item['startTime'] as String?)?.trim() ?? '';
      if (!_hhmm.hasMatch(startTime)) continue;
      final duration = (item['durationMinutes'] as num?)?.round();
      if (duration == null) continue;

      // Validate the task's date is inside the requested period.
      final parsedDate = DateTime.tryParse((item['date'] as String?) ?? '');
      if (parsedDate == null) continue;
      final day = _dateOnly(parsedDate);
      if (day.isBefore(start) || day.isAfter(last)) continue;

      clean.add(
        PlannedTask.fromMap({
          'title': title.length > 120 ? title.substring(0, 120) : title,
          'category': item['category'],
          'date': _isoDate(day),
          'startTime': startTime,
          'durationMinutes': duration.clamp(10, 180),
          'reasoning': item['reasoning'],
        }),
      );
    }
    // Order by day, then by start time within the day.
    clean.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.startMinute.compareTo(b.startMinute);
    });

    // Safety net: drop any same-day time overlaps the model may have produced
    final noOverlap = <PlannedTask>[];
    DateTime? lastDay;
    var lastEnd = 0;
    for (final t in clean) {
      final day = _dateOnly(t.date);
      if (lastDay == null || day != lastDay || t.startMinute >= lastEnd) {
        noOverlap.add(t);
        lastDay = day;
        lastEnd = t.startMinute + t.durationMinutes;
      }
    }

    final maxTasks = days <= 1 ? 8 : (days * 8).clamp(8, 240);
    return noOverlap.take(maxTasks).toList();
  }

  /// Returns the language-enforcement instruction for [locale].
  /// Used both in systemInstruction (highest priority) and repeated inside
  /// the prompt body (reduces the risk of the model "forgetting" mid-response).
  static String _langInstruction(String locale) {
    switch (locale) {
      case 'uz':
        return "MUHIM: Barcha vazifa nomlarini (\"title\" maydoni) FAQAT VA TO'LIQ "
            "O'ZBEK tilida yoz. Ingliz tilida birorta ham so'z ishlatma.";
      case 'ru':
        return 'ВАЖНО: Все названия задач (поле "title") пиши ТОЛЬКО И ПОЛНОСТЬЮ '
            'на русском языке. Не используй ни одного английского слова.';
      default:
        return 'IMPORTANT: Write all task titles (the "title" field) ONLY in English.';
    }
  }

  String _buildPrompt({
    required String goalText,
    required String focusType,
    required DateTime startDate,
    required int days,
    required Map<String, List<Map<String, String>>> busyTimesByDay,
    required Map<String, String> userContext,
    required String langInstruction,
  }) {
    // Build per-day busy time text.
    String busyText;
    if (busyTimesByDay.isEmpty) {
      busyText = 'none';
    } else {
      final lines = <String>[];
      for (final entry in busyTimesByDay.entries) {
        final times = entry.value.isEmpty
            ? 'none'
            : entry.value
                .map((b) => '${b['start']}-${b['end']}')
                .join(', ');
        lines.add('  ${entry.key}: $times');
      }
      busyText = lines.join('\n');
    }

    // Build user context block.
    final contextLines = <String>[];
    if (userContext.isNotEmpty) {
      contextLines.add(
        'User profile context — personalise the plan based on this:',
      );
      for (final e in userContext.entries) {
        contextLines.add('- ${e.key}: ${e.value}');
      }
      contextLines.add(
        'Reference the streak or stated goal in your reasoning where relevant.',
      );
    }

    final startIso = _isoDate(startDate);
    final lastIso = _isoDate(startDate.add(Duration(days: days - 1)));
    final multiDay = days > 1;
    return [
      // ── Language enforcement (repeated at the top AND bottom so the model
      // cannot "forget" it in a long response) ──
      langInstruction,
      '',
      'You are Flowa, a calm productivity planner.',
      multiDay
          ? "Turn the user's goal(s) into a realistic, gentle schedule spread "
                'across $days consecutive days.'
          : "Turn the user's goal(s) into a realistic, gentle schedule for a "
                'single day.',
      '',
      if (contextLines.isNotEmpty) ...contextLines,
      if (contextLines.isNotEmpty) '',
      'Start date: $startIso (ISO yyyy-mm-dd)',
      if (multiDay) 'Plan EVERY day from $startIso to $lastIso ($days days).',
      'Primary focus type: $focusType',
      if (busyTimesByDay.isEmpty)
        'Busy ranges to avoid (24h): none'
      else ...[
        'Busy ranges to avoid per day (24h):',
        busyText,
      ],
      '',
      'User\'s goals: "$goalText"',
      '',
      'FREQUENCY & TIMING RULES (IMPORTANT):',
      '- Read the user\'s goal text carefully and determine how often each '
          'goal should be done (e.g. "every day" = daily, "3 times a week" = '
          '3 sessions per week, "twice a day" = 2 sessions per day).',
      '- If the user explicitly states a frequency (e.g. "every day", '
          '"haftada 3 marta", "каждый день"), USE that exact frequency.',
      '- If no frequency is stated, choose a sensible default that fits the '
          'goal (e.g. reading a book → once daily; exercise → 3-4 times/week). '
          'In the "reasoning" field, briefly explain why you chose that '
          'frequency (e.g. "Daily reading builds a consistent habit").',
      '- Do NOT add extra repetitions beyond what makes sense for the goal.',
      '',
      'GENERAL RULES:',
      '- The input may contain SEVERAL goals (separated by "and", commas, new '
          'lines, or sentences). Plan EACH goal SEPARATELY, then merge all '
          'tasks into one combined schedule.',
      '- For each goal: split a quantity over its span into even chunks (e.g. '
          '"100 words in 10 days" → ~10 words/day); for a recurring goal (e.g. '
          '"run 3 times a week"), schedule that many sessions spread across the '
          'week(s); a goal with no span belongs on the start day.',
      '- Each task title MUST name which goal it serves (e.g. "Vocabulary: 10 '
          'words", "Read 25 pages", "Run").',
      if (multiDay) ...[
        '- Spread tasks across the days from $startIso to $lastIso (each within '
            'that goal\'s own span). Do NOT pile everything onto the first day.',
        '- Give each day a sensible number of tasks, with '
            'short restful breaks.',
        '- Every task MUST set "date" to its own day (ISO yyyy-mm-dd) within '
            '$startIso..$lastIso.',
      ] else ...[
        '- All tasks are dated $startIso.',
        '- Add short restful/wellness breaks between intense tasks.',
      ],
      '- NEVER overlap two tasks at the same time on the same day, and avoid the '
          'busy ranges; leave gaps between tasks.',
      '- category MUST be one of: ${_allowedCategories.join(', ')}.',
      '- startTime is 24-hour HH:mm. durationMinutes is an integer 10-180.',
      '- Order tasks by date, then startTime.',
      '- "reasoning" field: write exactly 1 short sentence (max 15 words) in '
          'the same language as the task title, explaining WHY this task is '
          'placed at this specific time or why the frequency was chosen. Be '
          'personal — mention the user\'s streak, goal, or focus style when '
          'relevant (e.g. "Morning sharpness suits your study streak", '
          '"Placed before lunch for peak cognitive energy").',
      'Return ONLY a JSON array of objects with keys:',
      'title, category, date, startTime, durationMinutes, reasoning.',
      '',
      // ── Repeat the language instruction at the end to reinforce it ──
      langInstruction,
    ].join('\n');
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _isoDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

final aiPlannerServiceProvider = Provider<AiPlannerService>(
  (ref) => AiPlannerService(http.Client()),
);
