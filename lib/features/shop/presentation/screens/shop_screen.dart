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
import '../providers/shop_provider.dart';
import '../widgets/shop_item_card.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final itemsAsync = ref.watch(filteredShopItemsProvider);
    final activeFilter = ref.watch(shopFilterProvider);
    final userProfile = ref.watch(userProfileProvider).asData?.value;
    final userPoints = userProfile?.totalPoints ?? 0;

    return Scaffold(
      appBar: FlowaAppBar(
        showBackButton: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Mening xaridlarim',
            icon: const Icon(Icons.shopping_bag_outlined, size: 24),
            color: colors.textPrimary,
            onPressed: () => context.push(AppRoutes.shopPurchases),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Title & Points Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do\'kon',
                          style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ochkolaringizni sovg\'alarga almashtiring',
                          style: AppTextStyles.body.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // User Points Badge
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sportFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.cyanAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SpinningCoin(size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '$userPoints ochko',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.cyanAccent,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  SegmentedFilterChip(
                    label: 'Barchasi',
                    icon: Icons.grid_view_rounded,
                    isSelected: activeFilter == null,
                    onTap: () => ref.read(shopFilterProvider.notifier).setFilter(null),
                  ),
                  const SizedBox(width: 8),
                  SegmentedFilterChip(
                    label: 'Kuponlar',
                    icon: Icons.confirmation_number_outlined,
                    isSelected: activeFilter == ShopItemType.coupon,
                    onTap: () => ref.read(shopFilterProvider.notifier).setFilter(ShopItemType.coupon),
                  ),
                  const SizedBox(width: 8),
                  SegmentedFilterChip(
                    label: 'Sovg\'alar',
                    icon: Icons.card_giftcard_rounded,
                    isSelected: activeFilter == ShopItemType.gift,
                    onTap: () => ref.read(shopFilterProvider.notifier).setFilter(ShopItemType.gift),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Main Catalog Grid
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ShopItemCard(
                        item: item,
                        onTap: () {
                          if (item.isCoupon) {
                            context.push(AppRoutes.couponDetail, extra: item);
                          } else {
                            context.push(AppRoutes.giftDetail, extra: item);
                          }
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.cyanAccent),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.redAccent.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Katalog yuklanishida xatolik',
                          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString().replaceAll('ShopException: ', ''),
                          style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(shopItemsProvider),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Qayta urinish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 64,
            color: colors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Hozircha mahsulotlar mavjud emas',
            style: AppTextStyles.h3.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Tez orada yangi chegirmalar va sovg\'alar qo\'shiladi',
            style: AppTextStyles.caption.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
