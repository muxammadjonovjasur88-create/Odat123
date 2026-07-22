import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/streak_badge.dart';

/// Shows the full-screen milestone celebration for a newly-earned [badge].
Future<void> showStreakMilestone(BuildContext context, StreakBadge badge) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: badge.name,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, _, _) => _MilestoneDialog(badge: badge),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: Transform.scale(
          scale: 0.9 + 0.1 * curved.value,
          child: child,
        ),
      );
    },
  );
}

class _MilestoneDialog extends StatelessWidget {
  const _MilestoneDialog({required this.badge});

  final StreakBadge badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingBadge(badge: badge),
              const SizedBox(height: 24),
              Text(
                '${badge.days} days in a row!',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                badge.message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '“${badge.name}” badge earned',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Continue',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The badge medallion with a slow, calm breathing glow.
class _PulsingBadge extends StatefulWidget {
  const _PulsingBadge({required this.badge});

  final StreakBadge badge;

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.badge.color.withValues(alpha: 0.35),
            boxShadow: [
              BoxShadow(
                color: widget.badge.color.withValues(alpha: 0.3 + 0.3 * t),
                blurRadius: 28 + 14 * t,
                spreadRadius: 2 + 4 * t,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.badge.color,
              ),
              child: Icon(
                widget.badge.icon,
                size: 36,
                color: colors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
