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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x224AADDC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xAA4AADDC), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x224AADDC),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bolt_rounded,
              color: Color(0xFF4AADDC),
              size: 15,
            ),
            const SizedBox(width: 3),
            Text(
              '$formattedPoints PTS',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Color(0xFF4AADDC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.black,
                size: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
