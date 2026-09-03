import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/widgets/bouncy_scale.dart';

import '../../gamification/presentation/widgets/lucky_wheel_modal.dart';
import '../../gamification/presentation/widgets/streak_calendar_modal.dart';
import '../../music/presentation/widgets/music_section_widget.dart';
import '../../profile/presentation/widgets/social_subscription_modal.dart';

/// Zen Kinetic Daily Quests & Mission Hub
/// Top: Animated Wallpaper Carousel + 31-Day Streak & Wheel
/// 4 Big Interactive Category Cards:
/// 1) 🏋️‍♂️ Mashg'ulotlar
/// 2) 📚 Bilim Olish (Kitoblar & Qat'iy Intizom)
/// 3) 💎 Qo'shimcha PTS
/// 4) ⚔️ Janglar
class DailyQuestsWidget extends ConsumerStatefulWidget {
  const DailyQuestsWidget({super.key});

  @override
  ConsumerState<DailyQuestsWidget> createState() => _DailyQuestsWidgetState();
}

class _DailyQuestsWidgetState extends ConsumerState<DailyQuestsWidget> {
  @override
  void initState() {
    super.initState();
  }

  void _shareReferral() {
    final user = ref.read(userProfileProvider).asData?.value;
    final code = user?.numericId ?? '849201';
    Share.share(
      'ODAT ilovasiga qo‘shiling va yangi odatlarni shakllantiring! Mening ODAT ID kodim: $code (+150 PTS bonus) 🔥 https://odat.app/ref/$code',
    );
  }

