import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/subscription_models.dart';
import '../providers/subscription_providers.dart';

class SubscriptionPaywallScreen extends ConsumerStatefulWidget {
  const SubscriptionPaywallScreen({super.key});

  @override
  ConsumerState<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends ConsumerState<SubscriptionPaywallScreen> {
  BillingCycle _selectedCycle = BillingCycle.yearly;
  SubscriptionPlanTier _selectedTier = SubscriptionPlanTier.pro;

  @override
  Widget build(BuildContext context) {
    ref.watch(userSubscriptionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await ref.read(userSubscriptionProvider.notifier).restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('sub.restored_msg'.tr())),
                );
              }
            },
            child: Text(
              'sub.restore'.tr(),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // Header
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x33FFB703),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB703), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'ODAT PREMIUM',
                    style: TextStyle(color: Color(0xFFFFB703), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'sub.headline'.tr(),
            style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'sub.subtitle'.tr(),
            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Monthly / Yearly Cycle Switcher
          _buildCycleToggle(),
          const SizedBox(height: 20),

          // Plan Cards: PRO vs FAMILY
          _buildPlanCard(
            tier: SubscriptionPlanTier.pro,
            badge: 'sub.most_popular'.tr(),
            badgeColor: const Color(0xFFFFB703),
            title: 'ODAT PRO',
            subtitle: 'sub.pro_tagline'.tr(),
            monthlyPrice: '59,900 UZS / oy',
            yearlyPrice: '499,000 UZS / yil',
            yearlyEquiv: '~41,600 UZS / oy (-30%)',
            features: [
              'sub.feat_full_ai'.tr(),
              'sub.feat_full_play2'.tr(),
              'sub.feat_strict_discipline'.tr(),
              'sub.feat_unlimited_habits'.tr(),
            ],
          ),
          const SizedBox(height: 14),

          _buildPlanCard(
            tier: SubscriptionPlanTier.family,
            badge: 'sub.best_for_families'.tr(),
            badgeColor: const Color(0xFF3B9BFF),
            title: 'ODAT FAMILY',
            subtitle: 'sub.family_tagline'.tr(),
            monthlyPrice: '99,900 UZS / oy',
            yearlyPrice: '799,000 UZS / yil',
            yearlyEquiv: '~66,600 UZS / oy (-33%)',
            features: [
              'sub.feat_all_pro'.tr(),
              'sub.feat_parent_mode'.tr(),
              'sub.feat_family_missions'.tr(),
              'sub.feat_ai_study_reports'.tr(),
              'sub.feat_safe_zones'.tr(),
            ],
          ),
          const SizedBox(height: 24),

          // CTA: 7 DAYS FREE TRIAL
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await ref.read(userSubscriptionProvider.notifier).start7DayTrial(_selectedTier);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF3B9BFF),
                    content: Text(
                      'sub.trial_activated_msg'.tr(),
                      style: const TextStyle(color: Color(0xFF080B14), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B9BFF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFF080B14), size: 20),
                const SizedBox(width: 8),
                Text(
                  'sub.cta_try_free'.tr(),
                  style: const TextStyle(color: Color(0xFF080B14), fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Transparent Terms Disclaimer
          Text(
            'sub.trial_terms_disclaimer'.tr(),
            style: const TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCycleToggle() {
    final isYearly = _selectedCycle == BillingCycle.yearly;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCycle = BillingCycle.monthly);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isYearly ? const Color(0xFF1A263E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'sub.cycle_monthly'.tr(),
                  style: TextStyle(
                    color: !isYearly ? Colors.white : Colors.white54,
                    fontWeight: !isYearly ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCycle = BillingCycle.yearly);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isYearly ? const Color(0xFF1A263E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'sub.cycle_yearly'.tr(),
                      style: TextStyle(
                        color: isYearly ? Colors.white : Colors.white54,
                        fontWeight: isYearly ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B9BFF),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        '-30%',
                        style: TextStyle(color: Color(0xFF080B14), fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlanTier tier,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String monthlyPrice,
    required String yearlyPrice,
    required String yearlyEquiv,
    required List<String> features,
  }) {
    final isSelected = _selectedTier == tier;
    final isYearly = _selectedCycle == BillingCycle.yearly;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTier = tier);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF121B2C) : const Color(0xFF0C1320),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? badgeColor : Colors.white10,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: badgeColor.withValues(alpha: 0.15), blurRadius: 16)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? badgeColor : Colors.white30,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  isYearly ? yearlyPrice : monthlyPrice,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                if (isYearly) ...[
                  const SizedBox(width: 8),
                  Text(
                    yearlyEquiv,
                    style: const TextStyle(color: Color(0xFF3B9BFF), fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF3B9BFF), size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
