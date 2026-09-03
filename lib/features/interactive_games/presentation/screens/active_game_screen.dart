import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/game_models.dart';
import '../providers/game_providers.dart';

class ActiveGameScreen extends ConsumerStatefulWidget {
  const ActiveGameScreen({
    super.key,
    required this.gameId,
    required this.category,
    required this.gameTitle,
  });

  final String gameId;
  final GameCategory category;
  final String gameTitle;

  @override
  ConsumerState<ActiveGameScreen> createState() => _ActiveGameScreenState();
}

class _ActiveGameScreenState extends ConsumerState<ActiveGameScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int _correctCount = 0;
  int _lives = 3;
  int? _selectedOption;
  bool _isAnswerChecked = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        _finishGame();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onOptionSelected(int index, GameQuestion q) {
    if (_isAnswerChecked) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedOption = index;
      _isAnswerChecked = true;
    });

    final isCorrect = index == q.correctIndex;
    if (isCorrect) {
      HapticFeedback.lightImpact();
      _score += 100;
      _correctCount++;
    } else {
      HapticFeedback.heavyImpact();
      _lives--;
      if (_lives <= 0) {
        _timer?.cancel();
        _finishGame();
        return;
      }
    }

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final questions = ref.read(activeGameQuestionsProvider((gameId: widget.gameId, category: widget.category)));
      if (_currentIndex < questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedOption = null;
          _isAnswerChecked = false;
        });
      } else {
        _timer?.cancel();
        _finishGame();
      }
    });
  }

  void _finishGame() {
    final questions = ref.read(activeGameQuestionsProvider((gameId: widget.gameId, category: widget.category)));
    final total = questions.isNotEmpty ? questions.length : 10;
    final accuracy = ((_correctCount / total) * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF3A7FCC), Color(0xFF4AADDC)]),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF04050D), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'play.round_complete'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'play.accuracy'.tr() + ': $accuracy% • ' + 'play.score'.tr() + ': $_score',
                style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _rewardPill('+25 XP', const Color(0xFF4AADDC)),
                  const SizedBox(width: 8),
                  _rewardPill('+5 FC', const Color(0xFFFFB703)),
                  const SizedBox(width: 8),
                  _rewardPill('+1 Index', const Color(0xFF3A7FCC)),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7FCC),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'play.continue_btn'.tr(),
                  style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rewardPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(activeGameQuestionsProvider((gameId: widget.gameId, category: widget.category)));
    if (questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF04050D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF3A7FCC))),
      );
    }

    final q = questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.gameTitle,
          style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: List.generate(3, (i) {
                return Icon(
                  i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: const Color(0xFFFF5252),
                  size: 20,
                );
              }),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Top HUD: Timer & Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFF4AADDC), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '0:$_secondsLeft',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Text(
                  'play.score'.tr() + ': $_score',
                  style: const TextStyle(color: Color(0xFFFFB703), fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / questions.length,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3A7FCC)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 24),

            // Center Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF132034), Color(0xFF0C1422)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x224AADDC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${q.topic} (${_currentIndex + 1}/${questions.length})',
                      style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q.prompt,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4 Option Cards
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: q.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildOptionTile(index, q.options[index], q);
                },
              ),
            ),

            // Socratic Hint Footer if hint is present
            if (q.hint != null && !_isAnswerChecked) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFFB703), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Hint: ${q.hint}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(int index, String optionText, GameQuestion q) {
    Color cardBorder = Colors.white10;
    Color cardBg = const Color(0xFF090B18);

    if (_isAnswerChecked) {
      if (index == q.correctIndex) {
        cardBorder = const Color(0xFF3A7FCC);
        cardBg = const Color(0x3300FF88);
      } else if (_selectedOption == index) {
        cardBorder = const Color(0xFFFF5252);
        cardBg = const Color(0x33FF5252);
      }
    }

    return InkWell(
      onTap: () => _onOptionSelected(index, q),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white12,
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                optionText,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
