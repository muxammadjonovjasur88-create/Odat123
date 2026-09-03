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
        badgeColor: const Color(0xFFF59E0B),
        title: 'ODAT PRO',
        subtitle: 'sub.pro_carousel_sub'.tr(),
        ctaLabel: sub.isTrial ? 'sub.explore_pro'.tr() : 'sub.cta_try_free'.tr(),
        accentColor: const Color(0xFFF59E0B),
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
        badgeColor: const Color(0xFF8B5CF6),
        title: 'QAT’IY INTIZOM',
        subtitle: 'Telefoningizni bloklang va chuqur diqqatga erishing.',
        ctaLabel: 'Fokusni Boshlash',
        accentColor: const Color(0xFF8B5CF6),
        icon: Icons.shield_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.strictDiscipline);
        },
      ),

      // Card 3: ODAT AI Yordamchi
      _buildPromoCard(
        badge: 'ODAT AI',
        badgeColor: const Color(0xFF38BDF8),
        title: 'ODAT AI YORDAMCHI',
        subtitle: 'Ovozli buyruqlar orqali kunni rejalashtiring va mashq bajaring.',
        ctaLabel: 'AI bilan Boshlash',
        accentColor: const Color(0xFF38BDF8),
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length, (index) {
            final isCurrent = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isCurrent ? 20 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF38BDF8) : const Color(0xFF1E283D),
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
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return BouncyScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1E283D),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ctaLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: accentColor, size: 13),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B2335),
                border: Border.all(
                  color: const Color(0xFF222B40),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}
