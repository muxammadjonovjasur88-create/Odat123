import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

/// Screen 01 — the launch "sanctuary" splash. Shows the brand, then gently
/// advances to the Discover carousel. Authenticated users are redirected away
/// by the auth gate before this matters.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _logoController.forward();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) context.go(AppRoutes.discover);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxTextWidth = MediaQuery.sizeOf(context).width * 0.8;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _logoController,
                    curve: Curves.easeOutBack,
                  ),
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.tintSage, colors.surfaceMuted],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow,
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.spa_rounded,
                      size: 56,
                      color: AppColors.forest.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Flowa',
                  style: AppTextStyles.h1.copyWith(
                    color: colors.textPrimary,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTextWidth),
                  child: Text(
                    'welcome.tagline'.tr(),
                    style: AppTextStyles.body.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: maxTextWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 2.5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 2.5,
                            backgroundColor: colors.surfaceMuted.withValues(
                              alpha: 0.7,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Dots(colors: colors),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'welcome.preparing'.tr(),
                  style: AppTextStyles.overline.copyWith(
                    color: colors.textTertiary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == 0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 9 : 7,
          height: active ? 9 : 7,
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.textTertiary,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
