import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../../notifications/data/notification_service.dart';
import '../domain/models/app_message.dart';

final inboxRepositoryProvider =
    NotifierProvider<InboxNotifier, List<AppMessage>>(InboxNotifier.new);

final unreadMessagesCountProvider = Provider<int>((ref) {
  final messages = ref.watch(inboxRepositoryProvider);
  return messages.where((m) => !m.isRead).length;
});

class InboxNotifier extends Notifier<List<AppMessage>> {
  StreamSubscription? _sub;
  bool _isClaiming = false;

  @override
  List<AppMessage> build() {
    final user = ref.watch(userProfileProvider).asData?.value;
    final isWelcomeClaimed = user != null && user.claimedBadges.contains('msg_welcome');

    final initialList = [
      AppMessage(
        id: 'msg_welcome',
        title: 'ODAT Olamiga Xush Kelibsiz! 🚀',
        body: 'Kundalik odatlaringizni shakllantiring, ballar yig‘ing, ligalarda qatnashing va yangi darajalarga ko‘tariling!',
        type: MessageType.system,
        icon: '🌟',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: isWelcomeClaimed,
        rewardPoints: 50,
        rewardCoins: 100,
        isClaimed: isWelcomeClaimed,
      ),
    ];

    if (user != null) {
      _sub?.cancel();
      final db = ref.watch(firestoreProvider);
      final seenNotifIds = <String>{};
      bool isFirstLoad = true;

      _sub = db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snap) {
        // Trigger heads-up notification ONLY for genuinely new real-time messages
        if (isFirstLoad) {
          for (final doc in snap.docs) {
            seenNotifIds.add(doc.id);
          }
          isFirstLoad = false;
        } else {
          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final docId = change.doc.id;
              if (seenNotifIds.contains(docId)) continue;
              seenNotifIds.add(docId);

              final d = change.doc.data();
              if (d != null && d['isRead'] != true) {
                final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
                // Only alert if created in the last 60 seconds
                if (createdAt != null &&
                    DateTime.now().difference(createdAt).inSeconds > 60) {
                  continue;
                }

                final body = d['body'] as String? ?? '';
                final senderName = d['senderName'] as String? ?? 'Do‘st';
                final senderUid = d['senderUid'] as String?;
                if (senderUid != null && senderUid != user.uid) {
                  ref.read(notificationServiceProvider).showChatNotification(
                        senderName: senderName,
                        message: body,
                        chatId: senderUid,
                      );
                }
              }
            }
          }
        }

        final remote = snap.docs.map((d) {
          final data = d.data();
          final typeStr = data['type'] as String? ?? 'system';
          final mType = switch (typeStr) {
            'friend' => MessageType.friend,
            'clan' => MessageType.clan,
            'admin' => MessageType.admin,
            'reward' => MessageType.reward,
            'achievement' => MessageType.achievement,
            _ => MessageType.system,
          };
          final ts = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final isClaimedRemote = (data['isClaimed'] as bool? ?? false) || user.claimedBadges.contains(d.id);

          return AppMessage(
            id: d.id,
            title: data['title'] as String? ?? 'Xabar',
            body: data['body'] as String? ?? '',
            type: mType,
            icon: data['icon'] as String? ?? '📬',
            createdAt: ts,
            isRead: data['isRead'] as bool? ?? false,
            senderUid: data['senderUid'] as String?,
            senderName: data['senderName'] as String?,
            senderAvatar: data['senderAvatar'] as String?,
            isFriendAccepted: data['isFriendAccepted'] as bool? ?? false,
            rewardPoints: (data['rewardPoints'] as num?)?.toInt() ?? 0,
            rewardCoins: (data['rewardCoins'] as num?)?.toInt() ?? 0,
            isClaimed: isClaimedRemote,
          );
        }).toList();

        // Merge remote notifications at top, followed by initial system welcome
        final allIds = <String>{};
        final merged = <AppMessage>[];
        for (final m in [...remote, ...initialList]) {
          if (!allIds.contains(m.id)) {
            allIds.add(m.id);
            merged.add(m);
          }
        }
        state = merged;
      });
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return initialList;
  }

  Future<void> markAsRead(String id) async {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(isRead: true);
      }
      return m;
    }).toList();

    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      try {
        final db = ref.read(firestoreProvider);
        await db
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(id)
            .set({'isRead': true}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead() async {
    state = state.map((m) => m.copyWith(isRead: true)).toList();

    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      try {
        final db = ref.read(firestoreProvider);
        final unreadDocs = await db
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .get();

        final batch = db.batch();
        for (final doc in unreadDocs.docs) {
          batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  Future<void> claimReward(String id) async {
    if (_isClaiming) return;
    _isClaiming = true;

    try {
      final message = state.firstWhere(
        (m) => m.id == id,
        orElse: () => throw Exception('Xabar topilmadi'),
      );
      if (message.isClaimed) return;

      final user = ref.read(userProfileProvider).asData?.value;
      if (user != null) {
        if (user.claimedBadges.contains(id)) return;

        final db = ref.read(firestoreProvider);
        final batch = db.batch();
        final userRef = db.collection('users').doc(user.uid);

        final Map<String, dynamic> updates = {
          'claimedBadges': FieldValue.arrayUnion([id]),
        };
        if (message.rewardPoints > 0) {
          updates['totalPoints'] = FieldValue.increment(message.rewardPoints);
          updates['weeklyPoints'] = FieldValue.increment(message.rewardPoints);
        }
        if (message.rewardCoins > 0) {
          updates['fenixCoins'] = FieldValue.increment(message.rewardCoins);
        }

        batch.set(userRef, updates, SetOptions(merge: true));

        // If it's a notification document, mark it claimed as well
        final notifRef = db.collection('users').doc(user.uid).collection('notifications').doc(id);
        batch.set(notifRef, {'isClaimed': true, 'isRead': true}, SetOptions(merge: true));

        await batch.commit();
      }

      state = state.map((m) {
        if (m.id == id) {
          return m.copyWith(isRead: true, isClaimed: true);
        }
        return m;
      }).toList();
    } finally {
      _isClaiming = false;
    }
  }

  Future<void> deleteMessage(String id) async {
    state = state.where((m) => m.id != id).toList();
    final user = ref.read(userProfileProvider).asData?.value;
    if (user != null) {
      try {
        final db = ref.read(firestoreProvider);
        await db.collection('users').doc(user.uid).collection('notifications').doc(id).delete();
      } catch (_) {}
    }
  }

  void addMessage(AppMessage message) {
    state = [message, ...state];
  }
}
