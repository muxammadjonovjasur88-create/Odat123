import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/widgets/bouncy_scale.dart';
import '../../../core/widgets/flowa_app_bar.dart';
import '../../shop/presentation/widgets/fenix_coin_topup_modal.dart';
import '../../shop/presentation/widgets/pts_exchange_modal.dart';
import 'widgets/coins_history_modal.dart';
import 'widgets/pts_history_modal.dart';

/// Comprehensive ODAT Wallet & Premium Hub Screen.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final fenixCoins = profile?.fenixCoins ?? 0;
    final totalPoints = profile?.totalPoints ?? 0;
    final isPremium = profile?.isPremium ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: const FlowaAppBar(showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Header Title ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2335),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF222B40)),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HAMYON & BALANS',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    profile?.displayName ?? profile?.name ?? 'Mening Hamyonim',
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Dual Balance Cards Row ────────────────────────────────────
          Row(
            children: [
              // Fenix Coins Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121826),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E283D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('🪙', style: TextStyle(fontSize: 17))),
                          ),
                          InkWell(
                            onTap: () => showCoinsHistoryModal(context),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.history_rounded, color: Color(0xFF64748B), size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Fenix Coins',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$fenixCoins FC',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => showFenixCoinTopUpModal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('To‘ldirish', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // PTS Points Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121826),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E283D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 17))),
                          ),
                          InkWell(
                            onTap: () => showPtsHistoryModal(context),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.history_rounded, color: Color(0xFF64748B), size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Jami PTS',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalPoints PTS',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => showPtsExchangeModal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E283D),
                            foregroundColor: const Color(0xFF38BDF8),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Almashish', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── ODAT Premium Banner Card ──────────────────────────────────
          _buildPremiumCard(isPremium),
          const SizedBox(height: 18),

          // ── Quick Services Section ────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'HAMYON XIZMATLARI',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E283D)),
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => showFenixCoinTopUpModal(context),
                  leading: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF38BDF8)),
                  title: const Text('Kunlik Bepul Bonus', style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Har kuni +10 Fenix Coin bepul oling', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 13),
                ),
                const Divider(color: Color(0xFF1E283D), height: 1),
                ListTile(
                  onTap: () => context.push(AppRoutes.shop),
                  leading: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6)),
                  title: const Text('Sovg‘alar Do‘koni', style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Kuponlar, elektronika va nishonlar', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 13),
                ),
                const Divider(color: Color(0xFF1E283D), height: 1),
                ListTile(
                  onTap: () => showPtsExchangeModal(context),
                  leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF10B981)),
                  title: const Text('PTS → Fenix Coin Ayirboshlash', style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('10,000 PTS = 100 Fenix Coin', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPremium ? const Color(0xFFF59E0B) : const Color(0xFF1E283D),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                      : const Color(0xFF1B2335),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium_rounded : Icons.star_border_rounded,
                  color: isPremium ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? 'ODAT PREMIUM FAOL' : 'ODAT PREMIUM',
                    style: TextStyle(
                      color: isPremium ? const Color(0xFFF59E0B) : const Color(0xFFF8FAFC),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    isPremium ? 'Barcha imkoniyatlar ochilgan' : '40 000 so‘m/oy • 390 000 so‘m/yil',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                  ),
                ],
              ),
              const Spacer(),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isPremium
                ? 'Sizda cheklovsiz AI murabbiy, barcha rejimlar va audio kitoblar faollashtirilgan.'
                : 'Cheklovsiz AI tahlil, to‘liq intizom qurollari va oylik eksklyuziv sovg‘alarni qo‘lga kiriting.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          BouncyScale(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.subscriptionPaywall);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  isPremium ? 'OBUNANI BOSHQARISH' : 'PREMIUMGA O‘TISH (40 000 SO‘M)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
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
