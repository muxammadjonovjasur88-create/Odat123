import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
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
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOutOfStock
                  ? colors.border.withValues(alpha: 0.3)
                  : colors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container with Type Badge & Stock Overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => _buildPlaceholder(),

                            )
                          : _buildPlaceholder(),
                    ),
                  ),

                  // Stock overlay when item is sold out
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(19),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
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
                    ),

                  // Type Badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.isCoupon
                            ? AppColors.cyanAccent.withValues(alpha: 0.9)
                            : AppColors.purpleAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
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
                            size: 12,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.type.label,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Discount / Stock Tag
                  if (item.discountText != null && item.discountText!.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),

                        child: Text(
                          item.discountText!,
                          style: const TextStyle(
                            color: AppColors.cyanAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Item details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.partnerName != null &&
                              item.partnerName!.isNotEmpty) ...[
                            Text(
                              item.partnerName!,
                              style: AppTextStyles.overline.copyWith(
                                color: colors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            item.title,
                            style: AppTextStyles.h3.copyWith(
                              color: isOutOfStock
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Price Tag (Points)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sportFill,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.purpleAccent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SpinningCoin(size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.pointsCost} ochko',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (item.stock != null && !isOutOfStock) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Qoldi: ${item.stock}',
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1E2638),
      child: Center(
        child: Icon(
          item.isCoupon ? Icons.confirmation_number_outlined : Icons.card_giftcard,
          size: 40,
          color: AppColors.cyanAccent.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
