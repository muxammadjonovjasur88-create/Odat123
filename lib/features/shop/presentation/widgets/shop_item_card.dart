import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_item.dart';

class ShopItemCard extends StatelessWidget {
  const ShopItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final ShopItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOutOfStock = item.isOutOfStock;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isOutOfStock
                  ? colors.border.withValues(alpha: 0.3)
                  : colors.border.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Full Prominent Image Section (Large & Wide)
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(item.imageUrl),

                    // Subtle Bottom Dark Gradient for smooth transition
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              colors.surfaceMuted.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Sold out overlay if out of stock
                    if (isOutOfStock)
                      Container(
                        color: Colors.black.withValues(alpha: 0.65),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Tugadi',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                    // Top Left: Pill Badge (Sovg'a / Kupon)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (item.isCoupon
                                  ? AppColors.cyanAccent
                                  : AppColors.purpleAccent)
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isCoupon
                                  ? Icons.local_offer_rounded
                                  : Icons.card_giftcard_rounded,
                              size: 11,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              item.type.label,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Right: Discount text if present
                    if (item.discountText != null && item.discountText!.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090B18).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.cyanAccent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            item.discountText!,
                            style: const TextStyle(
                              color: AppColors.cyanAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Bottom Content Section (Title lowered down & Big Bold Points)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product Title (Lowered down and clean)
                    Text(
                      item.title,
                      style: AppTextStyles.h3.copyWith(
                        color: isOutOfStock
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Big Prominent Points Badge (Ochko kattaroq va yorqin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4AADDC).withValues(alpha: 0.15),
                            AppColors.purpleAccent.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4AADDC).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFF4AADDC),
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.pointsCost} PTS',
                            style: const TextStyle(
                              color: Color(0xFF4AADDC),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.isEmpty) return _buildPlaceholder();

    if (url.startsWith('data:image') || url.startsWith('data:application')) {
      try {
        final commaIndex = url.indexOf(',');
        final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFF090B18),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.cyanAccent,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C2540),
            Color(0xFF090B18),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          item.isCoupon ? Icons.local_offer_outlined : Icons.card_giftcard_rounded,
          size: 46,
          color: AppColors.cyanAccent.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
