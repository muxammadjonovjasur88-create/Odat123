import 'dart:math';
import '../domain/game_models.dart';

class GameGenerators {
  static final Random _rng = Random();

  /// Generate a question set for a given game and category.
  static List<GameQuestion> generateQuestions(String gameId, GameCategory category, {int count = 10}) {
    switch (category) {
      case GameCategory.math:
        return _generateMathQuestions(gameId, count);
      case GameCategory.logic:
        return _generateLogicQuestions(gameId, count);
      case GameCategory.language:
        return _generateLanguageQuestions(gameId, count);
      case GameCategory.memory:
        return _generateMemoryQuestions(gameId, count);
    }
  }

  // --- MATH GENERATORS ---
  static List<GameQuestion> _generateMathQuestions(String gameId, int count) {
    final list = <GameQuestion>[];
    for (int i = 0; i < count; i++) {
      if (gameId.contains('algebra')) {
        // e.g. ax + b = c
        final a = _rng.nextInt(6) + 2; // 2 to 7
        final x = _rng.nextInt(9) + 1; // 1 to 9
        final b = _rng.nextInt(15) + 3; // 3 to 17
        final c = (a * x) + b;

        final correct = x;
        final options = <int>{correct};
        while (options.length < 4) {
          final delta = _rng.nextInt(7) - 3;
          final fake = correct + (delta == 0 ? 2 : delta);
          if (fake > 0) options.add(fake);
        }
        final optList = options.map((v) => 'x = $v').toList()..shuffle(_rng);
        final correctIdx = optList.indexOf('x = $correct');

        list.add(GameQuestion(
          id: 'alg_$i',
          prompt: '$a·x + $b = $c\nx ning qiymatini toping:',
          options: optList,
          correctIndex: correctIdx,
          explanation: '$c dan $b ni ayiramiz ($c - $b = ${c - b}), keyin $a ga bo‘lamiz: x = ${c - b} / $a = $x.',
          topic: 'Algebra',
          hint: 'Avval tenglikning har ikki tomonidan $b ni ayiring.',
        ));
      } else if (gameId.contains('percent')) {
        final base = (_rng.nextInt(10) + 1) * 20; // 20, 40, ..., 200
        final percent = [10, 20, 25, 50, 75][_rng.nextInt(5)];
        final correct = (base * percent) ~/ 100;

        final options = <int>{correct};
        while (options.length < 4) {
          final fake = correct + (_rng.nextInt(15) - 7);
          if (fake > 0 && fake != correct) options.add(fake);
        }
        final optList = options.map((v) => '$v').toList()..shuffle(_rng);
        final correctIdx = optList.indexOf('$correct');

        list.add(GameQuestion(
          id: 'pct_$i',
          prompt: '$base ning $percent% foizi qanchaga teng?',
          options: optList,
          correctIndex: correctIdx,
          explanation: '$base · $percent / 100 = $correct.',
          topic: 'Foizlar (Percentages)',
          hint: '$percent% = ${percent / 100}',
        ));
      } else {
        // Fast Mental Arithmetic
        final op = ['+', '-', '×'][_rng.nextInt(3)];
        int n1 = _rng.nextInt(25) + 5;
        int n2 = _rng.nextInt(15) + 2;
        int correct = 0;
        if (op == '+') {
          correct = n1 + n2;
        } else if (op == '-') {
          if (n1 < n2) {
            final t = n1;
            n1 = n2;
            n2 = t;
          }
          correct = n1 - n2;
        } else {
          n1 = _rng.nextInt(9) + 2;
          n2 = _rng.nextInt(9) + 2;
          correct = n1 * n2;
        }

        final options = <int>{correct};
        while (options.length < 4) {
          final fake = correct + (_rng.nextInt(9) - 4);
          if (fake >= 0 && fake != correct) options.add(fake);
        }
        final optList = options.map((v) => '$v').toList()..shuffle(_rng);
        final correctIdx = optList.indexOf('$correct');

        list.add(GameQuestion(
          id: 'math_$i',
          prompt: '$n1 $op $n2 = ?',
          options: optList,
          correctIndex: correctIdx,
          explanation: '$n1 $op $n2 = $correct',
          topic: 'Tezkor Hisob (Mental Math)',
        ));
      }
    }
    return list;
  }

