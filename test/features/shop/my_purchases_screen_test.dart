import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/core/widgets/segmented_filter_chip.dart';
import 'package:flowa/features/shop/domain/models/gift_order.dart';
import 'package:flowa/features/shop/domain/models/purchased_coupon.dart';
import 'package:flowa/features/shop/domain/models/shop_item.dart';
import 'package:flowa/features/shop/presentation/providers/shop_provider.dart';
import 'package:flowa/features/shop/presentation/screens/my_purchases_screen.dart';

void main() {
  group('SegmentedFilterChip Widget Tests', () {
    testWidgets('renders label, icon and handles tap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SegmentedFilterChip(
                label: 'Kuponlarim',
                icon: Icons.confirmation_number_outlined,
                isSelected: true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kuponlarim'), findsOneWidget);
      expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);

      await tester.tap(find.byType(SegmentedFilterChip));
      expect(tapped, isTrue);
    });

    testWidgets('renders inactive transparent state correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SegmentedFilterChip(
                label: 'Sovg\'alarim',
                icon: Icons.card_giftcard_rounded,
                isSelected: false,
                transparentInactive: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sovg\'alarim'), findsOneWidget);
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    });
  });

  group('MyPurchasesScreen Tab Switching Tests', () {
    final mockCoupons = <PurchasedCoupon>[
      PurchasedCoupon(
        id: 'c_1',
        userId: 'u_1',
        shopItemId: 'si_1',
        couponCode: 'PROMO123',
        purchasedAt: DateTime(2026, 8, 13, 10, 0),
        shopItem: const ShopItem(
          id: 'si_1',
          type: ShopItemType.coupon,
          title: 'Yandex Taxi 20% Chegirma',
          description: '20% off coupon',
          partnerName: 'Yandex Go',
          pointsCost: 200,
          imageUrl: '',
        ),
      ),
    ];

    final mockGiftOrders = <GiftOrder>[
      GiftOrder(
        id: 'g_1',
        userId: 'u_1',
        shopItemId: 'si_2',
        fullName: 'Jasur',
        phoneNumber: '+998901234567',
        address: 'Toshkent shahri, Yunusobod 4-mavze, 12-uy',
        status: GiftOrderStatus.confirmed,
        createdAt: DateTime(2026, 8, 13, 10, 30),
        shopItem: const ShopItem(
          id: 'si_2',
          type: ShopItemType.gift,
          title: 'Flowa Notebook',
          description: 'Custom notebook',
          pointsCost: 500,
          imageUrl: '',
        ),
      ),
    ];

    testWidgets('initial load displays Kuponlarim tab content by default', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchasedCouponsProvider.overrideWith((ref) => Stream.value(mockCoupons)),
            giftOrdersProvider.overrideWith((ref) => Stream.value(mockGiftOrders)),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MyPurchasesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Screen title
      expect(find.text('Mening xaridlarim'), findsOneWidget);

      // Segmented control tabs
      expect(find.text('Kuponlarim'), findsOneWidget);
      expect(find.text('Sovg\'alarim'), findsOneWidget);

      // Active tab content (Kuponlarim)
      expect(find.text('Yandex Taxi 20% Chegirma'), findsOneWidget);
      expect(find.text('PROMO123'), findsOneWidget);
      expect(find.text('Yandex Go'), findsOneWidget);

      // Sovg'alarim content should not be visible yet
      expect(find.text('Flowa Notebook'), findsNothing);
    });

    testWidgets('switches smoothly to Sovg\'alarim tab when segment chip is tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchasedCouponsProvider.overrideWith((ref) => Stream.value(mockCoupons)),
            giftOrdersProvider.overrideWith((ref) => Stream.value(mockGiftOrders)),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MyPurchasesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Sovg'alarim segment tab
      await tester.tap(find.text('Sovg\'alarim'));
      await tester.pumpAndSettle();

      // Now Sovg'alarim content should be displayed
      expect(find.text('Flowa Notebook'), findsOneWidget);
      expect(find.text('Tasdiqlandi'), findsOneWidget);
      expect(find.text('Toshkent shahri, Yunusobod 4-mavze, 12-uy'), findsOneWidget);

      // Switch back to Kuponlarim
      await tester.tap(find.text('Kuponlarim'));
      await tester.pumpAndSettle();

      expect(find.text('Yandex Taxi 20% Chegirma'), findsOneWidget);
    });

    testWidgets('displays enhanced empty states when no purchases exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchasedCouponsProvider.overrideWith((ref) => Stream.value(<PurchasedCoupon>[])),
            giftOrdersProvider.overrideWith((ref) => Stream.value(<GiftOrder>[])),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MyPurchasesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state on Kuponlarim tab
      expect(find.text('Sizda hali sotib olingan kuponlar mavjud emas'), findsOneWidget);
      expect(find.text('Do\'kondan yangi xaridlarni amalga oshirishingiz mumkin'), findsOneWidget);

      // Tap on Sovg'alarim tab
      await tester.tap(find.text('Sovg\'alarim'));
      await tester.pumpAndSettle();

      // Empty state on Sovg'alarim tab
      expect(find.text('Sizda hali sovg\'a buyurtmalari mavjud emas'), findsOneWidget);
    });
  });
}
