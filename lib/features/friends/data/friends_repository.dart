import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../../leaderboard/domain/leaderboard_entry.dart';
import '../domain/chat_message.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  return FriendsRepository(db);
});

final friendsLeaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  final user = ref.watch(userProfileProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(friendsRepositoryProvider).watchFriendsLeaderboard(user.uid);
});

final friendRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(userProfileProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(friendsRepositoryProvider).watchPendingFriendRequests(user.uid);
});

class FriendsRepository {
  FriendsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Streams the list of friends for [uid] as LeaderboardEntry objects
  Stream<List<LeaderboardEntry>> watchFriendsLeaderboard(String uid) {
    try {
      return _users
          .doc(uid)
          .collection('friends')
          .snapshots()
          .asyncMap((snap) async {
            try {
              final friendUids = snap.docs.map((d) => d.id).toList();
              if (friendUids.isEmpty) {
                try {
                  final meSnap = await _users.doc(uid).get();
                  if (meSnap.exists) {
                    final profile = UserProfile.fromDoc(meSnap);
                    return [LeaderboardEntry.fromProfile(profile, 1)];
                  }
                } catch (_) {}
                return <LeaderboardEntry>[];
              }

              final allUids = [uid, ...friendUids];
              final List<LeaderboardEntry> list = [];

              for (var i = 0; i < allUids.length; i += 10) {
                final chunk = allUids.sublist(i, (i + 10).clamp(0, allUids.length));
                try {
                  final usersSnap = await _users
                      .where(FieldPath.documentId, whereIn: chunk)
                      .get();

                  for (final doc in usersSnap.docs) {
                    final profile = UserProfile.fromDoc(doc);
                    list.add(LeaderboardEntry.fromProfile(profile, 0));
                  }
                } catch (_) {}
              }

              list.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

              return list.asMap().entries.map((e) {
                return e.value.copyWith(rank: e.key + 1);
              }).toList();
            } catch (_) {
              return <LeaderboardEntry>[];
            }
          })
          .handleError((_) => <LeaderboardEntry>[]);
    } catch (_) {
      return Stream.value(<LeaderboardEntry>[]);
    }
  }

