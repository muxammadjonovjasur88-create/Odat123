import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Screen 02 — three-slide intro carousel ending in "Get Started".
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  // Image + translation-key prefix per slide; titles/bodies are resolved at
  // build time so they follow the chosen language.
  static const _slides = [
    (image: 'assets/images/onboarding/onboard1.png', key: 'plan'),
    (image: 'assets/images/onboarding/onboard2.png', key: 'focus'),
    (image: 'assets/images/onboarding/onboard3.png', key: 'grow'),
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 18),
              const BrandLogo(),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final slide = _slides[i];
                    return _Slide(
                      image: slide.image,
                      title: 'discover.${slide.key}_title'.tr(),
                      body: 'discover.${slide.key}_body'.tr(),
                    );
                  },
                ),
              ),
              _Dots(count: _slides.length, active: _page, colors: colors),
              const SizedBox(height: 36),
              AppButton(
                label: 'common.get_started'.tr(),
                onPressed: () => context.push(AppRoutes.signIn),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.push(AppRoutes.signIn),
                child: Text.rich(
                  TextSpan(
                    text: 'discover.have_account'.tr(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'common.sign_in'.tr(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.image, required this.title, required this.body});

  final String image;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Scale the illustration with the screen, kept large but bounded so it
    // never overflows the card on small phones.
    final illustrationSize = (MediaQuery.sizeOf(context).width * 0.52).clamp(
      170.0,
      260.0,
    );
    return Center(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        radius: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              image,
              width: illustrationSize,
              height: illustrationSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.active,
    required this.colors,
  });

  final int count;
  final int active;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? colors.primary : colors.textTertiary,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
