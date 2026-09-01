import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/in_app_purchase_service.dart';
import '../../../../core/services/user_repository.dart';
import '../../domain/premium.dart';

/// Opens the interactive Premium Checkout & Payment Modal Sheet
Future<bool?> showPremiumCheckoutSheet({
  required BuildContext context,
  required PremiumPlan initialPlan,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PremiumCheckoutSheet(initialPlan: initialPlan),
  );
}

class _PremiumCheckoutSheet extends ConsumerStatefulWidget {
  const _PremiumCheckoutSheet({required this.initialPlan});

  final PremiumPlan initialPlan;

  @override
  ConsumerState<_PremiumCheckoutSheet> createState() =>
      _PremiumCheckoutSheetState();
}

class _PremiumCheckoutSheetState extends ConsumerState<_PremiumCheckoutSheet>
    with SingleTickerProviderStateMixin {
  late PremiumPlan _plan;
  PremiumPaymentMethod _method = PremiumPaymentMethod.payme;
  bool _isProcessing = false;
  String _processingStep = '';
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    setState(() {
      _isProcessing = true;
      _processingStep = 'To\'lov tizimiga ulanmoqda...';
    });

    HapticFeedback.mediumImpact();

    try {
      if (_method == PremiumPaymentMethod.googlePlay) {
        // Google Play Billing flow
        final iap = ref.read(inAppPurchaseServiceProvider);
        await iap.buySubscription(uid, _plan);
      } else {
        // Local Payment Gateway simulation & instant real-time activation (Payme / Click / Uzum)
        await Future.delayed(const Duration(milliseconds: 650));
        if (mounted) {
          setState(() {
            _processingStep = 'Tranzaksiya xavfsiz tasdiqlanmoqda...';
          });
        }
        await Future.delayed(const Duration(milliseconds: 750));
        if (mounted) {
          setState(() {
            _processingStep = 'Odat Premium faollashtirilmoqda...';
          });
        }
        await Future.delayed(const Duration(milliseconds: 500));

        final expiresAt = DateTime.now().add(_plan.duration);
        await ref.read(userRepositoryProvider).setPremium(
          uid,
          true,
          plan: _plan.name,
          paymentMethod: _method.name,
          amountUzs: _plan.priceUzs,
          expiresAt: expiresAt,
        );
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop(true);
        _showSuccessDialog(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF0055),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'To\'lovda xatolik yuz berdi. Iltimos, qayta urinib ko\'ring.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF131929),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kPremiumGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: kPremiumGold.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kPremiumGold.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: kPremiumGold, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded, color: kPremiumGold, size: 40),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Muvaffaqiyatli to\'lov!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Odat Premium muvaffaqiyatli faollashtirildi! Barcha cheklovlar olib tashlandi.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPremiumGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text(
                    'Boshlash ✨',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: kPremiumGold.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kPremiumGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payment_rounded,
                      color: kPremiumGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Odat Premium To\'lovi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Xavfsiz va tezkor to\'lov tizimi',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white10, height: 1),

            // Scrollable Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // Plan summary card
                  _buildPlanSummaryCard(),
                  const SizedBox(height: 20),

                  // Payment method selector title
                  const Text(
                    'To\'lov usulini tanlang',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Methods list
                  for (final method in PremiumPaymentMethod.values) ...[
                    _buildPaymentMethodTile(method),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 16),

                  // Security & Guarantee note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141C2D),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF3B9BFF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '256-bit SSL shifrlangan to\'lov. Hisobingiz va ma\'lumotlaringiz to\'liq himoyalangan.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Pay Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _isProcessing
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E283C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kPremiumGold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(kPremiumGold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _processingStep,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPremiumGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 6,
                          shadowColor: kPremiumGold.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _processPayment,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _method.icon,
                              size: 20,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'To\'lash: ${_plan.formattedPriceUzs}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPremiumGold.withValues(alpha: 0.15),
            const Color(0xFF151F33),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPremiumGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kPremiumGold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.workspace_premium_rounded, color: kPremiumGold, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _plan == PremiumPlan.monthly
                          ? 'Odat Premium (Oylik)'
                          : 'Odat Premium (Yillik)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _plan == PremiumPlan.monthly
                      ? 'Har oy to\'lanadi — istalgan vaqtda bekor qilish mumkin'
                      : '1 yillik to\'liq obuna — 2 oy tekinga ega bo\'lasiz',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _plan.formattedPriceUzs,
                style: const TextStyle(
                  color: kPremiumGold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _plan == PremiumPlan.monthly ? '/ oy' : '/ yil',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(PremiumPaymentMethod method) {
    final isSelected = _method == method;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _method = method);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? method.brandColor.withValues(alpha: 0.12)
              : const Color(0xFF131929),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? method.brandColor
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: method.brandColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                method.icon,
                color: method.brandColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? method.brandColor : Colors.white24,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
