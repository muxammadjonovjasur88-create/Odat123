import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/firebase_providers.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(ref.watch(firestoreProvider));
});

class ReferralRepository {
  ReferralRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _referralsCol =>
      _db.collection('referrals');

  /// Applies a referral code. Credits +100 PTS to referrer and +50 PTS to the joining user!
  Future<bool> applyReferralCode({
    required String currentUid,
    required String code,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) throw Exception('Referal kod kiritilmadi.');

    return await _db.runTransaction((transaction) async {
      // Find the user owning this referral code
      final query = await _usersCol.where('referralCode', isEqualTo: cleanCode).limit(1).get();
      if (query.docs.isEmpty) {
        throw Exception('Bunday referal kod topilmadi.');
      }

      final referrerDoc = query.docs.first;
      final referrerUid = referrerDoc.id;

      if (referrerUid == currentUid) {
        throw Exception('O‘zingizning referal kodingizni kirita olmaysiz.');
      }

      final currentUserRef = _usersCol.doc(currentUid);
      final currentUserSnap = await transaction.get(currentUserRef);
      final currentUserData = currentUserSnap.data() ?? {};

      if (currentUserData['hasUsedReferral'] == true) {
        throw Exception('Siz allaqachon referal koddan foydalangansiz.');
      }

      // 1. Award +100 PTS to Referrer
      transaction.update(referrerDoc.reference, {
        'totalPoints': FieldValue.increment(100),
        'weeklyPoints': FieldValue.increment(100),
        'referralCount': FieldValue.increment(1),
      });

      // 2. Award +50 PTS bonus to current user & mark as used
      transaction.update(currentUserRef, {
        'totalPoints': FieldValue.increment(50),
        'weeklyPoints': FieldValue.increment(50),
        'hasUsedReferral': true,
        'referredBy': referrerUid,
      });

      // 3. Log referral event
      final refLog = _referralsCol.doc();
      transaction.set(refLog, {
        'referrerUid': referrerUid,
        'refereeUid': currentUid,
        'code': cleanCode,
        'createdAt': FieldValue.serverTimestamp(),
        'pointsAwarded': 100,
      });

      debugPrint('🎁 [Referral System] +100 PTS referer ($referrerUid) ga va +50 PTS yangi userga berildi!');
      return true;
    });
  }

  /// Generates or fetches user referral code
  Future<String> getOrCreateReferralCode(UserProfile user) async {
    if (user.uid.isEmpty) return 'ODAT-REF-100';

    final userDoc = await _usersCol.doc(user.uid).get();
    final existing = userDoc.data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final shortId = user.uid.length > 5 ? user.uid.substring(0, 5).toUpperCase() : 'USER';
    final newCode = 'ODAT-REF-$shortId';

    await _usersCol.doc(user.uid).set({
      'referralCode': newCode,
      'referralCount': userDoc.data()?['referralCount'] ?? 0,
    }, SetOptions(merge: true));

    return newCode;
  }
}
