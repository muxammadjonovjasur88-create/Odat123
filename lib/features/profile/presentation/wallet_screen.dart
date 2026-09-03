import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/flowa_app_bar.dart';
import '../../../core/widgets/bouncy_scale.dart';

/// Premium holatini ko'rsatuvchi ekran.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    // Premium plan is retrieved or deduced, assuming logic exists or using defaults.
    // Replace with real provider if available.
    final bool isPremium = profile != null && profile.fenixCoins > 50000; // Mock logic

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: const FlowaAppBar(showBackButton: true),
      body: profile == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.odatCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: [
                // Premium Status Card
                _buildPremiumCard(isPremium),
              ],
            ),
    );
  }



  Widget _buildPremiumCard(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium 
            ? [const Color(0xFFC9A24B).withValues(alpha: 0.2), const Color(0xFF04050D)]
            : [const Color(0xFF161B26), const Color(0xFF04050D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPremium ? const Color(0xFFC9A24B) : const Color(0x336B25CC),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.workspace_premium_rounded : Icons.star_border_rounded,
                color: isPremium ? const Color(0xFFC9A24B) : const Color(0xFF8899B0),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isPremium ? 'ODAT PREMIUM' : 'BEPUL REJA',
                style: TextStyle(
                  color: isPremium ? const Color(0xFFC9A24B) : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A24B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FAOL',
                    style: TextStyle(
                      color: Color(0xFFC9A24B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isPremium 
              ? 'Siz Premium imkoniyatlardan to\'liq foydalanmoqdasiz. Oylik/Yillik obunangiz faol.'
              : 'Premium xizmatiga obuna bo\'ling va cheklovsiz AI rejalashtiruvchi hamda batafsil statistikaga ega bo\'ling.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          if (!isPremium)
            BouncyScale(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.subscriptionPaywall);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC9A24B), Color(0xFFB1893A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44C9A24B),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'PREMIUM SOTIB OLISH',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


}
