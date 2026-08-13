import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/shop_repository.dart';
import '../../domain/models/shop_item.dart';

class ShippingFormScreen extends ConsumerStatefulWidget {
  const ShippingFormScreen({
    super.key,
    required this.item,
  });

  final ShopItem item;

  static bool validateUzPhone(String phone) {
    if (phone.trim().isEmpty) return false;
    final clean = phone.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    final regex = RegExp(r'^(\+?998)?\d{9}$');
    return regex.hasMatch(clean);
  }

  @override
  ConsumerState<ShippingFormScreen> createState() => _ShippingFormScreenState();
}


class _ShippingFormScreenState extends ConsumerState<ShippingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).asData?.value;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _phoneController = TextEditingController(text: '+998 ');
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  static bool validateUzPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    final regex = RegExp(r'^(\+?998)?\d{9}$');
    return regex.hasMatch(clean);
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final userProfile = ref.read(userProfileProvider).asData?.value;
    final currentPoints = userProfile?.totalPoints ?? 0;

    if (currentPoints < widget.item.pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ochkolaringiz yetarli emas! Sizda: $currentPoints'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(shopRepositoryProvider);
      await repo.purchaseGift(
        shopItemId: widget.item.id,
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSuccessDialog();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.purpleAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Buyurtmangiz qabul qilindi!',
              style: AppTextStyles.h2.copyWith(color: ctx.colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'Sovg\'angiz tayyorlanmoqda. Tez orada yetkazib berish bo\'yicha siz bilan bog\'lanamiz.',
          style: AppTextStyles.body.copyWith(color: ctx.colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.shopPurchases);
            },
            child: const Text(
              'Xaridlarni ko\'rish',
              style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.shop);
            },
            child: const Text('Bosh sahifa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yetkazib berish ma\'lumotlari',
                  style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Buyurtmani yetkazib berish uchun quyidagi shaklni to\'ldiring',
                  style: AppTextStyles.body.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Selected Item Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: item.imageUrl.isNotEmpty
                              ? Image.network(item.imageUrl, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.card_giftcard, color: AppColors.purpleAccent),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.pointsCost} ochko',
                              style: AppTextStyles.caption.copyWith(color: AppColors.cyanAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Full Name Input
                Text(
                  'To\'liq ismingiz',
                  style: AppTextStyles.label.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ism va familiyangizni kiriting',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Iltimos, to\'liq ismingizni kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number Input
                Text(
                  'Telefon raqamingiz',
                  style: AppTextStyles.label.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '+998 90 123 45 67',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    prefixIcon: Icon(Icons.phone_outlined, color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || !validateUzPhone(val)) {
                      return 'Telefon raqamini to\'g\'ri kiriting (+998 9X XXX XX XX)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Delivery Address Input
                Text(
                  'Yetkazib berish manzili',
                  style: AppTextStyles.label.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Viloyat, tuman/shahar, ko\'cha, uy va xonadon raqami...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 5) {
                      return 'Iltimos, yetkazib berish manzilini batafsil kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.purpleAccent))
                    : AppButton(
                        label: 'Tasdiqlash va Buyurtma berish',
                        onPressed: _submitOrder,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
