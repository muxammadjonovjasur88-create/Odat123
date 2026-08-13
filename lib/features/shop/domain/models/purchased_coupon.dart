import 'package:cloud_firestore/cloud_firestore.dart';
import 'shop_item.dart';

class PurchasedCoupon {
  const PurchasedCoupon({
    required this.id,
    required this.userId,
    required this.shopItemId,
    required this.couponCode,
    required this.purchasedAt,
    this.shopItem,
  });

  final String id;
  final String userId;
  final String shopItemId;
  final String couponCode;
  final DateTime purchasedAt;
  final ShopItem? shopItem;

  PurchasedCoupon copyWith({
    String? id,
    String? userId,
    String? shopItemId,
    String? couponCode,
    DateTime? purchasedAt,
    ShopItem? shopItem,
  }) {
    return PurchasedCoupon(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shopItemId: shopItemId ?? this.shopItemId,
      couponCode: couponCode ?? this.couponCode,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      shopItem: shopItem ?? this.shopItem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'shopItemId': shopItemId,
      'couponCode': couponCode,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
    };
  }

  factory PurchasedCoupon.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PurchasedCoupon.fromMap(doc.data() ?? {}, doc.id);
  }

  factory PurchasedCoupon.fromMap(Map<String, dynamic> data, String id) {
    return PurchasedCoupon(
      id: id,
      userId: data['userId'] as String? ?? '',
      shopItemId: data['shopItemId'] as String? ?? '',
      couponCode: data['couponCode'] as String? ?? '',
      purchasedAt: (data['purchasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
