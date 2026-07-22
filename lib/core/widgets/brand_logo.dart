import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// The "🌿 Flowa" wordmark used in the top bar of several screens.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fontSize = 18, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.spa_rounded, size: fontSize + 4, color: c),
        const SizedBox(width: 8),
        Text(
          'Flowa',
          style: AppTextStyles.h3.copyWith(
            color: c,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
