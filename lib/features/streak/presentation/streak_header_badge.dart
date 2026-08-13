import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import 'streak_flame.dart';

/// A small, compact streak indicator chip designed for app bar / headers.
/// Displays a fire icon + streak count, with styling adapted to current streak value.
class StreakHeaderBadge extends ConsumerWidget {
  const StreakHeaderBadge({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profileAsync = ref.watch(userProfileProvider);
    final streak = profileAsync.asData?.value?.streak ?? 0;

    final visual = streakVisual(streak);
    final isInactive = streak == 0;

    final fireColor = isInactive ? colors.textTertiary : visual.color;
    final bgAlpha = isInactive ? 0.08 : 0.15;
    final bgColor = isInactive
        ? colors.textTertiary.withValues(alpha: bgAlpha)
        : visual.color.withValues(alpha: bgAlpha);

    return InkWell(
      onTap: onTap ??
          () {
            try {
              context.push(AppRoutes.progress);
            } catch (_) {}
          },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInactive
                ? Colors.transparent
                : visual.color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 18,
              color: fireColor,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: AppTextStyles.label.copyWith(
                color: isInactive ? colors.textTertiary : colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
