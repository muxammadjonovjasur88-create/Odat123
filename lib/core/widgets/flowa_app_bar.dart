import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_theme.dart';
import '../../features/streak/presentation/streak_header_badge.dart';

/// Displays no text-based screen titles, keeping a clean, minimalist layout.
/// Features a Shop/Store icon (`Icons.storefront_outlined`).
class FlowaAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const FlowaAppBar({
    super.key,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.coins,
    this.leading,
    this.showStreak = true,
  });

  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final int? coins;
  final Widget? leading;
  final bool showStreak;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

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
    } else if (showStreak) {
      leadingWidget = const StreakHeaderBadge();
    } else {
      leadingWidget = const SizedBox.shrink();
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
              // Shop / Store icon
              IconButton(
                tooltip: 'Shop',
                icon: const Icon(Icons.storefront_outlined, size: 24),
                color: colors.textPrimary,
                onPressed: () {
                  try {
                    context.push(AppRoutes.shop);
                  } catch (_) {}
                },
              ),

              if (actions != null) ...actions!,
            ],
          ),
        ],
      ),
    );
  }
}
