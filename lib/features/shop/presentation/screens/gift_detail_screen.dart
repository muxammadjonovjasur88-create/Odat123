import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/models/shop_item.dart';

class GiftDetailScreen extends ConsumerWidget {
  const GiftDetailScreen({
    super.key,
    required this.item,
  });

  final ShopItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final userProfile = ref.watch(userProfileProvider).asData?.value;
    final userPoints = userProfile?.totalPoints ?? 0;
    final canAfford = userPoints >= item.pointsCost;
    final isOutOfStock = item.isOutOfStock;

    return Scaffold(
      appBar: FlowaAppBar(
        showBackButton: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gift Image (Fuller & wider 4:3)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: _buildImage(item.imageUrl),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Badge (Sovg'a)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.purpleAccent.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.card_giftcard_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Fizik Sovg\'a',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOutOfStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Zaxirada tugadi',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      item.title,
                      style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 16),

                    // Points Cost Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const SpinningCoin(size: 24),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Buyurtma narxi',
                                    style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                                  ),
                                  Text(
                                    '${item.pointsCost} ochko',
                                    style: AppTextStyles.h2.copyWith(color: AppColors.cyanAccent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Sizdagi balans',
                                style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                              ),
                              Text(
                                '$userPoints ochko',
                                style: AppTextStyles.h3.copyWith(
                                  color: canAfford ? colors.textPrimary : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    Text(
                      'Mahsulot haqida',
                      style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description.isNotEmpty
                          ? item.description
                          : 'Ushbu sovg\'a bepul yetkazib beriladi. Buyurtma berish uchun yetkazib berish manzilini kiriting.',
                      style: AppTextStyles.body.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Shipping Note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.studyFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, color: AppColors.cyanAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Eslatma: Buyurtma qabul qilingach, administratorimiz 24-48 soat ichida bog\'lanadi.',
                              style: AppTextStyles.caption.copyWith(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Order Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: AppButton(
                label: isOutOfStock
                    ? 'Stokda tugadi'
                    : (canAfford ? 'Buyurtma berish' : 'Ochko yetarli emas'),
                onPressed: (!isOutOfStock && canAfford)
                    ? () => context.push(AppRoutes.shippingForm, extra: item)
                    : null,
              ),
            ),
          ],
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
          color: const Color(0xFF1C2540),
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
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
      color: const Color(0xFF1C2540),
      child: const Center(
        child: Icon(
          Icons.card_giftcard_rounded,
          size: 50,
          color: AppColors.purpleAccent,
        ),
      ),
    );
  }
}