  // --- LOGIC GENERATORS ---
  static List<GameQuestion> _generateLogicQuestions(String gameId, int count) {
    final list = <GameQuestion>[];
    for (int i = 0; i < count; i++) {
      if (i % 3 == 0) {
        // Arithmetic Progression Sequence
        final start = _rng.nextInt(10) + 2;
        final step = _rng.nextInt(5) + 2;
        final s1 = start;
        final s2 = s1 + step;
        final s3 = s2 + step;
        final s4 = s3 + step;
        final correct = s4 + step;

        final options = <int>{correct};
        while (options.length < 4) {
          final fake = correct + (_rng.nextInt(9) - 4);
          if (fake > 0 && fake != correct) options.add(fake);
        }
        final optList = options.map((v) => '$v').toList()..shuffle(_rng);
        final correctIdx = optList.indexOf('$correct');

        list.add(GameQuestion(
          id: 'seq_$i',
          prompt: '$s1,  $s2,  $s3,  $s4,  ?\nKetma-ketlikdagi keyingi sonni toping:',
          options: optList,
          correctIndex: correctIdx,
          explanation: 'Har bir son oldingisidan +$step ga oshib bormoqda ($s4 + $step = $correct).',
          topic: 'Ketma-ketlik (Sequence)',
          hint: 'Sonlar orasidagi farqni hisoblang.',
        ));
      } else if (i % 3 == 1) {
        // Geometric Doubling Sequence
        final start = _rng.nextInt(4) + 2; // 2, 3, 4, 5
        final s1 = start;
        final s2 = s1 * 2;
        final s3 = s2 * 2;
        final s4 = s3 * 2;
        final correct = s4 * 2;

        final options = <int>{correct};
        while (options.length < 4) {
          final fake = correct + (_rng.nextInt(15) - 7);
          if (fake > 0 && fake != correct) options.add(fake);
        }
        final optList = options.map((v) => '$v').toList()..shuffle(_rng);
        final correctIdx = optList.indexOf('$correct');

        list.add(GameQuestion(
          id: 'geom_$i',
          prompt: '$s1,  $s2,  $s3,  $s4,  ?\nQonuniyatni aniqlang:',
          options: optList,
          correctIndex: correctIdx,
          explanation: 'Har bir son 2 ga ko‘paytirib borilmoqda ($s4 × 2 = $correct).',
          topic: 'Mantiqiy Qonuniyat (Logic Pattern)',
        ));
      } else {
        // Odd One Out
        final puzzles = [
          {
            'prompt': 'Qaysi biri guruhga mos kelmaydi?',
            'options': ['Olma (Apple)', 'Banan (Banana)', 'Sabzi (Carrot)', 'Uzum (Grape)'],
            'correct': 2,
            'exp': 'Sabzi bu sabzavot, qolganlari esa meva.',
          },
          {
            'prompt': 'Qaysi son qolganlaridan tubdan farq qiladi?',
            'options': ['4', '9', '16', '15'],
            'correct': 3,
            'exp': '4 (2²), 9 (3²), 16 (4²) to‘la kvadrat sonlar, 15 esa emas.',
          },
        ];
        final p = puzzles[_rng.nextInt(puzzles.length)];
        list.add(GameQuestion(
          id: 'odd_$i',
          prompt: p['prompt'] as String,
          options: List<String>.from(p['options'] as List),
          correctIndex: p['correct'] as int,
          explanation: p['exp'] as String,
          topic: 'Guruhdan chiqarish (Odd One Out)',
        ));
      }
    }
    return list;
  }

  // --- LANGUAGE GENERATORS (Uzbek, Russian, English) ---
  static List<GameQuestion> _generateLanguageQuestions(String gameId, int count) {
    final vocab = [
      {'en': 'Knowledge', 'uz': 'Bilim', 'ru': 'Знание'},
      {'en': 'Discipline', 'uz': 'Intizom', 'ru': 'Дисциплина'},
      {'en': 'Growth', 'uz': 'O‘sish', 'ru': 'Рост'},
      {'en': 'Habit', 'uz': 'Odat', 'ru': 'Привычка'},
      {'en': 'Focus', 'uz': 'Diqqat / Fokus', 'ru': 'Фокус'},
      {'en': 'Victory', 'uz': 'G‘alaba', 'ru': 'Победа'},
      {'en': 'Challenge', 'uz': 'Sinov / Chaqiriq', 'ru': 'Вызов'},
      {'en': 'Confidence', 'uz': 'Ishonch', 'ru': 'Уверенность'},
      {'en': 'Creativity', 'uz': 'Ijodkorlik', 'ru': 'Творчество'},
      {'en': 'Courage', 'uz': 'Jasorat', 'ru': 'Смелость'},
    ];

    final list = <GameQuestion>[];
    for (int i = 0; i < count; i++) {
      final item = vocab[i % vocab.length];
      final targetWord = item['en']!;
      final correctTranslation = '${item['uz']} (${item['ru']})';

      final otherTranslations = vocab
          .where((v) => v['en'] != targetWord)
          .map((v) => '${v['uz']} (${v['ru']})')
          .toList()
        ..shuffle(_rng);

      final options = [correctTranslation, ...otherTranslations.take(3)]..shuffle(_rng);
      final correctIdx = options.indexOf(correctTranslation);

      list.add(GameQuestion(
        id: 'lang_$i',
        prompt: '“$targetWord” so‘zining to‘g‘ri tarjimasini toping:',
        options: options,
        correctIndex: correctIdx,
        explanation: '“$targetWord” — $correctTranslation degan ma’noni bildiradi.',
        topic: 'Lug‘at boyligi (Vocabulary)',
      ));
    }
    return list;
  }

  // --- MEMORY & ATTENTION GENERATORS ---
  static List<GameQuestion> _generateMemoryQuestions(String gameId, int count) {
    final list = <GameQuestion>[];
    for (int i = 0; i < count; i++) {
      final digits = List.generate(4, (_) => _rng.nextInt(9) + 1);
      final sequenceStr = digits.join(' - ');
      final correct = digits.reversed.join(' - ');

      final fake1 = (List.of(digits)..shuffle(_rng)).join(' - ');
      final fake2 = digits.map((d) => (d + 1) % 10).join(' - ');
      final fake3 = digits.join(' - ');

      final options = [correct, fake1, fake2, fake3]..shuffle(_rng);
      final correctIdx = options.indexOf(correct);

      list.add(GameQuestion(
        id: 'mem_$i',
        prompt: 'Ketma-ketlikni eslab qoling:\n[ $sequenceStr ]\n\nUshbu ketma-ketlikning TESKARI ko‘rinishi qaysi?',
        options: options,
        correctIndex: correctIdx,
        explanation: '$sequenceStr ning teskari tartibi: $correct',
        topic: 'Xotira va Diqqat (Memory Recall)',
      ));
    }
    return list;
  }
}
