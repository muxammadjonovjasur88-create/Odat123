import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../providers/subscription_providers.dart';
import '../screens/subscription_paywall_screen.dart';

class HomePromoCarousel extends ConsumerStatefulWidget {
  const HomePromoCarousel({super.key});

  @override
  ConsumerState<HomePromoCarousel> createState() => _HomePromoCarouselState();
}

class _HomePromoCarouselState extends ConsumerState<HomePromoCarousel> {
  late final PageController _controller;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_currentPage + 1) % 3;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(userSubscriptionProvider);

    final cards = <Widget>[
      // Card 1: ODAT Pro / 7-Day Trial
      _buildPromoCard(
        badge: sub.isTrial ? '${sub.trialDaysRemaining} ${"sub.days_left".tr()}' : 'sub.badge_7_days_free'.tr(),
        badgeColor: const Color(0xFFFFB703),
        title: 'ODAT PRO',
        subtitle: 'sub.pro_carousel_sub'.tr(),
        ctaLabel: sub.isTrial ? 'sub.explore_pro'.tr() : 'sub.cta_try_free'.tr(),
        gradientColors: [const Color(0xFF261D0F), const Color(0xFF13100B)],
        borderColor: const Color(0xFFFFB703),
        icon: Icons.workspace_premium_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
          );
        },
      ),

      // Card 2: Qat'iy Intizom & Fokus
      _buildPromoCard(
        badge: 'INTIZOM',
        badgeColor: const Color(0xFF6B25CC),
        title: 'QAT’IY INTIZOM',
        subtitle: 'Telefoningizni bloklang va chuqur diqqatga erishing.',
        ctaLabel: 'Fokusni Boshlash 🚀',
        gradientColors: [const Color(0xFF1F1135), const Color(0xFF0F081C)],
        borderColor: const Color(0xFF6B25CC),
        icon: Icons.shield_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.strictDiscipline);
        },
      ),

      // Card 3: ODAT AI Yordamchi
      _buildPromoCard(
        badge: 'ODAT AI',
        badgeColor: const Color(0xFF4AADDC),
        title: 'ODAT AI YORDAMCHI',
        subtitle: 'Ovozli buyruqlar orqali kunni rejalashtiring va mashq bajaring.',
        ctaLabel: 'AI bilan Boshlash ✦',
        gradientColors: [const Color(0xFF0A2234), const Color(0xFF07111D)],
        borderColor: const Color(0xFF4AADDC),
        icon: Icons.auto_awesome_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.aiAssistant);
        },
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 148,
          child: PageView(
            controller: _controller,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: cards,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length, (index) {
            final isCurrent = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isCurrent ? 18 : 6,
              height: 4.5,
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFFFFB703) : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPromoCard({
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String ctaLabel,
    required List<Color> gradientColors,
    required Color borderColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return BouncyScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withValues(alpha: 0.45), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        ctaLabel,
                        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: badgeColor, size: 12),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: borderColor.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: borderColor, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
