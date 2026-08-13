import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'shop_item.dart';

enum GiftOrderStatus {
  pending,
  confirmed,
  shipped,
  delivered,
  cancelled;

  String get value {
    switch (this) {
      case GiftOrderStatus.pending:
        return 'pending';
      case GiftOrderStatus.confirmed:
        return 'confirmed';
      case GiftOrderStatus.shipped:
        return 'shipped';
      case GiftOrderStatus.delivered:
        return 'delivered';
      case GiftOrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static GiftOrderStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return GiftOrderStatus.pending;
      case 'confirmed':
        return GiftOrderStatus.confirmed;
      case 'shipped':
        return GiftOrderStatus.shipped;
      case 'delivered':
        return GiftOrderStatus.delivered;
      case 'cancelled':
        return GiftOrderStatus.cancelled;
      default:
        return GiftOrderStatus.pending;
    }
  }

  String get labelUz {
    switch (this) {
      case GiftOrderStatus.pending:
        return 'Kutilmoqda';
      case GiftOrderStatus.confirmed:
        return 'Tasdiqlandi';
      case GiftOrderStatus.shipped:
        return 'Yo\'lda';
      case GiftOrderStatus.delivered:
        return 'Yetkazildi';
      case GiftOrderStatus.cancelled:
        return 'Bekor qilindi';
    }
  }

  Color get color {
    switch (this) {
      case GiftOrderStatus.pending:
        return const Color(0xFFFFB74D); // Amber/Orange
      case GiftOrderStatus.confirmed:
        return const Color(0xFF29B6F6); // Light Blue
      case GiftOrderStatus.shipped:
        return const Color(0xFFAB47BC); // Purple
      case GiftOrderStatus.delivered:
        return const Color(0xFF66BB6A); // Green
      case GiftOrderStatus.cancelled:
        return const Color(0xFFEF5350); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case GiftOrderStatus.pending:
        return Icons.hourglass_empty_rounded;
      case GiftOrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case GiftOrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case GiftOrderStatus.delivered:
        return Icons.task_alt_rounded;
      case GiftOrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }
}

class GiftOrder {
  const GiftOrder({
    required this.id,
    required this.userId,
    required this.shopItemId,
    required this.fullName,
    required this.phoneNumber,
    required this.address,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.adminNote,
    this.shopItem,
  });

  final String id;
  final String userId;
  final String shopItemId;
  final String fullName;
  final String phoneNumber;
  final String address;
  final GiftOrderStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? adminNote;
  final ShopItem? shopItem;

  GiftOrder copyWith({
    String? id,
    String? userId,
    String? shopItemId,
    String? fullName,
    String? phoneNumber,
    String? address,
    GiftOrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adminNote,
    ShopItem? shopItem,
  }) {
    return GiftOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shopItemId: shopItemId ?? this.shopItemId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNote: adminNote ?? this.adminNote,
      shopItem: shopItem ?? this.shopItem,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'shopItemId': shopItemId,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'address': address,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'adminNote': adminNote,
    };
  }

  factory GiftOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return GiftOrder.fromMap(doc.data() ?? {}, doc.id);
  }

  factory GiftOrder.fromMap(Map<String, dynamic> data, String id) {
    return GiftOrder(
      id: id,
      userId: data['userId'] as String? ?? '',
      shopItemId: data['shopItemId'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      status: GiftOrderStatus.fromString(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      adminNote: data['adminNote'] as String?,
    );
  }
}
