import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/shop_repository.dart';
import '../../domain/models/shop_item.dart';

class CouponDetailScreen extends ConsumerStatefulWidget {
  const CouponDetailScreen({
    super.key,
    required this.item,
  });

  final ShopItem item;

  @override
  ConsumerState<CouponDetailScreen> createState() => _CouponDetailScreenState();
}

class _CouponDetailScreenState extends ConsumerState<CouponDetailScreen> {
  bool _isLoading = false;

  Future<void> _handlePurchase() async {
    final userProfile = ref.read(userProfileProvider).asData?.value;
    final currentPoints = userProfile?.totalPoints ?? 0;

    if (currentPoints < widget.item.pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'shop.insufficient_points'.tr(namedArgs: {
              'current': currentPoints.toString(),
              'required': widget.item.pointsCost.toString(),
            }),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: Text(
          'shop.purchase_coupon'.tr(),
          style: AppTextStyles.h2.copyWith(color: ctx.colors.textPrimary),
        ),
        content: Text(
          'shop.confirm_purchase'.tr(namedArgs: {
            'title': widget.item.title,
            'points': widget.item.pointsCost.toString(),
          }),
          style: AppTextStyles.body.copyWith(color: ctx.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr(), style: TextStyle(color: ctx.colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('shop.buy_button'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(shopRepositoryProvider);
      final couponCode = await repo.purchaseCoupon(widget.item.id);

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSuccessDialog(couponCode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog(String couponCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.cyanAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'shop.purchase_success'.tr(),
              style: AppTextStyles.h2.copyWith(color: ctx.colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'shop.promo_code_label'.tr(),
              style: AppTextStyles.body.copyWith(color: ctx.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ctx.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SelectableText(
                      couponCode,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.cyanAccent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.cyanAccent),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: couponCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('shop.promo_copied'.tr()),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'shop.view_in_my_purchases'.tr(),
              style: AppTextStyles.caption.copyWith(color: ctx.colors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'common.understood'.tr(),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;
    final userProfile = ref.watch(userProfileProvider).asData?.value;
    final userPoints = userProfile?.totalPoints ?? 0;
    final canAfford = userPoints >= item.pointsCost;

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
                    // Coupon Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildImage(item.imageUrl),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Partner Name & Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (item.partnerName != null && item.partnerName!.isNotEmpty)
                          Text(
                            item.partnerName!,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.cyanAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (item.discountText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.sportFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.discountText!,
                              style: const TextStyle(
                                color: AppColors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

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
                                    'Xarid narxi',
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
                      'Tavsif',
                      style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description.isNotEmpty
                          ? item.description
                          : 'Ushbu chegirma kuponini sherik do\'konda promo kod ko\'rinishida ishlatishingiz mumkin.',
                      style: AppTextStyles.body.copyWith(
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Purchase Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent))
                  : AppButton(
                      label: canAfford ? 'Sotib olish' : 'Ochko yetarli emas',
                      onPressed: canAfford ? _handlePurchase : null,
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
      child: Center(
        child: Icon(
          Icons.confirmation_number_outlined,
          size: 50,
          color: AppColors.cyanAccent.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
