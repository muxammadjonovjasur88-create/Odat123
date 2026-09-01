import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/gamification/domain/weekly_reset.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';
import 'firebase_providers.dart';

/// Reads/writes the `users/{uid}` Firestore documents.
class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// Live profile for [uid]; emits null until the document exists.
  Stream<UserProfile?> watchProfile(String uid) => _doc(
    uid,
  ).snapshots().map((s) => s.exists ? UserProfile.fromDoc(s) : null);

  Future<UserProfile?> fetchProfile(String uid) async {
    final snap = await _doc(uid).get();
    return snap.exists ? UserProfile.fromDoc(snap) : null;
  }

  /// Creates the profile document on first login. [UserProfile.toCreateMap]
  /// seeds streak/points to 0 and stamps a server `createdAt`.
  Future<void> createProfile(UserProfile profile) =>
      _doc(profile.uid).set(profile.toCreateMap());

  /// Updates the user's role (personal / parent / child).
  Future<void> updateRole(String uid, {required String appRole, String? familyRole}) async {
    await _doc(uid).set({
      'appRole': appRole,
      'familyRole': familyRole,
      'roleSelected': true,
    }, SetOptions(merge: true));
  }

  static final Map<String, List<Map<String, dynamic>>> _recentPointAwards = {};

  /// Adds [points] to both lifetime and weekly totals when a focus session or quest
  /// is completed. Automatically applies active booster multiplier (e.g. 1.5x, 2.0x) if active.
  /// Strictly checks Anti-Cheat: if user earns >10,000 PTS in 1 minute, auto-bans the user.
  Future<void> awardPoints(String uid, int points) async {
    // 🛡️ Anti-Cheat Window Validation (1 minute > 10,000 PTS)
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(minutes: 1));

    _recentPointAwards.putIfAbsent(uid, () => []);
    _recentPointAwards[uid]!.removeWhere((entry) => (entry['time'] as DateTime).isBefore(windowStart));
    _recentPointAwards[uid]!.add({'time': now, 'points': points});

    final totalLastMinute = _recentPointAwards[uid]!.fold<int>(0, (acc, entry) => acc + (entry['points'] as int));

    if (totalLastMinute > 10000) {
      await _doc(uid).set({
        'isBanned': true,
        'banReason': 'Anti-Cheat: 1 daqiqa ichida $totalLastMinute PTS g‘ayritabiiy oshirildi',
        'bannedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('security_alerts').add({
        'uid': uid,
        'type': 'EXCESSIVE_PTS_EXPLOIT',
        'pointsLastMinute': totalLastMinute,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'AUTO_BANNED',
      });
      return;
    }

    int finalPoints = points;
    try {
      final snap = await _doc(uid).get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        if (data['isBanned'] == true) return; // Prevent banned accounts from earning

        final boosterMul = (data['boosterMultiplier'] as num?)?.toDouble() ?? 1.0;
        final expiresAt = (data['boosterExpiresAt'] as Timestamp?)?.toDate();
        if (boosterMul > 1.0 && expiresAt != null && expiresAt.isAfter(DateTime.now())) {
          finalPoints = (points * boosterMul).round();
        }
      }
    } catch (_) {}

    await _doc(uid).set({
      'currentWeekId': WeeklyReset.weekIdFor(DateTime.now()),
      'totalPoints': FieldValue.increment(finalPoints),
      'weeklyPoints': FieldValue.increment(finalPoints),
    }, SetOptions(merge: true));
  }

  /// Deducts [points] from user balance. Points are allowed to go negative
  /// (e.g. -200 PTS) and user drops rank in leaderboard accordingly.
  Future<void> deductPoints(String uid, int points) async {
    await _doc(uid).set({
      'currentWeekId': WeeklyReset.weekIdFor(DateTime.now()),
      'totalPoints': FieldValue.increment(-points),
      'weeklyPoints': FieldValue.increment(-points),
    }, SetOptions(merge: true));
  }

  /// Unlocks a music track with PTS: deducts points and saves trackId to unlockedTracks list.
  Future<bool> unlockMusicTrack(String uid, String trackId, int ptsCost) async {
    final docRef = _doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return false;

    final data = snap.data() ?? {};
    final unlocked = (data['unlockedTracks'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (unlocked.contains(trackId)) {
      return true; // Already unlocked
    }

    final totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
    if (ptsCost > 0 && totalPoints < ptsCost) {
      return false; // Insufficient balance
    }

    await docRef.set({
      'unlockedTracks': FieldValue.arrayUnion([trackId]),
      if (ptsCost > 0) 'totalPoints': FieldValue.increment(-ptsCost),
      if (ptsCost > 0) 'weeklyPoints': FieldValue.increment(-ptsCost),
    }, SetOptions(merge: true));
    return true;
  }

  /// Exchanges Fenix Coins to PTS at rate: 1 Fenix Coin = 10 PTS
  Future<bool> exchangeCoinsToPts(String uid, int coinsToSpend) async {
    if (coinsToSpend < 1) return false;
    final ptsToAdd = coinsToSpend * 10;

    final docRef = _doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return false;
    final data = snap.data() ?? {};
    final currentCoins = (data['fenixCoins'] as num?)?.toInt() ?? 0;
    if (currentCoins < coinsToSpend) return false;

    await docRef.set({
      'fenixCoins': FieldValue.increment(-coinsToSpend),
      'totalPoints': FieldValue.increment(ptsToAdd),
      'weeklyPoints': FieldValue.increment(ptsToAdd),
    }, SetOptions(merge: true));

    // Record in PTS History
    try {
      await docRef.collection('pts_history').add({
        'title': '🪙 $coinsToSpend Coin almashtirildi',
        'amount': ptsToAdd,
        'type': 'earn',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return true;
  }

  /// Claims a badge reward points once, preventing duplicate claims.
  Future<bool> claimBadge(String uid, String badgeId, int rewardPoints) async {
    final docRef = _doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return false;

    final data = snap.data() ?? {};
    final claimed = (data['claimedBadges'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (claimed.contains(badgeId)) {
      return false; // Already claimed!
    }

    int finalReward = rewardPoints;
    final boosterMul = (data['boosterMultiplier'] as num?)?.toDouble() ?? 1.0;
    final expiresAt = (data['boosterExpiresAt'] as Timestamp?)?.toDate();
    if (boosterMul > 1.0 && expiresAt != null && expiresAt.isAfter(DateTime.now())) {
      finalReward = (rewardPoints * boosterMul).round();
    }

    await docRef.set({
      'claimedBadges': FieldValue.arrayUnion([badgeId]),
      'totalPoints': FieldValue.increment(finalReward),
      'weeklyPoints': FieldValue.increment(finalReward),
    }, SetOptions(merge: true));
    return true;
  }

  /// Updates user streak (e.g. Day 1 claim or daily completion)
  Future<void> updateStreak(String uid, int streak) async {
    await _doc(uid).set({
      'streak': streak,
      'longestStreak': FieldValue.increment(0),
      'lastActiveDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Records a claimed streak reward day into Firestore so it survives reinstalls/device switches
  Future<void> claimStreakDay(String uid, int day, int month, int year) async {
    final monthKey = 'claimed_streak_${year}_$month';
    await _doc(uid).set({
      monthKey: FieldValue.arrayUnion([day]),
      'streak': day,
      'longestStreak': FieldValue.increment(0),
      'lastActiveDate': FieldValue.serverTimestamp(),
      'activeDaysCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Gets claimed streak days for a given month from Firestore
  Future<List<int>> getClaimedStreakDays(String uid, int month, int year) async {
    try {
      final snap = await _doc(uid).get();
      final data = snap.data();
      final monthKey = 'claimed_streak_${year}_$month';
      final raw = data?[monthKey] as List<dynamic>? ?? [];
      return raw.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Activates a PTS Booster (e.g. 1.25x, 1.5x, 2.0x, 2.5x, 3.0x)
  Future<void> activateBooster(String uid, double multiplier, int durationMinutes, int coinsCost) async {
    final expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));
    await _doc(uid).set({
      'boosterMultiplier': multiplier,
      'boosterExpiresAt': Timestamp.fromDate(expiresAt),
      if (coinsCost > 0) 'fenixCoins': FieldValue.increment(-coinsCost),
    }, SetOptions(merge: true));
  }

  /// Adds [coins] to the user's Fenix Coins balance.
  Future<void> addFenixCoins(String uid, int coins) => _doc(uid).set({
    'fenixCoins': FieldValue.increment(coins),
  }, SetOptions(merge: true));

  /// Buys and activates a PTS Booster with PTS points
  Future<bool> buyBoosterWithPts(String uid, double multiplier, int durationMinutes, int ptsCost) async {
    final docRef = _doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return false;
    final totalPoints = (snap.data()?['totalPoints'] as num?)?.toInt() ?? 0;
    if (totalPoints < ptsCost) return false;

    final expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));
    await docRef.set({
      'boosterMultiplier': multiplier,
      'boosterExpiresAt': Timestamp.fromDate(expiresAt),
      'totalPoints': FieldValue.increment(-ptsCost),
      'weeklyPoints': FieldValue.increment(-ptsCost),
    }, SetOptions(merge: true));

    try {
      await docRef.collection('pts_history').add({
        'title': '⚡ ${multiplier}x Ball Busteri xarid qilindi',
        'amount': -ptsCost,
        'type': 'spend',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return true;
  }

  /// Buys Streak Freeze with PTS points
  Future<bool> buyFreezeWithPts(String uid, int count, int ptsCost) async {
    final docRef = _doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return false;
    final totalPoints = (snap.data()?['totalPoints'] as num?)?.toInt() ?? 0;
    if (totalPoints < ptsCost) return false;

    await docRef.set({
      'freezes': FieldValue.increment(count),
      'totalPoints': FieldValue.increment(-ptsCost),
      'weeklyPoints': FieldValue.increment(-ptsCost),
    }, SetOptions(merge: true));

    try {
      await docRef.collection('pts_history').add({
        'title': '❄️ $count ta Streak Muzlatgich xarid qilindi',
        'amount': -ptsCost,
        'type': 'spend',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return true;
  }

  /// Buys Name Change Pass with PTS points
  Future<bool> buyNameChangePassWithPts(String uid, int ptsCost) async {
    final docRef = _doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return false;
    final totalPoints = (snap.data()?['totalPoints'] as num?)?.toInt() ?? 0;
    if (totalPoints < ptsCost) return false;

    await docRef.set({
      'nameChangePasses': FieldValue.increment(1),
      'totalPoints': FieldValue.increment(-ptsCost),
      'weeklyPoints': FieldValue.increment(-ptsCost),
    }, SetOptions(merge: true));

    try {
      await docRef.collection('pts_history').add({
        'title': '🏷️ Ismni o‘zgartirish taloni xarid qilindi',
        'amount': -ptsCost,
        'type': 'spend',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return true;
  }

  /// Adds [count] to user freezes.
  Future<void> addFreezes(String uid, int count) => _doc(uid).set({
    'freezes': FieldValue.increment(count),
  }, SetOptions(merge: true));

  /// Buys Streak Freezes
  Future<void> buyFreeze(String uid, int count, int coinsCost) => _doc(uid).set({
    'freezes': FieldValue.increment(count),
    if (coinsCost > 0) 'fenixCoins': FieldValue.increment(-coinsCost),
  }, SetOptions(merge: true));

  /// Deducts [coins] from the user's Fenix Coins balance.
  Future<void> deductFenixCoins(String uid, int coins) => _doc(uid).set({
    'fenixCoins': FieldValue.increment(-coins),
  }, SetOptions(merge: true));

  /// Updates the user's Premium status and records payment details if provided.
  Future<void> setPremium(
    String uid,
    bool value, {
    String? plan,
    String? paymentMethod,
    int? amountUzs,
    DateTime? expiresAt,
  }) async {
    final Map<String, dynamic> updateData = {
      'isPremium': value,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (value) {
      updateData['premiumSince'] = FieldValue.serverTimestamp();
      if (plan != null) updateData['premiumPlan'] = plan;
      if (paymentMethod != null) updateData['lastPaymentMethod'] = paymentMethod;
      if (expiresAt != null) {
        updateData['premiumExpiresAt'] = Timestamp.fromDate(expiresAt);
      }

      // Record transaction history in subcollection
      try {
        await _doc(uid).collection('payments').add({
          'type': 'premium_subscription',
          'plan': plan ?? 'monthly',
          'amountUzs': amountUzs ?? (plan == 'yearly' ? 390000 : 40000),
          'paymentMethod': paymentMethod ?? 'in_app',
          'status': 'completed',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        });
      } catch (_) {
        // Continue even if history record fails
      }
    }

    await _doc(uid).set(updateData, SetOptions(merge: true));
  }


  /// Toggles a like for [targetUserId] by [currentUserId].
  /// - If [currentUserId] has already liked, removes the like and decrements likesCount.
  /// - If not liked, adds a like and increments likesCount.
  /// Uses a WriteBatch for atomicity (prevent race conditions).
  /// Returns early if [currentUserId] tries to like their own profile.
  Future<void> toggleLike(String targetUserId, String currentUserId) async {
    if (targetUserId == currentUserId) {
      throw Exception('Cannot like your own profile');
    }

    final batch = _db.batch();
    final likeDocRef = _doc(targetUserId).collection('likedBy').doc(currentUserId);
    final userDocRef = _doc(targetUserId);

    // Check if the like already exists
    final likeDoc = await likeDocRef.get();

    if (likeDoc.exists) {
      // Already liked: remove and decrement
      batch.delete(likeDocRef);
      batch.update(userDocRef, {
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Not liked: add and increment
      batch.set(likeDocRef, {'timestamp': FieldValue.serverTimestamp()});
      batch.update(userDocRef, {
        'likesCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  /// Checks if [currentUserId] has liked [targetUserId]'s profile.
  Future<bool> hasLiked(String targetUserId, String currentUserId) async {
    final doc = await _doc(targetUserId).collection('likedBy').doc(currentUserId).get();
    return doc.exists;
  }

  /// Updates the user's bio and goal details
  Future<void> updateUserProfile(
    String uid, {
    String? bio,
    String? goalTitle,
    String? why,
  }) {
    final data = <String, dynamic>{};
    if (bio != null) data['bio'] = bio;
    if (goalTitle != null) data['goalTitle'] = goalTitle;
    if (why != null) data['goalWhy'] = why;
    return _doc(uid).set(data, SetOptions(merge: true));
  }

  /// Saves (or clears) the user's intention — their goal, their own reason for
  /// it, and an optional target date.
  Future<void> setAspiration(
    String uid, {
    String? title,
    String? why,
    DateTime? targetDate,
  }) => _doc(uid).update({
    'goalTitle': title,
    'goalWhy': why,
    'goalTargetDate': targetDate == null
        ? null
        : Timestamp.fromDate(targetDate),
  });

  Future<void> updateProfile(
    String uid, {
    String? displayName,
    String? bio,
    String? photoUrl,
    String? photoBase64,
  }) => _doc(uid).set({
    'displayName': displayName,
    'name': displayName,
    'bio': bio,
    'photoUrl': photoUrl,
    'photoBase64': photoBase64,
  }..removeWhere((key, value) => value == null), SetOptions(merge: true));

  // ---------------------------------------------------------------------------
  // Telegram
  // ---------------------------------------------------------------------------

  /// Telegram chat_id ni saqlaydi (bot webhook orqali ham yoki to'g'ridan-to'g'ri).
  Future<void> saveTelegramChatId(String uid, String chatId) =>
      _doc(uid).update({'telegramChatId': chatId});

  /// Telegram ulanishini bekor qiladi.
  Future<void> disconnectTelegram(String uid) =>
      _doc(uid).update({'telegramChatId': FieldValue.delete()});

  // ---------------------------------------------------------------------------
  // Do'stlar (sharedWith)
  // ---------------------------------------------------------------------------

  /// Ikki foydalanuvchini bir-birining `sharedWith` ro'yxatiga qo'shadi.
  Future<void> addFriend(String myUid, String friendUid) {
    final batch = _db.batch();
    batch.update(_doc(myUid), {
      'sharedWith': FieldValue.arrayUnion([friendUid]),
    });
    batch.update(_doc(friendUid), {
      'sharedWith': FieldValue.arrayUnion([myUid]),
    });
    return batch.commit();
  }

  /// Ikki foydalanuvchini bir-birining `sharedWith` ro'yxatidan chiqaradi.
  Future<void> removeFriend(String myUid, String friendUid) {
    final batch = _db.batch();
    batch.update(_doc(myUid), {
      'sharedWith': FieldValue.arrayRemove([friendUid]),
    });
    batch.update(_doc(friendUid), {
      'sharedWith': FieldValue.arrayRemove([myUid]),
    });
    return batch.commit();
  }

  /// Do'stlar profillarini bir marta o'qib qaytaradi.
  Future<List<UserProfile>> fetchFriends(List<String> uids) async {
    if (uids.isEmpty) return [];
    // Firestore 'whereIn' 30 ta limitga ega; amaliy holatda kichik ro'yxat.
    final snaps = await Future.wait(uids.map((uid) => _doc(uid).get()));
    return snaps
        .where((s) => s.exists)
        .map((s) => UserProfile.fromDoc(s))
        .toList();
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

/// The signed-in user's profile, or null if they haven't completed setup.
/// Rebuilds when auth state changes (login / logout).
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchProfile(user.uid);
});
