import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String? photoBase64;
  final String? photoUrl;
  final int? giftAmount;
  final String messageType; // 'text', 'photo', 'gift'
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    this.photoBase64,
    this.photoUrl,
    this.giftAmount,
    this.messageType = 'text',
    required this.createdAt,
  });

  bool get hasPhoto => (photoBase64 != null && photoBase64!.isNotEmpty) || (photoUrl != null && photoUrl!.isNotEmpty);
  bool get isGift => messageType == 'gift' || (giftAmount != null && giftAmount! > 0);

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    DateTime date;
    if (ts is Timestamp) {
      date = ts.toDate();
    } else if (ts is int) {
      date = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      date = DateTime.now();
    }

    final gift = (data['giftAmount'] as num?)?.toInt();
    final type = (data['messageType'] as String?) ?? (gift != null && gift > 0 ? 'gift' : 'text');

    return ChatMessage(
      id: doc.id,
      senderUid: (data['senderUid'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? 'Friend',
      senderAvatar: (data['senderAvatar'] as String?) ?? 'leaf',
      text: (data['text'] as String?) ?? '',
      photoBase64: data['photoBase64'] as String?,
      photoUrl: data['photoUrl'] as String?,
      giftAmount: gift,
      messageType: type,
      createdAt: date,
    );
  }
}
