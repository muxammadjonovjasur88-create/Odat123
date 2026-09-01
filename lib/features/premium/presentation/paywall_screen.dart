import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/in_app_purchase_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/premium.dart';
import 'widgets/premium_checkout_sheet.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PremiumPlan _plan = PremiumPlan.monthly; // Default to the requested 40k monthly plan
  bool _starting = false;

  Future<void> _startPremium() async {
    final result = await showPremiumCheckoutSheet(
      context: context,
      initialPlan: _plan,
    );

    if (result == true && mounted) {
      context.pop();
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _starting = true);
    try {
      await ref.read(inAppPurchaseServiceProvider).restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('premium.restored'.tr())));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: kPremiumGoldSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 38,
                        color: kPremiumGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'premium.title'.tr(),
                      style: AppTextStyles.h1.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'premium.subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        for (var i = 0; i < kPremiumBenefits.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _BenefitRow(benefit: kPremiumBenefits[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _PlanCard(
                    title: 'premium.plan_monthly'.tr(),
                    price: kMonthlyPriceLabel.tr(),
                    period: kMonthlyPeriodLabel.tr(),
                    selected: _plan == PremiumPlan.monthly,
                    onTap: () => setState(() => _plan = PremiumPlan.monthly),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    title: 'premium.plan_yearly'.tr(),
                    price: kYearlyPriceLabel.tr(),
                    period: kYearlyPeriodLabel.tr(),
                    saveLabel: kYearlySaveLabel.tr(),
                    selected: _plan == PremiumPlan.yearly,
                    onTap: () => setState(() => _plan = PremiumPlan.yearly),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'premium.start'.tr(),
                    icon: Icons.spa_rounded,
                    loading: _starting,
                    onPressed: _starting ? null : _startPremium,
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _starting ? null : () => context.pop(),
                          child: Text(
                            'premium.maybe_later'.tr(),
                            style: AppTextStyles.label.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(color: colors.textTertiary),
                        ),
                        TextButton(
                          onPressed: _starting ? null : _restorePurchases,
                          child: Text(
                            'premium.restore'.tr(),
                            style: AppTextStyles.label.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'premium.no_charge'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});

  final PremiumBenefit benefit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPremiumGold.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(benefit.icon, size: 20, color: kPremiumGold),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title.tr(),
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                benefit.subtitle.tr(),
                style: AppTextStyles.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.selected,
    required this.onTap,
    this.saveLabel,
  });

  final String title;
  final String price;
  final String period;
  final bool selected;
  final VoidCallback onTap;
  final String? saveLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      border: Border.all(
        color: selected ? kPremiumGold : colors.border,
        width: selected ? 2 : 1.2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? kPremiumGold : colors.textTertiary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
                if (saveLabel != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      saveLabel!,
                      style: AppTextStyles.chip.copyWith(
                        color: const Color(0xFFE5A93C),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                price,
                style: AppTextStyles.label.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w800),
              ),
              Text(
                period,
                style: AppTextStyles.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
