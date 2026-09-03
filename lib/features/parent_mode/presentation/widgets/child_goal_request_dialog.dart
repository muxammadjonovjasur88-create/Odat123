import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../domain/family_goal_models.dart';
import '../providers/family_goals_provider.dart';

class ChildGoalRequestDialog extends ConsumerWidget {
  const ChildGoalRequestDialog({
    super.key,
    required this.goal,
  });

  final FamilyGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1420),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A7FCC).withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3A7FCC).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.family_restroom_rounded, color: Color(0xFF3A7FCC), size: 36),
            ),
            const SizedBox(height: 16),

            // Header
            Text(
              'family.new_goal_from'.tr(args: [goal.parentName]),
              style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Goal Title
            Text(
              goal.title,
              style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Goal Details Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF090B18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.access_time_rounded, 'Vaqt', goal.scheduledTime),
                  const Divider(color: Colors.white10, height: 16),
                  _buildDetailRow(Icons.track_changes_rounded, 'Hajm', '${goal.targetValue} ${goal.unit}'),
                  const Divider(color: Colors.white10, height: 16),
                  _buildDetailRow(Icons.monetization_on_rounded, 'Mukofot', '+${goal.rewardCoins} Fenix Coin', isGold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notice
            Text(
              'family.goal_auto_reminder_notice'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Actions (Accept / Decline)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(familyGoalsProvider.notifier).declineGoal(goal.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('family.goal_declined_toast'.tr()),
                          backgroundColor: const Color(0xFF2C161D),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'family.decline'.tr(),
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BouncyScale(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      ref.read(familyGoalsProvider.notifier).acceptGoal(goal.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('family.goal_accepted_toast'.tr()),
                          backgroundColor: const Color(0xFF0F3822),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3A7FCC), Color(0xFF00C853)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3A7FCC).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'family.accept'.tr(),
                          style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isGold = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isGold ? const Color(0xFFFFB703) : const Color(0xFF4AADDC)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: isGold ? const Color(0xFFFFB703) : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
