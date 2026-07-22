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

  /// Adds [points] to both lifetime and weekly totals when a focus session is
  /// completed. Weekly points reset when the current week changes.
  Future<void> awardPoints(String uid, int points) => _doc(uid).set({
    'currentWeekId': WeeklyReset.weekIdFor(DateTime.now()),
    'totalPoints': FieldValue.increment(points),
    'weeklyPoints': FieldValue.increment(points),
  }, SetOptions(merge: true));

  /// Updates the user's Premium status.
  Future<void> setPremium(String uid, bool value) =>
      _doc(uid).update({'isPremium': value});

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
