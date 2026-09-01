import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../providers/game_providers.dart';

class SkillProfileScreen extends ConsumerWidget {
  const SkillProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skill = ref.watch(skillProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'play.skill_profile_title'.tr(),
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // Hero Skill Index Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1220), Color(0xFF0C1626)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF5BC8FA).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'play.learning_index_heading'.tr(),
                      style: const TextStyle(color: Color(0xFF5BC8FA), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFF5BC8FA), size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.military_tech_rounded, color: Color(0xFFFFB703), size: 36),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('74 / 100', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        Text('Umumiy Qobiliyat Indeksi', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080B14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB703), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${skill.learningStreak} kunlik o‘yin streaki (1.2x)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Skill Dimension Bars
          Text(
            'play.skill_breakdown'.tr(),
            style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
          ),
          const SizedBox(height: 12),

          _buildSkillBar('Matematika (Math)', skill.mathScore, const Color(0xFFFFB703), 'Lvl 9 • Tezkor hisob a’lo'),
          _buildSkillBar('Mantiq (Logic)', skill.logicScore, const Color(0xFF3B9BFF), 'Lvl 12 • Ketma-ketlik yuqori'),
          _buildSkillBar('Xotira & Diqqat (Memory)', skill.memoryScore, const Color(0xFF9D4EDD), 'Lvl 7 • Diqqat barqaror'),
          _buildSkillBar('Tillar (Languages)', skill.languageScore, const Color(0xFF5BC8FA), 'Lvl 15 • +120 yangi so‘z'),
          const SizedBox(height: 20),

          // Non-IQ Educational Transparency Disclaimer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'play.skill_disclaimer'.tr(),
                    style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSkillBar(String title, int score, Color color, String sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('$score / 100', style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
        ],
      ),
    );
  }
}
