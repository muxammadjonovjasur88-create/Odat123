import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/shop/domain/models/shop_item.dart';
import 'package:flowa/features/shop/domain/models/purchased_coupon.dart';
import 'package:flowa/features/shop/domain/models/gift_order.dart';

void main() {
  group('ShopItem Model', () {
    test('parses coupon item from map correctly', () {
      final map = {
        'type': 'coupon',
        'title': 'Yandex Plus 1 oy',
        'description': '1 oylik bepul obuna',
        'partnerName': 'Yandex',
        'pointsCost': 300,
        'imageUrl': 'https://example.com/image.png',
        'stock': 10,
        'discountText': '100% chegirma',
        'isActive': true,
      };

      final item = ShopItem.fromMap(map, 'item_1');

      expect(item.id, 'item_1');
      expect(item.type, ShopItemType.coupon);
      expect(item.isCoupon, isTrue);
      expect(item.isGift, isFalse);
      expect(item.title, 'Yandex Plus 1 oy');
      expect(item.partnerName, 'Yandex');
      expect(item.pointsCost, 300);
      expect(item.stock, 10);
      expect(item.isOutOfStock, isFalse);
      expect(item.requiresShipping, isFalse);
    });

    test('parses gift item from map correctly', () {
      final map = {
        'type': 'gift',
        'title': 'AirPods Pro',
        'description': 'Simsiz quloqchinlar',
        'pointsCost': 5000,
        'imageUrl': 'https://example.com/airpods.png',
        'stock': 0,
        'isActive': true,
        'requiresShipping': true,
      };

      final item = ShopItem.fromMap(map, 'item_2');

      expect(item.id, 'item_2');
      expect(item.type, ShopItemType.gift);
      expect(item.isGift, isTrue);
      expect(item.isOutOfStock, isTrue);
      expect(item.requiresShipping, isTrue);
    });
  });

  group('PurchasedCoupon Model', () {
    test('parses purchased coupon correctly', () {
      final map = {
        'userId': 'user_123',
        'shopItemId': 'item_1',
        'couponCode': 'FLOWA-TEST-1234',
      };

      final coupon = PurchasedCoupon.fromMap(map, 'c_1');

      expect(coupon.id, 'c_1');
      expect(coupon.userId, 'user_123');
      expect(coupon.shopItemId, 'item_1');
      expect(coupon.couponCode, 'FLOWA-TEST-1234');
    });
  });

  group('GiftOrder Model & Status', () {
    test('parses gift order correctly', () {
      final map = {
        'userId': 'user_123',
        'shopItemId': 'item_2',
        'fullName': 'Jasur M',
        'phoneNumber': '+998901234567',
        'address': 'Toshkent shahri, Chilonzor 1-mavze',
        'status': 'pending',
      };

      final order = GiftOrder.fromMap(map, 'g_1');

      expect(order.id, 'g_1');
      expect(order.userId, 'user_123');
      expect(order.fullName, 'Jasur M');
      expect(order.phoneNumber, '+998901234567');
      expect(order.status, GiftOrderStatus.pending);
      expect(order.status.labelUz, 'Kutilmoqda');
    });

    test('GiftOrderStatus correctly translates status string and properties', () {
      expect(GiftOrderStatus.fromString('pending'), GiftOrderStatus.pending);
      expect(GiftOrderStatus.fromString('confirmed').labelUz, 'Tasdiqlandi');
      expect(GiftOrderStatus.fromString('shipped').labelUz, 'Yo\'lda');
      expect(GiftOrderStatus.fromString('delivered').labelUz, 'Yetkazildi');
      expect(GiftOrderStatus.fromString('cancelled').labelUz, 'Bekor qilindi');
    });
  });
}
