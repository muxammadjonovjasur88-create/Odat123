import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../domain/models/exercise_session.dart';

/// Repository saving exercise sessions to `users/{uid}/exerciseSessions`.
class ExerciseRepository {
  ExerciseRepository(this._db, this._userRepository);

  final FirebaseFirestore _db;
  final UserRepository _userRepository;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('exerciseSessions');

  /// Saves a completed exercise session to Firestore and awards earned points.
  Future<void> saveExerciseSession(ExerciseSession session) async {
    final docRef = _sessionsRef(session.userId).doc(session.id);
    await docRef.set(session.toMap());

    if (session.pointsEarned > 0) {
      await _userRepository.awardPoints(session.userId, session.pointsEarned);
    }
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(
    ref.watch(firestoreProvider),
    ref.watch(userRepositoryProvider),
  ),
);
