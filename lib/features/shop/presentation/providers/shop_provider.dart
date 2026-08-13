import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_repository.dart';
import '../../data/shop_repository.dart';
import '../../domain/models/gift_order.dart';
import '../../domain/models/purchased_coupon.dart';
import '../../domain/models/shop_item.dart';

/// Active filter tab notifier for the shop items list. Null means "Barchasi" (All).
class ShopFilterNotifier extends Notifier<ShopItemType?> {
  @override
  ShopItemType? build() => null;

  void setFilter(ShopItemType? filter) {
    state = filter;
  }
}

final shopFilterProvider = NotifierProvider<ShopFilterNotifier, ShopItemType?>(
  ShopFilterNotifier.new,
);

/// Stream of all active shop items from Firestore.
final shopItemsProvider = StreamProvider<List<ShopItem>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchShopItems();
});

final filteredShopItemsProvider = Provider<AsyncValue<List<ShopItem>>>((ref) {
  final itemsAsync = ref.watch(shopItemsProvider);
  final filter = ref.watch(shopFilterProvider);

  if (itemsAsync.isLoading) return const AsyncValue.loading();
  if (itemsAsync.hasError) {
    debugPrint('filteredShopItemsProvider error: ${itemsAsync.error}');
    return AsyncValue.error(itemsAsync.error!, itemsAsync.stackTrace!);
  }

  final items = itemsAsync.value ?? [];
  debugPrint('filteredShopItemsProvider loaded ${items.length} items (filter: $filter)');
  if (filter == null) return AsyncValue.data(items);
  return AsyncValue.data(items.where((item) => item.type == filter).toList());
});

/// Stream of purchased coupons for the current user.
final purchasedCouponsProvider = StreamProvider<List<PurchasedCoupon>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchPurchasedCoupons(user.uid);
});

/// Stream of gift orders for the current user.
final giftOrdersProvider = StreamProvider<List<GiftOrder>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value([]);
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchGiftOrders(user.uid);
});
