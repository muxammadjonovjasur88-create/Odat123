import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/shop/domain/models/shop_item.dart';
import 'package:flowa/features/shop/presentation/widgets/shop_item_card.dart';

void main() {
  group('ShopItemCard Widget Tests', () {
    testWidgets('renders coupon item details correctly', (tester) async {
      const couponItem = ShopItem(
        id: 'c_1',
        type: ShopItemType.coupon,
        title: 'Yandex Taxi 20% Chegirma',
        description: 'Barcha safarlar uchun',
        partnerName: 'Yandex Go',
        pointsCost: 250,
        imageUrl: '',
        discountText: '20% Off',
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 240,
                child: ShopItemCard(
                  item: couponItem,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kupon'), findsOneWidget);
      expect(find.text('Yandex Go'), findsOneWidget);
      expect(find.text('Yandex Taxi 20% Chegirma'), findsOneWidget);
      expect(find.text('250 PTS'), findsOneWidget);

      await tester.tap(find.byType(ShopItemCard));
      expect(tapped, isTrue);
    });

    testWidgets('renders gift item details and sold out status correctly', (tester) async {
      const giftItem = ShopItem(
        id: 'g_1',
        type: ShopItemType.gift,
        title: 'AirPods Max',
        description: 'Premial quloqchin',
        pointsCost: 10000,
        imageUrl: '',
        stock: 0,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 240,
                child: ShopItemCard(
                  item: giftItem,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sovg\'a'), findsOneWidget);
      expect(find.text('AirPods Max'), findsOneWidget);
      expect(find.text('Tugadi'), findsOneWidget);

      await tester.tap(find.byType(ShopItemCard));
      expect(tapped, isFalse); // Sold out item should not trigger onTap
    });
  });
}