  void _openCategoryModal(BuildContext context, String categoryTitle, String emoji, List<Widget> quests) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      bui        height: MediaQuery.of(context).size.height * 0.78,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0E131F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF1E283D), width: 1)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(
                  categoryTitle,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: quests.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => quests[index],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Quick Equalized Daily Banners (Streak & Wheel) ───────
        Row(
          children: [
            Expanded(
              child: BouncyScale(
                onTap: () => showStreakCalendarModal(context),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121826),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E283D), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF59E0B), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'banners.streak_title'.tr(),
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'banners.streak_sub'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BouncyScale(
                onTap: () => showLuckyWheelModal(context),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121826),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E283D), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.casino_rounded, color: Color(0xFF8B5CF6), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'banners.wheel_title'.tr(),
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'banners.wheel_sub'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 2. 4 Katta Asosiy Bo'lim Kartalari ──────────────────────────
        Text(
          'categories.main_title'.tr(),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),

        // 1. MASHG'ULOTLAR
        _BigCategoryCard(
          title: 'categories.workouts_title'.tr(),
          emoji: '🏋️‍♂️',
          badgeText: '+450 PTS',
          gradientColors: const [Color(0xFF151C2C), Color(0xFF090B18)],
          borderColor: const Color(0xFF232D42),
          accentColor: const Color(0xFF4AADDC),
          iconBgColor: const Color(0x224AADDC),
          onTap: () => _openCategoryModal(
            context,
            'categories.workouts_title'.tr(),
            '🏋️‍♂️',
            [
              _QuestCard(
                title: 'Yugurish (GPS Xarita)',
                subtitle: '3.0 KM TARGET • Navoiy va barcha viloyatlar',
                icon: Icons.directions_run_rounded,
                iconColor: const Color(0xFF3A7FCC),
                badge: '+150 PTS',
                badgeColor: const Color(0xFF3A7FCC),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.running);
                },
              ),
              _QuestCard(
                title: 'Kamera Vision AI Mashqlari',
                subtitle: 'SQUAT • PUSHUP • PLANK • PRESS • TURNIK (AI Sanash)',
                icon: Icons.fitness_center_rounded,
                iconColor: const Color(0xFF4AADDC),
                badge: 'AI VISION',
                badgeColor: const Color(0xFF4AADDC),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.exerciseSelect);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. INTIZOM (Ertalabki Missiya Budilnigi, Qat'iy Intizom, Tungi Uyqu)
        _BigCategoryCard(
          title: 'INTIZOM',
          emoji: '🛡️',
          badgeText: '+500 PTS',
          gradientColors: const [Color(0xFF151C2C), Color(0xFF090B18)],
          borderColor: const Color(0xFF232D42),
          accentColor: const Color(0xFF6B25CC),
          iconBgColor: const Color(0x226B25CC),
          onTap: () => _openCategoryModal(
            context,
            'INTIZOM',
            '🛡️',
            [
              _QuestCard(
                title: 'Ertalabki Missiya Budilnigi',
                subtitle: '20 Squat + 20 Pushup qilmaguncha budilnik o‘chmaydi',
                icon: Icons.alarm_on_rounded,
                iconColor: const Color(0xFFFFB703),
                badge: '+10 PTS',
                badgeColor: const Color(0xFFFFB703),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.missionAlarm);
                },
              ),
              _QuestCard(
                title: 'Qat‘iy Intizom (Fokus)',
                subtitle: '30 Daqiqa • Telefon to‘liq bloklanadi • Faqat qo‘ng‘iroq',
                icon: Icons.lock_clock_rounded,
                iconColor: const Color(0xFF4AADDC),
                badge: '+60 PTS',
                badgeColor: const Color(0xFF4AADDC),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.strictDiscipline);
                },
              ),

            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. BILIM OLISH
        _BigCategoryCard(
          title: 'categories.study_title'.tr(),
          emoji: '📚',
          badgeText: '+200 PTS',
          gradientColors: const [Color(0xFF151C2C), Color(0xFF090B18)],
          borderColor: const Color(0xFF232D42),
          accentColor: const Color(0xFF4AADDC),
          iconBgColor: const Color(0x224AADDC),
          onTap: () => _openCategoryModal(
            context,
            'categories.study_title'.tr(),
            '📚',
            [
              _QuestCard(
                title: 'Kitob Mutolaasi & Kutubxona',
                subtitle: 'Elektron PDF Kutubxona • Mutolaa Tahlili',
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF6B25CC),
                badge: '+60 PTS',
                badgeColor: const Color(0xFF6B25CC),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.library);
                },
              ),
              _QuestCard(
                title: 'Fanlar & Intellektual Testlar',
                subtitle: 'Yoshingizga mos fanlar • 3 xil qiyinlik darajasi',
                icon: Icons.psychology_rounded,
                iconColor: const Color(0xFFFFB703),
                badge: '+80 PTS',
                badgeColor: const Color(0xFFFFB703),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.quiz);
                },
              ),
              _QuestCard(
                title: 'extra.audiobooks_title'.tr(),
                subtitle: 'extra.audiobooks_desc'.tr(),
                icon: Icons.headphones_rounded,
                iconColor: const Color(0xFF3A7FCC),
                badge: 'AUDIO',
                badgeColor: const Color(0xFF3A7FCC),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.audiobooks);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. QO'SHIMCHA PTS
        _BigCategoryCard(
          title: 'categories.extra_pts_title'.tr(),
          emoji: '💎',
          badgeText: '+8,100 PTS',
          gradientColors: const [Color(0xFF151C2C), Color(0xFF090B18)],
          borderColor: const Color(0xFF232D42),
          accentColor: const Color(0xFF6B25CC),
          iconBgColor: const Color(0x226B25CC),
          onTap: () => _openCategoryModal(
            context,
            'categories.extra_pts_title'.tr(),
            '💎',
            [
              _QuestCard(
                title: 'extra.social_sub_title'.tr(),
                subtitle: 'extra.social_sub_desc'.tr(),
                icon: Icons.public_rounded,
                iconColor: const Color(0xFF4AADDC),
                badge: '+3,000 PTS',
                badgeColor: const Color(0xFF4AADDC),
                onTap: () {
                  Navigator.pop(context);
                  showSocialSubscriptionModal(context);
                },
              ),
              _QuestCard(
                title: 'extra.wheel_fortune_title'.tr(),
                subtitle: 'extra.wheel_fortune_desc'.tr(),
                icon: Icons.casino_rounded,
                iconColor: const Color(0xFF6B25CC),
                badge: 'extra.free_gift'.tr(),
                badgeColor: const Color(0xFF6B25CC),
                onTap: () {
                  Navigator.pop(context);
                  showLuckyWheelModal(context);
                },
              ),
              _QuestCard(
                title: 'extra.marathon_title'.tr(),
                subtitle: 'extra.marathon_desc'.tr(),
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFFFFB703),
                badge: '+100 PTS',
                badgeColor: const Color(0xFFFFB703),
                onTap: () {
                  Navigator.pop(context);
                  showStreakCalendarModal(context);
                },
              ),
              _QuestCard(
                title: 'Do‘stlarni Taklif Qilish (Referal)',
                subtitle: 'Har bir do‘stingiz uchun +5,000 PTS katta bonus',
                icon: Icons.group_add_rounded,
                iconColor: const Color(0xFF3A7FCC),
                badge: '+5,000 PTS',
                badgeColor: const Color(0xFF3A7FCC),
                onTap: () {
                  Navigator.pop(context);
                  _shareReferral();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. JANGLAR
        _BigCategoryCard(
          title: 'categories.battles_title'.tr(),
          emoji: '⚔️',
          badgeText: '+680 PTS',
          gradientColors: const [Color(0xFF151C2C), Color(0xFF090B18)],
          borderColor: const Color(0xFF232D42),
          accentColor: const Color(0xFF4AADDC),
          iconBgColor: const Color(0x224AADDC),
          onTap: () => _openCategoryModal(
            context,
            'categories.battles_title'.tr(),
            '⚔️',
            [
              _QuestCard(
                title: 'extra.boss_raid'.tr(),
                subtitle: 'Jamoaviy 1000 HP Dangasalik Titanini yiqit!',
                icon: Icons.shield_moon_rounded,
                iconColor: const Color(0xFFFF0055),
                badge: '+500 PTS',
                badgeColor: const Color(0xFFFF0055),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.bossRaid);
                },
              ),
              _QuestCard(
                title: 'extra.1v1_battle'.tr(),
                subtitle: 'Do‘stingiz yoki tasodifiy raqib bilan bellashing',
                icon: Icons.sports_martial_arts_rounded,
                iconColor: const Color(0xFF3A7FCC),
                badge: '180 PTS 🏆',
                badgeColor: const Color(0xFF3A7FCC),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.battle);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5. YANGILIKLAR & XABARLAR
        _BigCategoryCard(
          title: 'news.title'.tr(),
          emoji: '📰',
          badgeText: 'HOT 🔥',
          gradientColors: const [Color(0xFF151C2C), Color(0xFF090B18)],
          borderColor: const Color(0xFF232D42),
          accentColor: const Color(0xFF6B25CC),
          iconBgColor: const Color(0x226B25CC),
          onTap: () => context.push(AppRoutes.news),
        ),
        const SizedBox(height: 12),

        // 6. MUSIQALAR & FOKUS AUDIO
        _BigCategoryCard(
          title: 'music.title'.tr(),
          emoji: '🎵',
          badgeText: 'AUDIO 🎧',
          gradientColors: const [Color(0xFF151C2C), Color(0xFF090B18)],
          borderColor: const Color(0xFF232D42),
          accentColor: const Color(0xFF4AADDC),
          iconBgColor: const Color(0x224AADDC),
          onTap: () => _openMusicModal(context),
        ),
      ],
    );
  }

  void _openMusicModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF0E131F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF1E283D), width: 1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: MusicSectionWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigCategoryCard extends StatelessWidget {
  const _BigCategoryCard({
    required this.title,
    required this.emoji,
    required this.badgeText,
    required this.gradientColors,
    required this.borderColor,
    required this.accentColor,
    required this.iconBgColor,
    required this.onTap,
  });

  final String title;
  final String emoji;
  final String badgeText;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color accentColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E283D), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2234),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF222B40), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2335),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF222B40), width: 1),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF475569), size: 12),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141A29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E283D), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2335),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF222B40), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2335),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF222B40), width: 1),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 16),
          ],
        ),
      ),
    );
  }
}
