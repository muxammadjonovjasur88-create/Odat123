import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_repository.dart';
import '../../../reminders/presentation/providers/reminders_provider.dart';
import '../../data/exercise_repository.dart';
import '../../domain/models/exercise_session.dart';

class ExerciseSummaryScreen extends ConsumerStatefulWidget {
  const ExerciseSummaryScreen({
    super.key,
    required this.sessionData,
  });

  final Map<String, dynamic> sessionData;

  @override
  ConsumerState<ExerciseSummaryScreen> createState() =>
      _ExerciseSummaryScreenState();
}

class _ExerciseSummaryScreenState
    extends ConsumerState<ExerciseSummaryScreen> {
  bool _isSaving = true;

  @override
  void initState() {
    super.initState();
    _saveSession();
  }

  Future<void> _saveSession() async {
    final user = ref.read(userProfileProvider).asData?.value;
    final userId = user?.uid ?? 'anonymous';
    final sessionId = const Uuid().v4();

    final reps = widget.sessionData['repCount'] as int? ?? 0;
    final duration = widget.sessionData['durationSeconds'] as int? ?? 0;
    final points = widget.sessionData['pointsEarned'] as int? ?? 0;
    final type = widget.sessionData['exerciseType'] as String? ?? 'SQUAT';

    final session = ExerciseSession(
      id: sessionId,
      userId: userId,
      exerciseType: type,
      repCount: reps,
      durationSeconds: duration,
      pointsEarned: points,
      completedAt: DateTime.now(),
    );

    if (userId != 'anonymous') {
      try {
        await ref.read(exerciseRepositoryProvider).saveExerciseSession(session);
        
        final reminderId = widget.sessionData['reminderId'] as String?;
        if (reminderId != null) {
          await ref.read(remindersProvider.notifier).markCompleted(reminderId);
        }
      } catch (e) {
        debugPrint('Error saving exercise session: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reps = widget.sessionData['repCount'] as int? ?? 0;
    final duration = widget.sessionData['durationSeconds'] as int? ?? 0;
    final points = widget.sessionData['pointsEarned'] as int? ?? 0;
    final exerciseType = widget.sessionData['exerciseType'] as String? ?? 'SQUAT';
    final isPlank = exerciseType.toUpperCase() == 'PLANK';

    final m = duration ~/ 60;
    final s = duration % 60;
    final durationText = '${m < 10 ? '0$m' : m}:${s < 10 ? '0$s' : s}';

    final pm = reps ~/ 60;
    final ps = reps % 60;
    final plankHoldText = '${pm < 10 ? '0$pm' : pm}:${ps < 10 ? '0$ps' : ps}';

    final exerciseName = exerciseType.toUpperCase() == 'PUSH_UP'
        ? 'PUSH-UP'
        : (exerciseType.toUpperCase() == 'PLANK' ? 'PLANK' : 'SQUAT');

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B14),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mashq Natijasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // --- CELEBRATION HEADER ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPlank
                        ? [const Color(0xFFFF9F00), const Color(0xFFFF0055)]
                        : [const Color(0xFF3B9BFF), const Color(0xFF5BC8FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: isPlank ? const Color(0x66FF9F00) : const Color(0x6639FF14),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: Colors.black, size: 54),
                    const SizedBox(height: 12),
                    Text(
                      '$exerciseName MASHQI YAKUNLANDI!',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+$points OCHKO ISHLANDI',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- STATS GRID ---
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryTile(
                      isPlank ? 'PLANK DAVOMIYLIGI' : 'TAKRORLAR',
                      isPlank ? plankHoldText : '$reps ta',
                      isPlank ? Icons.timer_rounded : Icons.fitness_center_rounded,
                      isPlank ? const Color(0xFFFF9F00) : const Color(0xFF5BC8FA),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildSummaryTile(
                      'SARFLANGAN VAQT',
                      durationText,
                      Icons.access_time_filled_rounded,
                      Colors.white,
                    ),
                  ),
                ],
              ),

              if (_isSaving) ...[
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF5BC8FA),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Natija saqlanmoqda...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],

              const Spacer(),

              // --- FINISH BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/daily');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B9BFF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                  ),
                  child: const Text(
                    'ASOSIY EKRANGA QAYTISH',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTile(
      String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262D40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF8B9BB4),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
