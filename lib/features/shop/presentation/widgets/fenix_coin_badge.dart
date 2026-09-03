import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatting.dart';

import '../../../../core/services/user_repository.dart';
import 'fenix_coin_topup_modal.dart';

/// Top bar badge showing the user's Fenix Coin balance with a quick "+" top-up button.
class FenixCoinBadge extends ConsumerWidget {
  const FenixCoinBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final coins = user?.fenixCoins ?? 0;

    final formattedCoins = formatCompactNumber(coins);

    return InkWell(
      onTap: () => showFenixCoinTopUpModal(context),
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
              Icons.local_fire_department_rounded,
              color: Color(0xFFF59E0B),
              size: 15,
            ),
            const SizedBox(width: 4),
            Text(
              formattedCoins,
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
                color: Color(0xFFF59E0B),
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
