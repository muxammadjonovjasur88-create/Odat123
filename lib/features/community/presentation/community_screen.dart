import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../growth/presentation/self_growth_card.dart';

/// Screen 16 — Community. There is NO global, app-wide ranking of all users:
/// the only competitive leaderboard lives inside private lobbies (ranked by
/// weekly honest points). Here we show the user's own growth (the main,
/// non-competitive motivator) and an entry to their small-group lobbies.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.leaderboard,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              children: [
                if (context.canPop())
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.textPrimary,
                    ),
                  ),
                const BrandLogo(),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'community.your_circle'.tr(),
                style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'community.your_circle_sub'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            // Personal weekly growth — the main, non-competitive motivator.
            const SelfGrowthCard(),
            const SizedBox(height: 16),
            const _GlobalLeaderboardEntry(),
            const SizedBox(height: 12),
            // Private lobbies for small group competition.
            const _LobbiesEntry(),
          ],
        ),
      ),
    );
  }
}

class _GlobalLeaderboardEntry extends StatelessWidget {
  const _GlobalLeaderboardEntry();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.surface,
      onTap: () => context.push(AppRoutes.leaderboard),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.tintSage,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: colors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'leaderboard.title'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Barcha foydalanuvchilar va umumiy ballar reytingi',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}

/// Entry point to the private competition lobbies — the only place a ranked,
/// points-based leaderboard appears (a small, friendly group).
class _LobbiesEntry extends StatelessWidget {
  const _LobbiesEntry();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.tintSage,
      onTap: () => context.push(AppRoutes.lobbies),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_rounded, color: colors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'community.private_lobbies'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'community.private_lobbies_sub'.tr(),
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}
