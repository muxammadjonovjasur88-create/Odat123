import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../domain/premium.dart';

/// A small gold "Premium" badge shown next to a user's name on the profile,
/// leaderboard, and lobby. Gate visibility at the call site with
/// `kPremiumEnabled && user.isPremium` so it never shows while the system is off.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.showLabel = false, this.size = 15});

  /// When true, renders a gold pill with the word "Premium"; otherwise a
  /// compact gold star chip suitable for tight list rows.
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: kPremiumGold.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.workspace_premium_rounded,
          size: size,
          color: kPremiumGold,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kPremiumGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 14,
            color: kPremiumGold,
          ),
          const SizedBox(width: 5),
          Text(
            'premium.badge'.tr(),
            style: AppTextStyles.chip.copyWith(color: const Color(0xFF8A6D2B)),
          ),
        ],
      ),
    );
  }
}
