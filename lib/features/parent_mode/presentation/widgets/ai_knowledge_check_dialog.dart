import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showAiKnowledgeCheckDialog(BuildContext context, {required String subject, required int rewardCoins}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AiKnowledgeCheckDialog(subject: subject, rewardCoins: rewardCoins),
  );
}

class _AiKnowledgeCheckDialog extends StatefulWidget {
  const _AiKnowledgeCheckDialog({required this.subject, required this.rewardCoins});
  final String subject;
  final int rewardCoins;

  @override
  State<_AiKnowledgeCheckDialog> createState() => _AiKnowledgeCheckDialogState();
}

class _AiKnowledgeCheckDialogState extends State<_AiKnowledgeCheckDialog> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int? _selectedOption;
  bool _isFinished = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'q': 'Kvadrat tenglamaning diskriminant formulasi qaysi?',
      'options': ['D = b² - 4ac', 'D = b² + 4ac', 'D = 2a / -b', 'D = a² + b²'],
      'correct': 0,
    },
    {
      'q': 'Agar D > 0 bo‘lsa, tenglama nechta haqiqiy ildizga ega?',
      'options': ['Ildizga ega emas', '1 ta ildiz', '2 ta turli ildiz', 'Cheksiz ko‘p'],
      'correct': 2,
    },
    {
      'q': 'x² - 5x + 6 = 0 tenglamaning ildizlari qaysilar?',
      'options': ['x = 1, x = 6', 'x = 2, x = 3', 'x = -2, x = -3', 'x = 0, x = 5'],
      'correct': 1,
    },
    {
      'q': 'Viyet teoremasiga ko‘ra, ildizlar ko‘paytmasi nimaga teng?',
      'options': ['c / a', '-b / a', 'b² - 4ac', '2a'],
      'correct': 0,
    },
    {
      'q': 'Agar D = 0 bo‘lsa, ildizlar haqida nima deyish mumkin?',
      'options': ['Ildiz yo‘q', '2 ta teng (bitta) ildiz', '3 ta ildiz', 'Ildizlar manfiy'],
      'correct': 1,
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      final passed = _correctAnswers >= 4;
      return Dialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: passed ? const Color(0x224AADDC) : const Color(0x22FF5252),
                ),
                child: Icon(passed ? Icons.verified_rounded : Icons.replay_rounded, color: passed ? const Color(0xFF3A7FCC) : const Color(0xFFFF5252), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                passed ? 'A’lo Natija!' : 'Yana bir bor takrorlang',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '$_correctAnswers / 5 to‘g‘ri javob (${(_correctAnswers / 5 * 100).round()}%)',
                style: TextStyle(color: passed ? const Color(0xFF3A7FCC) : Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                passed
                  ? 'Mavzu juda yaxshi o‘zlashtirildi! +${widget.rewardCoins} Fenix Coins hisobingizga qo‘shildi.'
                  : 'Mavzuni to‘liq o‘zlashtirish uchun yana 10 daqiqa qayta o‘qib chiqing.',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: passed ? const Color(0xFF3A7FCC) : const Color(0xFF1B2844),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Yopish',
                  style: TextStyle(color: passed ? const Color(0xFF04050D) : Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];

    return Dialog(
      backgroundColor: const Color(0xFF090B18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'AI TEST (${_currentIndex + 1}/5)',
                  style: const TextStyle(color: Color(0xFFFFB703), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
                Text(
                  '+${widget.rewardCoins} FC',
                  style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              q['q'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 16),

            // Options
            for (int i = 0; i < (q['options'] as List<String>).length; i++) ...[
              _buildOption(i, (q['options'] as List<String>)[i]),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _selectedOption == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      if (_selectedOption == q['correct']) {
                        _correctAnswers++;
                      }
                      if (_currentIndex < _questions.length - 1) {
                        setState(() {
                          _currentIndex++;
                          _selectedOption = null;
                        });
                      } else {
                        setState(() => _isFinished = true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A7FCC),
                disabledBackgroundColor: Colors.white10,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Center(
                child: Text(
                  _currentIndex < _questions.length - 1 ? 'Keyingi Savol' : 'Yakunlash',
                  style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int index, String text) {
    final isSel = _selectedOption == index;
    return InkWell(
      onTap: () => setState(() => _selectedOption = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel ? const Color(0x224AADDC) : const Color(0xFF090B18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? const Color(0xFF3A7FCC) : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? const Color(0xFF3A7FCC) : Colors.white12,
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(color: isSel ? const Color(0xFF04050D) : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }
}
