import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../features/premium/domain/premium.dart';
import '../../features/shop/domain/fenix_coin_package.dart';
import 'user_repository.dart';

/// Provider for Google Play In-App Purchase Service
final inAppPurchaseServiceProvider = Provider<InAppPurchaseService>((ref) {
  final service = InAppPurchaseService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class InAppPurchaseService {
  InAppPurchaseService(this._ref) {
    _init();
  }

  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  final Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => _products;

  void _init() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('⚠️ [Google Play Billing] Xatolik: $error');
      },
    );
    loadProducts();
  }

  /// Loads available products (Coins + Subscriptions) from Google Play
  Future<void> loadProducts() async {
    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('ℹ️ [Google Play Billing] Do‘kon hozircha mavjud emas.');
        return;
      }

      final productIds = {
        ...kFenixCoinPackages.map((p) => p.id),
        'fenix_50000',
        'fenix_50k',
        'fenix_25000',
        kPremiumMonthlySku,
        kPremiumYearlySku,
      };

      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('⚠️ [Google Play Billing] Mahsulotlarni yuklashda xatolik: ${response.error}');
      }

      _products.clear();
      for (final product in response.productDetails) {
        _products[product.id] = product;
      }
      debugPrint('✅ [Google Play Billing] ${_products.length} ta mahsulot yuklandi.');
    } catch (e) {
      debugPrint('⚠️ [Google Play Billing] loadProducts error: $e');
    }
  }

  /// Initiates Google Play purchase for a coin package
  Future<bool> buyPackage(String userId, FenixCoinPackage pkg) async {
    try {
      // Find matching product detail (supporting aliases like fenix_50000 for 50k)
      ProductDetails? productDetails = _products[pkg.id];
      if (productDetails == null && (pkg.id == 'fenix_25000' || pkg.id == 'fenix_50000')) {
        productDetails = _products['fenix_50000'] ?? _products['fenix_50k'] ?? _products['fenix_25000'];
      }

      if (_isAvailable && productDetails != null) {
        final purchaseParam = PurchaseParam(productDetails: productDetails);
        return await _iap.buyConsumable(
          purchaseParam: purchaseParam,
          autoConsume: true,
        );
      } else {
        // Fallback / Direct Purchase for development & testing
        debugPrint('ℹ️ [Google Play Billing] Test rejimida to‘g‘ridan-to‘g‘ri coin qo‘shilmoqda: ${pkg.totalCoins}');
        await Future.delayed(const Duration(milliseconds: 500));
        await _ref.read(userRepositoryProvider).addFenixCoins(userId, pkg.totalCoins);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [Google Play Billing] Xarid xatosi: $e');
      rethrow;
    }
  }

  /// Initiates Google Play subscription purchase for Premium
  Future<bool> buySubscription(String userId, PremiumPlan plan) async {
    try {
      final sku = plan == PremiumPlan.yearly ? kPremiumYearlySku : kPremiumMonthlySku;
      final productDetails = _products[sku];

      if (_isAvailable && productDetails != null) {
        final purchaseParam = PurchaseParam(productDetails: productDetails);
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Fallback / Direct Purchase for testing
        debugPrint('ℹ️ [Google Play Billing] Test rejimida Premium faollashtirilmoqda ($plan)');
        await Future.delayed(const Duration(milliseconds: 500));
        await _ref.read(userRepositoryProvider).setPremium(userId, true);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [Google Play Billing] Obuna xatosi: $e');
      rethrow;
    }
  }

  /// Restores previous purchases
  Future<void> restorePurchases() async {
    try {
      if (_isAvailable) {
        await _iap.restorePurchases();
      }
    } catch (e) {
      debugPrint('⚠️ [Google Play Billing] Restore error: $e');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ [Google Play Billing] To‘lov kutilmoqda: ${purchaseDetails.productID}');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ [Google Play Billing] To‘lov xatosi: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _deliverProduct(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = _ref.read(userProfileProvider).asData?.value;
    if (user == null) return;

    final productId = purchaseDetails.productID;

    // Check if it's a subscription
    if (productId == kPremiumMonthlySku || productId == kPremiumYearlySku) {
      await _ref.read(userRepositoryProvider).setPremium(user.uid, true);
      debugPrint('👑 [Google Play Billing] ODAT Premium hisobga muvaffaqiyatli ulandi!');
      return;
    }

    // Otherwise check coin packages (supporting 50k aliases)
    final pkg = kFenixCoinPackages.firstWhere(
      (p) => p.id == productId || (productId.contains('50000') && p.id == 'fenix_25000') || (productId.contains('50k') && p.id == 'fenix_25000'),
      orElse: () => const FenixCoinPackage(id: '', coins: 0, priceUzs: 0),
    );

    final coinsToCredit = pkg.totalCoins > 0 ? pkg.totalCoins : (productId.contains('50') ? 50000 : pkg.coins);
    if (coinsToCredit > 0) {
      await _ref.read(userRepositoryProvider).addFenixCoins(user.uid, coinsToCredit);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
