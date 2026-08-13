import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/shop_provider.dart';

class MyPurchasesScreen extends ConsumerStatefulWidget {
  const MyPurchasesScreen({super.key});

  @override
  ConsumerState<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends ConsumerState<MyPurchasesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: FlowaAppBar(
        showBackButton: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
          onPressed: () => context.pop(),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Mening xaridlarim',
                    style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),

            // Segmented Control Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  SegmentedFilterChip(
                    label: 'Kuponlarim',
                    icon: Icons.confirmation_number_outlined,
                    isSelected: _tabController.index == 0,
                    expanded: true,
                    transparentInactive: true,
                    onTap: () => _tabController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SegmentedFilterChip(
                    label: 'Sovg\'alarim',
                    icon: Icons.card_giftcard_rounded,
                    isSelected: _tabController.index == 1,
                    expanded: true,
                    transparentInactive: true,
                    onTap: () => _tabController.animateTo(
                      1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CouponsTabView(),
                  _GiftsTabView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponsTabView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(purchasedCouponsProvider);
    final colors = context.colors;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return couponsAsync.when(
      data: (coupons) {
        if (coupons.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.confirmation_number_outlined,
            message: 'Sizda hali sotib olingan kuponlar mavjud emas',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: coupons.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final coupon = coupons[index];
            final item = coupon.shopItem;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item?.title ?? 'Chegirma Kuponi',
                          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateFormat.format(coupon.purchasedAt),
                        style: AppTextStyles.caption.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                  if (item?.partnerName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item!.partnerName!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.cyanAccent),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Code Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SelectableText(
                          coupon.couponCode,
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.cyanAccent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.cyanAccent),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: coupon.couponCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Promo kod nusxalandi!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent)),
      error: (err, _) => Center(child: Text('Xatolik: $err', style: TextStyle(color: colors.textSecondary))),
    );
  }
}

class _GiftsTabView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(giftOrdersProvider);
    final colors = context.colors;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return giftsAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.card_giftcard_rounded,
            message: 'Sizda hali sovg\'a buyurtmalari mavjud emas',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final item = order.shopItem;
            final status = order.status;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item?.title ?? 'Sovg\'a buyurtmasi',
                          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: status.color.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, size: 14, color: status.color),
                            const SizedBox(width: 4),
                            Text(
                              status.labelUz,
                              style: TextStyle(
                                color: status.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Delivery Address
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: colors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.address,
                          style: AppTextStyles.body.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Date
                  Text(
                    'Sana: ${dateFormat.format(order.createdAt)}',
                    style: AppTextStyles.caption.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.purpleAccent)),
      error: (err, _) => Center(child: Text('Xatolik: $err', style: TextStyle(color: colors.textSecondary))),
    );
  }
}

Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message}) {
  final colors = context.colors;
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceMuted,
              border: Border.all(
                color: AppColors.cyanAccent.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 38,
              color: AppColors.cyanAccent.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Do\'kondan yangi xaridlarni amalga oshirishingiz mumkin',
            style: AppTextStyles.caption.copyWith(color: colors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
