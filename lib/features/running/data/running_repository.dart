import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../domain/models/run_session.dart';

/// Repository handling Firestore persistence for running sessions under `users/{uid}/runSessions`.
class RunningRepository {
  RunningRepository(this._db, this._userRepository);

  final FirebaseFirestore _db;
  final UserRepository _userRepository;

  CollectionReference<Map<String, dynamic>> _runSessionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('runSessions');

  /// Saves a completed run session to Firestore and awards earned points to the user.
  Future<void> saveRunSession(RunSession session) async {
    final docRef = _runSessionsRef(session.userId).doc(session.id);
    await docRef.set(session.toMap());

    if (session.pointsEarned > 0) {
      await _userRepository.awardPoints(session.userId, session.pointsEarned);
    }
  }

  /// Streams the user's completed run sessions ordered by start date.
  Stream<List<RunSession>> watchRunSessions(String uid) {
    return _runSessionsRef(uid)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => RunSession.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }
}

final runningRepositoryProvider = Provider<RunningRepository>(
  (ref) => RunningRepository(
    ref.watch(firestoreProvider),
    ref.watch(userRepositoryProvider),
  ),
);
