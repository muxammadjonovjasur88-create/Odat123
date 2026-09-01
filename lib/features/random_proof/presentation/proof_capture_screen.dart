import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../gamification/data/gamification_repository.dart';

class MoodItem {
  final String value;
  final String emoji;
  final String label;
  final Color color;

  const MoodItem({
    required this.value,
    required this.emoji,
    required this.label,
    required this.color,
  });
}

const _moods = [
  MoodItem(
    value: 'great',
    emoji: '😊',
    label: 'Ha, ajoyib',
    color: Color(0xFF22C55E),
  ),
  MoodItem(
    value: 'hard',
    emoji: '😐',
    label: 'Ha, lekin qiyin bo\'ldi',
    color: Color(0xFFEAB308),
  ),
  MoodItem(
    value: 'missed',
    emoji: '😔',
    label: 'Yo\'q, chalg\'idim',
    color: Color(0xFFEF4444),
  ),
];

class ProofCaptureScreen extends ConsumerStatefulWidget {
  const ProofCaptureScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ProofCaptureScreen> createState() => _ProofCaptureScreenState();
}

class _ProofCaptureScreenState extends ConsumerState<ProofCaptureScreen> {
  String? _selectedMood;
  bool _isSubmitting = false;
  String _errorMessage = '';

  Future<void> _selectMood(MoodItem mood, String userId, String? taskId) async {
    if (_isSubmitting || _selectedMood != null) return;

    setState(() {
      _selectedMood = mood.value;
      _isSubmitting = true;
    });

    try {
      // 1. Update Firestore proof session document
      await FirebaseFirestore.instance
          .collection('proofSessions')
          .doc(widget.sessionId)
          .update({
        'status': 'completed',
        'moodResponse': mood.value,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update user streak if mood is great or hard
      if (mood.value == 'great' || mood.value == 'hard') {
        await ref
            .read(gamificationRepositoryProvider)
            .recordProofStreakUpdate(userId);
      }

      // 3. Notify Vercel / Telegram
      try {
        final url = Uri.parse('https://YOUR_VERCEL_PROJECT.vercel.app/api/notify-proof-complete');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sessionId': widget.sessionId,
            'userId': userId,
            'taskId': taskId,
            'moodResponse': mood.value,
          }),
        );
      } catch (e) {
        debugPrint('Vercel API error: $e');
      }

      // 4. Confirmation delay (1 second) for scale animation to be visible
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('proof.answer_saved'.tr())),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Saqlashda xatolik yuz berdi: $e";
          _isSubmitting = false;
          _selectedMood = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: Center(child: Text('proof.not_signed_in'.tr())),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Orqaga qaytish',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                )
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('proofSessions')
          .doc(widget.sessionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Xatolik: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final taskId = data['taskId'] as String?;
        final taskTitle = data['taskTitle'] as String? ?? 'Vazifa';

        return PopScope(
          canPop: false, // disable back button while answering
          child: Scaffold(
            backgroundColor: colors.background,
            body: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.2,
                  colors: [
                    colors.primary.withValues(alpha: 0.08),
                    colors.background,
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Subtle header tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'KAYFIYAT CHECK-IN',
                            style: AppTextStyles.overline.copyWith(color: colors.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Main Question
                        Text(
                          'Vazifangizni bajardingizmi?',
                          style: AppTextStyles.h1.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        // Task Info Box
                        if (taskId != null)
                          Text(
                            'Vazifa: $taskTitle',
                            style: AppTextStyles.body.copyWith(
                              color: colors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 48),
                        // Emojis list
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _moods.map((mood) {
                            final isSelected = _selectedMood == mood.value;
                            final isAnySelected = _selectedMood != null;
                            final isDimmed = isAnySelected && !isSelected;

                            return GestureDetector(
                              onTap: () => _selectMood(mood, uid, taskId),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: isDimmed ? 0.3 : 1.0,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 400),
                                  scale: isSelected ? 1.3 : 1.0,
                                  curve: Curves.elasticOut,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Emoji ring
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? mood.color.withValues(alpha: 0.2)
                                              : colors.surface,
                                          border: Border.all(
                                            color: isSelected
                                                ? mood.color
                                                : colors.border.withValues(alpha: 0.5),
                                            width: isSelected ? 3 : 1.5,
                                          ),
                                          boxShadow: [
                                            if (isSelected)
                                              BoxShadow(
                                                color: mood.color.withValues(alpha: 0.4),
                                                blurRadius: 16,
                                                spreadRadius: 2,
                                              )
                                            else
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            mood.emoji,
                                            style: const TextStyle(fontSize: 40),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Label text
                                      Text(
                                        mood.label,
                                        style: AppTextStyles.caption.copyWith(
                                          color: isSelected
                                              ? mood.color
                                              : colors.textSecondary,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (_isSubmitting) ...[
                          const SizedBox(height: 48),
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
