import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';

/// Stores short post-session self-reflections at `users/{uid}/reflections`.
/// Kept deliberately simple — two free-text answers + when.
class ReflectionRepository {
  ReflectionRepository(this._db);

  final FirebaseFirestore _db;

  Future<void> save(
    String uid, {
    required String taskTitle,
    required String wentWell,
    required String distraction,
  }) => _db.collection('users').doc(uid).collection('reflections').add({
    'taskTitle': taskTitle,
    'wentWell': wentWell,
    'distraction': distraction,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

final reflectionRepositoryProvider = Provider<ReflectionRepository>(
  (ref) => ReflectionRepository(ref.watch(firestoreProvider)),
);
