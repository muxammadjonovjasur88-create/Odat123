import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/shop/data/shop_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ShopRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    // Pass null for functions in basic repository unit test as Firestore operations are isolated
    repository = ShopRepository(fakeFirestore, null as dynamic);
  });

  group('ShopRepository Firestore Streams', () {
    test('watchShopItems emits active shop items correctly', () async {
      await fakeFirestore.collection('shopItems').doc('item_1').set({
        'type': 'coupon',
        'title': 'Kupon 1',
        'description': 'Tavsif 1',
        'pointsCost': 100,
        'imageUrl': 'https://example.com/1.png',
        'isActive': true,
      });

      await fakeFirestore.collection('shopItems').doc('item_2').set({
        'type': 'gift',
        'title': 'Sovg\'a 1',
        'description': 'Tavsif 2',
        'pointsCost': 500,
        'imageUrl': 'https://example.com/2.png',
        'isActive': false, // Inactive item
      });

      final items = await repository.watchShopItems().first;

      expect(items.length, 1);
      expect(items.first.id, 'item_1');
      expect(items.first.title, 'Kupon 1');
      expect(items.first.pointsCost, 100);
    });

    test('watchPurchasedCoupons streams coupons for specific user', () async {
      await fakeFirestore.collection('purchasedCoupons').doc('c_1').set({
        'userId': 'user_A',
        'shopItemId': 'item_1',
        'couponCode': 'FLOWA-AAA-111',
        'purchasedAt': DateTime.now(),
      });

      await fakeFirestore.collection('purchasedCoupons').doc('c_2').set({
        'userId': 'user_B',
        'shopItemId': 'item_1',
        'couponCode': 'FLOWA-BBB-222',
        'purchasedAt': DateTime.now(),
      });

      final coupons = await repository.watchPurchasedCoupons('user_A').first;

      expect(coupons.length, 1);
      expect(coupons.first.id, 'c_1');
      expect(coupons.first.couponCode, 'FLOWA-AAA-111');
    });

    test('watchGiftOrders streams gift orders for specific user', () async {
      await fakeFirestore.collection('giftOrders').doc('g_1').set({
        'userId': 'user_A',
        'shopItemId': 'item_2',
        'fullName': 'Ali Valiyev',
        'phoneNumber': '+998901234567',
        'address': 'Toshkent sh., Yunusobod 4-mavze',
        'status': 'pending',
        'createdAt': DateTime.now(),
      });

      final orders = await repository.watchGiftOrders('user_A').first;

      expect(orders.length, 1);
      expect(orders.first.id, 'g_1');
      expect(orders.first.fullName, 'Ali Valiyev');
      expect(orders.first.status.labelUz, 'Kutilmoqda');
    });
  });
}
