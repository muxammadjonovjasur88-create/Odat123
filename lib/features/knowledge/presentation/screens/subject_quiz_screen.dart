import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';



enum QuizDifficulty {
  easy(label: 'Oson', pts: 20, color: Color(0xFF3B9BFF), icon: Icons.sentiment_satisfied_alt_rounded),
  medium(label: 'O‘rta', pts: 40, color: Color(0xFFFFB703), icon: Icons.psychology_rounded),
  hard(label: 'Qiyin', pts: 80, color: Color(0xFFFF0055), icon: Icons.local_fire_department_rounded);

  const QuizDifficulty({
    required this.label,
    required this.pts,
    required this.color,
    required this.icon,
  });

  final String label;
  final int pts;
  final Color color;
  final IconData icon;
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class SubjectQuizScreen extends ConsumerStatefulWidget {
  const SubjectQuizScreen({super.key});

  @override
  ConsumerState<SubjectQuizScreen> createState() => _SubjectQuizScreenState();
}

class _SubjectQuizScreenState extends ConsumerState<SubjectQuizScreen> {
  // Age categories
  int _selectedAgeGroup = 2; // 0: 7-10 yosh, 1: 11-15 yosh, 2: 16+ yosh
  String _selectedSubject = 'Matematika & Mantiq';
  QuizDifficulty _selectedDifficulty = QuizDifficulty.easy;

  bool _isQuizActive = false;
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _answered = false;
  int _correctAnswersCount = 0;
  bool _quizFinished = false;

  Timer? _timer;
  int _secondsRemaining = 20;

  final Map<int, List<Map<String, dynamic>>> _subjectsByAge = {
    0: [
      {'name': 'Matematika & Hisob', 'icon': Icons.calculate_rounded, 'color': Color(0xFF5BC8FA)},
      {'name': 'Ona tili & Alifbo', 'icon': Icons.menu_book_rounded, 'color': Color(0xFF7B2FFF)},
      {'name': 'Mantiqiy Topishmoq', 'icon': Icons.lightbulb_rounded, 'color': Color(0xFFFFB703)},
      {'name': 'Ingliz tili (Kids)', 'icon': Icons.language_rounded, 'color': Color(0xFF3B9BFF)},
    ],
    1: [
      {'name': 'Matematika & Algebra', 'icon': Icons.functions_rounded, 'color': Color(0xFF5BC8FA)},
      {'name': 'Fizika & Tabiat', 'icon': Icons.science_rounded, 'color': Color(0xFFFF0055)},
      {'name': 'Tarix & Geografiya', 'icon': Icons.public_rounded, 'color': Color(0xFFFFB703)},
      {'name': 'Ingliz tili (Grammar)', 'icon': Icons.translate_rounded, 'color': Color(0xFF3B9BFF)},
      {'name': 'IT & Dasturlash Asoslari', 'icon': Icons.code_rounded, 'color': Color(0xFF7B2FFF)},
    ],
    2: [
      {'name': 'Matematika & Mantiq', 'icon': Icons.auto_awesome_rounded, 'color': Color(0xFF5BC8FA)},
      {'name': 'IELTS & Advanced English', 'icon': Icons.school_rounded, 'color': Color(0xFF3B9BFF)},
      {'name': 'IT, Flutter & Python', 'icon': Icons.terminal_rounded, 'color': Color(0xFF7B2FFF)},
      {'name': 'Jahon Tarixi & Moliya', 'icon': Icons.account_balance_rounded, 'color': Color(0xFFFFB703)},
      {'name': 'Tanqidiy Tafakkur & AI', 'icon': Icons.psychology_alt_rounded, 'color': Color(0xFFFF0055)},
    ],
  };

  List<QuizQuestion> _currentQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadUserAge();
  }

