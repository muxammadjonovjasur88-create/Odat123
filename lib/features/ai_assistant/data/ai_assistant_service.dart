import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/task.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/utils/ai_date_parser.dart';
import '../domain/models/ai_chat_message.dart';

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return AiAssistantService(
    http.Client(),
    ref.watch(firestoreProvider),
  );
});

class AiAssistantService {
  AiAssistantService(this._client, this._db);

  final http.Client _client;
  final FirebaseFirestore _db;

  static const _defaultOpenAiApiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const _defaultOpenAiModel = 'gpt-4o-mini';

  static const _memoryBoxName = 'odat_ai_memory';

  /// In-memory cache for dynamic Firestore AI settings
  static String? _cachedApiKey;
  static String? _cachedModel;
  static DateTime? _cacheExpiry;

  /// Resolves the active OpenAI API key and model dynamically from Firestore `system_config/ai`.
  /// If Firestore has a new key, it uses it immediately without requiring an APK rebuild.
  Future<Map<String, String>> _resolveApiConfig() async {
    final now = DateTime.now();
    if (_cachedApiKey != null && _cacheExpiry != null && now.isBefore(_cacheExpiry!)) {
      return {
        'apiKey': _cachedApiKey!,
        'model': _cachedModel ?? _defaultOpenAiModel,
      };
    }

    try {
      final doc = await _db.collection('system_config').doc('ai').get().timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = doc.data();
        final remoteKey = data?['apiKey'] as String?;
        final remoteModel = data?['model'] as String?;
        if (remoteKey != null && remoteKey.trim().isNotEmpty) {
          _cachedApiKey = remoteKey.trim();
          _cachedModel = (remoteModel != null && remoteModel.trim().isNotEmpty) ? remoteModel.trim() : _defaultOpenAiModel;
          _cacheExpiry = now.add(const Duration(minutes: 10));
          return {
            'apiKey': _cachedApiKey!,
            'model': _cachedModel!,
          };
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [AI Config Resolver] Using default OpenAI key: $e');
    }

    _cachedApiKey = _defaultOpenAiApiKey;
    _cachedModel = _defaultOpenAiModel;
    _cacheExpiry = now.add(const Duration(minutes: 5));
    return {
      'apiKey': _cachedApiKey!,
      'model': _cachedModel!,
    };
  }

  /// Voice limits per day based on tier
  static const int kFreeVoiceLimit = 5;
  static const int kStandardVoiceLimit = 15;

  /// Gets current voice message count for today
  int getTodayVoiceCount() {
    try {
      final box = Hive.box(_memoryBoxName);
      final todayKey = 'voice_count_${_getTodayKey()}';
      return (box.get(todayKey) as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Increments today's voice message count
  Future<void> incrementTodayVoiceCount() async {
    try {
      final box = Hive.isBoxOpen(_memoryBoxName)
          ? Hive.box(_memoryBoxName)
          : await Hive.openBox(_memoryBoxName);
      final todayKey = 'voice_count_${_getTodayKey()}';
      final current = (box.get(todayKey) as int?) ?? 0;
      await box.put(todayKey, current + 1);
    } catch (e) {
      debugPrint('⚠️ Error incrementing voice count: $e');
    }
  }

  /// Checks if user is eligible to send a voice message
  bool canSendVoiceMessage(UserProfile? profile) {
    if (profile == null) return true;
    if (profile.isPremium) return true; // Unlimited for Pro

    final count = getTodayVoiceCount();
    return count < kFreeVoiceLimit;
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  /// Returns saved user long-term memory (interests, goals, books, workouts)
  List<String> getSavedInterests() {
    try {
      final box = Hive.isBoxOpen(_memoryBoxName) ? Hive.box(_memoryBoxName) : null;
      final raw = box?.get('user_interests') as List<dynamic>?;
      if (raw != null) {
        return raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Updates user interests in local memory
  Future<void> addInterest(String interest) async {
    try {
      final box = Hive.isBoxOpen(_memoryBoxName)
          ? Hive.box(_memoryBoxName)
          : await Hive.openBox(_memoryBoxName);
      final current = (box.get('user_interests') as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      if (!current.contains(interest)) {
        current.add(interest);
        if (current.length > 25) current.removeAt(0);
        await box.put('user_interests', current);
      }
    } catch (e) {
      debugPrint('⚠️ Error saving interest: $e');
    }
  }

  /// Saves a message to Firestore under users/{uid}/ai_messages
  Future<void> saveMessageToFirestore(String uid, AiChatMessage msg) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('ai_messages')
          .doc(msg.id)
          .set({
        'id': msg.id,
        'text': msg.text,
        'isUser': msg.isUser,
        'timestamp': Timestamp.fromDate(msg.timestamp),
        'isVoice': msg.isVoice,
        'suggestedTasks': msg.suggestedTasks.map((t) => t.toMap()).toList(),
        'imageBase64': msg.imageBase64,
      });
    } catch (e) {
      debugPrint('⚠️ Error saving AI message to Firestore: $e');
    }
  }

  /// Loads previous messages from the last 7 days and purges older messages
  Future<List<AiChatMessage>> loadWeeklyMessages(String uid) async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('ai_messages')
          .orderBy('timestamp', descending: false)
          .get();

      final List<AiChatMessage> messages = [];
      final batch = _db.batch();
      bool hasExpired = false;

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['timestamp'];
        final date = ts is Timestamp ? ts.toDate() : DateTime.now();

        if (date.isBefore(oneWeekAgo)) {
          batch.delete(doc.reference);
          hasExpired = true;
        } else {
          final tasksRaw = data['suggestedTasks'] as List<dynamic>? ?? [];
          final tasks = tasksRaw
              .map((e) => AiSuggestedTask.fromMap(e as Map<String, dynamic>))
              .toList();

          messages.add(AiChatMessage(
            id: doc.id,
            text: (data['text'] as String?) ?? '',
            isUser: (data['isUser'] as bool?) ?? false,
            timestamp: date,
            isVoice: (data['isVoice'] as bool?) ?? false,
            suggestedTasks: tasks,
            imageBase64: data['imageBase64'] as String?,
          ));
        }
      }

      if (hasExpired) {
        await batch.commit();
      }

      return messages;
    } catch (e) {
      debugPrint('⚠️ Error loading AI history: $e');
      return [];
    }
  }

  Future<AiChatMessage> processMessage({
    required String userText,
    required List<Task> todayTasks,
    UserProfile? profile,
    bool isVoice = false,
    String languageCode = 'uz',
    List<AiChatMessage>? previousMessages,
    String? userImageBase64,
  }) async {
    final isRu = languageCode == 'ru';
    final isEn = languageCode == 'en';

    int totalBooksRead = 0;
    int totalBooksInProgress = 0;
    if (profile != null) {
      try {
        final progressSnap = await _db
            .collection('users')
            .doc(profile.uid)
            .collection('book_progress')
            .get()
            .timeout(const Duration(seconds: 3));
        for (final d in progressSnap.docs) {
          final data = d.data();
          final isCompleted = data['isCompleted'] as bool? ?? false;
          final lastRead = (data['lastPageRead'] as num? ?? 0).toInt();
          if (isCompleted) {
            totalBooksRead++;
          } else if (lastRead > 0) {
            totalBooksInProgress++;
          }
        }
      } catch (_) {}
    }

    if (isVoice) {
      if (!canSendVoiceMessage(profile)) {
        final count = getTodayVoiceCount();
        return AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: isRu
              ? '⚠️ Ваш лимит бесплатных голосовых сообщений на сегодня ($count/$kFreeVoiceLimit) исчерпан. Вы можете писать текстовые сообщения! 🎙️✨'
              : (isEn
                  ? '⚠️ Your daily free voice message limit ($count/$kFreeVoiceLimit) has been reached. Feel free to send text messages! 🎙️✨'
                  : '⚠️ Bugungi bepul ovozli xabarlar limitingiz ($count/$kFreeVoiceLimit) tugadi. Matnli xabar orqali bemalol yozishingiz mumkin! 🎙️✨'),
          isUser: false,
          timestamp: DateTime.now(),
          isVoice: false,
        );
      }
      await incrementTodayVoiceCount();
    }

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final tasksContext = todayTasks.isEmpty
        ? (isRu
            ? 'На сегодня еще нет запланированных задач.'
            : (isEn
                ? 'No scheduled tasks for today yet.'
                : 'Bugun uchun rejalashtirilgan vazifalar hali yo‘q.'))
        : todayTasks.map((t) {
            final h = (t.startMinute ~/ 60).toString().padLeft(2, '0');
            final m = (t.startMinute % 60).toString().padLeft(2, '0');
            final timeStr = '$h:$m';
            return '- "${t.title}" ($timeStr, ${t.durationMinutes} min, status: ${t.isCompleted ? "Completed" : "Pending"})';
          }).join('\n');

    final memoryInterests = getSavedInterests();
    final memoryContext = memoryInterests.isEmpty
        ? (isRu
            ? 'Интересы пользователя еще формируются.'
            : (isEn
                ? 'User interests are still forming.'
                : 'Foydalanuvchi qiziqishlari hali shakllanmagan.'))
        : (isRu
            ? 'Интересы пользователя: ${memoryInterests.join(", ")}.'
            : (isEn
                ? 'User interests: ${memoryInterests.join(", ")}.'
                : 'Foydalanuvchi qiziqishlari: ${memoryInterests.join(", ")}.'));

    final userName = profile?.displayName ?? profile?.name ?? (isRu ? 'Foydalanuvchi' : (isEn ? 'Friend' : 'Do‘stim'));
    final userGoal = profile?.goalTitle ?? (isRu ? 'Эффективные привычки и дисциплина' : (isEn ? 'Effective habits and discipline' : 'Samarali odatlar va intizom'));
    final totalPoints = profile?.totalPoints ?? 0;
    final weeklyPoints = profile?.weeklyPoints ?? 0;
    final fenixCoins = profile?.fenixCoins ?? 0;
    final streakDays = profile?.streak ?? 0;

    final String systemInstruction;
    if (isRu) {
      systemInstruction = '''
Вы — персональный умный тренер и ИИ-помощник приложения ODAT (ODAT AI Coach & Smart Planner).
Данные пользователя:
- Имя: $userName
- Главная цель: $userGoal
- Всего баллов (PTS): $totalPoints PTS
- Баллы за неделю: $weeklyPoints PTS
- Fenix Coins: $fenixCoins
- Серия активности (streak): $streakDays дней
- Общее время фокуса: ${profile?.totalFocusMinutes ?? 0} минут
- Время фокуса за неделю: ${profile?.weeklyFocusMinutes ?? 0} минут
- Время фокуса за месяц: ${profile?.monthlyFocusMinutes ?? 0} минут
- Глубокие сессии фокуса: ${profile?.totalDeepSessions ?? 0} сессий
- Общая дистанция бега: ${(profile?.totalRunningKm ?? 0.0).toStringAsFixed(2)} км
- Прочитано книг: $totalBooksRead, В процессе чтения: $totalBooksInProgress
- Побед в битвах: ${profile?.battleWins ?? 0}, Поражений: ${profile?.battleLosses ?? 0} (Процент побед: ${profile?.winratePercent ?? 0}%)
$memoryContext

Текущая дата: $todayStr (Завтра: $tomorrowStr). Время: $currentTimeStr.
Задачи на сегодня:
$tasksContext

ПРАВИЛА И 4 ОСНОВНЫХ НАПРАВЛЕНИЯ:
1. 🧠 AI → Real Action (Напоминания и привычки):
   - Если пользователь просит напомнить (напр. "Напомни завтра в 8:00 урок" или "Каждый день в 22:00 напоминай читать книгу"):
     Создайте блок ```tasks``` с полями title, date (YYYY-MM-DD), time (HH:mm), durationMinutes, focusType ("study"|"sport"|"pomodoro"|"custom"), repeatType ("once"|"daily"|"weekly"), isReminder (true).
     ВАЖНО: Если пользователь говорит "завтра", обязательно используйте date: "$tomorrowStr".
2. 📅 AI Planner (Планирование):
   - Если пользователь просит составить расписание (напр. "У меня есть 4 часа, нужно сделать C++, English и спорт"):
     Разбейте время на логичные блоки задач и верните массив задач в блоке ```tasks```! 
     ОБЯЗАТЕЛЬНО: Если речь о тренировке, спорте или упражнениях, устанавливайте goalType: "exercise" и focusType: "sport"!
3. 💬 AI Personal Coach (Коучинг):
   - При вопросах о прокрастинации, тайм-менеджменте, мотивации дайте краткий практичный совет и предложите 1 конкретное действие (задачу) в блоке ```tasks```.
4. 📊 AI Progress & Weekly Review:
   - При запросе анализа недели покажите процент выполнения, самую слабую привычку и 1 четкую рекомендацию на следующую неделю.

ФОРМАТ БЛОКА ЗАДАЧ (генерируйте ТОЛЬКО когда требуется действие/план/напоминание):
```tasks
[
  {
    "title": "Название задачи",
    "date": "$todayStr",
    "time": "18:00",
    "durationMinutes": 60,
    "focusType": "study",
    "goalType": "focus",
    "repeatType": "once",
    "isReminder": true,
    "notifyBefore10Min": true
  }
]
```
''';
    } else if (isEn) {
      systemInstruction = '''
You are the personal AI Coach & Smart Planner for the ODAT productivity app.
User Profile:
- Name: $userName
- Primary Goal: $userGoal
- Total Points (PTS): $totalPoints PTS
- Weekly Points: $weeklyPoints PTS
- Fenix Coins: $fenixCoins
- Active Streak: $streakDays days
- Total Focus Time: ${profile?.totalFocusMinutes ?? 0} minutes
- Weekly Focus Time: ${profile?.weeklyFocusMinutes ?? 0} minutes
- Monthly Focus Time: ${profile?.monthlyFocusMinutes ?? 0} minutes
- Deep Focus Sessions: ${profile?.totalDeepSessions ?? 0}
- Total Running Distance: ${(profile?.totalRunningKm ?? 0.0).toStringAsFixed(2)} km
- Books Read: $totalBooksRead, In Progress: $totalBooksInProgress
- Battle Record: ${profile?.battleWins ?? 0} Wins, ${profile?.battleLosses ?? 0} Losses (Winrate: ${profile?.winratePercent ?? 0}%)
$memoryContext

Current Date: $todayStr (Tomorrow: $tomorrowStr). Current Time: $currentTimeStr.
Today's Scheduled Tasks:
$tasksContext

CORE 4 PILLARS & RULES:
1. 🧠 AI → Real Action (Reminders & Habits):
   - If the user asks for reminders (e.g. "Remind me tomorrow at 8:00 class"):
     Create a ```tasks``` block with title, date (YYYY-MM-DD), time (HH:mm), durationMinutes, focusType, repeatType, isReminder (true).
     CRITICAL: If the user says "tomorrow", you MUST set date to "$tomorrowStr".
2. 📅 AI Planner (Smart Scheduling):
   - If the user asks for a daily plan (e.g. "I have 4 hours to learn C++, English, and hit the gym"):
     Distribute the available time logically and return the sequence of tasks in a ```tasks``` block!
     CRITICAL: If the task is related to physical exercise, sports, or workouts, you MUST set goalType: "exercise" and focusType: "sport"!
3. 💬 AI Personal Coach (Actionable Advice):
   - For queries about motivation, time management, or procrastination, give concise atomic habit advice and propose 1 immediate action task in the ```tasks``` block.
4. 📊 AI Progress & Weekly Review:
   - When asked for a review, analyze the user's statistics, completion percentage, weakest habit, and provide 1 concrete recommendation for next week.

TASK BLOCK FORMAT (Only generate when an action/reminder/plan is requested):
```tasks
[
  {
    "title": "Task title",
    "date": "$todayStr",
    "time": "18:00",
    "durationMinutes": 60,
    "focusType": "study",
    "goalType": "focus",
    "repeatType": "once",
    "isReminder": true,
    "notifyBefore10Min": true
  }
]
```
''';
    } else {
      systemInstruction = '''
Sen ODAT ilovasining shaxsiy aqlli murabbiyi va rejalashtiruvchisisan (ODAT AI Coach & Smart Planner).
Foydalanuvchi ma'lumotlari:
- Ismi: $userName
- Asosiy maqsadi: $userGoal
- Umumiy ballari (PTS): $totalPoints PTS
- Haftalik ballari: $weeklyPoints PTS
- Fenix Coins: $fenixCoins
- Kunlik streak: $streakDays kun
- Umumiy fokus vaqti: ${profile?.totalFocusMinutes ?? 0} daqiqa
- Haftalik fokus vaqti: ${profile?.weeklyFocusMinutes ?? 0} daqiqa
- Oylik fokus vaqti: ${profile?.monthlyFocusMinutes ?? 0} daqiqa
- Chuqur fokus seanslari: ${profile?.totalDeepSessions ?? 0} ta
- Umumiy yugurish masofasi: ${(profile?.totalRunningKm ?? 0.0).toStringAsFixed(2)} km
- Tugatilgan kitoblar: $totalBooksRead ta, O'qilayotgan kitoblar: $totalBooksInProgress ta
- Janglardagi g'alabalar: ${profile?.battleWins ?? 0} ta, mag'lubiyatlar: ${profile?.battleLosses ?? 0} ta (G'alabalar foizi: ${profile?.winratePercent ?? 0}%)
$memoryContext

Joriy sana: $todayStr (Ertangi sana: $tomorrowStr). Hozirgi vaqt: $currentTimeStr.
Bugungi vazifalar:
$tasksContext

SENING 4 TA ASOSIY VAZIFANG VA QOIDALAR:

1. 🧠 AI → Real Action (Eslatma, Vazifa va Odat yaratish):
   - "Ertaga 8:00 da darsni eslat" -> date: "$tomorrowStr", time: "08:00", isReminder: true.
   - "Har kuni 22:00 da kitob o‘qishni eslat" -> repeatType: "daily", goalType: "focus", time: "22:00".
   - QAT'IY QOIDA: Agar foydalanuvchi "Ertaga" desa, MUTLAQO "date": "$tomorrowStr" ni ishlating, aks holda vazifa kechagi kunga tushib qoladi!

2. 🎯 FAOLIYAT TURLARI (Fokus, Mashq, Zametka):
   - Har bir vazifani quyidagi 3 turdan biriga ajrat:
     1) 🎯 **Fokus** (goalType: "focus", focusType: "study") - Dars, ishlash, kitob o‘qish (hatto "eslat" so'zi ishtirok etsa ham!).
     2) 🏃 **Mashq** (goalType: "exercise", focusType: "sport") - Sport, yugurish, turnik, otjimaniya, zal (hatto "eslat" so'zi ishtirok etsa ham!).
     3) 📝 **Zametka** (goalType: "note", focusType: "custom") - Boshqa barcha oddiy eslatmalar (masalan: kimga qo'ng'iroq qilish, suv ichish).
   - QAT'IY QOIDA: Foydalanuvchi "eslatib qo'y" yoki "eslat" degan so'zni ishlatsa, uni darhol Zametka QILMANG! Agar vazifa sport haqida bo'lsa "exercise", dars haqida bo'lsa "focus" deb belgilang! Mashq, yugurish yoki sport tilga olinsa, MUTLAQO "goalType": "exercise" va "focusType": "sport" bo'lishi SHART!

3. 📅 AI Planner (Optimal Reja tuzish):
   - Foydalanuvchi qachon va qanday reja so‘rasa, mavjud vaqtni aniq taqsimlab, har kunlik, 2 kunda bir yoki 3 kunda bir variantlarni chiroyli tushuntir va ```tasks [ ... ]``` blokida barcha vazifalarni qaytar!

4. 💬 AI Personal Coach (Muammo va Motivatsiya):
   - "Vaqtimni boshqara olmayapman", "Telefonni ko'p ishlatyapman", "Motivatsiya yo'q" kabi holatlarda qisqa, tushunarli maslahat ber va 1 ta amaliy yechim vazifasini ```tasks``` blokida taklif qil.

MUHIM QOIDALAR:
- Javoblaring o'ta samimiy, do'stona, qisqa va amaliy bo'lsin.
- Oddiy salomlashish ("Salom", "Qalaysiz") yoki oddiy savollarda HECH QACHON ```tasks``` blokini ishlatma!
- Foydalanuvchi reja/eslatma so'raganida quyidagi formatda ```tasks [ ... ]``` blokini yarat:

```tasks
[
  {
    "title": "Vazifa nomi",
    "date": "$todayStr",
    "time": "18:00",
    "durationMinutes": 60,
    "focusType": "study",
    "goalType": "focus",
    "repeatType": "daily",
    "isReminder": true,
    "notifyBefore10Min": true
  }
]
```
''';
    }

    _recordAnalyticsTopic(userText, profile?.uid);

    final List<Map<String, dynamic>> conversationMessages = [
      {'role': 'system', 'content': systemInstruction},
    ];

    if (previousMessages != null && previousMessages.isNotEmpty) {
      final recent = previousMessages.length > 8
          ? previousMessages.sublist(previousMessages.length - 8)
          : previousMessages;
      for (final m in recent) {
        if (m.imageBase64 != null) {
          conversationMessages.add({
            'role': m.isUser ? 'user' : 'assistant',
            'content': [
              {'type': 'text', 'text': m.text},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,${m.imageBase64}',
                }
              }
            ],
          });
        } else {
          conversationMessages.add({
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.text,
          });
        }
      }
    }

    if (userImageBase64 != null) {
      conversationMessages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userText},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$userImageBase64',
            }
          }
        ],
      });
    } else {
      conversationMessages.add({'role': 'user', 'content': userText});
    }

    try {
      final apiConfig = await _resolveApiConfig();
      final apiKey = apiConfig['apiKey'] ?? _defaultOpenAiApiKey;
      final model = apiConfig['model'] ?? _defaultOpenAiModel;

      final response = await _client.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': conversationMessages,
          'temperature': 0.7,
          'max_tokens': 700,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('⚠️ [OpenAI API] error ${response.statusCode}: ${response.body}');
        return _generateLocalFallback(userText, todayTasks, isVoice);
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return _generateLocalFallback(userText, todayTasks, isVoice);
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final fullText = (message?['content'] as String?) ?? '';

      // Extract tasks if present in ```tasks ... ```
      final tasksRegex = RegExp(r'```tasks\s*([\s\S]*?)\s*```');
      final match = tasksRegex.firstMatch(fullText);
      final List<AiSuggestedTask> suggestedTasks = [];
      var cleanText = fullText;

      if (match != null) {
        cleanText = fullText.replaceAll(tasksRegex, '').trim();
        try {
          final tasksJson = jsonDecode(match.group(1)!) as List<dynamic>;
          final parsedDateInfo = AiDateParser.parse(userText);
          final defaultDateIso = '${parsedDateInfo.scheduledDateTime.year}-${parsedDateInfo.scheduledDateTime.month.toString().padLeft(2, '0')}-${parsedDateInfo.scheduledDateTime.day.toString().padLeft(2, '0')}';

          for (final item in tasksJson) {
            final taskMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
            taskMap['date'] ??= defaultDateIso;
            if (taskMap['repeatType'] == null && parsedDateInfo.isDaily) {
              taskMap['repeatType'] = 'daily';
            }
            suggestedTasks.add(AiSuggestedTask.fromMap(taskMap));
          }
        } catch (e) {
          debugPrint('⚠️ Tasks JSON parse error: $e');
        }
      }

      // Fallback NLP parser ONLY if user explicitly stated a direct scheduling command and AI omitted JSON
      if (suggestedTasks.isEmpty) {
        final parsed = AiDateParser.parse(userText);
        final lower = userText.toLowerCase();

        final isGreetingOrGeneric = lower.trim() == 'salom' ||
            lower.trim() == 'assalomu alaykum' ||
            lower.trim() == 'qalaysiz' ||
            lower.trim() == 'qalesiz' ||
            lower.trim() == 'qalesan' ||
            lower.trim() == 'privet' ||
            lower.trim() == 'привет' ||
            lower.trim() == 'здравствуйте' ||
            lower.trim() == 'hello' ||
            lower.trim() == 'hi' ||
            lower.trim() == 'rahmat' ||
            lower.trim() == 'спасибо' ||
            lower.trim() == 'thanks';

        if (!isGreetingOrGeneric && (parsed.hasExplicitTime || (parsed.hasIntent && parsed.hasExplicitDate))) {
          final title = parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : 'Rejalashtirilgan ish';
          final defaultDateIso = '${parsed.scheduledDateTime.year}-${parsed.scheduledDateTime.month.toString().padLeft(2, '0')}-${parsed.scheduledDateTime.day.toString().padLeft(2, '0')}';
          final hourStr = parsed.scheduledDateTime.hour.toString().padLeft(2, '0');
          final minStr = parsed.scheduledDateTime.minute.toString().padLeft(2, '0');

          suggestedTasks.add(AiSuggestedTask(
            title: title,
            dateStr: defaultDateIso,
            timeStr: '$hourStr:$minStr',
            durationMinutes: 60,
            focusType: (lower.contains('sport') || lower.contains('mashq') || lower.contains('yugur')) ? 'sport' : 'study',
            goalType: (lower.contains('sport') || lower.contains('mashq') || lower.contains('yugur')) ? 'exercise' : (lower.contains('eslatma') || lower.contains('telefon') ? 'note' : 'focus'),
            isReminder: true,
            repeatType: parsed.repeatType,
            notifyBefore1Hour: true,
            notifyBefore10Min: true,
          ));
        }
      }

      // Automatically remember key user interests
      _detectAndSaveInterests(userText);

      return AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: cleanText,
        isUser: false,
        timestamp: DateTime.now(),
        isVoice: isVoice,
        suggestedTasks: suggestedTasks,
      );
    } catch (e) {
      debugPrint('⚠️ [AI Assistant Service Error]: $e');
      return _generateLocalFallback(userText, todayTasks, isVoice);
    }
  }

  void _detectAndSaveInterests(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('kitob') || lower.contains('o\'qiyapman') || lower.contains('o‘qiyapman')) {
      addInterest('Kitob mutolaasi');
    }
    if (lower.contains('yugurish') || lower.contains('yugur')) {
      addInterest('Yugurish');
    }
    if (lower.contains('otjimaniye') || lower.contains('turnik') || lower.contains('mashq')) {
      addInterest('Sport mashqlari');
    }
    if (lower.contains('ingliz') || lower.contains('dasturlash') || lower.contains('kod')) {
      addInterest('Ta’lim & Ko‘nikma');
    }
  }

  Future<void> _recordAnalyticsTopic(String text, String? uid) async {
    try {
      final lower = text.toLowerCase();
      String category = 'general';
      if (lower.contains('kitob')) category = 'books';
      if (lower.contains('yugur') || lower.contains('mashq') || lower.contains('sport')) category = 'workout';
      if (lower.contains('reja') || lower.contains('fokus') || lower.contains('odat')) category = 'habits';

      await _db.collection('aiAnalytics').add({
        'query': text.length > 100 ? text.substring(0, 100) : text,
        'category': category,
        'uid': uid ?? 'anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  AiChatMessage _generateLocalFallback(String text, List<Task> tasks, bool isVoice) {
    final lower = text.toLowerCase();
    String reply = 'Sizga ODAT maqsadlaringiz va intizom bo‘yicha yordam berishdan mamnunman. Qanday rejangiz bor?';
    final List<AiSuggestedTask> fallbackTasks = [];

    final parsed = AiDateParser.parse(text);
    final isSport = lower.contains('mashq') || lower.contains('sport') || lower.contains('turnik') || lower.contains('otjimaniy') || lower.contains('yugur') || lower.contains('press') || lower.contains('zal');
    final isStudy = lower.contains('kitob') || lower.contains('dars') || lower.contains('fokus') || lower.contains('o‘qish') || lower.contains('o\'qish') || lower.contains('mutolaa') || lower.contains('ingliz');

    if (parsed.hasIntent || isSport || isStudy || parsed.repeatType != 'once' || parsed.hasExplicitTime || parsed.hasExplicitDate) {
      final hourStr = parsed.scheduledDateTime.hour.toString().padLeft(2, '0');
      final minStr = parsed.scheduledDateTime.minute.toString().padLeft(2, '0');
      final timeStr = parsed.hasExplicitTime ? '$hourStr:$minStr' : (isSport ? '18:00' : '09:00');
      final defaultDateIso = '${parsed.scheduledDateTime.year}-${parsed.scheduledDateTime.month.toString().padLeft(2, '0')}-${parsed.scheduledDateTime.day.toString().padLeft(2, '0')}';
      final title = parsed.cleanTitle.trim().isNotEmpty
          ? parsed.cleanTitle.trim()
          : (isSport ? 'Sport mashg‘uloti va intizom' : (isStudy ? 'Kitob mutolaasi va fokus' : 'Rejalashtirilgan vazifa'));

      String intervalText = '';
      if (parsed.repeatType == 'every_2_days') {
        intervalText = ' (har 2 kunda bir)';
      } else if (parsed.repeatType == 'every_3_days') {
        intervalText = ' (har 3 kunda bir)';
      } else if (parsed.repeatType == 'daily') {
        intervalText = ' (har kuni)';
      } else if (parsed.repeatType == 'weekly') {
        intervalText = ' (har hafta)';
      }

      reply = '✅ "$title" rejasi$intervalText soat $timeStr ga tayyorlandi va eslatmalarga muvaffaqiyatli saqlandi!';

      fallbackTasks.add(
        AiSuggestedTask(
          title: title,
          dateStr: defaultDateIso,
          timeStr: timeStr,
          durationMinutes: isSport ? 45 : 30,
          focusType: isSport ? 'sport' : (isStudy ? 'study' : 'custom'),
          goalType: isSport ? 'exercise' : (isStudy ? 'focus' : 'note'),
          repeatType: parsed.repeatType,
          isReminder: true,
          notifyBefore10Min: true,
        ),
      );
    } else if (lower.contains('jadval tuz') || lower.contains('reja tuz') || lower.contains('kunlik reja')) {
      reply = 'Siz uchun kunlik muvozanatli reja tayyorlandi va eslatmalarga qo‘shildi:';
      fallbackTasks.addAll([
        const AiSuggestedTask(title: 'Diqqat va Rejalashtirish', timeStr: '09:00', durationMinutes: 60, focusType: 'study', goalType: 'focus', repeatType: 'once', isReminder: true),
        const AiSuggestedTask(title: 'Chuqur Fokus (Kitob/Dars)', timeStr: '11:00', durationMinutes: 90, focusType: 'study', goalType: 'focus', repeatType: 'once', isReminder: true),
        const AiSuggestedTask(title: 'Jismoniy mashg‘ulot & Sport', timeStr: '18:00', durationMinutes: 60, focusType: 'sport', goalType: 'exercise', repeatType: 'once', isReminder: true),
      ]);
    }

    return AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: reply,
      isUser: false,
      timestamp: DateTime.now(),
      isVoice: isVoice,
      suggestedTasks: fallbackTasks,
    );
  }

  Future<String> generateParentAiConsultation({
    required String query,
    required String childName,
    required int disciplineScore,
    required int completedTasks,
    required int totalTasks,
    required int screenTime,
  }) async {
    final conf = await _resolveApiConfig();
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final prompt = '''
Siz "Odat Parents" ilovasida ota-onalar uchun sun'iy intellekt maslahatchisisiz.
Farzand ismi: $childName
Intizom balli: $disciplineScore / 100
Bajarilgan vazifalar: $completedTasks / $totalTasks
Bugungi ekran vaqti: $screenTime daqiqa.

Ota-onaning savoli/so'rovi: "$query"

Qisqa, aniq va motivatsion javob bering. O'zbek tilida (Lotin yozuvida) yozing. Kerak bo'lganda emoji ishlating.
Yolg'on faktlar to'qimang. Yuqoridagi haqiqiy statistikaga asoslaning.
''';

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer ${conf['apiKey']}',
        },
        body: jsonEncode({
          'model': conf['model'],
          'messages': [
            {'role': 'system', 'content': 'Sen ota-onalar uchun yordamchi AIsan. Faqat berilgan faktlar asosida maslahat berasan.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        return body['choices'][0]['message']['content'].toString().trim();
      }
      return 'Kechirasiz, AI xizmati bilan bog‘lanishda xatolik yuz berdi (${res.statusCode}).';
    } catch (e) {
      debugPrint('Parent AI error: $e');
      return 'Kechirasiz, AI tarmoq xatosi.';
    }
  }
}
