import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Visual treatment for a streak length — the flame grows and changes color as
/// the streak gets longer.
class StreakVisual {
  const StreakVisual({
    required this.color,
    required this.scale,
    required this.label,
  });

  final Color color;

  /// Multiplier on the base flame size (longer streak → bigger flame).
  final double scale;
  final String label;
}

StreakVisual streakVisual(int streak) {
  if (streak >= 100) {
    return const StreakVisual(
      color: Color(0xFF6FA8DC),
      scale: 1.5,
      label: 'Inner fire',
    );
  }
  if (streak >= 30) {
    return const StreakVisual(
      color: Color(0xFFE3B23C),
      scale: 1.35,
      label: 'Steady flame',
    );
  }
  if (streak >= 7) {
    return const StreakVisual(
      color: Color(0xFFF2994A),
      scale: 1.18,
      label: 'Burning bright',
    );
  }
  if (streak >= 1) {
    return const StreakVisual(
      color: Color(0xFFE08A4B),
      scale: 1.0,
      label: 'Getting started',
    );
  }
  return const StreakVisual(
    color: Color(0xFFB5B2A8),
    scale: 0.9,
    label: 'No streak yet',
  );
}

/// A streak flame whose size, color and glow scale with [streak]. Gently
/// pulses to feel alive and mirrors the calm palette of the home cards.
class StreakFlame extends StatefulWidget {
  const StreakFlame({super.key, required this.streak, this.size = 40});

  final int streak;

  /// Base size; the flame scales up from here per [streakVisual].
  final double size;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = streakVisual(widget.streak);
    final active = widget.streak > 0;
    final iconSize = widget.size * v.scale;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final glowStrength = active ? (0.28 + 0.2 * t) : 0.0;
        final pulse = active ? (1.0 + 0.05 * t) : 1.0;
        return SizedBox(
          width: iconSize * 1.7,
          height: iconSize * 1.7,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: v.color.withValues(alpha: glowStrength * 0.45),
                    blurRadius: iconSize * 0.75,
                    spreadRadius: iconSize * 0.12,
                  ),
                  BoxShadow(
                    color: v.color.withValues(alpha: glowStrength * 0.18),
                    blurRadius: iconSize * 1.2,
                    spreadRadius: iconSize * 0.2,
                  ),
                ],
              ),
              child: Transform.scale(
                scale: pulse,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: v.color,
                  size: iconSize,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small "frozen flame" chip showing the number of available streak freezes.
class StreakFreezeChip extends StatelessWidget {
  const StreakFreezeChip({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const frost = Color(0xFF6CA8C9);
    final tooltipText = 'streak.freeze_tooltip'.tr();

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tooltipText,
              style: AppTextStyles.caption.copyWith(color: colors.onPrimary),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.primaryPressed,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Tooltip(
        message: tooltipText,
        preferBelow: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.tintSage.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ac_unit_rounded, size: 16, color: frost),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent Home streak banner: a growing flame, the day count, and the
/// available freezes. Tapping opens the profile (where freezes can be bought).
class StreakCard extends StatefulWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.freezes,
    this.onTap,
  });

  final int streak;
  final int freezes;
  final VoidCallback? onTap;

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasStreak = widget.streak > 0;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
      child: AppCard(
        onTap: widget.onTap,
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Center(child: StreakFlame(streak: widget.streak, size: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.streak}',
                        style: AppTextStyles.display.copyWith(
                          fontSize: 30,
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'streak.day_suffix'.tr(),
                        style: AppTextStyles.label.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasStreak
                        ? 'streak.desc_active'.tr()
                        : 'streak.desc_inactive'.tr(),
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StreakFreezeChip(count: widget.freezes, onTap: widget.onTap),
          ],
        ),
      ),
    );
  }
}
