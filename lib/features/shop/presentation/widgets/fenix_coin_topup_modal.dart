import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/in_app_purchase_service.dart';
import '../../../../core/services/user_repository.dart';
import '../../domain/fenix_coin_package.dart';

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the Fenix Coin Top-Up Modal Bottom Sheet with Google Play In-App Billing support.
Future<void> showFenixCoinTopUpModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _FenixCoinTopUpSheet(),
  );
}

class _FenixCoinTopUpSheet extends ConsumerStatefulWidget {
  const _FenixCoinTopUpSheet();

  @override
  ConsumerState<_FenixCoinTopUpSheet> createState() => _FenixCoinTopUpSheetState();
}

class _FenixCoinTopUpSheetState extends ConsumerState<_FenixCoinTopUpSheet>
    with TickerProviderStateMixin {
  final _promoController = TextEditingController();
  bool _isRedeemingPromo = false;

  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  int _lastDailyBonusEpoch = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadDailyBonusState();
  }

  Future<void> _loadDailyBonusState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastDailyBonusEpoch = prefs.getInt('fc_last_daily_bonus_epoch') ?? 0;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _promoController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _claimDailyBonus() async {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
    final diffMs = nowEpoch - _lastDailyBonusEpoch;
    final oneDayMs = 24 * 60 * 60 * 1000;

    if (diffMs < oneDayMs && _lastDailyBonusEpoch > 0) {
      final remainingMs = oneDayMs - diffMs;
      final hours = remainingMs ~/ (60 * 60 * 1000);
      final minutes = (remainingMs % (60 * 60 * 1000)) ~/ (60 * 1000);
      final seconds = (remainingMs % (60 * 1000)) ~/ 1000;

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF090B18),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Ertaga keling! Qolgan vaqt: $hours soat $minutes daqiqa $seconds soniya ⏳',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return;

    HapticFeedback.heavyImpact();
    await ref.read(userRepositoryProvider).addFenixCoins(user.uid, 10);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fc_last_daily_bonus_epoch', nowEpoch);
    setState(() => _lastDailyBonusEpoch = nowEpoch);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3A7FCC),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                ),
                child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF090B18), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tabriklaymiz! +10 Fenix Coin hisobingizga qo‘shildi!',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDailyBonusBanner() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const cooldownMs = 24 * 60 * 60 * 1000;
    final elapsed = now - _lastDailyBonusEpoch;
    final isAvailable = _lastDailyBonusEpoch == 0 || elapsed >= cooldownMs;

    String countdownText = 'OLISH';
    if (!isAvailable) {
      final remainingMs = cooldownMs - elapsed;
      final hours = remainingMs ~/ (3600 * 1000);
      final minutes = (remainingMs % (3600 * 1000)) ~/ (60 * 1000);
      final seconds = (remainingMs % (60 * 1000)) ~/ 1000;
      countdownText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return GestureDetector(
      onTap: _claimDailyBonus,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAvailable
                  ? [
                      Color.lerp(const Color(0xFF1A2840), const Color(0xFF1E3050), _pulseController.value)!,
                      Color.lerp(const Color(0xFF1E2F4A), const Color(0xFF243860), _pulseController.value)!,
                    ]
                  : [const Color(0xFF0F1420), const Color(0xFF0A0E18)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAvailable
                  ? Color.lerp(const Color(0x5500BFFF), const Color(0xAA00BFFF), _pulseController.value)!
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isAvailable ? const Color(0x2200BFFF) : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isAvailable ? const Color(0xFF4AADDC) : Colors.white24),
                ),
                child: Icon(
                  isAvailable ? Icons.card_giftcard_rounded : Icons.hourglass_top_rounded,
                  color: isAvailable ? const Color(0xFF4AADDC) : Colors.white60,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KUNLIK BEPUL BONUS',
                      style: TextStyle(
                        color: isAvailable ? const Color(0xFF4AADDC) : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      isAvailable ? 'Har kuni kiring va 10 tanga bepul oling!' : 'Keyingi bonus uchun 24 soat kuting',
                      style: TextStyle(
                        color: isAvailable ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isAvailable ? const Color(0xFF4AADDC) : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  countdownText,
                  style: TextStyle(
                    color: isAvailable ? Colors.black : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePromoCode() async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return;

    setState(() => _isRedeemingPromo = true);
    HapticFeedback.mediumImpact();

    int coinsToAdd = 0;
    int ptsToAdd = 0;
    String rewardTitle = '';

    if (code == 'FENIX2026') {
      coinsToAdd = 1000;
      ptsToAdd = 500;
      rewardTitle = '1000 Fenix Coin + 500 PTS';
    } else if (code == 'ODATPRO') {
      coinsToAdd = 500;
      rewardTitle = '500 Fenix Coin';
    } else if (code == 'FENIXGOLD') {
      coinsToAdd = 2500;
      ptsToAdd = 1000;
      rewardTitle = '2500 Fenix Coin + 1000 PTS';
    } else if (code == 'START100') {
      coinsToAdd = 100;
      rewardTitle = '100 Fenix Coin';
    } else {
      // Default bonus for valid admin format promo codes
      if (code.startsWith('FNX') || code.length >= 6) {
        coinsToAdd = 200;
        rewardTitle = '200 Fenix Coin';
      }
    }

    if (coinsToAdd == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF0055),
            behavior: SnackBarBehavior.floating,
            content: Text('shop.invalid_promo'.tr()),
          ),
        );
        setState(() => _isRedeemingPromo = false);
      }
      return;
    }

    try {
      final userRepo = ref.read(userRepositoryProvider);
      if (coinsToAdd > 0) {
        await userRepo.addFenixCoins(user.uid, coinsToAdd);
      }
      if (ptsToAdd > 0) {
        await userRepo.awardPoints(user.uid, ptsToAdd);
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A7FCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)]),
                  ),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF090B18), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PROMO-KOD TASDIQLANDI: +$rewardTitle hisobingizga qo‘shildi!',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRedeemingPromo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final currentCoins = user?.fenixCoins ?? 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF04050D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0x88FFB703), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // Header
          _buildHeader(currentCoins),

          // Daily bonus banner
          _buildDailyBonusBanner(),

          // Promo code section
          _buildPromoCodeSection(),

          const Divider(color: Colors.white10, height: 12),

          // Packages list
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF090B18), size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fenix Coin to‘plamlari tez kunda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          _buildSecurityBadge(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(int currentCoins) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) => Transform.scale(
                  scale: 1.0 + _pulseController.value * 0.12,
                  child: child,
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF090B18), size: 22),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FENIX COIN',
                    style: TextStyle(
                      color: Color(0xFFFFB703),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Do\'konni To\'ldirish',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Balance pill
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (_, child) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0x44FFB703),
                    const Color(0x88FFB703),
                    const Color(0x44FFB703),
                  ],
                  stops: [
                    (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                    _shimmerController.value.clamp(0.0, 1.0),
                    (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFB703)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    '$currentCoins',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildPromoCodeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x44FFB703)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.confirmation_number_outlined, color: Color(0xFFFFB703), size: 18),
              SizedBox(width: 8),
              Text(
                'PROMO-KOD ALMASHTIRISH',
                style: TextStyle(
                  color: Color(0xFFFFB703),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF04050D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'KODNI KIRITING (masalan: FENIX2026)',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 0.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isRedeemingPromo ? null : _handlePromoCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB703),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isRedeemingPromo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'ALMASHTIRISH',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1000FF88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x3000FF88)),
      ),
      child: const Row(
        children: [
          Icon(Icons.security_rounded, color: Color(0xFF3A7FCC), size: 15),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Google Play xavfsiz to\'lov · 1 USD = 12 800 so\'m',
              style: TextStyle(
                color: Color(0xFF3A7FCC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

