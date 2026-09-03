import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../domain/game_models.dart';
import '../providers/game_providers.dart';
import 'active_game_screen.dart';
import 'skill_profile_screen.dart';

class PlayHubScreen extends ConsumerWidget {
  const PlayHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(dailyBrainChallengeProvider);
    final games = ref.watch(availableGamesProvider);
    final skill = ref.watch(skillProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'play.hub_title'.tr(),
                  style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x224AADDC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PLAY',
                    style: TextStyle(color: Color(0xFF3A7FCC), fontSize: 9.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            Text(
              'play.hub_subtitle'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: Color(0xFF4AADDC)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SkillProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // 1. Daily Brain Challenge Hero Card
          _buildDailyChallengeCard(context, challenge),
          const SizedBox(height: 20),

          // 2. Skill Index Summary Pill Card
          _buildSkillIndexSnippet(context, skill),
          const SizedBox(height: 20),

          // 3. Game Categories Grid
          Text(
            'play.categories_title'.tr(),
            style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
          ),
          const SizedBox(height: 10),

          // 4 Category Action Cards (Math, Logic, Language, Memory)
          _buildCategoryCard(
            context: context,
            icon: Icons.calculate_rounded,
            iconColor: const Color(0xFFFFB703),
            title: 'play.cat_math'.tr(),
            levelStr: 'Lvl 9 • 81/100',
            desc: 'Tezkor hisob, Foizlar, Algebra',
            games: games.where((g) => g.category == GameCategory.math).toList(),
          ),
          const SizedBox(height: 10),
          _buildCategoryCard(
            context: context,
            icon: Icons.psychology_rounded,
            iconColor: const Color(0xFF3A7FCC),
            title: 'play.cat_logic'.tr(),
            levelStr: 'Lvl 12 • 72/100',
            desc: 'Ketma-ketlik, Qonuniyat, Guruhlash',
            games: games.where((g) => g.category == GameCategory.logic).toList(),
          ),
          const SizedBox(height: 10),
          _buildCategoryCard(
            context: context,
            icon: Icons.translate_rounded,
            iconColor: const Color(0xFF4AADDC),
            title: 'play.cat_language'.tr(),
            levelStr: 'Lvl 15 • 67/100',
            desc: 'Ingliz, Rus, O‘zbek tillari so‘z boyligi',
            games: games.where((g) => g.category == GameCategory.language).toList(),
          ),
          const SizedBox(height: 10),
          _buildCategoryCard(
            context: context,
            icon: Icons.memory_rounded,
            iconColor: const Color(0xFF9D4EDD),
            title: 'play.cat_memory'.tr(),
            levelStr: 'Lvl 7 • 75/100',
            desc: 'Xotira matritsasi, Diqqat va Fokus',
            games: games.where((g) => g.category == GameCategory.memory).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDailyChallengeCard(BuildContext context, DailyBrainChallenge ch) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF261D10), Color(0xFF13100B)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x33FFB703), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFFFB703), size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'play.daily_challenge_title'.tr(),
                    style: const TextStyle(color: Color(0xFFFFB703), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x3300FF88),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '+50 XP  +20 FC',
                  style: TextStyle(color: Color(0xFF3A7FCC), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${ch.completedPuzzles} / ${ch.totalPuzzles} ' + 'play.puzzles_done'.tr(),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ch.progressRatio,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ActiveGameScreen(gameId: 'math_sprint', category: GameCategory.math, gameTitle: 'Tezkor Hisob (Math Sprint)'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'play.continue_btn'.tr(),
                style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillIndexSnippet(BuildContext context, SkillProfile skill) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SkillProfileScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF090B18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x224AADDC)),
              child: const Icon(Icons.insights_rounded, color: Color(0xFF4AADDC), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'play.skill_index_title'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Matematika: ${skill.mathScore} • Mantiq: ${skill.logicScore} • Til: ${skill.languageScore}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF4AADDC), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String levelStr,
    required String desc,
    required List<LearningGame> games,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 1),
                    Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  levelStr,
                  style: TextStyle(color: iconColor, fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (games.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: games.map((g) {
                return BouncyScale(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActiveGameScreen(gameId: g.id, category: g.category, gameTitle: g.titleKey.tr()),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      g.titleKey.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
