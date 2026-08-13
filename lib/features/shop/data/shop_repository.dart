import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_providers.dart';
import '../domain/models/gift_order.dart';
import '../domain/models/purchased_coupon.dart';
import '../domain/models/shop_item.dart';

class ShopException implements Exception {
  ShopException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ShopRepository {
  ShopRepository(this._db, [this._functions]);

  final FirebaseFirestore _db;
  final FirebaseFunctions? _functions;


  CollectionReference<Map<String, dynamic>> get _shopItemsRef =>
      _db.collection('shopItems');

  CollectionReference<Map<String, dynamic>> get _purchasedCouponsRef =>
      _db.collection('purchasedCoupons');

  CollectionReference<Map<String, dynamic>> get _giftOrdersRef =>
      _db.collection('giftOrders');

  Stream<List<ShopItem>> watchShopItems() {
    return _shopItemsRef
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final items = <ShopItem>[];
          for (final doc in snap.docs) {
            try {
              items.add(ShopItem.fromDoc(doc));
            } catch (e, st) {
              debugPrint('ShopItem parse error doc ID=${doc.id}: $e\n$st');
            }
          }
          items.sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
          return items;
        })
        .handleError((error, stackTrace) {
          debugPrint('watchShopItems Firestore error: $error\n$stackTrace');
          throw ShopException('Firestore xatosi: $error');
        });
  }

  /// Streams purchased coupons for a specific user, enriched with ShopItem if available.
  Stream<List<PurchasedCoupon>> watchPurchasedCoupons(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _purchasedCouponsRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final coupons = snap.docs.map((doc) => PurchasedCoupon.fromDoc(doc)).toList();
      coupons.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

      if (coupons.isEmpty) return coupons;

      // Enrich with shop item details
      final itemIds = coupons.map((c) => c.shopItemId).toSet().toList();
      final itemsMap = await _fetchShopItemsByIds(itemIds);

      return coupons.map((coupon) {
        return coupon.copyWith(shopItem: itemsMap[coupon.shopItemId]);
      }).toList();
    });
  }

  /// Streams gift orders for a specific user, enriched with ShopItem if available.
  Stream<List<GiftOrder>> watchGiftOrders(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _giftOrdersRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final orders = snap.docs.map((doc) => GiftOrder.fromDoc(doc)).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (orders.isEmpty) return orders;

      // Enrich with shop item details
      final itemIds = orders.map((o) => o.shopItemId).toSet().toList();
      final itemsMap = await _fetchShopItemsByIds(itemIds);

      return orders.map((order) {
        return order.copyWith(shopItem: itemsMap[order.shopItemId]);
      }).toList();
    });
  }

  Future<Map<String, ShopItem>> _fetchShopItemsByIds(List<String> ids) async {
    final Map<String, ShopItem> result = {};
    if (ids.isEmpty) return result;

    // Firestore whereIn has a max limit of 30 items
    for (var i = 0; i < ids.length; i += 30) {
      final end = (i + 30 < ids.length) ? i + 30 : ids.length;
      final chunk = ids.sublist(i, end);
      final snap = await _shopItemsRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = ShopItem.fromDoc(doc);
      }
    }
    return result;
  }

  /// Purchases a discount coupon via Cloud Function.
  Future<String> purchaseCoupon(String shopItemId) async {
    try {
      final functions = _functions ?? FirebaseFunctions.instance;
      final callable = functions.httpsCallable('purchaseCoupon');

      final response = await callable.call<Map<String, dynamic>>({
        'shopItemId': shopItemId,
      });

      final data = response.data;
      final couponCode = data['couponCode'] as String?;
      if (couponCode == null || couponCode.isEmpty) {
        throw ShopException('Promo kod olinmadi. Qaytadan urinib ko\'ring.');
      }
      return couponCode;
    } on FirebaseFunctionsException catch (e) {
      throw ShopException(e.message ?? 'Xatolik yuz berdi (${e.code}).');
    } catch (e) {
      if (e is ShopException) rethrow;
      throw ShopException('Server bilan bog\'lanishda xatolik: $e');
    }
  }

  /// Purchases a gift (creates a gift order with delivery address) via Cloud Function.
  Future<String> purchaseGift({
    required String shopItemId,
    required String fullName,
    required String phoneNumber,
    required String address,
  }) async {
    try {
      final functions = _functions ?? FirebaseFunctions.instance;
      final callable = functions.httpsCallable('purchaseGift');

      final response = await callable.call<Map<String, dynamic>>({
        'shopItemId': shopItemId,
        'fullName': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'address': address.trim(),
      });

      final data = response.data;
      final orderId = data['orderId'] as String?;
      if (orderId == null || orderId.isEmpty) {
        throw ShopException('Buyurtma ID olinmadi. Qaytadan urinib ko\'ring.');
      }
      return orderId;
    } on FirebaseFunctionsException catch (e) {
      throw ShopException(e.message ?? 'Xatolik yuz berdi (${e.code}).');
    } catch (e) {
      if (e is ShopException) rethrow;
      throw ShopException('Server bilan bog\'lanishda xatolik: $e');
    }
  }
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  );
});
