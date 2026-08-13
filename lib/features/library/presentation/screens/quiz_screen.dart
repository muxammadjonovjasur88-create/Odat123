import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/book.dart';
import '../../domain/models/quiz_question.dart';
import '../../domain/models/quiz_result.dart';
import '../providers/library_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final Book book;

  const QuizScreen({super.key, required this.book});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<QuizQuestion> _questions = [];
  final Map<int, int> _userAnswers = {};
  int _currentQuestionIndex = 0;

  QuizResult? _result;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(libraryRepositoryProvider);
      final questions = await repo.generateBookQuiz(widget.book.id);
      if (questions.isEmpty) {
        throw Exception("Ushbu kitob uchun test savollari topilmadi.");
      }
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (err) {
      setState(() {
        _isLoading = false;
        _errorMessage = err.toString().replaceAll("Exception: ", "");
      });
    }
  }

  Future<void> _submitQuiz() async {
    if (_questions.isEmpty) return;

    // Check if user answered all questions
    final List<int> answersList = [];
    for (int i = 0; i < _questions.length; i++) {
      answersList.add(_userAnswers[i] ?? -1);
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(libraryRepositoryProvider);
      final result = await repo.submitBookQuiz(
        bookId: widget.book.id,
        answers: answersList,
      );
      setState(() {
        _result = result;
        _isSubmitting = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString().replaceAll("Exception: ", "")),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.book.title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.cyanAccent),
                  SizedBox(height: 16),
                  Text(
                    'AI test savollarini tayyorlamoqda...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Iltimos kuting, 10 ta test shakllantirilmoqda',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFB7185), size: 52),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadQuiz,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Qayta urinish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cyanAccent,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _result != null
                  ? _buildResultView()
                  : _buildQuestionsView(),
    );
  }

  Widget _buildQuestionsView() {
    final question = _questions[_currentQuestionIndex];
    final selectedOptionIndex = _userAnswers[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;

    final progressPct = (_currentQuestionIndex + 1) / _questions.length;

    return Column(
      children: [
        // Top Progress Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Savol ${_currentQuestionIndex + 1} / ${_questions.length}',
                    style: const TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${(progressPct * 100).toInt()}%',
                    style: TextStyle(color: AppColors.dark.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressPct,
                  minHeight: 6,
                  backgroundColor: AppColors.dark.surfaceMuted,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Question & Options Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.dark.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.dark.border),
                  ),
                  child: Text(
                    question.question,
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Options List
                ...List.generate(question.options.length, (optIdx) {
                  final optionText = question.options[optIdx];
                  final isSelected = selectedOptionIndex == optIdx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _userAnswers[_currentQuestionIndex] = optIdx;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.cyanAccent.withValues(alpha: 0.15)
                              : AppColors.dark.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.cyanAccent : AppColors.dark.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.cyanAccent : AppColors.dark.surfaceMuted,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + optIdx),
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.dark.textSecondary,
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Navigation Footer
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex--;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: AppColors.dark.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Oldingisi'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: selectedOptionIndex != null
                          ? AppColors.primaryGradient
                          : null,
                      color: selectedOptionIndex == null ? AppColors.dark.surfaceMuted : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: selectedOptionIndex != null && !_isSubmitting
                          ? () {
                              if (isLastQuestion) {
                                _submitQuiz();
                              } else {
                                setState(() {
                                  _currentQuestionIndex++;
                                });
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text(
                              isLastQuestion ? 'Yakunlash va Yuborish' : 'Keyingisi',
                              style: TextStyle(
                                color: selectedOptionIndex != null ? Colors.black : Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final result = _result!;
    final bool isSuccess = result.score >= (result.totalQuestions * 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Animated Celebration Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isSuccess
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSuccess ? const Color(0xFF34D399) : Colors.amberAccent,
                width: 2,
              ),
            ),
            child: Icon(
              isSuccess ? Icons.emoji_events_rounded : Icons.thumb_up_rounded,
              color: isSuccess ? const Color(0xFF34D399) : Colors.amberAccent,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            isSuccess ? 'Ajoyib natija! 🎉' : 'Yaxshi urinish! 👍',
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.alreadySubmitted
                ? 'Siz ushbu kitob uchun testni avval topshirgansiz.'
                : 'Siz kitob bo\'yicha bilimlaringizni muvaffaqiyatli sinab ko\'rdingiz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.dark.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),

          // Stats Cards Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dark.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dark.border),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Natija',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${result.score} / ${result.totalQuestions}',
                        style: const TextStyle(
                          color: AppColors.cyanAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dark.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dark.border),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Olingan Ball',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+${result.pointsEarned}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Back to Library Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Kutubxonaga qaytish',
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
