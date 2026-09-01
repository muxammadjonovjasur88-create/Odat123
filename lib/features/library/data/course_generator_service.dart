import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/firebase_providers.dart';
import '../domain/models/book.dart';
import '../domain/models/interactive_course.dart';

final courseGeneratorServiceProvider = Provider<CourseGeneratorService>((ref) {
  return CourseGeneratorService(
    http.Client(),
    ref.watch(firestoreProvider),
  );
});

class CourseGeneratorService {
  CourseGeneratorService(this._client, this._db);

  final http.Client _client;
  final FirebaseFirestore _db;

  static const _defaultOpenAiModel = 'gpt-4o-mini';

  Future<String> _resolveApiKey() async {
    const envKey = String.fromEnvironment('OPENAI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    try {
      final doc = await _db.collection('system_config').doc('ai').get().timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final key = doc.data()?['apiKey'] as String?;
        if (key != null && key.isNotEmpty) return key;
      }
    } catch (_) {}
    return '';
  }

  /// Generates or fetches an interactive course for the given book
  Future<InteractiveCourse> getOrGenerateCourse(Book book, String userId) async {
    final docRef = _db.collection('books').doc(book.id).collection('courses').doc(userId);

    try {
      final snap = await docRef.get();
      if (snap.exists && snap.data() != null) {
        return InteractiveCourse.fromMap(snap.id, snap.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching existing course: $e');
    }

    // Generate new interactive course
    final generated = await _generateWithAi(book);

    try {
      await docRef.set(generated.toMap());
    } catch (e) {
      debugPrint('⚠️ Error saving generated course: $e');
    }

    return generated;
  }

  /// Updates lesson completion or exam score
  Future<void> updateCourseProgress({
    required String bookId,
    required String userId,
    required InteractiveCourse course,
  }) async {
    final docRef = _db.collection('books').doc(bookId).collection('courses').doc(userId);
    try {
      await docRef.set(course.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error updating course progress: $e');
    }
  }

  /// Generates or fetches an interactive course for a custom topic or user book title
  Future<InteractiveCourse> getOrGenerateCustomCourse(String topicOrTitle, String userId) async {
    final cleanId = topicOrTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final docRef = _db.collection('custom_courses').doc('${userId}_$cleanId');

    try {
      final snap = await docRef.get();
      if (snap.exists && snap.data() != null) {
        return InteractiveCourse.fromMap(snap.id, snap.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching existing custom course: $e');
    }

    final fakeBook = Book(
      id: 'custom_$cleanId',
      title: topicOrTitle,
      author: 'AI Ilmiy Murabbiy',
      category: 'Interaktiv Kurs',
      description: '$topicOrTitle mavzusi bo‘yicha to‘liq AI interaktiv ta‘lim kursi.',
      coverImageUrl: '',
      pdfUrl: '',
      totalPages: 100,
    );

    final generated = await _generateWithAi(fakeBook);

    try {
      await docRef.set(generated.toMap());
    } catch (e) {
      debugPrint('⚠️ Error saving custom course: $e');
    }

    return generated;
  }

  Future<InteractiveCourse> _generateWithAi(Book book) async {
    final prompt = '''
Siz ta'lim va shaxsiy rivojlanish bo'yicha eng ilg'or AI metodistsiz.
Quyidagi kitob yoki mavzu asosida to'liq interaktiv kurs yarating:
Kitob/Mavzu nomi: "${book.title}"
Muallif: "${book.author}"
Tavsif: "${book.description}"

Talablar:
1. Kitobni 3 ta mukammal bob/darsga (lessons) bo'ling.
2. Har bir darsda quyidagilar bo'lsin:
   - title: Dars mavzusi
   - content: 3-4 xatboshidan iborat, kitobning asosiy g'oyasini chuqur, qiziqarli va ravon tushuntiruvchi dars matni (O'zbek tilida).
   - practicalExercise: O'quvchi hayotida bugunoq qo'llashi mumkin bo'lgan aniq amaliy mashq/topshiriq.
   - quizQuestions: Darsni to'liq mustahkamlash uchun 3 ta sifatli test savoli (har birida questionText, options (4 ta variant), correctIndex (0-3), explanation).
3. Butun kitob/mavzu bo'yicha 5 ta keng qamrovli test savolidan iborat yakuniy imtihon (finalExam).

Javobingizni FAQAT toza JSON formatida quyidagi strukturada qaytaring:
{
  "lessons": [
    {
      "id": "lesson_1",
      "index": 0,
      "title": "...",
      "content": "...",
      "practicalExercise": "...",
      "quizQuestions": [
        {
          "questionText": "...",
          "options": ["A", "B", "C", "D"],
          "correctIndex": 0,
          "explanation": "..."
        }
      ]
    }
  ],
  "finalExam": [
    {
      "questionText": "...",
      "options": ["A", "B", "C", "D"],
      "correctIndex": 0,
      "explanation": "..."
    }
  ]
}
''';

    try {
      final apiKey = await _resolveApiKey();
      final response = await _client.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _defaultOpenAiModel,
          'messages': [
            {'role': 'system', 'content': 'You are a JSON-only response bot.'},
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final contentStr = decoded['choices'][0]['message']['content'] as String;
        final jsonResult = jsonDecode(contentStr) as Map<String, dynamic>;

        final lessonsData = (jsonResult['lessons'] as List<dynamic>? ?? []);
        final finalExamData = (jsonResult['finalExam'] as List<dynamic>? ?? []);

        final lessons = lessonsData.map((l) => CourseLesson.fromMap(Map<String, dynamic>.from(l as Map))).toList();
        final finalExam = finalExamData.map((q) => CourseQuestion.fromMap(Map<String, dynamic>.from(q as Map))).toList();

        return InteractiveCourse(
          id: 'course_${book.id}',
          bookId: book.id,
          title: book.title,
          author: book.author,
          category: book.category,
          totalLessons: lessons.length,
          rewardPoints: 200 + (lessons.length * 50),
          lessons: lessons,
          finalExam: finalExam,
          isCompleted: false,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ AI Course Generation API failed, using structured template: $e');
    }

    return _createFallbackCourse(book);
  }

  InteractiveCourse _createFallbackCourse(Book book) {
    return InteractiveCourse(
      id: 'course_${book.id}',
      bookId: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      totalLessons: 3,
      rewardPoints: 350,
      lessons: [
        CourseLesson(
          id: 'lesson_1',
          index: 0,
          title: '1-Dars: Asosiy Tamoyil va Falsafa',
          content:
              'Ushbu kitobning birinchi darsi muvaffaqiyat va shaxsiy rivojlanishning poydevori haqida. Har qanday buyuk natija fikrlash tarzini o\'zgartirish va ichki intizomni shakllantirishdan boshlanadi. Inson o\'z oldiga qo\'ygan maqsadini aniq tasavvur qilgandagina unga intilish uchun energiya topadi.',
          practicalExercise:
              'Daftaringizga kitobdan o\'rgangan 3 ta eng muhim g\'oyani yozing va bugun ulardan birini hayotingizda qo\'llang.',
          quizQuestions: const [
            CourseQuestion(
              questionText: 'Kitobdagi birinchi asosiy qadam nima deb ta\'kidlanadi?',
              options: [
                'Fikrlash tarzi va intizomni yo\'lga qo\'yish',
                'Hech narsa qilmasdan kutish',
                'Faqat boshqalarga tayanib yashash',
                'Maqsadlarsiz ish boshlash'
              ],
              correctIndex: 0,
              explanation: 'Muvaffaqiyat poydevori shaxsiy intizom va ongli fikrlashdan boshlanadi.',
            ),
            CourseQuestion(
              questionText: 'Natijaga erishish uchun eng muhim vosita nima?',
              options: [
                'Tasodifiy omad',
                'Doimiy va uzluksiz harakat',
                'Kechikib boshlash',
                'Rejasiz yondashuv'
              ],
              correctIndex: 1,
              explanation: 'Doimiy va uzluksiz harakat har qanday to\'siqni yengadi.',
            ),
          ],
        ),
        CourseLesson(
          id: 'lesson_2',
          index: 1,
          title: '2-Dars: Odatlar va Samarali Tizim Yaratish',
          content:
              'Ikkinchi darsda odatlarning kuchi o\'rganiladi. Katta g\'alabalar bir kunda emas, har kuni takrorlanadigan kichik odatlar orqali qo\'lga kiritiladi. Agar tizimingiz to\'g\'ri yo\'lga qo\'yilgan bo\'lsa, natija o\'z-o\'zidan keladi.',
          practicalExercise:
              'Ertangi kuningiz uchun 2 ta foydali mikro-odatni belgilang (masalan: 10 daqiqa kitob o\'qish yoki 20 ta mashq).',
          quizQuestions: const [
            CourseQuestion(
              questionText: 'Odatlar inson hayotiga qanday ta\'sir qiladi?',
              options: [
                'Uzoq muddatda ulkan natijalar yaratadi',
                'Hech qanday ta\'sir ko\'rsatmaydi',
                'Faqat vaqtni oladi',
                'Tezda yo\'qolib ketadi'
              ],
              correctIndex: 0,
              explanation: 'Kichik kundalik odatlar uzoq muddatda eksponensial natija beradi.',
            ),
          ],
        ),
        CourseLesson(
          id: 'lesson_3',
          index: 2,
          title: '3-Dars: To\'siqlarni Yengish va Liderlik',
          content:
              'Uchinchi dars inqirozlar va qiyinchiliklar paytida tushkunlikka tushmaslikni o\'rgatadi. Har bir xato — bu yangi tajriba va o\'sish imkoniyati. Qat\'iyatli insonlar xatolardan saboq olib, oldinga intilishda davom etadilar.',
          practicalExercise:
              'Oxirgi paytlarda sizni to\'xtatib turgan 1 ta qo\'rquv yoki to\'siqni aniqlang va uni yengish uchun birinchi qadamni yozing.',
          quizQuestions: const [
            CourseQuestion(
              questionText: 'Xatolar va to\'siqlarga qanday qarash kerak?',
              options: [
                'O\'sish va saboq olish imkoniyati sifatida',
                'Umidni butunlay uzish belgisi',
                'Boshqalarni ayblash sababi',
                'Harakatni to\'xtatish signali'
              ],
              correctIndex: 0,
              explanation: 'Xatolar tajriba beradi va o\'sish poydevoriga aylanadi.',
            ),
          ],
        ),
      ],
      finalExam: const [
        CourseQuestion(
          questionText: 'Kitobning bosh maqsadi nima?',
          options: [
                'Insonni ongli ravishda rivojlanishga va maqsadga erishishga ilhomlantirish',
                'Vaqtni behuda sarflash',
                'Faqat nazariyani o\'rgatish',
                'Boshqalardan ortda qolish'
              ],
          correctIndex: 0,
          explanation: 'Kitob insonning ichki salohiyatini ochishga qaratilgan.',
        ),
        CourseQuestion(
          questionText: 'Muvaffaqiyatli insonlarning asosiy farqi nimada?',
          options: [
                'Qat\'iyat va doimiy o\'rganishga intilish',
                'Tez taslim bo\'lish',
                'Boshqalardan shikoyat qilish',
                'Dangasalik'
              ],
          correctIndex: 0,
          explanation: 'Doimiy o\'rganish va qat\'iyat asosiy farqdir.',
        ),
        CourseQuestion(
          questionText: 'O\'rganilgan bilimlarni qanday qilib foydaga aylantirish mumkin?',
          options: [
                'Amalda muntazam qo\'llash orqali',
                'Faqat eslab qolish orqali',
                'Hech kimga aytmasdan yashirish orqali',
                'Unutib yuborish orqali'
              ],
          correctIndex: 0,
          explanation: 'Amaliyotsiz bilim foydasizdir.',
        ),
      ],
      isCompleted: false,
      createdAt: DateTime.now(),
    );
  }
}