  void _loadUserAge() {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      // Defaults to 16+ or adjusts based on user
      _selectedAgeGroup = 2;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 20;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        if (!_answered) {
          _submitAnswer(-1); // Timed out
        }
      }
    });
  }

  List<QuizQuestion> _generateQuestions(int ageGroup, String subject, QuizDifficulty difficulty) {
    if (ageGroup == 0) {
      // 7-10 yosh
      if (difficulty == QuizDifficulty.easy) {
        return const [
          QuizQuestion(question: '7 + 8 necha bo‘ladi?', options: ['13', '14', '15', '16'], correctIndex: 2, explanation: '7 ga 8 qo‘shilsa 15 hosil bo‘ladi.'),
          QuizQuestion(question: 'Qaysi son juft son?', options: ['7', '9', '12', '15'], correctIndex: 2, explanation: '12 soni 2 ga qoldiqsiz bo‘linadi.'),
          QuizQuestion(question: '1 soatda necha daqiqa bor?', options: ['50', '60', '100', '24'], correctIndex: 1, explanation: '1 soat = 60 daqiqa.'),
          QuizQuestion(question: 'Alifboda birinchi harf qaysi?', options: ['B', 'A', 'D', 'O'], correctIndex: 1, explanation: 'O‘zbek alifbosi "A" harfidan boshlanadi.'),
          QuizQuestion(question: 'Kvadratning nechta tomoni bor?', options: ['3 ta', '4 ta', '5 ta', '6 ta'], correctIndex: 1, explanation: 'Kvadrat 4 ta teng tomonga ega.'),
        ];
      } else if (difficulty == QuizDifficulty.medium) {
        return const [
          QuizQuestion(question: '9 × 6 necha bo‘ladi?', options: ['45', '54', '56', '63'], correctIndex: 1, explanation: '9 × 6 = 54 karra jadvalidan olinadi.'),
          QuizQuestion(question: 'Qaysi faslda daraxtlar barg to‘kadi?', options: ['Bahor', 'Yoz', 'Kuz', 'Qish'], correctIndex: 2, explanation: 'Kuz faslida tabiatda xazonrezgi bo‘ladi.'),
          QuizQuestion(question: 'O‘zbekiston poytaxti qaysi shahar?', options: ['Samarqand', 'Buxoro', 'Toshkent', 'Navoiy'], correctIndex: 2, explanation: 'Toshkent — O‘zbekiston Respublikasi poytaxti.'),
          QuizQuestion(question: 'Ingliz tilida "Apple" nima degani?', options: ['Nok', 'Olma', 'Uzum', 'Anor'], correctIndex: 1, explanation: '"Apple" ingliz tilidan tarjima qilinganda "Olma" degan ma‘noni bildiradi.'),
          QuizQuestion(question: '100 dan 35 ni ayirsak necha qoladi?', options: ['55', '65', '75', '60'], correctIndex: 1, explanation: '100 - 35 = 65.'),
        ];
      } else {
        return const [
          QuizQuestion(question: 'Uchburchakning ichki burchaklari yig‘indisi necha gradus?', options: ['90°', '180°', '360°', '270°'], correctIndex: 1, explanation: 'Har qanday uchburchakning burchaklari yig‘indisi doimo 180° ga teng.'),
          QuizQuestion(question: 'Quyosh tizimidagi eng katta sayyora qaysi?', options: ['Mars', 'Yupiter', 'Venera', 'Saturn'], correctIndex: 1, explanation: 'Yupiter — Quyosh tizimidagi eng ulkan sayyora.'),
          QuizQuestion(question: '1 metrda necha santimetr bor?', options: ['10 cm', '100 cm', '1000 cm', '50 cm'], correctIndex: 1, explanation: '1 metr = 100 santimetr.'),
          QuizQuestion(question: 'Eng tez yuguruvchi quruqlik jonivori qaysi?', options: ['Sher', 'Gepard', 'Ot', 'Bo‘ri'], correctIndex: 1, explanation: 'Gepard soatiga 120 km gacha tezlikda yugura oladi.'),
          QuizQuestion(question: '12 × 12 necha bo‘ladi?', options: ['124', '144', '132', '154'], correctIndex: 1, explanation: '12 × 12 = 144.'),
        ];
      }
    } else if (ageGroup == 1) {
      // 11-15 yosh
      if (difficulty == QuizDifficulty.easy) {
        return const [
          QuizQuestion(question: 'Tenglamani yeching: 2x + 10 = 26. x = ?', options: ['6', '8', '10', '12'], correctIndex: 1, explanation: '2x = 16 => x = 8.'),
          QuizQuestion(question: 'Yorug‘lik tezligi vakuumda taxminan qancha?', options: ['300,000 km/s', '150,000 km/s', '3,000 km/s', '1,000 km/s'], correctIndex: 0, explanation: 'Yorug‘lik tezligi c ≈ 300 000 km/soniya.'),
          QuizQuestion(question: 'Amir Temur qaysi yilda tavallud topgan?', options: ['1336-yil', '1340-yil', '1370-yil', '1405-yil'], correctIndex: 0, explanation: 'Sohibqiron Amir Temur 1336-yil 9-aprelda Xo‘ja Ilg‘orda tug‘ilgan.'),
          QuizQuestion(question: 'Suvning kimyoviy formulasi qaysi?', options: ['CO2', 'H2O', 'NaCl', 'O2'], correctIndex: 1, explanation: 'Suv vodorod va kisloroddan tashkil topgan: H2O.'),
          QuizQuestion(question: 'Ingliz tilida "Book" so‘zining ko‘pligi qanday yoziladi?', options: ['Bookes', 'Books', 'Bookies', 'Booken'], correctIndex: 1, explanation: 'Otlar ko‘plikda -s qo‘shimchasini oladi: Books.'),
        ];
      } else if (difficulty == QuizDifficulty.medium) {
        return const [
          QuizQuestion(question: 'Pifagor teoremasi qaysi uchburchakka tegishli?', options: ['Teng tomonli', 'To‘g‘ri burchakli', 'O‘tmas burchakli', 'Teng yonli'], correctIndex: 1, explanation: 'a² + b² = c² to‘g‘ri burchakli uchburchak gipotenuzasi uchun o‘rinli.'),
          QuizQuestion(question: 'Kompyuter xotirasining eng kichik o‘lchov birligi nima?', options: ['Bayt', 'Bit', 'Kilobayt', 'Megabayt'], correctIndex: 1, explanation: 'Bit (0 yoki 1) raqamli xotiraning elementar birligi hisoblanadi.'),
          QuizQuestion(question: 'Dunyodagi eng chuqur ko‘l qaysi?', options: ['Kaspiy', 'Boykal', 'Viktoriya', 'Orol'], correctIndex: 1, explanation: 'Baykal ko‘li chuqurligi 1642 metrgacha yetadi.'),
          QuizQuestion(question: 'Alisher Navoiy qaysi asarlar to‘plami bilan mashhur?', options: ['Xamsa', 'Boburnoma', 'Qutadg‘u bilig', 'Devonu lug‘atit turk'], correctIndex: 0, explanation: 'Hazrat Navoiy besh dostondan iborat "Xamsa" yaratgan.'),
          QuizQuestion(question: 'O‘simliklar quyosh nuri orqali oziqlanish jarayoni nima deyiladi?', options: ['Transpiratsiya', 'Fotosintez', 'Diffuziya', 'Osmoz'], correctIndex: 1, explanation: 'Fotosintez orqali o‘simliklar xlorofill yordamida organik modda ishlab chiqaradi.'),
        ];
      } else {
        return const [
          QuizQuestion(question: 'Kvadrat tenglama ildizlari soni diskriminant D > 0 bo‘lsa nechta?', options: ['0 ta', '1 ta', '2 ta', 'Cheksiz'], correctIndex: 2, explanation: 'D > 0 bo‘lganda tenglama 2 ta haqiqiy ildizga ega.'),
          QuizQuestion(question: 'Nyutonning ikkinchi qonuni formulasi qaysi?', options: ['E = mc²', 'F = m·a', 'v = s/t', 'P = F/S'], correctIndex: 1, explanation: 'Kuch jism massasi va uning tezlanishi ko‘paytmasiga teng: F = ma.'),
          QuizQuestion(question: 'Python dasturlash tilida ro‘yxat (list) qanday qavs bilan ochiladi?', options: ['{}', '()', '[]', '<>'], correctIndex: 2, explanation: 'Pythonda massivlar to‘rtburchak [ ] qavslar bilan belgilanadi.'),
          QuizQuestion(question: 'Ipak yo‘li qaysi davlatlar orqali o‘tgan?', options: ['Xitoy - Markaziy Osiyo - Yevropa', 'Faqat Amerika', 'Avstraliya', 'Afrika janubi'], correctIndex: 0, explanation: 'Buyuk Ipak yo‘li Sharq va G‘arbni Markaziy Osiyo orqali bog‘lagan.'),
          QuizQuestion(question: 'Al-Xorazmiy qaysi fanning asoschisi hisoblanadi?', options: ['Algebra & Algoritm', 'Biologiya', 'Geologiya', 'Psixologiya'], correctIndex: 0, explanation: 'Muhammad al-Xorazmiy "Al-Jabr" asari bilan Algebra va algoritm faniga asos solgan.'),
        ];
      }
    } else {
      // 16+ yosh (Katta / Talaba)
      if (difficulty == QuizDifficulty.easy) {
        return const [
          QuizQuestion(question: 'Flutter freymvorki qaysi dasturlash tilida yozilgan?', options: ['JavaScript', 'Dart', 'Kotlin', 'Swift'], correctIndex: 1, explanation: 'Google Flutter ilovalari Dart tilida yaratiladi.'),
          QuizQuestion(question: 'O‘zbekiston Respublikasi Konstitutsiyasi ilk bor qaysi yilda qabul qilingan?', options: ['1991-yil', '1992-yil 8-dekabr', '1993-yil', '1995-yil'], correctIndex: 1, explanation: '1992-yil 8-dekabrda Bosh qomusimiz qabul qilingan.'),
          QuizQuestion(question: 'IELTS imtihonining eng yuqori maksimal balli qancha?', options: ['10.0', '9.0', '100', '120'], correctIndex: 1, explanation: 'IELTS shkalasi bo‘yicha eng yuqori daraja Band 9.0 hisoblanadi.'),
          QuizQuestion(question: 'Inflyatsiya nima?', options: ['Pul qadrsizlanishi va narxlar oshishi', 'Valyuta mustahkamlanishi', 'Soliqlar kamayishi', 'Ish haqi 2 barobar oshishi'], correctIndex: 0, explanation: 'Inflyatsiya — pul birligi xarid qobiliyatining pasayishi.'),
          QuizQuestion(question: 'Eng ko‘p tarqalgan relyatsion ma‘lumotlar bazasi tili qaysi?', options: ['HTML', 'SQL', 'CSS', 'JSON'], correctIndex: 1, explanation: 'SQL (Structured Query Language) jadvalli ma‘lumotlar bazasi bilan ishlash standarti.'),
        ];
      } else if (difficulty == QuizDifficulty.medium) {
        return const [
          QuizQuestion(question: 'Git tizimida yangi tarmoq (branch) yaratish buyrug‘i qaysi?', options: ['git push', 'git branch <nomi>', 'git commit', 'git pull'], correctIndex: 1, explanation: 'git branch <nomi> yoki git checkout -b yangi tarmoq ochadi.'),
          QuizQuestion(question: 'Murakkab foiz (Compound Interest) qoidasiga ko‘ra, 72 qoidasi nimani hisoblaydi?', options: ['Investitsiya 2 barobar ko‘payish muddatini', 'Soliq foizini', 'Kredit jarimasini', 'Valyuta kursini'], correctIndex: 0, explanation: '72 ni yillik daromad foiziga bo‘lsak, kapital necha yilda 2 baravar bo‘lishi chiqadi.'),
          QuizQuestion(question: 'O‘zbekiston mustaqillikka erishgan sana qachon?', options: ['1991-yil 1-sentyabr', '1990-yil 8-dekabr', '1992-yil 1-sentyabr', '1991-yil 31-avgust'], correctIndex: 0, explanation: '1991-yil 1-sentyabr — O‘zbekiston Mustaqilligi kuni.'),
          QuizQuestion(question: 'Sun‘iy intellektda "LLM" qisqartmasi nimani bildiradi?', options: ['Large Language Model', 'Low Level Machine', 'Linear Logic Matrix', 'Long Learning Method'], correctIndex: 0, explanation: 'LLM — Katta til modellari (masalan Gemini, GPT).'),
          QuizQuestion(question: 'Inson miyasida motivatsiya va odat shakllanishiga javobgar neyromediator qaysi?', options: ['Dofamin', 'Adrenalin', 'Insulin', 'Melatonin'], correctIndex: 0, explanation: 'Dofamin — mukofot, intizom va intilish hissini boshqaradi.'),
        ];
      } else {
        return const [
          QuizQuestion(question: 'O(1) vaqt murakkabligiga ega bo‘lgan ma‘lumotlar tuzilmasi qaysi?', options: ['Linked List qidiruvi', 'Hash Table (Lug‘at)', 'Binary Search Tree', 'Oddiy massiv qidiruvi'], correctIndex: 1, explanation: 'Hash Table kalit orqali qiymatni o‘rtacha O(1) doimiy vaqtda topadi.'),
          QuizQuestion(question: 'Dunyo iqtisodiyotida "GDP" (YaIM) nimani anglatadi?', options: ['Yalpi Ichki Mahsulot', 'Davlat daromadlari', 'Oltin zaxirasi', 'Tashqi qarz hajmi'], correctIndex: 0, explanation: 'Gross Domestic Product — ma‘lum davrda mamlakatda ishlab chiqarilgan tovar va xizmatlar umumiy qiymati.'),
          QuizQuestion(question: 'SOLID tamoyillarida "S" harfi nimani bildiradi?', options: ['Single Responsibility Principle', 'Security First', 'Speed Optimization', 'Static State'], correctIndex: 0, explanation: 'Single Responsibility Principle — har bir sinf faqat bitta vazifaga javobgar bo‘lishi lozim.'),
          QuizQuestion(question: 'Qadimgi Rim imperiyasida birinchi imperator kim bo‘lgan?', options: ['Yuliy Sezar', 'Oktavian Avgust', 'Neron', 'Mark Avreliy'], correctIndex: 1, explanation: 'Oktavian Avgust — miloddan avvalgi 27-yilda Rimning birinchi rasmiy imperatori bo‘lgan.'),
          QuizQuestion(question: 'Kvadrant tahlilida "Eisenhower Matritsasi" vazifalarni qaysi 2 mezon bo‘yicha ajratadi?', options: ['Muhimlik va Shoshilinchlik', 'Qiyinlik va Narx', 'Vaqt va Ball', 'Osonlik va Xursandchilik'], correctIndex: 0, explanation: 'Eyzenxauer matritsasi: Muhim/Muhim emas va Shoshilinch/Shoshilinch emas.'),
        ];
      }
    }
  }

  void _startQuiz() {
    setState(() {
      _currentQuestions = _generateQuestions(_selectedAgeGroup, _selectedSubject, _selectedDifficulty);
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _answered = false;
      _correctAnswersCount = 0;
      _quizFinished = false;
      _isQuizActive = true;
    });
    _startTimer();
  }

  void _submitAnswer(int index) {
    if (_answered) return;
    _timer?.cancel();
    HapticFeedback.mediumImpact();

    final isCorrect = index >= 0 && index == _currentQuestions[_currentQuestionIndex].correctIndex;

    setState(() {
      _selectedAnswerIndex = index;
      _answered = true;
      if (isCorrect) {
        _correctAnswersCount++;
      }
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex + 1 < _currentQuestions.length) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answered = false;
      });
      _startTimer();
    } else {
      // Finished Quiz
      setState(() {
        _quizFinished = true;
        _isQuizActive = false;
      });

      // Calculate PTS
      final user = ref.read(authStateProvider).asData?.value;
      if (user != null && _correctAnswersCount > 0) {
        final ratio = _correctAnswersCount / _currentQuestions.length;
        final earnedPts = (_selectedDifficulty.pts * ratio).round();
        if (earnedPts > 0) {
          await ref.read(userRepositoryProvider).awardPoints(user.uid, earnedPts);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: FlowaAppBar(
        showBackButton: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _quizFinished
            ? _buildResultScreen(colors)
            : _isQuizActive
                ? _buildQuizActiveScreen(colors)
                : _buildSetupScreen(colors),
      ),
    );
  }

  Widget _buildSetupScreen(AppColorScheme colors) {
    final subjects = _subjectsByAge[_selectedAgeGroup] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D154B), Color(0xFF101626)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF7B2FFF).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0x337B2FFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Color(0xFF7B2FFF), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fanlar bo‘yicha bilim sinovi',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Yoshingizga mos savollarga javob berib, PTS va Fenix Coinlar yutib oling!',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. Yosh toifasi (Age Group)
          const Text(
            '1. YOSH TOIFASINI TANLANG',
            style: TextStyle(
              color: Color(0xFF5BC8FA),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildAgeChip(0, '7-10 yosh', 'Boshlang‘ich'),
              const SizedBox(width: 8),
              _buildAgeChip(1, '11-15 yosh', 'Maktab'),
              const SizedBox(width: 8),
              _buildAgeChip(2, '16+ yosh', 'Katta / Talaba'),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Fanlar (Subjects)
          const Text(
            '2. FANNI TANLANG',
            style: TextStyle(
              color: Color(0xFF5BC8FA),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subjects.map((sub) {
              final isSelected = _selectedSubject == sub['name'];
              final color = sub['color'] as Color;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSubject = sub['name'] as String);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF0D1220),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sub['icon'] as IconData, color: isSelected ? color : Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        sub['name'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 3. Qiyinlik darajasi (Difficulty)
          const Text(
            '3. QIYINLIK DARAJASI VA MUKOFOT',
            style: TextStyle(
              color: Color(0xFF5BC8FA),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: QuizDifficulty.values.map((diff) {
              final isSelected = _selectedDifficulty == diff;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDifficulty = diff);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? diff.color.withValues(alpha: 0.2) : const Color(0xFF0D1220),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? diff.color : Colors.white12,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(diff.icon, color: diff.color, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          diff.label,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+${diff.pts} PTS',
                          style: TextStyle(
                            color: diff.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2FFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Testni Boshlash (+${_selectedDifficulty.pts} PTS) 🚀',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeChip(int index, String title, String subtitle) {
    final isSelected = _selectedAgeGroup == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedAgeGroup = index;
            final available = _subjectsByAge[index] ?? [];
            if (!available.any((s) => s['name'] == _selectedSubject)) {
              _selectedSubject = available.first['name'] as String;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x335BC8FA) : const Color(0xFF0D1220),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF5BC8FA) : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF5BC8FA) : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizActiveScreen(AppColorScheme colors) {
    final question = _currentQuestions[_currentQuestionIndex];
    final total = _currentQuestions.length;
    final progress = (_currentQuestionIndex + 1) / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Progress & Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Savol ${_currentQuestionIndex + 1} / $total',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _secondsRemaining <= 5 ? const Color(0x33FF0055) : const Color(0x225BC8FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _secondsRemaining <= 5 ? const Color(0xFFFF0055) : const Color(0xFF5BC8FA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      color: _secondsRemaining <= 5 ? const Color(0xFFFF0055) : const Color(0xFF5BC8FA),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_secondsRemaining s',
                      style: TextStyle(
                        color: _secondsRemaining <= 5 ? const Color(0xFFFF0055) : const Color(0xFF5BC8FA),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7B2FFF)),
            ),
          ),
          const SizedBox(height: 20),

          // Question Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1220),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Text(
              question.question,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Options List
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final option = question.options[idx];
                final isSelected = _selectedAnswerIndex == idx;
                final isCorrect = idx == question.correctIndex;

                Color cardColor = const Color(0xFF131A2D);
                Color borderColor = Colors.white12;
                Color textColor = Colors.white;

                if (_answered) {
                  if (isCorrect) {
                    cardColor = const Color(0x2239FF14);
                    borderColor = const Color(0xFF3B9BFF);
                    textColor = const Color(0xFF3B9BFF);
                  } else if (isSelected) {
                    cardColor = const Color(0x22FF0055);
                    borderColor = const Color(0xFFFF0055);
                    textColor = const Color(0xFFFF0055);
                  }
                }

                return GestureDetector(
                  onTap: _answered ? null : () => _submitAnswer(idx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + idx), // A, B, C, D
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (_answered && isCorrect)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF3B9BFF), size: 20)
                        else if (_answered && isSelected)
                          const Icon(Icons.cancel_rounded, color: Color(0xFFFF0055), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Explanation when answered
          if (_answered) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2338),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x335BC8FA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF5BC8FA), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      question.explanation,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5BC8FA),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  _currentQuestionIndex + 1 < total ? 'Keyingi Savol ➡️' : 'Natijani Ko‘rish 🏆',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultScreen(AppColorScheme colors) {
    final total = _currentQuestions.length;
    final ratio = _correctAnswersCount / total;
    final earnedPts = (_selectedDifficulty.pts * ratio).round();
    final earnedCoins = (earnedPts / 2).round();
    final isSuccess = ratio >= 0.6;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0x3339FF14) : const Color(0x33FFB703),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSuccess ? const Color(0xFF3B9BFF) : const Color(0xFFFFB703),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  isSuccess ? '🏆' : '📚',
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSuccess ? 'Ajoyib Natija!' : 'Yaxshi Urinish!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              'Siz $total ta savoldan $_correctAnswersCount tasiga to‘g‘ri javob berdingiz.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Reward Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1220),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF5BC8FA).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '+$earnedPts PTS',
                        style: const TextStyle(
                          color: Color(0xFF5BC8FA),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('knowledge.total_points'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.white12),
                  Column(
                    children: [
                      Text(
                        '${(ratio * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF3B9BFF),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('knowledge.accuracy'.tr(), style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _quizFinished = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('knowledge.retry_quiz'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5BC8FA),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('common.ready'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
