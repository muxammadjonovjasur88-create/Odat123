import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/formatting.dart';

import '../../features/shop/presentation/widgets/pts_exchange_modal.dart';
import '../services/user_repository.dart';

/// Top bar badge showing the user's total PTS (ballar/ochkolar) balance with a quick "+" exchange button.
class TotalPointsBadge extends ConsumerWidget {
  const TotalPointsBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final points = user?.totalPoints ?? 0;

    final formattedPoints = formatCompactNumber(points);

    return InkWell(
      onTap: () => showPtsExchangeModal(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2335),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF222B40), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bolt_rounded,
              color: Color(0xFF38BDF8),
              size: 15,
            ),
            const SizedBox(width: 4),
            Text(
              '$formattedPoints PTS',
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF38BDF8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.black,
                size: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
