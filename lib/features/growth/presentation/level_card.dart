import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../gamification/domain/level_calculator.dart';

/// A calm, circular-progress card that turns total focus minutes into a
/// level-based milestone. The vertical layout with a prominent ring visually
/// differentiates it from the horizontal [StreakCard].
class LevelCard extends ConsumerStatefulWidget {
  const LevelCard({super.key});

  @override
  ConsumerState<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends ConsumerState<LevelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
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
    final profile = ref.watch(userProfileProvider).asData?.value;
    if (profile == null) return const SizedBox.shrink();

    final focusMinutes = profile.totalFocusMinutes;
    final level = LevelCalculator.calculateLevel(focusMinutes);
    final progress = LevelCalculator.levelProgress(focusMinutes);
    final minutesToNext = LevelCalculator.minutesToNextLevel(focusMinutes);
    final progressPercent = (progress * 100).round().clamp(0, 100);
    final currentLevelMinutes =
        LevelCalculator.minutesInCurrentLevel(focusMinutes);
    final currentLevelTarget =
        LevelCalculator.minutesForCurrentLevelGoal(focusMinutes);

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: AppCard(
        color: colors.tintSage,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // ── Level chip label ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'growth.level_title'
                    .tr(namedArgs: {'level': '$level'})
                    .toUpperCase(),
                style: AppTextStyles.overline.copyWith(
                  color: colors.primary,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Circular progress ring with level number ──
            AnimatedBuilder(
              animation: curvedAnimation,
              builder: (context, child) {
                return SizedBox(
                  width: 82,
                  height: 82,
                  child: CustomPaint(
                    painter: _CircularProgressPainter(
                      progress: progress * curvedAnimation.value,
                      trackColor: colors.surfaceMuted,
                      progressColor: colors.primary,
                      glowColor: colors.primary.withValues(alpha: 0.25),
                      strokeWidth: 6,
                    ),
                    child: Center(
                      child: Text(
                        '$level',
                        style: AppTextStyles.display.copyWith(
                          fontSize: 28,
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // ── Percentage (shown only ONCE) ──
            Text(
              '$progressPercent%',
              style: AppTextStyles.h3.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),

            // ── Minutes progress (without percent) ──
            Text(
              'growth.level_progress_summary'.tr(
                namedArgs: {
                  'current': '$currentLevelMinutes',
                  'target': '$currentLevelTarget',
                },
              ),
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),

            // ── Next level info ──
            Text(
              minutesToNext <= 0
                  ? 'growth.level_complete'.tr()
                  : 'growth.next_level'.tr(
                      namedArgs: {'minutes': '$minutesToNext'},
                    ),
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a circular track with a progress arc and subtle glow.
class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.glowColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final Color glowColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (background circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    // Glow behind the progress arc
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      trackColor != oldDelegate.trackColor ||
      progressColor != oldDelegate.progressColor;
}
