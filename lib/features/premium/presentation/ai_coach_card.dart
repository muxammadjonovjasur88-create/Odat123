import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../gamification/data/gamification_repository.dart';
import '../data/premium_providers.dart';
import '../domain/ai_coach.dart';
import 'premium_badge.dart';

/// Premium "AI Coach" card — a short daily, personalized nudge built from the
/// user's recent habits. Shown on the Progress screen for premium users only.
/// Render it behind `kPremiumEnabled && isPremium` at the call site.
class AiCoachCard extends ConsumerWidget {
  const AiCoachCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final today = ref.watch(todayStatsProvider).asData?.value;
    final week = ref.watch(weekStatsProvider).asData?.value ?? const [];

    final weekMinutes = week.fold<int>(0, (s, d) => s + d.focusMinutes);
    // mostProductiveLabel returns a translation key; resolve it to a word so the
    // coach line can interpolate it in the current language.
    final productiveKey = mostProductiveLabel(week);
    final tip = dailyCoachTip(
      CoachInput(
        name: profile?.name ?? '',
        streak: profile?.streak ?? 0,
        completedToday: today?.completed ?? 0,
        totalToday: today?.total ?? 0,
        weekMinutes: weekMinutes,
        productiveLabel: productiveKey?.tr(),
      ),
      daySeed: coachDaySeed(DateTime.now()),
    );

    return AppCard(
      color: colors.tintSage,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'premium.ai_coach'.tr(),
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(width: 8),
              const PremiumBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            tip.key.tr(namedArgs: tip.args),
            style: AppTextStyles.body.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
