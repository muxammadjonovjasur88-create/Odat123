import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/family_models.dart';
import '../providers/family_providers.dart';

class ParentStudyScreen extends ConsumerWidget {
  const ParentStudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationsAsync = ref.watch(recentStudyVerificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'family.study_analytics_title'.tr(),
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // Study Overview Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF261E10), Color(0xFF13100B)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'family.study_today'.tr(),
                      style: const TextStyle(color: Color(0xFFFFB703), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                    const Icon(Icons.auto_stories_rounded, color: Color(0xFFFFB703), size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '1h 48m',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statPill('Matematika: 45m', const Color(0xFFFFB703)),
                    const SizedBox(width: 8),
                    _statPill('Ingliz tili: 40m', const Color(0xFF5BC8FA)),
                    const SizedBox(width: 8),
                    _statPill('IT: 23m', const Color(0xFF3B9BFF)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AI Study Verifications List
          Text(
            'family.verified_sessions'.tr(),
            style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
          ),
          const SizedBox(height: 10),

          verificationsAsync.when(
            data: (verifications) => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: verifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final v = verifications[index];
                return _buildVerificationTile(context, v);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703))),
            error: (e, st) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVerificationTile(BuildContext context, AiStudyVerification v) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                v.subject,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x2200FF88),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${v.score}/${v.totalQuestions} (${v.percentage}%)',
                  style: const TextStyle(color: Color(0xFF3B9BFF), fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(v.topic, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text('“${v.verdict}”', style: const TextStyle(color: Color(0xFF3B9BFF), fontSize: 11.5, fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(v.verifiedAtStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF3B9BFF),
                      content: Text('family.reward_sent'.tr(), style: const TextStyle(color: Color(0xFF080B14), fontWeight: FontWeight.bold)),
                    ),
                  );
                },
                icon: const Icon(Icons.stars_rounded, color: Color(0xFF080B14), size: 16),
                label: Text('family.send_coins_btn'.tr(), style: const TextStyle(color: Color(0xFF080B14), fontWeight: FontWeight.w900, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B9BFF),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
