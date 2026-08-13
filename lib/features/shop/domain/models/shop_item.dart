import 'package:cloud_firestore/cloud_firestore.dart';

enum ShopItemType {
  coupon,
  gift;

  String get value {
    switch (this) {
      case ShopItemType.coupon:
        return 'coupon';
      case ShopItemType.gift:
        return 'gift';
    }
  }

  static ShopItemType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'coupon':
        return ShopItemType.coupon;
      case 'gift':
        return ShopItemType.gift;
      default:
        return ShopItemType.coupon;
    }
  }

  String get label {
    switch (this) {
      case ShopItemType.coupon:
        return 'Kupon';
      case ShopItemType.gift:
        return 'Sovg\'a';
    }
  }
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.imageUrl,
    this.partnerName,
    this.stock,
    this.expiresAt,
    this.isActive = true,
    this.createdAt,
    this.discountText,
    this.requiresShipping = false,
  });

  final String id;
  final ShopItemType type;
  final String title;
  final String description;
  final String? partnerName;
  final int pointsCost;
  final String imageUrl;
  final int? stock;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime? createdAt;
  final String? discountText;
  final bool requiresShipping;

  bool get isCoupon => type == ShopItemType.coupon;
  bool get isGift => type == ShopItemType.gift;
  bool get isOutOfStock => stock != null && stock! <= 0;

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'description': description,
      'partnerName': partnerName,
      'pointsCost': pointsCost,
      'imageUrl': imageUrl,
      'stock': stock,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'discountText': discountText,
      'requiresShipping': requiresShipping,
    };
  }

  factory ShopItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ShopItem.fromMap(doc.data() ?? {}, doc.id);
  }

  factory ShopItem.fromMap(Map<String, dynamic> data, String id) {
    return ShopItem(
      id: id,
      type: ShopItemType.fromString(data['type'] as String? ?? 'coupon'),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      partnerName: data['partnerName'] as String?,
      pointsCost: (data['pointsCost'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] as String? ?? '',
      stock: (data['stock'] as num?)?.toInt(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      discountText: data['discountText'] as String?,
      requiresShipping: (data['requiresShipping'] as bool?) ??
          (ShopItemType.fromString(data['type'] as String? ?? 'coupon') == ShopItemType.gift),
    );
  }
}
