import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExerciseSelectionScreen extends StatelessWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C101A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mashqni tanlang',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Camera Vision',
                style: TextStyle(
                  color: Color(0xFF00F3FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bo\'g\'inlaringiz harakatini real-time kuzatish va takrorlarni sanash uchun mashqni tanlang.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // --- SQUAT CARD ---
              _ExerciseCard(
                title: 'Squat (Cho\'qqayish)',
                subtitle: 'Oyoq va bel mushaklarini rivojlantirish',
                badgeText: '20 takror maqsad',
                icon: Icons.fitness_center_rounded,
                accentColor: const Color(0xFF00F3FF),
                onTap: () {
                  context.push(
                    '/exercise/camera',
                    extra: {
                      'exerciseType': 'SQUAT',
                      'targetReps': 20,
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- PUSH-UP CARD ---
              _ExerciseCard(
                title: 'Push-Up (Otjimaniya)',
                subtitle: 'Ko\'krak va qo\'l mushaklarini rivojlantirish',
                badgeText: '15 takror maqsad',
                icon: Icons.accessibility_new_rounded,
                accentColor: const Color(0xFF39FF14),
                onTap: () {
                  context.push(
                    '/exercise/camera',
                    extra: {
                      'exerciseType': 'PUSH_UP',
                      'targetReps': 15,
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- PLANK CARD ---
              _ExerciseCard(
                title: 'Plank (Tekis tortilish)',
                subtitle: 'Poydevor va qorin mushaklarini mustahkamlash',
                badgeText: '60 soniya maqsad',
                icon: Icons.self_improvement_rounded,
                accentColor: const Color(0xFFFF9F00),
                onTap: () {
                  context.push(
                    '/exercise/camera',
                    extra: {
                      'exerciseType': 'PLANK',
                      'targetReps': 60,
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151A27),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF262D40)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
