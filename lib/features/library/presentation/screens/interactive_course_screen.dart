import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/course_generator_service.dart';
import '../../domain/models/book.dart';
import '../../domain/models/interactive_course.dart';

class InteractiveCourseScreen extends ConsumerStatefulWidget {
  final Book book;

  const InteractiveCourseScreen({super.key, required this.book});

  @override
  ConsumerState<InteractiveCourseScreen> createState() => _InteractiveCourseScreenState();
}

class _InteractiveCourseScreenState extends ConsumerState<InteractiveCourseScreen> {
  InteractiveCourse? _course;
  bool _isLoading = true;
  int _currentLessonIndex = 0;
  bool _showExam = false;

  // Lesson quiz state
  int? _selectedOptionIndex;
  bool _answerRevealed = false;
  int _currentQuizQIndex = 0;

  // Final Exam state
  int _examQIndex = 0;
  int? _selectedExamOption;
  bool _examAnswerRevealed = false;
  int _examScore = 0;
  bool _examCompleted = false;

  final TextEditingController _exerciseNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  @override
  void dispose() {
    _exerciseNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadCourse() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid ?? 'guest';
    try {
      final course = await ref.read(courseGeneratorServiceProvider).getOrGenerateCourse(widget.book, uid);
      if (mounted) {
        setState(() {
          _course = course;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markLessonComplete(int index) async {
    if (_course == null) return;
    final uid = ref.read(authStateProvider).asData?.value?.uid ?? 'guest';

    final updatedLessons = List<CourseLesson>.from(_course!.lessons);
    if (index < updatedLessons.length) {
      updatedLessons[index] = updatedLessons[index].copyWith(isCompleted: true);
    }

    final updatedCourse = InteractiveCourse(
      id: _course!.id,
      bookId: _course!.bookId,
      title: _course!.title,
      author: _course!.author,
      category: _course!.category,
      totalLessons: _course!.totalLessons,
      rewardPoints: _course!.rewardPoints,
      lessons: updatedLessons,
      finalExam: _course!.finalExam,
      isCompleted: updatedLessons.every((l) => l.isCompleted),
      userScore: _course!.userScore,
    );

    setState(() {
      _course = updatedCourse;
      _currentQuizQIndex = 0;
      _selectedOptionIndex = null;
      _answerRevealed = false;
      _exerciseNoteController.clear();
      if (_currentLessonIndex < updatedLessons.length - 1) {
        _currentLessonIndex++;
      } else {
        _showExam = true;
      }
    });

    await ref.read(courseGeneratorServiceProvider).updateCourseProgress(
          bookId: widget.book.id,
          userId: uid,
          course: updatedCourse,
        );
  }

  Future<void> _completeFinalExam() async {
    if (_course == null) return;
    final uid = ref.read(authStateProvider).asData?.value?.uid ?? 'guest';

    setState(() {
      _examCompleted = true;
    });

    // Reward user with Points
    final pointsToAward = _course!.rewardPoints;
    try {
      if (uid != 'guest') {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'totalPoints': FieldValue.increment(pointsToAward),
          'weeklyPoints': FieldValue.increment(pointsToAward),
        });
      }
    } catch (_) {}

    final updatedCourse = InteractiveCourse(
      id: _course!.id,
      bookId: _course!.bookId,
      title: _course!.title,
      author: _course!.author,
      category: _course!.category,
      totalLessons: _course!.totalLessons,
      rewardPoints: _course!.rewardPoints,
      lessons: _course!.lessons,
      finalExam: _course!.finalExam,
      isCompleted: true,
      userScore: _examScore,
    );

    await ref.read(courseGeneratorServiceProvider).updateCourseProgress(
          bookId: widget.book.id,
          userId: uid,
          course: updatedCourse,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.dark.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('AI Kurs Generatori', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(color: Color(0xFF4AADDC), strokeWidth: 3.5),
              ),
              const SizedBox(height: 24),
              const Text(
                '🧠 Kitob tahlil qilinmoqda...',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Darslar, testlar, mashqlar va imtihon shakllantirilmoqda',
                style: TextStyle(color: AppColors.dark.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_course == null) {
      return Scaffold(
        backgroundColor: AppColors.dark.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: Text('Kursni yuklashda xatolik yuz berdi', style: TextStyle(color: Colors.white))),
      );
    }

    final totalLessons = _course!.lessons.length;
    final completedCount = _course!.lessons.where((l) => l.isCompleted).length;
    final allLessonsCompleted = totalLessons > 0 && completedCount == totalLessons;

    return Scaffold(
      backgroundColor: AppColors.dark.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              widget.book.title,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '🎓 Interaktiv Kurs (+${_course!.rewardPoints} PTS)',
              style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showExam ? Icons.auto_stories_rounded : Icons.school_rounded,
              color: const Color(0xFF4AADDC),
            ),
            tooltip: _showExam ? 'Darslarga qaytish' : 'Imtihonga o\'tish',
            onPressed: () {
              setState(() => _showExam = !_showExam);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Progress Bar
          Container(
            color: const Color(0xFF090B18),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bajarildi: $completedCount/$totalLessons dars',
                      style: TextStyle(color: AppColors.dark.textSecondary, fontSize: 12),
                    ),
                    Text(
                      '${((completedCount / (totalLessons == 0 ? 1 : totalLessons)) * 100).toInt()}%',
                      style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalLessons == 0 ? 0 : completedCount / totalLessons,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4AADDC)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Lesson Selector Tabs
          if (!_showExam)
            Container(
              height: 48,
              color: const Color(0xFF090B18),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: totalLessons + 1, // lessons + exam tab
                itemBuilder: (context, idx) {
                  if (idx == totalLessons) {
                    final isSel = _showExam;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSel,
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_rounded, size: 14, color: Color(0xFFFFB703)),
                            SizedBox(width: 4),
                            Text('Imtihon 🎓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        selectedColor: const Color(0xFFFFB703),
                        backgroundColor: const Color(0xFF192238),
                        onSelected: (_) => setState(() => _showExam = true),
                      ),
                    );
                  }

                  final lesson = _course!.lessons[idx];
                  final isSelected = !_showExam && _currentLessonIndex == idx;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lesson.isCompleted)
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF3A7FCC))
                          else
                            Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text(
                            '${idx + 1}-Dars',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      selectedColor: const Color(0xFF4AADDC),
                      backgroundColor: const Color(0xFF192238),
                      onSelected: (_) {
                        setState(() {
                          _showExam = false;
                          _currentLessonIndex = idx;
                          _currentQuizQIndex = 0;
                          _selectedOptionIndex = null;
                          _answerRevealed = false;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

          // Main Body: Lesson View or Final Exam View
          Expanded(
            child: _showExam ? _buildFinalExamView(allLessonsCompleted) : _buildLessonView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonView() {
    if (_course!.lessons.isEmpty) {
      return const Center(child: Text('Darslar mavjud emas', style: TextStyle(color: Colors.white)));
    }

    final lesson = _course!.lessons[_currentLessonIndex];
    final quizQuestions = lesson.quizQuestions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Lesson Title Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF19253C), Color(0xFF090B18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x444AADDC)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4AADDC).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.menu_book_rounded, color: Color(0xFF4AADDC), size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentLessonIndex + 1}-Dars',
                        style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        lesson.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Lesson Content Text
          const Text(
            '📖 Dars Mazmuni',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF090B18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              lesson.content,
              style: const TextStyle(color: Color(0xFFDDE6F5), fontSize: 14.5, height: 1.6),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Practical Exercise
          const Text(
            '✍️ Amaliy Mashq & Topshiriq',
            style: TextStyle(color: Color(0xFFFFB703), fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66FFB703)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.practicalExercise,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _exerciseNoteController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Mashq bo\'yicha xulosangiz yoki bajarish qaydlaringiz...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF090B18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Lesson Quiz Section
          if (quizQuestions.isNotEmpty) ...[
            const Text(
              '❓ Darsni Mustahkamlash Testi',
              style: TextStyle(color: Color(0xFF3A7FCC), fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _buildLessonQuizCard(quizQuestions),
            const SizedBox(height: 24),
          ],

          // 5. Complete Lesson Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _markLessonComplete(_currentLessonIndex),
              icon: Icon(
                lesson.isCompleted ? Icons.check_circle_rounded : Icons.done_all_rounded,
                color: Colors.black,
              ),
              label: Text(
                lesson.isCompleted
                    ? 'Keyingi darsga o\'tish ➡️'
                    : 'Darsni Bajarildi deb belgilash ✅',
                style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: lesson.isCompleted ? const Color(0xFF4AADDC) : const Color(0xFF3A7FCC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildLessonQuizCard(List<CourseQuestion> questions) {
    if (_currentQuizQIndex >= questions.length) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x224AADDC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3A7FCC)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ajoyib! Ushbu darsning barcha testlariga to\'g\'ri javob berdingiz!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final q = questions[_currentQuizQIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x3300FF88)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Savol ${_currentQuizQIndex + 1}/${questions.length}',
                style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            q.questionText,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          ...q.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isSelected = _selectedOptionIndex == idx;
            final isCorrect = idx == q.correctIndex;

            Color bgColor = const Color(0xFF192238);
            Color borderClr = Colors.transparent;

            if (_answerRevealed) {
              if (isCorrect) {
                bgColor = const Color(0x3300FF88);
                borderClr = const Color(0xFF3A7FCC);
              } else if (isSelected && !isCorrect) {
                bgColor = const Color(0x33FF0055);
                borderClr = const Color(0xFFFF0055);
              }
            } else if (isSelected) {
              bgColor = const Color(0x334AADDC);
              borderClr = const Color(0xFF4AADDC);
            }

            return GestureDetector(
              onTap: _answerRevealed
                  ? null
                  : () {
                      setState(() {
                        _selectedOptionIndex = idx;
                        _answerRevealed = true;
                      });

                      Future.delayed(const Duration(milliseconds: 1400), () {
                        if (mounted && _currentQuizQIndex < questions.length) {
                          setState(() {
                            _currentQuizQIndex++;
                            _selectedOptionIndex = null;
                            _answerRevealed = false;
                          });
                        }
                      });
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderClr),
                ),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + idx)})',
                      style: TextStyle(color: borderClr == Colors.transparent ? Colors.white60 : borderClr, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    if (_answerRevealed && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFinalExamView(bool allLessonsCompleted) {
    final examQuestions = _course!.finalExam;

    if (_examCompleted || _course!.isCompleted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎓', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                'Tabriklaymiz! Kursni Muvaffaqiyatli Yakunladingiz! 🏆',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Sizga +${_course!.rewardPoints} PTS taqdim etildi va profilingizga sertifikat belgisi qo\'shildi!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4AADDC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Kutubxonaga qaytish', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (!allLessonsCompleted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_rounded, color: Color(0xFFFFB703), size: 64),
              const SizedBox(height: 16),
              const Text(
                'Yakuniy Imtihon Hali Qulflangan 🔒',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Imtihonni ochish uchun avval barcha ${_course!.lessons.length} ta darsni va mashqlarni yakunlang.',
                style: TextStyle(color: AppColors.dark.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _showExam = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4AADDC),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Darslarga o\'tish 📖', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (examQuestions.isEmpty) {
      return const Center(child: Text('Imtihon savollari topilmadi', style: TextStyle(color: Colors.white)));
    }

    final q = examQuestions[_examQIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎓 Yakuniy Imtihon: Savol ${_examQIndex + 1}/${examQuestions.length}',
                style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'To\'g\'ri: $_examScore',
                style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF221A0F), Color(0xFF090B18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x66FFB703), width: 1.5),
            ),
            child: Text(
              q.questionText,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          ...q.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final option = entry.value;
            final isSelected = _selectedExamOption == idx;
            final isCorrect = idx == q.correctIndex;

            Color bgColor = const Color(0xFF090B18);
            Color borderClr = Colors.white12;

            if (_examAnswerRevealed) {
              if (isCorrect) {
                bgColor = const Color(0x3300FF88);
                borderClr = const Color(0xFF3A7FCC);
              } else if (isSelected && !isCorrect) {
                bgColor = const Color(0x33FF0055);
                borderClr = const Color(0xFFFF0055);
              }
            } else if (isSelected) {
              bgColor = const Color(0x33FFB703);
              borderClr = const Color(0xFFFFB703);
            }

            return GestureDetector(
              onTap: _examAnswerRevealed
                  ? null
                  : () {
                      setState(() {
                        _selectedExamOption = idx;
                        _examAnswerRevealed = true;
                        if (isCorrect) _examScore++;
                      });

                      Future.delayed(const Duration(milliseconds: 1400), () {
                        if (mounted) {
                          if (_examQIndex < examQuestions.length - 1) {
                            setState(() {
                              _examQIndex++;
                              _selectedExamOption = null;
                              _examAnswerRevealed = false;
                            });
                          } else {
                            _completeFinalExam();
                          }
                        }
                      });
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderClr),
                ),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + idx)})',
                      style: TextStyle(color: borderClr == Colors.white12 ? Colors.white60 : borderClr, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    if (_examAnswerRevealed && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
