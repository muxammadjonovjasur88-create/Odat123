import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/models/shop_item.dart';
import '../providers/shop_provider.dart';
import '../widgets/shop_item_card.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String _selectedTab = 'all'; // 'all', 'boosters', 'coupons', 'gifts'

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(userProfileProvider).asData?.value;
    final userPoints = user?.totalPoints ?? 0;
    final shopItemsAsync = ref.watch(shopItemsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: FlowaAppBar(
        showBackButton: true,
        showShopButton: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: colors.textPrimary,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.dailyPlan);
            }
          },
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF4AADDC),
          backgroundColor: const Color(0xFF090B18),
          onRefresh: () async {
            ref.invalidate(shopItemsProvider);
            ref.invalidate(userProfileProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: Title & Balance ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do‘kon',
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Busterlar, kuponlar va sovg‘alar',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // My Purchases button
                    ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.shopPurchases),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                      label: const Text('Xaridlarim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF121826),
                        foregroundColor: const Color(0xFF38BDF8),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF1E283D)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Category Tabs ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildTabChip('all', 'Barchasi', Icons.grid_view_rounded),
                      const SizedBox(width: 8),
                      _buildTabChip('boosters', '⚡ Busterlar', null),
                      const SizedBox(width: 8),
                      _buildTabChip('coupons', '🎟️ Kuponlar', null),
                      const SizedBox(width: 8),
                      _buildTabChip('gifts', '🎁 Sovg‘alar', null),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Content Sections ──
                if (_selectedTab == 'all' || _selectedTab == 'boosters') ...[
                  _buildSectionHeader('⚡ PTS & STREAK BUSTERLAR', 'Ochkolaringiz evaziga buster va muzlatgichlar oling'),
                  const SizedBox(height: 12),
                  _buildBoostersGrid(context, userPoints, user?.uid ?? ''),
                  const SizedBox(height: 24),
                ],

                if (_selectedTab == 'all' || _selectedTab == 'coupons') ...[
                  _buildSectionHeader('🎟️ CHEGIRMA KUPONLARI', 'Hamkor do‘konlar va xizmatlar uchun promokodlar'),
                  const SizedBox(height: 12),
                  _buildCouponsSection(shopItemsAsync),
                  const SizedBox(height: 24),
                ],

                if (_selectedTab == 'all' || _selectedTab == 'gifts') ...[
                  _buildSectionHeader('🎁 EKSKLYUZIV SOVG‘ALAR', 'Yetkazib beriladigan esdalik sovg‘alari va merch'),
                  const SizedBox(height: 12),
                  _buildGiftsSection(shopItemsAsync),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(String id, String label, IconData? icon) {
    final isSelected = _selectedTab == id;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF121826),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E283D),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.black : const Color(0xFF94A3B8)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8B9BB4),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _buildBoostersGrid(BuildContext context, int userPoints, String uid) {
    final List<Map<String, dynamic>> boosters = [
      {
        'id': 'streak_freeze',
        'title': 'shop.booster_freeze_title'.tr(),
        'desc': 'shop.booster_freeze_desc'.tr(),
        'ptsCost': 300,
        'color': const Color(0xFF38B6FF),
        'action': () => _buyFreeze(context, uid, 1, 300, userPoints),
      },
      {
        'id': 'booster_3x_focus',
        'title': 'shop.booster_3x_title'.tr(),
        'desc': 'shop.booster_3x_desc'.tr(),
        'ptsCost': 750,
        'color': const Color(0xFFFF5252),
        'action': () => _buyBooster(context, uid, 3.0, 720, 750, 'shop.booster_3x_title'.tr(), userPoints),
      },
      {
        'id': 'name_change',
        'title': 'shop.booster_name_title'.tr(),
        'desc': 'shop.booster_name_desc'.tr(),
        'ptsCost': 400,
        'color': const Color(0xFFFFB703),
        'action': () => _buyNameChangePass(context, uid, 400, userPoints),
      },
      {
        'id': 'booster_1_5x',
        'title': 'shop.booster_1_5x_title'.tr(),
        'desc': 'shop.booster_1_5x_desc'.tr(),
        'ptsCost': 250,
        'color': const Color(0xFF3A7FCC),
        'action': () => _buyBooster(context, uid, 1.5, 360, 250, 'shop.booster_1_5x_title'.tr(), userPoints),
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: boosters.length,
      itemBuilder: (ctx, i) {
        final b = boosters[i];
        final ptsCost = b['ptsCost'] as int;
        final canAfford = userPoints >= ptsCost;
        final color = b['color'] as Color;

        final buyText = canAfford
            ? ('shop.buy_action'.tr().isNotEmpty && !'shop.buy_action'.tr().contains('shop.')
                ? 'shop.buy_action'.tr()
                : 'Sotib olish')
            : ('shop.insufficient_pts_btn'.tr().isNotEmpty && !'shop.insufficient_pts_btn'.tr().contains('shop.')
                ? 'shop.insufficient_pts_btn'.tr()
                : 'Yetarli emas');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121826),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E283D), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Title + Price Pill
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Icon(_boosterIcon(b['id'] as String), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      b['title'] as String,
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF182030),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF222B40), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 3),
                        Text(
                          '$ptsCost PTS',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Description (Clean, full width, easy to read)
              Text(
                b['desc'] as String,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Row: Status / Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    canAfford ? 'Hisobingizda mavjud' : 'Ballar yetarli emas',
                    style: TextStyle(
                      color: canAfford ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: canAfford ? () => (b['action'] as VoidCallback)() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAfford ? const Color(0xFF38BDF8) : const Color(0xFF182030),
                        foregroundColor: canAfford ? Colors.black : const Color(0xFF64748B),
                        disabledBackgroundColor: const Color(0xFF182030),
                        disabledForegroundColor: const Color(0xFF64748B),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: canAfford ? const Color(0xFF38BDF8) : const Color(0xFF222B40),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        buyText,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _buyBooster(BuildContext ctx, String uid, double mul, int mins, int cost, String name, int userPoints) async {
    if (userPoints < cost) {
      if (mounted) _showInsufficientPointsDialog(context, cost, userPoints);
      return;
    }

    final confirm = await _showConfirmDialog(context, name, cost);
    if (confirm != true || !mounted) return;

    final success = await ref.read(userRepositoryProvider).buyBoosterWithPts(uid, mul, mins, cost);
    if (!mounted) return;

    if (success) {
      _showSuccessPurchaseDialog(context, '$name muvaffaqiyatli faollashtirildi! ⚡');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('extra.error_purchase'.tr())),
      );
    }
  }

  void _buyFreeze(BuildContext ctx, String uid, int count, int cost, int userPoints) async {
    if (userPoints < cost) {
      if (mounted) _showInsufficientPointsDialog(context, cost, userPoints);
      return;
    }

    final confirm = await _showConfirmDialog(context, '1 ta Streak Muzlatgich', cost);
    if (confirm != true || !mounted) return;

    final success = await ref.read(userRepositoryProvider).buyFreezeWithPts(uid, count, cost);
    if (!mounted) return;

    if (success) {
      _showSuccessPurchaseDialog(context, 'Streak Muzlatgich balansingizga qo‘shildi! ❄️');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('extra.error_purchase'.tr())),
      );
    }
  }

  void _buyNameChangePass(BuildContext ctx, String uid, int cost, int userPoints) async {
    if (userPoints < cost) {
      if (mounted) _showInsufficientPointsDialog(context, cost, userPoints);
      return;
    }

    final confirm = await _showConfirmDialog(context, 'Ism O‘zgartirish Taloni', cost);
    if (confirm != true || !mounted) return;

    final success = await ref.read(userRepositoryProvider).buyNameChangePassWithPts(uid, cost);
    if (!mounted) return;

    if (success) {
      _showSuccessPurchaseDialog(context, 'Ism o‘zgartirish taloni inventaringizga qo‘shildi! 🎒');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('extra.error_purchase'.tr())),
      );
    }
  }

  Future<bool?> _showConfirmDialog(BuildContext ctx, String title, int cost) {
    return showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF4AADDC), width: 1.2),
        ),
        title: const Text('Xaridni tasdiqlang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Haqiqatan ham $cost PTS evaziga "$title"ni xarid qilmoqchimisiz?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Bekor qilish', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4AADDC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Sotib olish', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInsufficientPointsDialog(BuildContext context, int requiredPts, int currentPts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
        ),
        title: Text('extra.insufficient_pts_title'.tr(), style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
        content: Text(
          'extra.purchase_pts_error'.tr(namedArgs: {
            'required': requiredPts.toString(),
            'current': currentPts.toString(),
          }),
          style: const TextStyle(
            color: Colors.white70,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('extra.understand_btn'.tr()),
          ),
        ],
      ),
    );
  }

  void _showSuccessPurchaseDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF3A7FCC), width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Xarid muvaffaqiyatli!',
              style: TextStyle(color: Color(0xFF3A7FCC), fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7FCC),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ajoyib!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponsSection(AsyncValue<List<ShopItem>> shopItemsAsync) {
    return shopItemsAsync.when(
      data: (items) {
        final coupons = items.where((i) => i.isCoupon).toList();
        if (coupons.isEmpty) {
          return _buildEmptyCategoryBox(Icons.confirmation_number_rounded, 'Hozircha kuponlar tez kunda qo‘shiladi');
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: coupons.length,
          itemBuilder: (context, index) {
            final item = coupons[index];
            return ShopItemCard(
              item: item,
              onTap: () => context.push(AppRoutes.couponDetail, extra: item),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4AADDC))),
      error: (_, __) => _buildEmptyCategoryBox(Icons.warning_amber_rounded, 'Kuponlarni yuklashda xatolik', const Color(0xFFFF5252)),
    );
  }

  Widget _buildGiftsSection(AsyncValue<List<ShopItem>> shopItemsAsync) {
    return shopItemsAsync.when(
      data: (items) {
        final gifts = items.where((i) => i.isGift).toList();
        if (gifts.isEmpty) {
          return _buildEmptyCategoryBox(Icons.card_giftcard_rounded, 'Sovg‘alar tez kunda qo‘shiladi');
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: gifts.length,
          itemBuilder: (context, index) {
            final item = gifts[index];
            return ShopItemCard(
              item: item,
              onTap: () => context.push(AppRoutes.giftDetail, extra: item),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4AADDC))),
      error: (_, __) => _buildEmptyCategoryBox(Icons.warning_amber_rounded, 'Sovg‘alarni yuklashda xatolik', const Color(0xFFFF5252)),
    );
  }

  IconData _boosterIcon(String id) {
    switch (id) {
      case 'streak_freeze':
        return Icons.ac_unit_rounded;
      case 'booster_3x_focus':
        return Icons.local_fire_department_rounded;
      case 'name_change':
        return Icons.badge_rounded;
      case 'booster_1_5x':
        return Icons.rocket_launch_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  Widget _buildEmptyCategoryBox(IconData icon, String message, [Color iconColor = Colors.white38]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1626),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
        ],
      ),
    );
  }
}
