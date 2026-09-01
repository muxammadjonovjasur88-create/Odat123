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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x22FFB703),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xAAFFB703), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22FFB703),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFFFB703),
              size: 15,
            ),
            const SizedBox(width: 4),
            Text(
              formattedCoins,
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
                color: Color(0xFFFFB703),
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
