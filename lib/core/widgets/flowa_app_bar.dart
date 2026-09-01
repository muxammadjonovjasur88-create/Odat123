import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_theme.dart';
import 'beta_ticker_banner.dart';
import '../../features/shop/presentation/widgets/fenix_coin_badge.dart';
import 'total_points_badge.dart';

/// Flowa top navigation bar.
/// Features a minimalist logo/back button on the left, and Total PTS + Fenix Coins balance + Shop on the right.
/// Includes the yellow animated BetaTickerBanner by default on all screens.
class FlowaAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const FlowaAppBar({
    super.key,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.coins,
    this.leading,
    this.showFenixCoins = true,
    this.showShopButton = true,
    this.showBetaBanner = true,
  });

  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final int? coins;
  final Widget? leading;
  final bool showFenixCoins;
  final bool showShopButton;
  final bool showBetaBanner;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (showBetaBanner ? 26.0 : 0.0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    bool canNavigateBack = showBackButton;
    if (!canNavigateBack) {
      try {
        canNavigateBack = context.canPop();
      } catch (_) {
        canNavigateBack = ModalRoute.of(context)?.canPop ?? false;
      }
    }

    Widget leadingWidget;
    if (leading != null) {
      leadingWidget = leading!;
    } else if (canNavigateBack) {
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: colors.textPrimary,
        onPressed: onBack ??
            () {
              try {
                context.pop();
              } catch (_) {
                Navigator.of(context).maybePop();
              }
            },
      );
    } else {
      leadingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5BC8FA), Color(0xFF3B9BFF)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'ODAT',
          style: TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: colors.background, // Color(0xFF0B0F19)
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leadingWidget,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total PTS Balance
              const TotalPointsBadge(),
              const SizedBox(width: 4),

              // Fenix Coin Balance with Top-Up Button
              if (showFenixCoins) ...[
                const FenixCoinBadge(),
                const SizedBox(width: 2),
              ],

              // Shop / Store icon
              if (showShopButton)
                IconButton(
                  tooltip: 'Do‘kon',
                  icon: const Icon(Icons.storefront_outlined, size: 20),
                  color: colors.textPrimary,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    try {
                      context.push(AppRoutes.shop);
                    } catch (_) {}
                  },
                ),

              ...?actions,
            ],
          ),
        ],
      ),
      bottom: showBetaBanner
          ? const PreferredSize(
              preferredSize: Size.fromHeight(26),
              child: BetaTickerBanner(),
            )
          : null,
    );
  }
}
