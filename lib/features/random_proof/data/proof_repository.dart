import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/firebase_providers.dart';
import '../domain/proof_session.dart';

/// Firestore `proofSessions` kolleksiyasiga kirish.
class ProofRepository {
  ProofRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('proofSessions');

  // ---------------------------------------------------------------------------
  // O'z sessiyalarim
  // ---------------------------------------------------------------------------

  /// Bugungi kunning barcha sessiyalarini real-time stream qilib qaytaradi.
  Stream<List<ProofSession>> watchTodaySessions(String uid) {
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day);
    final end = start.add(const Duration(days: 1));

    return _col
        .where('userId', isEqualTo: uid)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) =>
                  ProofSession.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Do'stlarning sessiyalari
  // ---------------------------------------------------------------------------

  /// [friendUid] foydalanuvchisining bugungi ProofSession'larini qaytaradi.
  /// Firestore Security Rules orqali faqat `sharedWith`da bo'lgan
  /// foydalanuvchilar o'qiy oladi.
  Stream<List<ProofSession>> watchFriendTodaySessions(String friendUid) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _col
        .where('userId', isEqualTo: friendUid)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) =>
                  ProofSession.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
              .toList(),
        );
  }

  /// Bir ProofSession ni ID bo'yicha kuzatish.
  Stream<ProofSession?> watchSession(String sessionId) =>
      _col.doc(sessionId).snapshots().map((s) =>
          s.exists ? ProofSession.fromDoc(s) : null);
}

final proofRepositoryProvider = Provider<ProofRepository>(
  (ref) => ProofRepository(ref.watch(firestoreProvider)),
);

/// Bugungi o'z sessiyalari.
final todayProofSessionsProvider = StreamProvider<List<ProofSession>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(proofRepositoryProvider).watchTodaySessions(uid);
});

/// Do'stning bugungi sessiyalari.
final friendProofSessionsProvider =
    StreamProvider.family<List<ProofSession>, String>((ref, friendUid) {
  return ref.watch(proofRepositoryProvider).watchFriendTodaySessions(friendUid);
});
