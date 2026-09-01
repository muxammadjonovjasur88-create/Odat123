import 'package:flutter/material.dart';

enum MessageType { system, admin, clan, friend, reward, achievement }

/// Represents an in-app message / notification in the user's profile inbox.
class AppMessage {
  const AppMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.icon,
    required this.createdAt,
    this.isRead = false,
    this.rewardPoints = 0,
    this.rewardCoins = 0,
    this.isClaimed = false,
    this.senderUid,
    this.senderName,
    this.senderAvatar,
    this.isFriendAccepted = false,
  });

  final String id;
  final String title;
  final String body;
  final MessageType type;
  final String icon;
  final DateTime createdAt;
  final bool isRead;
  final int rewardPoints;
  final int rewardCoins;
  final bool isClaimed;
  final String? senderUid;
  final String? senderName;
  final String? senderAvatar;
  final bool isFriendAccepted;

  Color get accentColor {
    switch (type) {
      case MessageType.system:
        return const Color(0xFF5BC8FA);
      case MessageType.admin:
        return const Color(0xFFBF00FF);
      case MessageType.clan:
        return const Color(0xFFFFB703);
      case MessageType.friend:
        return const Color(0xFF3B9BFF);
      case MessageType.reward:
        return const Color(0xFFFFD700);
      case MessageType.achievement:
        return const Color(0xFFFF0055);
    }
  }

  AppMessage copyWith({
    bool? isRead,
    bool? isClaimed,
    bool? isFriendAccepted,
    String? body,
  }) {
    return AppMessage(
      id: id,
      title: title,
      body: body ?? this.body,
      type: type,
      icon: icon,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      rewardPoints: rewardPoints,
      rewardCoins: rewardCoins,
      isClaimed: isClaimed ?? this.isClaimed,
      senderUid: senderUid,
      senderName: senderName,
      senderAvatar: senderAvatar,
      isFriendAccepted: isFriendAccepted ?? this.isFriendAccepted,
    );
  }
}