  /// Streams incoming friend requests for [uid]
  Stream<List<Map<String, dynamic>>> watchPendingFriendRequests(String uid) {
    return _users
        .doc(uid)
        .collection('friend_requests')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'fromUid': d.id, ...d.data()}).toList())
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  /// Sends a friend request and adds notification to recipient's inbox
  Future<void> sendFriendRequest({
    required String fromUid,
    required String fromName,
    required String fromAvatar,
    required String toUid,
  }) async {
    if (fromUid == toUid) throw Exception('O‘zingizga do‘stlik taklifi yubora olmaysiz');
    final recipientSnap = await _users.doc(toUid).get();
    if (!recipientSnap.exists) throw Exception('profile.user_not_found'.tr());

    final batch = _db.batch();

    // 1. Friend requests collection
    batch.set(_users.doc(toUid).collection('friend_requests').doc(fromUid), {
      'fromUid': fromUid,
      'fromName': fromName.isEmpty ? 'Foydalanuvchi' : fromName,
      'fromAvatar': fromAvatar,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Notifications inbox collection
    final notifRef = _users.doc(toUid).collection('notifications').doc('freq_$fromUid');
    batch.set(notifRef, {
      'id': 'freq_$fromUid',
      'title': "Do'stlik taklifi 👥",
      'body': "${fromName.isEmpty ? 'Foydalanuvchi' : fromName} sizga do'stlik taklifi yubordi.",
      'type': 'friend',
      'icon': '🤝',
      'senderUid': fromUid,
      'senderName': fromName,
      'senderAvatar': fromAvatar,
      'isRead': false,
      'isFriendAccepted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Accepts a friend request
  Future<void> acceptFriendRequest({
    required String currentUid,
    required String fromUid,
  }) async {
    final batch = _db.batch();
    batch.set(
      _users.doc(currentUid).collection('friends').doc(fromUid),
      {'addedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _users.doc(fromUid).collection('friends').doc(currentUid),
      {'addedAt': FieldValue.serverTimestamp()},
    );
    batch.delete(_users.doc(currentUid).collection('friend_requests').doc(fromUid));

    // Update receiver's notification
    batch.set(
      _users.doc(currentUid).collection('notifications').doc('freq_$fromUid'),
      {
        'isRead': true,
        'body': "Do'stlik taklifi qabul qilindi ✅",
        'isFriendAccepted': true,
      },
      SetOptions(merge: true),
    );

    // Notify sender that request was accepted
    final senderNotifRef = _users.doc(fromUid).collection('notifications').doc();
    batch.set(senderNotifRef, {
      'id': senderNotifRef.id,
      'title': "Do'stlik tasdiqlandi! 🎉",
      'body': "Do'stingiz taklifingizni qabul qildi. Endi reytingda bir-biringizning natijalaringizni ko'ra olasiz!",
      'type': 'friend',
      'icon': '🎉',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Rejects a friend request
  Future<void> rejectFriendRequest({
    required String currentUid,
    required String fromUid,
  }) async {
    final batch = _db.batch();
    batch.delete(_users.doc(currentUid).collection('friend_requests').doc(fromUid));
    batch.delete(_users.doc(currentUid).collection('notifications').doc('freq_$fromUid'));
    await batch.commit();
  }

  /// Adds a friend by UID directly
  Future<void> addFriend(String currentUid, String friendUid) async {
    if (currentUid == friendUid) throw Exception('O‘zingizni do‘st qilib qo‘sha olmaysiz');
    final friendSnap = await _users.doc(friendUid).get();
    if (!friendSnap.exists) throw Exception('profile.user_not_found'.tr());

    final batch = _db.batch();
    batch.set(
      _users.doc(currentUid).collection('friends').doc(friendUid),
      {'addedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _users.doc(friendUid).collection('friends').doc(currentUid),
      {'addedAt': FieldValue.serverTimestamp()},
    );

    // Also add notification
    final friendNotifRef = _users.doc(friendUid).collection('notifications').doc();
    batch.set(friendNotifRef, {
      'id': friendNotifRef.id,
      'title': "Yangi do'st qo'shildi! 👥",
      'body': "Siz yangi do'st bilan ulandingiz!",
      'type': 'friend',
      'icon': '🤝',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Removes a friend
  Future<void> removeFriend(String currentUid, String friendUid) async {
    final batch = _db.batch();
    batch.delete(_users.doc(currentUid).collection('friends').doc(friendUid));
    batch.delete(_users.doc(friendUid).collection('friends').doc(currentUid));
    await batch.commit();
  }

  /// Searches users by UID, numeric ID, telegram ID, referral code, name, or email
  Future<List<UserProfile>> searchUsers(String query) async {
    final rawQuery = query.trim();
    final clean = rawQuery.toLowerCase();
    if (clean.isEmpty) return [];

    final Map<String, UserProfile> resultMap = {};

    // 1. Direct UID Document lookup
    try {
      final docSnap = await _users.doc(rawQuery).get();
      if (docSnap.exists) {
        final profile = UserProfile.fromDoc(docSnap);
        resultMap[profile.uid] = profile;
      }
    } catch (_) {}

    // 2. Lookup by numericId
    try {
      final numSnap = await _users.where('numericId', isEqualTo: rawQuery).limit(5).get();
      for (final doc in numSnap.docs) {
        final profile = UserProfile.fromDoc(doc);
        resultMap[profile.uid] = profile;
      }
    } catch (_) {}

    // 3. Lookup by telegramId
    try {
      final tgSnap = await _users.where('telegramId', isEqualTo: rawQuery).limit(5).get();
      for (final doc in tgSnap.docs) {
        final profile = UserProfile.fromDoc(doc);
        resultMap[profile.uid] = profile;
      }
    } catch (_) {}

    // 4. Lookup by referralCode
    try {
      final refSnap = await _users.where('referralCode', isEqualTo: rawQuery.toUpperCase()).limit(5).get();
      for (final doc in refSnap.docs) {
        final profile = UserProfile.fromDoc(doc);
        resultMap[profile.uid] = profile;
      }
    } catch (_) {}

    // 5. Broad name / email search across recent users
    try {
      final snap = await _users.limit(100).get();
      for (final doc in snap.docs) {
        final u = UserProfile.fromDoc(doc);
        final n = u.name.toLowerCase();
        final dn = (u.displayName ?? '').toLowerCase();
        final e = (u.email ?? '').toLowerCase();
        final numId = u.numericId.toLowerCase();
        final uidLower = u.uid.toLowerCase();

        if (n.contains(clean) ||
            dn.contains(clean) ||
            e.contains(clean) ||
            numId.contains(clean) ||
            uidLower.contains(clean) ||
            uidLower.startsWith(clean)) {
          resultMap[u.uid] = u;
        }
      }
    } catch (_) {}

    return resultMap.values.toList();
  }

  /// Returns unique sorted chatId for two users
  static String getChatId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  /// Streams direct messages between two friends
  Stream<List<ChatMessage>> watchWeeklyChat(String myUid, String friendUid) {
    final chatId = getChatId(myUid, friendUid);
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

    return _db
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList())
        .handleError((_) => <ChatMessage>[]);
  }

  /// Sends a new direct chat message with instant optimistic responsiveness & notification
  Future<void> sendMessage({
    required String myUid,
    required String friendUid,
    required String text,
    required String senderName,
    required String senderAvatar,
    String? photoBase64,
    String? photoUrl,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty && (photoBase64 == null || photoBase64.isEmpty) && (photoUrl == null || photoUrl.isEmpty)) {
      return;
    }

    final chatId = getChatId(myUid, friendUid);
    final chatRef = _db.collection('direct_chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final previewText = cleanText.isNotEmpty
        ? cleanText
        : (photoBase64 != null || photoUrl != null ? '📷 Rasm' : '');

    final notifRef = _users.doc(friendUid).collection('notifications').doc();

    // Write message, update thread, and notify recipient
    await Future.wait([
      msgRef.set({
        'senderUid': myUid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'text': cleanText,
        if (photoBase64 != null && photoBase64.isNotEmpty) 'photoBase64': photoBase64,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      chatRef.set({
        'participants': [myUid, friendUid],
        'lastMessage': previewText,
        'lastSenderUid': myUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      notifRef.set({
        'id': notifRef.id,
        'title': "Sizga do'stingizdan xabar keldi 💬",
        'body': "$senderName: \"$previewText\"",
        'type': 'friend',
        'icon': '💬',
        'senderUid': myUid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    ]);
  }

  /// Sends a PTS gift to a friend via Firestore transaction and sends chat confirmation + notification
  Future<void> sendPtsGift({
    required String myUid,
    required String friendUid,
    required int amount,
    required String senderName,
    required String senderAvatar,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Sovg‘a miqdori kamida 1 PTS bo‘lishi kerak');
    if (myUid == friendUid) throw Exception('O‘zingizga PTS sovg‘a qila olmaysiz');

    await _db.runTransaction((transaction) async {
      final senderDoc = await transaction.get(_users.doc(myUid));
      if (!senderDoc.exists) throw Exception('Foydalanuvchi hisobi topilmadi');

      final senderData = senderDoc.data() ?? {};
      final senderPoints = (senderData['totalPoints'] as num?)?.toInt() ?? 0;

      if (senderPoints < amount) {
        throw Exception('Balansingizda yetarli PTS yo‘q (Mavjud: $senderPoints PTS)');
      }

      final friendDoc = await transaction.get(_users.doc(friendUid));
      if (!friendDoc.exists) throw Exception('Do‘stingiz hisobi topilmadi');

      // Deduct from sender
      transaction.update(_users.doc(myUid), {
        'totalPoints': FieldValue.increment(-amount),
        'weeklyPoints': FieldValue.increment(-amount),
      });

      // Add to recipient
      transaction.update(_users.doc(friendUid), {
        'totalPoints': FieldValue.increment(amount),
        'weeklyPoints': FieldValue.increment(amount),
      });

      // Add message in chat
      final chatId = getChatId(myUid, friendUid);
      final chatRef = _db.collection('direct_chats').doc(chatId);
      final msgRef = chatRef.collection('messages').doc();

      final giftText = note != null && note.isNotEmpty
          ? '🎁 $amount PTS sovg‘a qildi!\n"$note"'
          : '🎁 $amount PTS sovg‘a qildi!';

      transaction.set(msgRef, {
        'senderUid': myUid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'text': giftText,
        'giftAmount': amount,
        'messageType': 'gift',
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        chatRef,
        {
          'participants': [myUid, friendUid],
          'lastMessage': '🎁 $amount PTS sovg‘a yuborildi',
          'lastSenderUid': myUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Notification for friend
      final notifRef = _users.doc(friendUid).collection('notifications').doc();
      transaction.set(notifRef, {
        'id': notifRef.id,
        'title': "Sovg‘a qabul qilindi! 🎁",
        'body': "$senderName sizga $amount PTS sovg‘a qildi! ⚡",
        'type': 'reward',
        'icon': '🎁',
        'senderUid': myUid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Sends a Fenix Coin gift to a friend via Firestore transaction
  Future<void> sendCoinGift({
    required String myUid,
    required String friendUid,
    required int amount,
    required String senderName,
    required String senderAvatar,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Sovg‘a miqdori kamida 1 Coin bo‘lishi kerak');
    if (myUid == friendUid) throw Exception('O‘zingizga Coin sovg‘a qila olmaysiz');

    await _db.runTransaction((transaction) async {
      final senderDoc = await transaction.get(_users.doc(myUid));
      if (!senderDoc.exists) throw Exception('Foydalanuvchi hisobi topilmadi');

      final senderData = senderDoc.data() ?? {};
      final senderCoins = (senderData['fenixCoins'] as num?)?.toInt() ?? 0;

      if (senderCoins < amount) {
        throw Exception('Balansingizda yetarli Fenix Coin yo‘q (Mavjud: $senderCoins Coin)');
      }

      final friendDoc = await transaction.get(_users.doc(friendUid));
      if (!friendDoc.exists) throw Exception('Do‘stingiz hisobi topilmadi');

      // Deduct coins from sender
      transaction.update(_users.doc(myUid), {
        'fenixCoins': FieldValue.increment(-amount),
      });

      // Add coins to recipient
      transaction.update(_users.doc(friendUid), {
        'fenixCoins': FieldValue.increment(amount),
      });

      // Add message in chat
      final chatId = getChatId(myUid, friendUid);
      final chatRef = _db.collection('direct_chats').doc(chatId);
      final msgRef = chatRef.collection('messages').doc();

      final giftText = note != null && note.isNotEmpty
          ? '🪙 $amount Fenix Coin sovg‘a qildi!\n"$note"'
          : '🪙 $amount Fenix Coin sovg‘a qildi!';

      transaction.set(msgRef, {
        'senderUid': myUid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'text': giftText,
        'giftAmount': amount,
        'messageType': 'coin_gift',
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        chatRef,
        {
          'participants': [myUid, friendUid],
          'lastMessage': '🪙 $amount Fenix Coin sovg‘a yuborildi',
          'lastSenderUid': myUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Notification for friend
      final notifRef = _users.doc(friendUid).collection('notifications').doc();
      transaction.set(notifRef, {
        'id': notifRef.id,
        'title': "Fenix Coin sovg‘asi! 🪙",
        'body': "$senderName sizga $amount Fenix Coin sovg‘a qildi!",
        'type': 'reward',
        'icon': '🪙',
        'senderUid': myUid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
